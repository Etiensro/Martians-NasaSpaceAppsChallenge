extends RefCounted
## Ayudas de movimiento compartidas por el astronauta, el rover, el robot y los personajes
## que caminan solos (mapa general, intro).
## Uso: const Movement := preload("res://scripts/core/movement.gd")
##
## Todos los sprites tienen animaciones "<prefijo>_down", "<prefijo>_up" y "<prefijo>_side"
## (p. ej. idle_side, walk_side, drive_side). Los de lado miran a la DERECHA; para la
## izquierda se usa flip_h.


## Dirección pedida con el teclado (WASD o flechas), normalizada. ZERO si no se pulsa nada.
static func input_vector() -> Vector2:
	var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var down := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var up := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	return Vector2(float(right) - float(left), float(down) - float(up)).normalized()


static func is_running() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


## "side", "down" o "up" según hacia dónde va `dir`.
static func facing_of(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return "side"
	return "down" if dir.y > 0 else "up"


## Mueve `pos` un paso, por ejes separados para "deslizar" contra los obstáculos.
## `can_stand` recibe una posición y dice si se puede estar ahí.
static func slide(pos: Vector2, step: Vector2, can_stand: Callable) -> Vector2:
	if can_stand.call(pos + Vector2(step.x, 0)):
		pos.x += step.x
	if can_stand.call(pos + Vector2(0, step.y)):
		pos.y += step.y
	return pos


## Pone la animación "<prefix>_<facing>" (solo si cambia, para no reiniciarla) y el volteo.
static func animate(sprite: AnimatedSprite2D, prefix: String, facing: String, face_left: bool) -> void:
	sprite.flip_h = facing == "side" and face_left
	var anim := prefix + "_" + facing
	if sprite.animation != anim:
		sprite.play(anim)


## Hace caminar un sprite en línea recta hasta `to` con la animación adecuada y lo deja
## quieto mirando en esa dirección. Devuelve el Tween (se puede esperar con `await tw.finished`).
static func walk_to(sprite: AnimatedSprite2D, to: Vector2, speed: float, delay := 0.0) -> Tween:
	var dir := to - sprite.position
	var facing := facing_of(dir)
	var tw := sprite.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(sprite.set.bind("flip_h", facing == "side" and dir.x < 0))
	tw.tween_callback(sprite.play.bind("walk_" + facing))
	tw.tween_property(sprite, "position", to, dir.length() / speed)
	tw.tween_callback(sprite.play.bind("idle_" + facing))
	return tw
