extends Node2D
## PASOS 3, 4 y 5 de la intro, dentro de la Base Ares 1:
##   3. A.R.I.A. da la alerta y la tripulación decide que 3 deben dormir  (data/intro/intro_dialogue.json)
##   4. El jugador elige quién se queda despierto                          (role_select.gd + data/intro/roles.json)
##   5. Despedida: los otros 3 entran en las cápsulas de criosueño y se pasa a la jugabilidad
##      (GameState.GAMEPLAY_SCENE). El rol elegido queda en GameState.selected_role / role_data / crew.

const Style := preload("res://scripts/intro/intro_style.gd")
const Room := preload("res://scripts/intro/interior_room.gd")
const DialogueBox := preload("res://scripts/intro/dialogue_box.gd")
const RoleSelect := preload("res://scripts/intro/role_select.gd")
const Fader := preload("res://scripts/intro/screen_fader.gd")

const DIALOGUE_FILE := "res://data/intro/intro_dialogue.json"
const WALK_SPEED := 190.0
## Dónde está cada tripulante alrededor de la mesa y hacia dónde mira.
const STAND := {
	"engineer": [Vector2(470, 475), "side", false],
	"biologist": [Vector2(810, 475), "side", true],
	"medic": [Vector2(575, 360), "down", false],
	"astrophysicist": [Vector2(705, 360), "down", false],
}
## Lugar final del jugador, frente a la mesa.
const PLAYER_SPOT := Vector2(640, 600)

var roles: Dictionary = {}
var order: Array = []
var dialogue: Dictionary = {}

var room: Room
var crew := {}            # role_id -> AnimatedSprite2D
var camera := Camera2D.new()
var light := CanvasModulate.new()
var ui := Control.new()
var box: DialogueBox
var fader: Fader
var _marker: Polygon2D    # flecha sobre quien habla

var _alarm := false
var _base_light := Color.WHITE
var _shake := 0.0
var _t := 0.0
var _in_dialogue := false
var _skip := false


func _ready() -> void:
	var roles_data := GameState.load_roles()
	roles = roles_data.get("roles", {})
	order = roles_data.get("order", roles.keys())
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_FILE))
	dialogue = parsed if parsed is Dictionary else {}

	room = Room.new()
	add_child(room)
	add_child(light)
	_build_crew()

	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	box = DialogueBox.new()
	box.hide()
	ui.add_child(box)

	fader = Fader.new()
	add_child(fader)
	fader.set_black(true)
	_run(roles_data)


func _build_crew() -> void:
	for id in order:
		var r: Dictionary = roles[id]
		# Cada tripulante con su propio sprite (biólogo, ingeniero, médico, astrofísico)
		var a := Style.make_astronaut(Color.html(r.get("color", "#ffffff")), 1.4)
		a.sprite_frames = GameState.frames_for(id)
		a.material = null
		var s: Array = STAND.get(id, [Vector2(640, 500), "down", false])
		a.position = s[0]
		a.play("idle_" + s[1])
		a.flip_h = s[2]
		var tag := Style.label(str(r.get("crew_name", id)).get_slice(" ", 0), 13, Color.html(r.get("color", "#ffffff")), 4)
		tag.size = Vector2(120, 20)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.scale = Vector2.ONE / a.scale  # que el texto no se escale con el sprite
		tag.position = Vector2(-60, 4) / a.scale
		a.add_child(tag)
		add_child(a)
		crew[id] = a

	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([Vector2(-10, -8), Vector2(10, -8), Vector2(0, 6)])
	_marker.color = Style.AMBER
	_marker.visible = false
	_marker.z_index = 10
	add_child(_marker)


# ---------------------------------------------------------------- secuencia principal

func _run(roles_data: Dictionary) -> void:
	await fader.fade_in(1.0)

	# 3) Alerta y conversación
	await _play_lines(dialogue.get("intro", []))
	box.hide()
	_set_speaker("")
	_alarm = false
	room.alarm = false

	# 4) Selección de personaje
	var picker := RoleSelect.new()
	picker.setup(roles_data)
	ui.add_child(picker)
	var role_id: String = await picker.role_chosen
	GameState.choose_role(role_id)
	var tw := create_tween()
	tw.tween_property(picker, "modulate:a", 0.0, 0.35)
	await tw.finished
	picker.queue_free()
	crew[role_id].play("celebrate")

	# 5) Despedida, criosueño y salida
	await _play_lines(_build_farewell(role_id))
	box.hide()
	_set_speaker("")
	await _sleep_sequence(role_id)
	await _play_lines(dialogue.get("ending", []))
	box.hide()
	await _final_shot(role_id)
	get_tree().change_scene_to_file(GameState.GAMEPLAY_SCENE)


## Construye las líneas de despedida sustituyendo "player" y "sleeper" por tripulantes reales.
func _build_farewell(role_id: String) -> Array:
	var out: Array = []
	var sleeper_lines: Array = dialogue.get("sleeper_lines", ["Good luck, {player}!"])
	var k := 0
	for line in dialogue.get("farewell", []):
		match line.get("speaker", ""):
			"player":
				var l: Dictionary = line.duplicate()
				l.speaker = role_id
				out.append(l)
			"sleeper":
				for id in order:
					if id == role_id:
						continue
					out.append({"speaker": id, "text": sleeper_lines[k % sleeper_lines.size()]})
					k += 1
			_:
				out.append(line)
	return out


# ---------------------------------------------------------------- diálogo

func _play_lines(lines: Array) -> void:
	_in_dialogue = true
	_skip = false
	for line in lines:
		if _skip:
			break
		_run_event(line.get("event", ""))
		var who: String = line.get("speaker", "aria")
		_set_speaker(who)
		var text := _fill(str(line.get("text", "")))
		if who == "aria":
			var a: Dictionary = dialogue.get("speakers", {}).get("aria", {})
			room.aria_talking = true
			await box.say(a.get("name", "A.R.I.A."), Color.html(a.get("color", "#5ef2e4")), text, Style.aria_portrait())
			room.aria_talking = false
		else:
			var r: Dictionary = roles.get(who, {})
			var col := Color.html(r.get("color", "#ffffff"))
			var speaker_name := "%s  ·  %s" % [r.get("crew_name", who), r.get("title", "")]
			var face := GameState.portrait_for(who)
			if face:
				await box.say(speaker_name, col, text, face)
			else:
				await box.say(speaker_name, col, text, Style.astronaut_frame(0), Style.suit_material(col))
	_in_dialogue = false
	room.aria_talking = false


func _fill(text: String) -> String:
	var name_ := str(GameState.role_data.get("crew_name", "Commander")).get_slice(" ", 0)
	return text.format({"player": name_, "player_role": str(GameState.role_data.get("title", "")).capitalize()})


func _set_speaker(id: String) -> void:
	if not crew.has(id):
		_marker.visible = false
		return
	var a: AnimatedSprite2D = crew[id]
	_marker.visible = true
	_marker.position = a.position + Vector2(0, -150)
	# pequeño salto del que habla
	var tw := create_tween()
	tw.tween_property(a, "offset:y", -55.0, 0.08)
	tw.tween_property(a, "offset:y", -47.0, 0.12)


func _run_event(ev: String) -> void:
	match ev:
		"alarm_on":
			_alarm = true
			room.alarm = true
			_shake = 8.0
		"alarm_off":
			_alarm = false
			room.alarm = false
		"shake":
			_shake = 12.0
		"lights_dim":
			create_tween().tween_property(self, "_base_light", Color(0.6, 0.66, 0.9), 1.5)


# ---------------------------------------------------------------- criosueño y salida

func _sleep_sequence(role_id: String) -> void:
	var longest := 0.0
	var delay := 0.0
	for i in order.size():
		var id: String = order[i]
		if id == role_id:
			continue
		longest = maxf(longest, _send_to_pod(id, i, delay))
		delay += 0.5
	# El jugador camina al frente de la mesa mientras tanto
	var me: AnimatedSprite2D = crew[role_id]
	_walk(me, PLAYER_SPOT, 0.8)
	await get_tree().create_timer(longest + 0.6).timeout
	me.flip_h = false
	me.play("idle_down")


## Hace caminar al tripulante hasta su cápsula, entrar y cerrarla. Devuelve la duración total.
func _send_to_pod(id: String, pod: int, delay: float) -> float:
	var a: AnimatedSprite2D = crew[id]
	var entry: Vector2 = room.pod_entry(pod)
	var walk_t := _walk(a, entry, delay)
	var tw := create_tween()
	tw.tween_interval(delay + walk_t)
	tw.tween_callback(a.play.bind("walk_up"))
	tw.tween_property(a, "position:y", entry.y - 50, 0.4)
	tw.parallel().tween_property(a, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_label_pod.bind(pod, id))
	tw.tween_method(room.set_pod_frost.bind(pod), 0.0, 1.0, 1.0)
	return delay + walk_t + 1.4


## Camina en línea recta con la animación adecuada. Devuelve la duración del trayecto.
func _walk(a: AnimatedSprite2D, to: Vector2, delay := 0.0) -> float:
	var d := to - a.position
	var dur := d.length() / WALK_SPEED
	var anim := "walk_side"
	if absf(d.y) > absf(d.x):
		anim = "walk_down" if d.y > 0 else "walk_up"
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_start_anim.bind(a, anim, anim == "walk_side" and d.x < 0))
	tw.tween_property(a, "position", to, dur)
	tw.tween_callback(a.play.bind("idle_" + anim.trim_prefix("walk_")))
	return dur


func _start_anim(a: AnimatedSprite2D, anim: String, flip: bool) -> void:
	a.flip_h = flip
	a.play(anim)


func _label_pod(pod: int, id: String) -> void:
	room.pod_labels[pod] = str(roles[id].get("crew_name", "")).get_slice(" ", 0)


func _final_shot(role_id: String) -> void:
	var me: AnimatedSprite2D = crew[role_id]
	var tw := create_tween().set_parallel()
	tw.tween_property(camera, "zoom", Vector2.ONE * 1.7, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "position", me.position + Vector2(0, -70), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	me.play("celebrate")
	var card := Style.label("YOU ARE IN COMMAND", 54, Style.AMBER, 12)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.offset_left = -500
	card.offset_right = 500
	card.offset_top = 70
	card.modulate.a = 0.0
	ui.add_child(card)
	var sub := Style.label("Keep Energy, Oxygen, Health and Research in balance until the storm passes.", 20, Style.WHITE, 5)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.offset_left = -600
	sub.offset_right = 600
	sub.offset_top = 140
	sub.modulate.a = 0.0
	ui.add_child(sub)
	var t2 := create_tween()
	t2.tween_interval(0.8)
	t2.tween_property(card, "modulate:a", 1.0, 0.6)
	t2.tween_property(sub, "modulate:a", 1.0, 0.6)
	t2.tween_interval(2.4)
	await t2.finished
	await fader.fade_out(1.2)


# ---------------------------------------------------------------- por frame / entrada

func _process(delta: float) -> void:
	_t += delta
	var c := _base_light
	if _alarm:
		c = c.lerp(Color(1, 0.5, 0.45), 0.5 + 0.5 * sin(_t * 7.0))
	light.color = c
	_shake = move_toward(_shake, 0.0, delta * 10.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if _marker.visible:
		_marker.position.y += sin(_t * 8.0) * 0.6


func _unhandled_input(event: InputEvent) -> void:
	if _in_dialogue and event.is_action_pressed("ui_cancel"):
		_skip = true
		box.force_advance()
		get_viewport().set_input_as_handled()
