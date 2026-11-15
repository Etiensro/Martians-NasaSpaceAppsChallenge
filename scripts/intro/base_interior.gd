extends Node2D
## PASOS 3, 4 y 5 de la intro, dentro de la Base Ares 1:
##   3. A.R.I.A. da la alerta y la tripulación decide que 3 deben dormir  (data/intro/intro_dialogue.json)
##   4. El jugador elige quién se queda despierto                          (role_select.gd + data/intro/roles.json)
##   5. Despedida: los otros 3 entran en las cápsulas de criosueño y se pasa a la jugabilidad
##      (GameState.GAMEPLAY_SCENE). El rol elegido queda en GameState.selected_role / role_data / crew.

const Style := preload("res://scripts/core/style.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Room := preload("res://scripts/intro/interior_room.gd")
const DialogueBox := preload("res://scripts/intro/dialogue_box.gd")
const RoleSelect := preload("res://scripts/intro/role_select.gd")

const DIALOGUE_FILE := "res://data/intro/intro_dialogue.json"
const CREW_SCALE := 1.4
const WALK_SPEED := 190.0
## Dónde está cada tripulante alrededor de la mesa y hacia dónde mira: [posición, dirección, mira a la izquierda]
const STAND := {
	"engineer": [Vector2(470, 475), "side", false],
	"biologist": [Vector2(810, 475), "side", true],
	"medic": [Vector2(575, 360), "down", false],
	"astrophysicist": [Vector2(705, 360), "down", false],
}
## Lugar final del jugador, frente a la mesa.
const PLAYER_SPOT := Vector2(640, 600)

@export var room_texture: Texture2D  # interior final 1280x720 (sustituye el dibujo provisional)

var dialogue: Dictionary = {}
var room: Room
var crew := {}  # role_id -> AnimatedSprite2D
var camera := Camera2D.new()
var light := CanvasModulate.new()
var ui := Control.new()
var box: DialogueBox
var _marker: Polygon2D  # flecha sobre quien habla
var _aria_face: Texture2D

var _alarm := false
var _base_light := Color.WHITE
var _shake := 0.0
var _t := 0.0
var _in_dialogue := false
var _skip := false


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_FILE))
	dialogue = parsed if parsed is Dictionary else {}
	_aria_face = Room.aria_portrait()

	room = Room.new()
	room.room_texture = room_texture
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
	_run()


func _build_crew() -> void:
	for id in GameState.role_order:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = GameState.frames_for(id)
		a.offset = Vector2(0, -47)  # los pies quedan en la posición del nodo
		a.scale = Vector2.ONE * CREW_SCALE
		var s: Array = STAND.get(id, [Vector2(640, 500), "down", false])
		a.position = s[0]
		Movement.animate(a, "idle", s[1], s[2])
		# Nombre bajo los pies (con escala inversa para que el texto no crezca con el sprite)
		var tag := Style.label(GameState.first_name(id), 13, GameState.role_color(id), 4)
		tag.size = Vector2(120, 20)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.scale = Vector2.ONE / CREW_SCALE
		tag.position = Vector2(-60, 4) / CREW_SCALE
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

func _run() -> void:
	await get_tree().create_timer(1.0).timeout  # deja terminar el fundido de entrada

	# 3) Alerta y conversación
	await _play_lines(dialogue.get("intro", []))
	box.hide()
	_set_speaker("")
	_set_alarm(false)

	# 4) Selección de personaje
	var picker := RoleSelect.new()
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
	SceneChanger.go_to(GameState.GAMEPLAY_SCENE, 1.2)


## Líneas de despedida: "player" pasa a ser el rol elegido y "sleeper" se reparte entre los que duermen.
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
				for id in GameState.role_order:
					if id != role_id:
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
		var text := _fill(str(line.get("text", "")))
		_set_speaker(who)
		if who == "aria":
			var a: Dictionary = dialogue.get("speakers", {}).get("aria", {})
			room.aria_talking = true
			await box.say(a.get("name", "A.R.I.A."), Color.html(a.get("color", "#5ef2e4")), text, _aria_face)
			room.aria_talking = false
		else:
			var r: Dictionary = GameState.roles.get(who, {})
			var speaker_name := "%s  ·  %s" % [r.get("crew_name", who), r.get("title", "")]
			await box.say(speaker_name, GameState.role_color(who), text, GameState.portrait_for(who))
	_in_dialogue = false
	room.aria_talking = false


## Sustituye {player} y {player_role} por el nombre y la profesión del jugador.
func _fill(text: String) -> String:
	var role := str(GameState.role_data.get("title", "")).capitalize()
	return text.format({"player": GameState.first_name(), "player_role": role})


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
			_set_alarm(true)
			_shake = 8.0
		"alarm_off":
			_set_alarm(false)
		"shake":
			_shake = 12.0
		"lights_dim":
			create_tween().tween_property(self, "_base_light", Color(0.6, 0.66, 0.9), 1.5)


func _set_alarm(on: bool) -> void:
	_alarm = on
	room.alarm = on


# ---------------------------------------------------------------- criosueño y salida

## Los que duermen caminan a su cápsula (una por rol, en orden) mientras el jugador va al frente.
func _sleep_sequence(role_id: String) -> void:
	var longest := 0.0
	var delay := 0.0
	for i in GameState.role_order.size():
		var id: String = GameState.role_order[i]
		if id != role_id:
			longest = maxf(longest, _send_to_pod(id, i, delay))
			delay += 0.5
	var me: AnimatedSprite2D = crew[role_id]
	Movement.walk_to(me, PLAYER_SPOT, WALK_SPEED, 0.8)
	await get_tree().create_timer(longest + 0.6).timeout
	Movement.animate(me, "idle", "down", false)


## Camina hasta la cápsula, entra y la cápsula se congela. Devuelve cuánto tarda en total.
func _send_to_pod(id: String, pod: int, delay: float) -> float:
	var a: AnimatedSprite2D = crew[id]
	var entry := room.pod_entry(pod)
	var walk_time := a.position.distance_to(entry) / WALK_SPEED
	Movement.walk_to(a, entry, WALK_SPEED, delay)
	var tw := create_tween()
	tw.tween_interval(delay + walk_time)
	tw.tween_callback(a.play.bind("walk_up"))
	tw.tween_property(a, "position:y", entry.y - 50, 0.4)
	tw.parallel().tween_property(a, "modulate:a", 0.0, 0.4)
	tw.tween_callback(room.set_pod_label.bind(pod, GameState.first_name(id)))
	tw.tween_method(room.set_pod_frost.bind(pod), 0.0, 1.0, 1.0)
	return delay + walk_time + 1.4


func _final_shot(role_id: String) -> void:
	var me: AnimatedSprite2D = crew[role_id]
	var tw := create_tween().set_parallel()
	tw.tween_property(camera, "zoom", Vector2.ONE * 1.7, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "position", me.position + Vector2(0, -70), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	me.play("celebrate")
	var card := _centered_label("YOU ARE IN COMMAND", 54, Style.AMBER, 12, 70, 1000)
	var sub := _centered_label("Keep Energy, Oxygen, Health and Research in balance until the storm passes.",
		20, Style.WHITE, 5, 140, 1200)
	var t2 := create_tween()
	t2.tween_interval(0.8)
	t2.tween_property(card, "modulate:a", 1.0, 0.6)
	t2.tween_property(sub, "modulate:a", 1.0, 0.6)
	t2.tween_interval(2.4)
	await t2.finished


## Texto centrado arriba, invisible al crearse (para hacerlo aparecer con un tween).
func _centered_label(text: String, font_size: int, color: Color, outline: int, top: float, width: float) -> Label:
	var l := Style.label(text, font_size, color, outline)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -width / 2.0
	l.offset_right = width / 2.0
	l.offset_top = top
	l.modulate.a = 0.0
	ui.add_child(l)
	return l


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
