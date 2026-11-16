extends Node
## Autoload "Audio": música de ambiente y efectos de sonido.
##   - Música: assets/music/calm_retro.mp3 en bucle, bajita, siempre (menú, juego, minijuegos y pausas).
##   - Efectos sueltos:   Audio.play("regar")              (assets/sounds/<nombre>.mp3)
##   - Efectos en bucle:  Audio.set_loop("excavator", true)  en cada frame mientras pasa algo (taladrar,
##                        correr...). Si se deja de pedir (o se cambia de escena) se apaga solo.
##   - Tormenta: tormenta.mp3 en bucle mientras hay tormenta (Mission), más fuerte según la intensidad y
##     más baja y apagada (filtro) dentro de la estación.
## Volúmenes en dB en VOLUME (0 = el archivo tal cual).

const MUSIC := "res://assets/music/calm_retro.mp3"
const SOUNDS := "res://assets/sounds/%s.mp3"
const MUSIC_DB := -16.0
const VOLUME := {
	"driving": -4.0, "parking": -4.0, "panel_cleaning": -8.0, "excavator": -8.0, "gym_running": -8.0,
	"regar": -4.0, "switch": -2.0, "scanning": -6.0, "space_rocket_launch": -4.0, "tormenta": 0.0,
}
## Tormenta: dB según intensidad, y cuánto baja dentro de la estación.
const STORM_DB := {"light": -18.0, "moderate": -11.0, "intense": -5.0}
const STORM_INSIDE_DB := -8.0
const FADE_DB_PER_S := 12.0

var _music := AudioStreamPlayer.new()
var _storm := AudioStreamPlayer.new()
var _storm_filter := AudioEffectLowPassFilter.new()
var _loops := {}            # nombre -> AudioStreamPlayer
var _asked := {}            # nombre -> frame en que se pidió por última vez
var _cache := {}            # nombre -> AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la música sigue aunque el juego esté en pausa
	for bus in ["Music", "SFX", "Storm"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_storm_filter.cutoff_hz = 700.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Storm"), _storm_filter)

	var m: AudioStreamMP3 = load(MUSIC)
	m.loop = true
	_music.stream = m
	_music.bus = "Music"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_music.play()

	_storm.stream = _stream("tormenta", true)
	_storm.bus = "Storm"
	_storm.volume_db = -60.0
	add_child(_storm)


func _stream(name: String, loop := false) -> AudioStream:
	var key := name + ("#loop" if loop else "")
	if not _cache.has(key):
		var s: AudioStreamMP3 = load(SOUNDS % name).duplicate()
		s.loop = loop
		_cache[key] = s
	return _cache[key]


## Efecto de sonido de una vez.
func play(name: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(name)
	p.bus = "SFX"
	p.volume_db = VOLUME.get(name, 0.0) + volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Enciende o apaga un efecto en bucle. Para que siga sonando hay que pedirlo en cada frame.
func set_loop(name: String, on: bool, volume_db := 0.0) -> void:
	if on:
		_asked[name] = Engine.get_process_frames()
		if not _loops.has(name):
			var p := AudioStreamPlayer.new()
			p.stream = _stream(name, true)
			p.bus = "SFX"
			add_child(p)
			p.play()
			_loops[name] = p
		_loops[name].volume_db = VOLUME.get(name, 0.0) + volume_db
	elif _loops.has(name):
		_loops[name].queue_free()
		_loops.erase(name)


func stop_loops() -> void:
	for name in _loops.keys():
		set_loop(name, false)


func _process(delta: float) -> void:
	# los bucles que nadie pidió en los últimos frames (otra escena, pausa...) se apagan
	for name in _loops.keys():
		if Engine.get_process_frames() - int(_asked.get(name, 0)) > 3:
			set_loop(name, false)
	_update_storm(delta)


func _update_storm(delta: float) -> void:
	var target := -60.0
	if Mission.storm_active() and Mission.is_running():  # no en el menú ni en los finales
		target = STORM_DB.get(Mission.storm.get("type", ""), -12.0)
		var inside := Mission.location() == "inside"
		if inside:
			target += STORM_INSIDE_DB
		_storm_filter.cutoff_hz = 700.0 if inside else 20000.0
	if target > -60.0 and not _storm.playing:
		_storm.play()
	_storm.volume_db = move_toward(_storm.volume_db, target, FADE_DB_PER_S * delta)
	if _storm.volume_db <= -59.0 and target <= -60.0 and _storm.playing:
		_storm.stop()
