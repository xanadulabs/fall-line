extends Node2D

## Flat pixel hill, one scale. The window is the meadow.
## World +y is downhill, which is down the screen. The rider sits a third of the way down.
## Sprites do not shrink with distance. Feet stay at the bottom of each sprite.

const Rides := preload("res://scripts/rides.gd")

const PPM := 8.0
const TRAIL_HALF := 2.4
const CHUNK := 52.0
const CREEK_EVERY := 520.0
const LEASH := 22.0
const VERGE := 18.0
const POST_EVERY := 8.0
const BIGFOOT_AT := 2000.0
const GRAVITY := 20.0
const LAUNCH_VZ := 9.0
const LOOKAHEAD := 46.0
const VW := 320.0
const VH := 200.0

const OUTLINE := Color8(12, 12, 10)
const PAPER := Color8(244, 240, 220)
const GRASS := Color8(118, 162, 68)
const GRASS_DARK := Color8(86, 128, 46)
const GRASS_LIGHT := Color8(156, 192, 102)
const FLOWER := Color8(214, 72, 64)
const DIRT := Color8(150, 104, 54)
const DIRT_LIGHT := Color8(184, 140, 78)
const DUST := Color8(222, 198, 142)
const DUST_GRASS := Color8(176, 208, 120)
const DIRT_EDGE := Color8(92, 62, 32)
const PINE := Color8(36, 122, 40)
const PINE_DARK := Color8(18, 78, 28)
const TRUNK := Color8(102, 64, 32)
const ROCK := Color8(128, 124, 116)
const ROCK_LIGHT := Color8(168, 164, 154)
const WOOD := Color8(148, 96, 48)
const RUBBER := Color8(28, 26, 24)
const SKIN := Color8(214, 156, 96)
const SKIN_LIGHT := Color8(232, 186, 128)
const HAIR := Color8(36, 28, 22)
const SHORTS := Color8(42, 46, 58)
const WATER := Color8(56, 112, 118)
const WATER_LIGHT := Color8(120, 168, 164)
const INK := Color8(12, 10, 8)
const SHADOW := Color8(56, 54, 50)

enum Mode { TITLE, RIDE, WRECK }

var mode := Mode.TITLE
var pick := 0
var hover := -1
var ride: Dictionary = {}
var rng := RandomNumberGenerator.new()

var player_x := 0.0
var player_y := 0.0
var prev_y := 0.0
var player_speed := 0.0
var vx := 0.0
var heading := 0
var air_lean := 0
var show_pose := ""
var show_t := 0.0
var height := 0.0
var vz := 0.0
var ride_t := 0.0
var tick := 0.0
var kick := 0.0
var paused := false
var wreck_line := ""
var best := 0.0

var obstacles: Array = []
var generated_y := 16.0
var dust: Array = []
var dust_bank := 0.0
var finger_btn := {}
var hold_left := false
var hold_right := false
var hold_down := false
var hold_up := false
var step_arm := 0.0

var bigfoot_on := false
var bigfoot_x := 0.0
var bigfoot_y := 0.0
var bigfoot_vx := 0.0
var bigfoot_vy := 0.0
var grab := ""
var grab_t := 0.0
var grab_x := 0.0
var grab_y := 0.0
var throw_x := 0.0
var throw_y := 0.0
var throw_span := 0.45

var view_w := VW
var view_h := VH

var glyphs := {}
var grass_tex: Texture2D
var tex := {}


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_build_font()
	_build_grass()
	_build_sprites()
	rng.randomize()
	ride = Rides.all()[pick]
	player_x = _trail_x(0.0)
	player_speed = 14.0
	_generate()


func _process(delta: float) -> void:
	_sync_view()
	if mode != Mode.WRECK:
		tick += delta
	kick = move_toward(kick, 0.0, delta * 30.0)
	if mode == Mode.TITLE:
		ride = Rides.all()[pick]
		_hover()
		_coast(delta)
	elif mode == Mode.RIDE and not paused:
		ride_t += delta
		_ride(delta)
		_step_repeat(delta)
	if mode != Mode.WRECK:
		_blow_dust(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_click(get_viewport().get_mouse_position())
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_touch_button(touch.index, touch.position, touch.pressed)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_button(drag.index, drag.position, true)
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed:
			return
		var steer := key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT or key.keycode == KEY_A or key.keycode == KEY_D
		if key.echo and not (steer and mode == Mode.RIDE):
			return
		_key(key.keycode)


func _key(code: Key) -> void:
	if mode == Mode.TITLE:
		if code == KEY_RIGHT or code == KEY_D:
			pick = (pick + 1) % 3
		elif code == KEY_LEFT or code == KEY_A:
			pick = (pick + 2) % 3
		elif code >= KEY_1 and code <= KEY_3:
			pick = int(code - KEY_1)
			_begin()
		elif code >= KEY_KP_1 and code <= KEY_KP_3:
			pick = int(code - KEY_KP_1)
			_begin()
		elif code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
			_begin()
	elif mode == Mode.RIDE and paused:
		if code == KEY_ESCAPE or code == KEY_ENTER or code == KEY_SPACE or code == KEY_KP_ENTER:
			paused = false
		elif code == KEY_Q:
			_to_title()
	elif mode == Mode.RIDE:
		if code == KEY_ESCAPE:
			paused = true
		elif code == KEY_LEFT or code == KEY_A:
			_step_heading(-1)
		elif code == KEY_RIGHT or code == KEY_D:
			_step_heading(1)
		elif code == KEY_DOWN or code == KEY_S:
			if grab != "":
				return
			if height <= 0.05:
				heading = 0
				air_lean = 0
		elif code == KEY_UP or code == KEY_W:
			_try_climb()
		elif code == KEY_SPACE:
			_hop()
	elif mode == Mode.WRECK:
		if code == KEY_ENTER or code == KEY_SPACE or code == KEY_KP_ENTER:
			_begin()
		elif code == KEY_ESCAPE or code == KEY_Q:
			_to_title()


func _click(at: Vector2) -> void:
	_sync_view()
	if mode == Mode.TITLE:
		for i in 3:
			if _slot(i).has_point(at):
				pick = i
				_begin()
				return
	elif mode == Mode.WRECK:
		var again := _wreck_buttons()
		if again[0].has_point(at):
			_begin()
		elif again[1].has_point(at):
			_to_title()
	elif paused:
		var choice := _pause_buttons()
		if choice[0].has_point(at):
			paused = false
		elif choice[1].has_point(at):
			_to_title()


func _hover() -> void:
	hover = -1
	var mouse := get_viewport().get_mouse_position()
	for i in 3:
		if _slot(i).has_point(mouse):
			hover = i
			return


func _begin() -> void:
	rng.randomize()
	ride = Rides.all()[pick]
	player_y = 0.0
	prev_y = 0.0
	player_x = _trail_x(0.0)
	vx = 0.0
	player_speed = 8.0
	heading = 0
	air_lean = 0
	show_pose = ""
	show_t = 0.0
	obstacles.clear()
	dust.clear()
	dust_bank = 0.0
	_drop_touch()
	generated_y = 18.0
	bigfoot_on = false
	grab = ""
	grab_t = 0.0
	height = 0.0
	vz = 0.0
	paused = false
	wreck_line = ""
	ride_t = 0.0
	kick = 0.0
	mode = Mode.RIDE
	while generated_y < 160.0:
		_spawn_chunk()


func _to_title() -> void:
	mode = Mode.TITLE
	paused = false
	bigfoot_on = false
	grab = ""
	grab_t = 0.0
	wreck_line = ""
	player_y = 0.0
	prev_y = 0.0
	player_x = _trail_x(0.0)
	vx = 0.0
	height = 0.0
	vz = 0.0
	player_speed = 14.0
	heading = 0
	air_lean = 0
	show_pose = ""
	show_t = 0.0
	obstacles.clear()
	dust.clear()
	dust_bank = 0.0
	_drop_touch()
	generated_y = 16.0
	ride = Rides.all()[pick]
	_generate()


func _coast(delta: float) -> void:
	player_y += 12.0 * delta
	player_x = _trail_x(player_y)
	player_speed = 12.0
	vx = 0.0
	_generate()
	_cull()


func _step_heading(dir: int) -> void:
	if grab != "":
		return
	if height > 0.05:
		air_lean = dir
		return
	if dir < 0 and heading > -3:
		heading -= 1
	elif dir > 0 and heading < 3:
		heading += 1
	else:
		_skate(dir)


func _skate(dir: int) -> void:
	var lat := float(ride.lat_max)
	vx += float(dir) * 0.5 * maxf(player_speed, 0.0)
	vx = clampf(vx, -lat, lat)
	show_pose = "skate"
	show_t = 0.16


func _try_climb() -> void:
	if grab != "":
		return
	if height > 0.05 or player_speed > 0.4 or absi(heading) < 3:
		return
	player_speed = -0.25 * float(ride.max_speed)
	show_pose = "climb"
	show_t = 0.16


func _hop() -> void:
	if grab != "" or height > 0.05:
		return
	vz = LAUNCH_VZ * 0.5
	var cost := 0.25 * float(ride.max_speed)
	if player_speed > cost:
		player_speed -= cost
	air_lean = 0
	kick = maxf(kick, 3.0)


func _phone() -> bool:
	return DisplayServer.is_touchscreen_available()


func _touch_rects() -> Dictionary:
	return {
		"left": Rect2(4, view_h - 30, 46, 24),
		"down": Rect2(56, view_h - 30, 48, 24),
		"up": Rect2(110, view_h - 30, 40, 24),
		"hop": Rect2(156, view_h - 30, 40, 24),
		"right": Rect2(view_w - 50, view_h - 30, 46, 24),
		"pause": Rect2(view_w - 28, 3, 24, 14),
	}


func _button_at(at: Vector2) -> String:
	var rects := _touch_rects()
	for name in ["pause", "left", "right", "down", "up", "hop"]:
		var rect: Rect2 = rects[name]
		if rect.has_point(at):
			return String(name)
	return ""


func _touch_button(index: int, at: Vector2, pressed: bool) -> void:
	if not _phone() or mode != Mode.RIDE:
		return
	if not pressed:
		finger_btn.erase(index)
		_sync_holds()
		return
	var name := _button_at(at)
	var prev := String(finger_btn.get(index, ""))
	if name == "":
		if prev != "":
			finger_btn.erase(index)
			_sync_holds()
		return
	if name == prev:
		return
	if grab != "" and name != "pause":
		return
	finger_btn[index] = name
	_sync_holds()
	if name == "left":
		_step_heading(-1)
		step_arm = 0.38
	elif name == "right":
		_step_heading(1)
		step_arm = 0.38
	elif name == "down":
		if height <= 0.05:
			heading = 0
			air_lean = 0
	elif name == "up":
		_try_climb()
	elif name == "hop":
		_hop()
	elif name == "pause":
		paused = not paused


func _sync_holds() -> void:
	hold_left = false
	hold_right = false
	hold_down = false
	hold_up = false
	for idx in finger_btn.keys():
		var name := String(finger_btn[idx])
		if name == "left":
			hold_left = true
		elif name == "right":
			hold_right = true
		elif name == "down":
			hold_down = true
		elif name == "up":
			hold_up = true
	if not hold_left and not hold_right:
		step_arm = 0.0


func _drop_touch() -> void:
	finger_btn.clear()
	hold_left = false
	hold_right = false
	hold_down = false
	hold_up = false
	step_arm = 0.0


func _step_repeat(delta: float) -> void:
	if paused or (not hold_left and not hold_right) or (hold_left and hold_right):
		return
	step_arm -= delta
	if step_arm > 0.0:
		return
	_step_heading(-1 if hold_left else 1)
	step_arm = 0.12


func _blow_dust(delta: float) -> void:
	var keep: Array = []
	for p in dust:
		p["t"] = float(p.t) - delta
		if float(p.t) > 0.0:
			keep.append(p)
	dust = keep
	if dust.size() > 240:
		dust = dust.slice(dust.size() - 240)
	if paused or height > 0.05 or ride.is_empty():
		return
	var moving := Vector2(vx, player_speed)
	var spd := moving.length()
	if spd < 0.8:
		return
	var id := String(ride.id)
	var rate := 36.0
	var spread := 0.16
	var life := 0.55
	var reach := 1.05
	if id == "bike":
		rate = 52.0
		spread = 0.38
		life = 0.72
		reach = 1.55
	elif id == "thumper":
		rate = 76.0
		spread = 0.62
		life = 0.95
		reach = 2.35
	var on_dirt := absf(player_x - _trail_x(player_y)) <= TRAIL_HALF
	if not on_dirt:
		rate *= 0.4
		life *= 0.7
		reach *= 0.65
	var speed_scale := clampf(spd / float(ride.max_speed), 0.0, 1.0)
	rate *= lerpf(0.35, 1.0, speed_scale)
	life *= lerpf(0.6, 1.3, speed_scale)
	reach *= lerpf(0.45, 1.0, speed_scale)
	dust_bank += rate * delta
	var back := -moving / spd
	var side := Vector2(-back.y, back.x)
	var color: Color = DUST if on_dirt else DUST_GRASS
	var spawned := 0
	while dust_bank >= 1.0 and spawned < 8:
		dust_bank -= 1.0
		spawned += 1
		var along := rng.randf_range(0.12, 0.28 + reach)
		var lateral := rng.randf_range(-spread, spread)
		dust.append({
			"x": player_x + back.x * along + side.x * lateral,
			"y": player_y + back.y * along + side.y * lateral,
			"t": life * rng.randf_range(0.65, 1.0),
			"c": color,
		})


func _draw_dust() -> void:
	for p in dust:
		var at := _screen(float(p.x), float(p.y))
		if at.x < -2.0 or at.y < -2.0 or at.x > view_w + 2.0 or at.y > view_h + 2.0:
			continue
		draw_rect(Rect2(at.x, at.y, 1, 1), p.c)


func _draw_touch() -> void:
	if paused:
		return
	var rects := _touch_rects()
	_touch_key(rects["left"], "LEFT", hold_left)
	_touch_key(rects["right"], "RIGHT", hold_right)
	_touch_key(rects["down"], "DOWN", hold_down)
	_touch_key(rects["up"], "UP", hold_up)
	_touch_key(rects["hop"], "HOP", false)
	var mark: Rect2 = rects["pause"]
	draw_rect(mark, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(mark.position.x + 7, mark.position.y + 3, 2, 8), PAPER)
	draw_rect(Rect2(mark.position.x + 13, mark.position.y + 3, 2, 8), PAPER)


func _touch_key(rect: Rect2, label: String, hot: bool) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.35))
	draw_rect(rect, PAPER if hot else INK, false, 1.0)
	var nx := int(rect.position.x + (rect.size.x - label.length() * 4.0) * 0.5)
	_text_px(nx, int(rect.position.y + 9), label, 1, PAPER if hot else INK)


func _ride(delta: float) -> void:
	if grab != "":
		_grab_step(delta)
		_generate()
		_cull()
		return
	show_t = maxf(show_t - delta, 0.0)
	if show_t <= 0.0:
		show_pose = ""
	var push := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or hold_down
	var brake := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or hold_up
	var on_dirt := absf(player_x - _trail_x(player_y)) <= TRAIL_HALF
	var abs_h := absi(heading)
	var scale: float = [1.0, 12.0 / 16.0, 6.0 / 16.0, 0.0][abs_h]
	if height > 0.05:
		scale = 22.0 / 16.0 if air_lean != 0 else 24.0 / 16.0
	var target: float = float(ride.max_speed) * scale
	if height <= 0.05 and not on_dirt:
		target *= float(ride.grass)
	var gain := float(ride.pull)
	if push and height <= 0.05:
		gain += float(ride.throttle)
	var drop := float(ride.pull) * 2.0
	if brake and player_speed > 0.4 and height <= 0.05:
		drop += float(ride.brake)
	var rate := gain if player_speed < target else drop
	player_speed = move_toward(player_speed, target, rate * delta)
	var lat := float(ride.lat_max)
	var side := 0.0
	if height <= 0.05 and player_speed > 0.0 and abs_h > 0:
		var factor: int = [0, 1, 4, 8][abs_h]
		side = float(signi(heading)) * (float(factor) * player_speed) / 2.0
		side = clampf(side, -lat, lat)
	var opening := absf(side) > absf(vx) and (vx == 0.0 or signf(side) == signf(vx))
	vx = move_toward(vx, side, (gain if opening else drop) * delta)
	vx = clampf(vx, -lat, lat)
	prev_y = player_y
	player_x += vx * delta
	player_y += player_speed * delta
	_leash()
	_air(delta)
	_crossings()
	if mode != Mode.RIDE:
		return
	_bigfoot(delta)
	_generate()
	_cull()


func _crossings() -> void:
	var hits: Array = []
	for o in obstacles:
		if bool(o.cleared) or String(o.kind) == "post":
			continue
		var oy := float(o.y)
		if String(o.kind) == "trunk":
			if _trunk_hit(o):
				if height > 0.05:
					if oy < prev_y:
						o.cleared = true
				elif not _blocked(o):
					hits.append(o)
			elif player_y > oy + 0.5:
				o.cleared = true
			continue
		if oy > player_y + 0.35:
			continue
		if oy < player_y - 1.5:
			o.cleared = true
			continue
		if String(o.kind) == "rise":
			if absf(float(o.x) - player_x) <= float(o.r):
				hits.append(o)
			elif oy < prev_y:
				o.cleared = true
			continue
		if height > 0.05:
			if oy < prev_y:
				o.cleared = true
			continue
		if String(o.kind) == "creek":
			if not _blocked(o):
				hits.append(o)
			elif oy < prev_y:
				o.cleared = true
			continue
		var reach := float(o.r) + float(ride.radius)
		if absf(float(o.x) - player_x) <= reach:
			if not _blocked(o):
				hits.append(o)
		elif oy < prev_y:
			o.cleared = true
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))
	for o in hits:
		if mode != Mode.RIDE:
			return
		o.cleared = true
		if String(o.kind) == "rise":
			_launch()
		elif String(o.kind) == "creek":
			_hit_creek()
		else:
			_hit_solid(o)


func _hit_solid(o: Dictionary) -> void:
	var kind := String(o.kind)
	if kind == "tree":
		_wreck("A tree.")
		return
	if kind == "table":
		_wreck("A picnic table.")
		return
	if kind == "rock":
		match String(ride.rock):
			"wreck":
				_wreck("A rock.")
			"shrug":
				_thud(0.92)
			_:
				_thud(0.62)
		return
	if kind == "stump" or kind == "trunk":
		var line := "A trunk." if kind == "trunk" else "A stump."
		match String(ride.stump):
			"wreck":
				_wreck(line)
			"fast_wreck":
				if player_speed > 12.0:
					_wreck(line)
				else:
					_thud(0.55)
			"plow":
				_thud(0.96)
			_:
				_thud(0.74)


func _hit_creek() -> void:
	if player_speed > float(ride.creek_safe):
		_wreck("The creek.")
	else:
		_thud(0.60)


func _thud(scale: float) -> void:
	player_speed *= scale
	kick = maxf(kick, 7.0 if scale < 0.95 else 3.5)


func _launch() -> void:
	vz = LAUNCH_VZ
	air_lean = 0


func _air(delta: float) -> void:
	if height <= 0.0 and vz <= 0.0:
		height = 0.0
		vz = 0.0
		return
	var was_up := height > 0.05
	height += vz * delta
	vz -= GRAVITY * delta
	if height <= 0.0:
		height = 0.0
		vz = 0.0
		if was_up:
			kick = maxf(kick, 4.0)
			if air_lean < 0:
				heading = -3
			elif air_lean > 0:
				heading = 3
			else:
				heading = 0
			air_lean = 0


func _leash() -> void:
	var trail := _trail_x(player_y)
	var off := player_x - trail
	if absf(off) <= LEASH:
		return
	var side := signf(off)
	player_x = trail + side * LEASH
	if signf(vx) == side:
		vx = 0.0


func _wreck(line: String) -> void:
	if mode != Mode.RIDE:
		return
	wreck_line = line
	if player_y > best:
		best = player_y
	height = 0.0
	vz = 0.0
	paused = false
	mode = Mode.WRECK


func _bigfoot(delta: float) -> void:
	if not bigfoot_on:
		if player_y < BIGFOOT_AT:
			return
		bigfoot_on = true
		bigfoot_x = player_x + 6.0
		bigfoot_y = player_y - 5.0
		bigfoot_vx = 0.0
		bigfoot_vy = maxf(player_speed, 12.0)
		return
	var want_vx := clampf(player_x - bigfoot_x, -14.0, 14.0)
	bigfoot_vx = move_toward(bigfoot_vx, want_vx, 16.0 * delta)
	var want_vy := maxf(player_speed + 2.4, 11.0)
	if bigfoot_y > player_y + 0.6:
		want_vy = -7.0
	bigfoot_vy = move_toward(bigfoot_vy, want_vy, 12.0 * delta)
	bigfoot_x += bigfoot_vx * delta
	bigfoot_y += bigfoot_vy * delta
	if absf(bigfoot_x - player_x) < float(ride.radius) + 1.05 and absf(bigfoot_y - player_y) < 1.35:
		_start_grab()


func _start_grab() -> void:
	if grab != "":
		return
	var tree := _nearest_tree()
	throw_x = tree.x
	throw_y = tree.y
	grab = "lift"
	grab_t = 0.0
	grab_x = player_x
	grab_y = player_y
	bigfoot_vx = 0.0
	bigfoot_vy = 0.0
	player_speed = 0.0
	vx = 0.0
	height = 0.0
	vz = 0.0
	air_lean = 0


func _grab_step(delta: float) -> void:
	grab_t += delta
	var u := 0.0
	if grab == "lift":
		var hold := _hold_feet()
		u = clampf(grab_t / 0.32, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		player_x = lerpf(grab_x, hold.x, u)
		player_y = lerpf(grab_y, hold.y, u)
		if grab_t >= 0.78:
			grab = "throw"
			grab_t = 0.0
			grab_x = player_x
			grab_y = player_y
			var impact_y := throw_y - 1.0
			var dist := Vector2(throw_x - grab_x, impact_y - grab_y).length()
			throw_span = clampf(dist / 18.0, 0.30, 0.70)
		return
	u = clampf(grab_t / throw_span, 0.0, 1.0)
	var along := lerpf(grab_y, throw_y - 1.0, u)
	player_x = lerpf(grab_x, throw_x, u)
	player_y = along - sin(u * PI) * 1.6
	if u >= 1.0:
		player_x = throw_x
		player_y = throw_y - 1.0
		grab = ""
		_wreck("A tree.")


func _hold_feet() -> Vector2:
	var image_tex: Texture2D = tex["bigfoot_lift_a"]
	var sprite_h := image_tex.get_size().y
	return Vector2(bigfoot_x, bigfoot_y - (sprite_h - 2.0) / PPM)


func _nearest_tree() -> Vector2:
	var best: float = INF
	var at := Vector2(player_x, player_y)
	var found := false
	for o in obstacles:
		if String(o.kind) != "tree":
			continue
		var spot := Vector2(float(o.x), float(o.y))
		var dist := spot.distance_squared_to(Vector2(player_x, player_y))
		if dist < best:
			best = dist
			at = spot
			found = true
	if found:
		return at
	var y := player_y + 5.0
	var side := 1.0 if player_x >= _trail_x(y) else -1.0
	var x := _trail_x(y) + side * (TRAIL_HALF + 3.2)
	obstacles.append(_obs("tree", x, y, 0.30))
	return Vector2(x, y)


func _generate() -> void:
	var guard := 0
	while generated_y < player_y + LOOKAHEAD and guard < 8:
		_spawn_chunk()
		guard += 1


func _cull() -> void:
	var keep: Array = []
	var limit := player_y - 12.0
	for o in obstacles:
		if grab != "" and String(o.kind) == "tree" and absf(float(o.x) - throw_x) < 0.05 and absf(float(o.y) - throw_y) < 0.05:
			keep.append(o)
			continue
		if float(o.y) >= limit:
			keep.append(o)
	obstacles = keep


func _spawn_chunk() -> void:
	var y0 := generated_y
	var y1 := y0 + CHUNK
	_spawn_rises(y0, y1)
	_scatter("tree", y0, y1, 8, LEASH, 6.0, 0.30, 4.0, 0.0, 0.0)
	_scatter("rock", y0, y1, 6, LEASH, 2.4, 0.46, 6.0, 11.0, 2.2)
	_scatter("stump", y0, y1, 5, LEASH, 3.0, 0.36, 6.0, 0.0, 0.0)
	_spawn_trunks(y0, y1)
	if y0 > 60.0 and rng.randf() < 0.30:
		var guard_t := 0
		while guard_t < 6:
			guard_t += 1
			var y := rng.randf_range(y0, y1)
			var x := _trail_x(y) + rng.randf_range(-LEASH, LEASH)
			if _on_rise(x, y) or _covers_trail(x, y, TABLE_ROWS):
				continue
			obstacles.append(_obs("table", x, y, 0.80))
			break
	var creek := _mark_in_chunk(y0, y1, CREEK_EVERY)
	if creek > 400.0:
		var guard_c := 0
		while _on_rise(_trail_x(creek), creek) and guard_c < 4:
			creek += 6.0
			guard_c += 1
		if creek < y1 and not _on_rise(_trail_x(creek), creek):
			obstacles.append(_obs("creek", _trail_x(creek), creek, 1.6))
	var post_y := _mark_in_chunk(y0, y1, 100.0)
	if post_y >= 100.0:
		var post_x := _trail_x(post_y) + 3.2
		if _on_rise(post_x, post_y):
			post_x = _trail_x(post_y) + 4.8
		var post := _obs("post", post_x, post_y, 0.15)
		post["n"] = int(post_y)
		obstacles.append(post)
	generated_y = y1


func _spawn_rises(y0: float, y1: float) -> void:
	var n := 0
	var guard := 0
	while n < 6 and guard < 48:
		guard += 1
		var y := rng.randf_range(y0, y1)
		if y < 12.0:
			continue
		var x := _trail_x(y) + rng.randf_range(-LEASH, LEASH)
		if _on_rise(x, y):
			continue
		_add_rise(x, y, rng.randf() < 1.0 / 3.0)
		n += 1
	if _dirt_rise(y0, y1):
		return
	guard = 0
	while guard < 8:
		guard += 1
		var y := rng.randf_range(maxf(y0, 12.0), y1)
		var x := _trail_x(y)
		if _on_rise(x, y):
			continue
		_add_rise(x, y, true)
		return


func _dirt_rise(y0: float, y1: float) -> bool:
	for o in obstacles:
		if String(o.kind) != "rise":
			continue
		var y := float(o.y)
		if y < y0 or y >= y1:
			continue
		if absf(float(o.x) - _trail_x(y)) <= TRAIL_HALF:
			return true
	return false


func _add_rise(x: float, y: float, big: bool) -> void:
	var rows: Array = RISE_BIG_ROWS if big else RISE_ROWS
	var rise := _obs("rise", x, y, float(String(rows[0]).length()) * 0.5 / PPM)
	rise["sprite"] = "rise_big" if big else "rise"
	obstacles.append(rise)


func _on_rise(x: float, y: float) -> bool:
	for o in obstacles:
		if String(o.kind) != "rise":
			continue
		if absf(float(o.y) - y) > 1.6:
			continue
		if absf(float(o.x) - x) <= float(o.r) + 0.4:
			return true
	return false


func _mark_in_chunk(y0: float, y1: float, every: float) -> float:
	var mark := ceilf(y0 / every) * every
	if mark >= y0 and mark < y1:
		return mark
	return -1.0


func _scatter(kind: String, y0: float, y1: float, count: int, span: float, gap: float, radius: float, min_y: float, clear_until: float, clear_half: float) -> void:
	var n := 0
	var guard := 0
	while n < count and guard < count * 8:
		guard += 1
		var y := rng.randf_range(y0, y1)
		if y < min_y:
			continue
		var x := _trail_x(y) + rng.randf_range(-span, span)
		if clear_until > 0.0 and y < clear_until and absf(x - _trail_x(y)) < clear_half:
			continue
		if kind == "tree" and _covers_trail(x, y, PINE_ROWS):
			continue
		if kind == "stump" and _covers_trail(x, y, STUMP_ROWS):
			continue
		if _on_rise(x, y):
			continue
		var spot := Vector2(x, y)
		var ok := true
		for o in obstacles:
			if absf(float(o.y) - y) > gap:
				continue
			if Vector2(float(o.x), float(o.y)).distance_to(spot) < gap:
				ok = false
				break
		if not ok:
			continue
		obstacles.append(_obs(kind, x, y, radius))
		n += 1


func _spawn_trunks(y0: float, y1: float) -> void:
	var n := 0
	var guard := 0
	while n < 3 and guard < 30:
		guard += 1
		var y := rng.randf_range(y0, y1)
		if y < 8.0:
			continue
		var down := rng.randf() < 0.5
		var rows: Array = _transpose(TRUNK_ACROSS) if down else TRUNK_ACROSS
		var width := float(String(rows[0]).length())
		var half := floorf(width * 0.5) / PPM
		var x := _trail_x(y) + rng.randf_range(-LEASH + half + 0.4, LEASH - half - 0.4)
		if _covers_trail(x, y, rows) or _on_rise(x, y):
			continue
		var spot := Vector2(x, y)
		var ok := true
		for o in obstacles:
			if absf(float(o.y) - y) > 4.0:
				continue
			if Vector2(float(o.x), float(o.y)).distance_to(spot) < 4.0:
				ok = false
				break
		if not ok:
			continue
		var height := float(rows.size())
		var trunk := _obs("trunk", x, y, 0.4)
		trunk["sprite"] = "trunk_down" if down else "trunk_across"
		trunk["left_m"] = half
		trunk["right_m"] = (width - floorf(width * 0.5)) / PPM
		trunk["up_m"] = (height - 1.0) / PPM
		obstacles.append(trunk)
		n += 1


func _covers_trail(x: float, y: float, rows: Array) -> bool:
	var width := float(String(rows[0]).length())
	var reach := TRAIL_HALF + (floorf(width * 0.5) + 1.0) / PPM
	var top := y - float(rows.size() - 1) / PPM
	var at := top
	while at < y:
		if absf(x - _trail_x(at)) <= reach:
			return true
		at += 0.5
	return absf(x - _trail_x(y)) <= reach


func _trunk_hit(o: Dictionary) -> bool:
	var ox := float(o.x)
	var oy := float(o.y)
	var rad := float(ride.radius)
	if player_x < ox - float(o.left_m) - rad or player_x > ox + float(o.right_m) + rad:
		return false
	if player_y < oy - float(o.up_m) - 0.15 or player_y > oy + 0.35:
		return false
	return true


func _transpose(rows: Array) -> Array:
	var width := String(rows[0]).length()
	var out: Array = []
	for x in width:
		var line := ""
		for y in range(rows.size() - 1, -1, -1):
			line += String(rows[y])[x]
		out.append(line)
	return out


func _obs(kind: String, x: float, y: float, r: float) -> Dictionary:
	return {"kind": kind, "x": x, "y": y, "r": r, "cleared": false}


func _trail_x(y: float) -> float:
	return sin(y * 0.021) * 16.0 + sin(y * 0.006 + 1.7) * 28.0


func _on_dirt() -> bool:
	return absf(player_x - _trail_x(player_y)) <= TRAIL_HALF


func _blocked(o: Dictionary) -> bool:
	if not _on_dirt():
		return false
	var kind := String(o.kind)
	return kind != "rock" and kind != "rise"


func _draw_creek(at: Vector2) -> void:
	var band := int(at.y)
	var top := band - 1
	var bottom := band + 3
	var half := int(TRAIL_HALF * PPM)
	var view_r := int(view_w)
	var sy := top
	while sy < bottom:
		if sy >= -6 and sy < int(view_h) + 4:
			var wy := player_y + (float(sy) - _anchor()) / PPM
			var sx := int(round(view_w * 0.5 + (_trail_x(wy) - player_x) * PPM))
			var dirt_left := sx - half
			var dirt_right := dirt_left + half * 2
			if dirt_left > 0:
				draw_rect(Rect2(0, sy, dirt_left, 1), WATER)
			if dirt_right < view_r:
				var x0 := maxi(dirt_right, 0)
				draw_rect(Rect2(x0, sy, view_r - x0, 1), WATER)
			if sy == band:
				var x := 0
				while x < view_r:
					if x < dirt_left or x >= dirt_right:
						draw_rect(Rect2(x, sy, 1, 1), WATER_LIGHT)
					x += 2
		sy += 1


func _sync_view() -> void:
	var size := get_viewport_rect().size
	view_w = size.x if size.x > 10.0 else VW
	view_h = size.y if size.y > 10.0 else VH


func _anchor() -> float:
	return view_h / 3.0


func _screen(wx: float, wy: float) -> Vector2:
	var shake := 0.0
	if kick > 1.0:
		shake = sin(tick * 42.0) * minf(2.0, kick * 0.2)
	var sx := view_w * 0.5 + (wx - player_x) * PPM + shake
	var sy := _anchor() + (wy - player_y) * PPM
	return Vector2(round(sx), round(sy))


func _draw() -> void:
	_sync_view()
	_draw_field()
	_draw_things()
	if mode == Mode.TITLE:
		_draw_title()
	elif mode == Mode.RIDE:
		_draw_hud()
		if _phone():
			_draw_touch()
		if paused:
			_draw_pause()
	else:
		_draw_hud()
		_draw_wreck()


func _draw_field() -> void:
	draw_rect(Rect2(0, 0, view_w, view_h), GRASS)
	var half := int(TRAIL_HALF * PPM)
	for sy in int(view_h):
		var wy := player_y + (float(sy) - _anchor()) / PPM
		_draw_verge(sy, wy)
		var sx := int(round(view_w * 0.5 + (_trail_x(wy) - player_x) * PPM))
		var left := sx - half
		var width := half * 2
		if left >= int(view_w) or left + width <= 0:
			continue
		draw_rect(Rect2(left, sy, width, 1), DIRT)
		draw_rect(Rect2(left, sy, 1, 1), DIRT_EDGE)
		draw_rect(Rect2(left + width - 1, sy, 1, 1), DIRT_EDGE)
		var iy := int(floor(wy * 2.0))
		var fleck := left + 2 + posmod(iy, 4)
		while fleck < left + width - 1:
			if fleck >= 0 and fleck < int(view_w):
				draw_rect(Rect2(fleck, sy, 1, 1), DIRT_LIGHT)
			fleck += 4
	_draw_leash()


func _draw_verge(sy: int, wy: float) -> void:
	var trail := _trail_x(wy)
	var mid := view_w * 0.5
	for side in [-1.0, 1.0]:
		var inner := int(round(mid + (trail + side * VERGE - player_x) * PPM))
		var outer := int(round(mid + (trail + side * LEASH - player_x) * PPM))
		var left := mini(inner, outer)
		var right := maxi(inner, outer)
		if right <= 0 or left >= int(view_w):
			continue
		left = maxi(left, 0)
		right = mini(right, int(view_w))
		if right <= left:
			continue
		draw_rect(Rect2(left, sy, right - left, 1), GRASS_DARK)


func _draw_leash() -> void:
	var y := ceilf((player_y - 10.0) / POST_EVERY) * POST_EVERY
	var limit := player_y + 20.0
	while y < limit:
		for side in [-1.0, 1.0]:
			var at := _screen(_trail_x(y) + side * LEASH, y)
			if at.x < -8.0 or at.x > view_w + 8.0 or at.y < -12.0 or at.y > view_h + 4.0:
				continue
			_draw_edge_post(at)
		y += POST_EVERY


func _draw_edge_post(at: Vector2) -> void:
	var x := int(round(at.x))
	var y := int(round(at.y))
	draw_rect(Rect2(x - 2, y - 8, 5, 9), OUTLINE)
	draw_rect(Rect2(x - 1, y - 7, 3, 7), TRUNK)
	draw_rect(Rect2(x, y - 7, 1, 6), WOOD)


func _draw_things() -> void:
	var items: Array = []
	for o in obstacles:
		var dy := float(o.y) - player_y
		if dy < -8.0 or dy > 28.0:
			continue
		items.append({"y": float(o.y), "o": o})
	if grab == "":
		items.append({"y": player_y, "player": true})
	if bigfoot_on:
		items.append({"y": bigfoot_y, "bigfoot": true})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))
	for item in items:
		if item.has("player"):
			_draw_player()
		elif item.has("bigfoot"):
			_draw_bigfoot()
			if grab == "lift":
				_draw_grabbed()
		else:
			_draw_obstacle(item.o)
	if grab == "throw":
		_draw_grabbed()
	if grab != "":
		_draw_dust()


func _draw_obstacle(o: Dictionary) -> void:
	var kind := String(o.kind)
	var at := _screen(float(o.x), float(o.y))
	if kind == "creek":
		_draw_creek(at)
		return
	if at.x < -40.0 or at.x > view_w + 40.0 or at.y < -8.0 or at.y > view_h + 40.0:
		return
	if kind == "tree":
		_stamp("pine", at)
	elif kind == "trunk":
		_stamp(String(o.sprite), at)
	elif kind == "rock":
		_stamp("rock", at)
	elif kind == "stump":
		_stamp("stump", at)
	elif kind == "table":
		_stamp("table", at)
	elif kind == "rise":
		_stamp(String(o.sprite) if o.has("sprite") else "rise", at)
	elif kind == "post":
		draw_rect(Rect2(at.x, at.y - 9, 1, 9), TRUNK)
		draw_rect(Rect2(at.x - 2, at.y - 9, 5, 3), PAPER)
		_text_px(at.x + 5, at.y - 8, str(int(o.n)), 1, INK)


func _draw_player() -> void:
	if ride.is_empty():
		return
	var ground := _screen(player_x, player_y)
	if height > 0.2 and mode != Mode.WRECK:
		draw_rect(Rect2(ground.x - 3, ground.y - 1, 6, 1), SHADOW)
		draw_rect(Rect2(ground.x - 1, ground.y, 3, 1), SHADOW)
	var at := ground
	if mode != Mode.WRECK:
		at.y -= round(height * PPM)
	_draw_dust()
	_stamp_pose(at)


func _draw_bigfoot() -> void:
	var at := _screen(bigfoot_x, bigfoot_y)
	var id := "bigfoot_run_a"
	if grab == "lift":
		id = "bigfoot_lift_a" if int(tick * 5.0) % 2 == 0 else "bigfoot_lift_b"
	elif grab == "throw":
		id = "bigfoot_throw"
	elif int(tick * 5.0) % 2 == 1:
		id = "bigfoot_run_b"
	if grab == "" and bigfoot_vy < -0.5:
		_stamp_flipped(id, at)
	else:
		_stamp(id, at)


func _draw_grabbed() -> void:
	if grab == "throw":
		var u := clampf(grab_t / throw_span, 0.0, 1.0)
		var along := lerpf(grab_y, throw_y - 1.0, u)
		var ground := _screen(player_x, along)
		draw_rect(Rect2(ground.x - 3, ground.y - 1, 6, 1), SHADOW)
		draw_rect(Rect2(ground.x - 1, ground.y, 3, 1), SHADOW)
	_stamp(String(ride.id) + "_grab", _screen(player_x, player_y))


func _draw_hud() -> void:
	_ink(3, 3, _meters(player_y), 1)
	_text_px(3, 10, "%d" % int(round(player_speed)), 1, ride.shirt)
	var ground := "DIRT" if absf(player_x - _trail_x(player_y)) <= TRAIL_HALF else "GRASS"
	_ink(20, 10, ground, 1)
	if mode == Mode.RIDE and bigfoot_on and player_y - bigfoot_y > 0.0 and player_y - bigfoot_y < 12.0:
		_ink(int((view_w - 40) * 0.5), 3, "BEHIND YOU", 1)


func _draw_title() -> void:
	_ink_center(6, "FALL LINE", 2)
	_ink_center(20, "THE SNOW LEFT", 1)
	_ink_center(28, "1-3 PICK   ARROWS STEP   DOWN LINES UP", 1)
	var rides := Rides.all()
	for i in 3:
		var slot := _slot(i)
		var info: Dictionary = rides[i]
		var on := i == pick or i == hover
		if on:
			draw_rect(Rect2(slot.position.x + 6, slot.position.y + slot.size.y - 1, slot.size.x - 12, 1), info.shirt)
		var id := String(info.id) + "_side"
		if tex.has(id):
			var image_tex: Texture2D = tex[id]
			var s := image_tex.get_size()
			var sx: float = roundf(slot.position.x + (slot.size.x - s.x) * 0.5)
			var sy: float = roundf(slot.position.y + slot.size.y - 10.0 - s.y)
			draw_texture(image_tex, Vector2(sx, sy))
		var name := String(info.name).to_upper()
		var nx := int(slot.position.x + (slot.size.x - name.length() * 4) * 0.5)
		var ny := int(slot.position.y + slot.size.y - 8)
		if on:
			_text_px(nx, ny, name, 1, info.shirt)
		else:
			_ink(nx, ny, name, 1)


func _draw_wreck() -> void:
	_ink_center(int(view_h * 0.36), wreck_line.to_upper(), 2)
	_ink_center(int(view_h * 0.36) + 14, _meters(player_y), 1)
	if best > 1.0:
		_ink_center(int(view_h * 0.36) + 22, "BEST " + _meters(best), 1)
	var buttons := _wreck_buttons()
	_pixel_button(buttons[0], "AGAIN", true)
	_pixel_button(buttons[1], "SWITCH", false)


func _draw_pause() -> void:
	_ink_center(int(view_h * 0.40), "PAUSED", 2)
	var buttons := _pause_buttons()
	_pixel_button(buttons[0], "GO", true)
	_pixel_button(buttons[1], "SWITCH", false)


func _pixel_button(rect: Rect2, label: String, hot: bool) -> void:
	draw_rect(rect, INK if hot else Color8(48, 42, 28))
	draw_rect(rect, PAPER, false, 1.0)
	var nx := int(rect.position.x + (rect.size.x - label.length() * 4) * 0.5)
	_text_px(nx, int(rect.position.y + 4), label, 1, PAPER if hot else INK)


func _slot(i: int) -> Rect2:
	var w := 96.0
	var gap := 8.0
	var x0 := (view_w - (3.0 * w + 2.0 * gap)) * 0.5
	return Rect2(x0 + i * (w + gap), view_h - 36, w, 32)


func _wreck_buttons() -> Array[Rect2]:
	var y := view_h - 22
	return [Rect2(78, y, 70, 14), Rect2(172, y, 74, 14)]


func _pause_buttons() -> Array[Rect2]:
	var y := view_h - 22
	return [Rect2(78, y, 70, 14), Rect2(172, y, 74, 14)]


func _build_grass() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var roll := RandomNumberGenerator.new()
	roll.seed = 7
	for y in 32:
		for x in 32:
			var n := roll.randi() % 100
			var c := GRASS
			if n < 3:
				c = GRASS_DARK
			elif n < 5:
				c = GRASS_LIGHT
			elif n == 7 and (x + y) % 9 == 0:
				c = FLOWER
			img.set_pixel(x, y, c)
	grass_tex = ImageTexture.create_from_image(img)


func _build_sprites() -> void:
	_bake("pine", PINE_ROWS, {"O": OUTLINE, "G": PINE, "D": PINE_DARK, "T": TRUNK})
	_bake("rock", ROCK_ROWS, {"O": OUTLINE, "G": ROCK, "W": ROCK_LIGHT})
	_bake("stump", STUMP_ROWS, {"O": OUTLINE, "T": TRUNK, "W": WOOD})
	var log := {"O": OUTLINE, "T": TRUNK, "W": WOOD}
	_bake("trunk_across", TRUNK_ACROSS, log)
	_bake("trunk_down", _transpose(TRUNK_ACROSS), log)
	_bake("table", TABLE_ROWS, {"O": OUTLINE, "T": WOOD})
	var mound := {"F": DIRT_LIGHT, "E": DIRT_EDGE}
	_bake("rise", RISE_ROWS, mound)
	_bake("rise_big", RISE_BIG_ROWS, mound)
	var fur := {
		"O": Color8(0, 0, 0),
		"G": Color8(156, 98, 48),
		"D": Color8(88, 50, 26),
		"R": Color8(255, 0, 0),
		"Y": Color8(236, 228, 206),
	}
	_bake("bigfoot", BIGFOOT_ROWS, fur)
	_bake("bigfoot_run_a", BIGFOOT_RUN_A, fur)
	_bake("bigfoot_run_b", BIGFOOT_RUN_B, fur)
	_bake("bigfoot_lift_a", BIGFOOT_LIFT_A, fur)
	_bake("bigfoot_lift_b", BIGFOOT_LIFT_B, fur)
	_bake("bigfoot_throw", BIGFOOT_THROW, fur)
	for info in Rides.all():
		var id := String(info.id)
		var colors := {"O": OUTLINE, "K": info.shirt, "W": WOOD, "B": RUBBER, "T": TRUNK}
		_bake(id, _rows_for(id), colors)
		_bake(id + "_grab", _rows_for(id + "_grab"), colors)
		_bake(id + "_down", WRECK_ROWS, colors)
		for pose in ["slight", "medium", "hard", "skate", "climb", "spread", "air", "side"]:
			_bake(id + "_" + pose, _rows_for(id + "_" + pose), colors)


func _rows_for(id: String) -> Array:
	match id:
		"bike":
			return BIKE_ROWS
		"bike_slight":
			return BIKE_SLIGHT
		"bike_medium":
			return BIKE_MEDIUM
		"bike_hard":
			return BIKE_HARD
		"bike_skate":
			return BIKE_SKATE
		"bike_climb":
			return BIKE_CLIMB
		"bike_spread":
			return BIKE_SPREAD
		"bike_air":
			return BIKE_AIR
		"bike_side":
			return BIKE_SIDE
		"bike_grab":
			return BIKE_GRAB
		"thumper":
			return THUMPER_ROWS
		"thumper_slight":
			return THUMPER_SLIGHT
		"thumper_medium":
			return THUMPER_MEDIUM
		"thumper_hard":
			return THUMPER_HARD
		"thumper_skate":
			return THUMPER_SKATE
		"thumper_climb":
			return THUMPER_CLIMB
		"thumper_spread":
			return THUMPER_SPREAD
		"thumper_air":
			return THUMPER_AIR
		"thumper_side":
			return THUMPER_SIDE
		"thumper_grab":
			return THUMPER_GRAB
		"deck_slight":
			return DECK_SLIGHT
		"deck_medium":
			return DECK_MEDIUM
		"deck_hard":
			return DECK_HARD
		"deck_skate":
			return DECK_SKATE
		"deck_climb":
			return DECK_CLIMB
		"deck_spread":
			return DECK_SPREAD
		"deck_air":
			return DECK_AIR
		"deck_side":
			return DECK_SIDE
		"deck_grab":
			return DECK_GRAB
		_:
			return DECK_ROWS


func _bake(id: String, rows: Array, colors: Dictionary) -> void:
	var height := rows.size()
	var width := int(rows[0].length())
	for row in rows:
		if int(row.length()) != width:
			push_error("sprite width " + id)
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in height:
		var line: String = rows[y]
		for x in width:
			var ch := line[x]
			if ch == ".":
				continue
			if not colors.has(ch):
				push_error("sprite color " + id + " " + ch)
				continue
			img.set_pixel(x, y, colors[ch])
	tex[id] = ImageTexture.create_from_image(img)


func _stamp_pose(at: Vector2) -> void:
	var id := String(ride.id)
	var flip := false
	if mode == Mode.WRECK:
		_stamp(id + "_down", at)
		return
	if height > 0.05:
		if air_lean != 0:
			id += "_air"
			flip = air_lean > 0
		else:
			id += "_spread"
	elif show_pose == "skate" or show_pose == "climb":
		id += "_" + show_pose
		flip = heading > 0
	else:
		match absi(heading):
			1:
				id += "_slight"
			2:
				id += "_medium"
			3:
				id += "_hard"
		flip = heading > 0
	if flip:
		_stamp_x(id, at)
	else:
		_stamp(id, at)


func _stamp(id: String, at: Vector2) -> void:
	if not tex.has(id):
		return
	var image_tex: Texture2D = tex[id]
	var s := image_tex.get_size()
	draw_texture(image_tex, at - Vector2(floor(s.x * 0.5), s.y - 1.0))


func _stamp_x(id: String, at: Vector2) -> void:
	if not tex.has(id):
		return
	var image_tex: Texture2D = tex[id]
	var s := image_tex.get_size()
	var left: float = at.x - floorf(s.x * 0.5)
	var top: float = at.y - (s.y - 1.0)
	draw_set_transform(Vector2(left + s.x, top), 0.0, Vector2(-1, 1))
	draw_texture(image_tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _stamp_flipped(id: String, at: Vector2) -> void:
	if not tex.has(id):
		return
	var image_tex: Texture2D = tex[id]
	var s := image_tex.get_size()
	draw_set_transform(at - Vector2(floor(s.x * 0.5), 1.0), 0.0, Vector2(1, -1))
	draw_texture(image_tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_font() -> void:
	glyphs = {
		" ": ["...", "...", "...", "...", "..."],
		".": ["...", "...", "...", "...", ".#."],
		"-": ["...", "...", "###", "...", "..."],
		"0": ["###", "#.#", "#.#", "#.#", "###"],
		"1": [".#.", ".#.", ".#.", ".#.", ".#."],
		"2": ["###", "..#", "###", "#..", "###"],
		"3": ["###", "..#", "###", "..#", "###"],
		"4": ["#.#", "#.#", "###", "..#", "..#"],
		"5": ["###", "#..", "###", "..#", "###"],
		"6": ["###", "#..", "###", "#.#", "###"],
		"7": ["###", "..#", "..#", "..#", "..#"],
		"8": ["###", "#.#", "###", "#.#", "###"],
		"9": ["###", "#.#", "###", "..#", "###"],
		"A": [".#.", "#.#", "###", "#.#", "#.#"],
		"B": ["##.", "#.#", "##.", "#.#", "##."],
		"C": [".##", "#..", "#..", "#..", ".##"],
		"D": ["##.", "#.#", "#.#", "#.#", "##."],
		"E": ["###", "#..", "##.", "#..", "###"],
		"F": ["###", "#..", "##.", "#..", "#.."],
		"G": [".##", "#..", "#.#", "#.#", ".##"],
		"H": ["#.#", "#.#", "###", "#.#", "#.#"],
		"I": ["###", ".#.", ".#.", ".#.", "###"],
		"J": ["..#", "..#", "..#", "#.#", ".#."],
		"K": ["#.#", "#.#", "##.", "#.#", "#.#"],
		"L": ["#..", "#..", "#..", "#..", "###"],
		"M": ["#.#", "###", "#.#", "#.#", "#.#"],
		"N": ["#.#", "##.", "#.#", "#.#", "#.#"],
		"O": [".#.", "#.#", "#.#", "#.#", ".#."],
		"P": ["##.", "#.#", "##.", "#..", "#.."],
		"Q": [".#.", "#.#", "#.#", ".##", "..#"],
		"R": ["##.", "#.#", "##.", "#.#", "#.#"],
		"S": [".##", "#..", ".#.", "..#", "##."],
		"T": ["###", ".#.", ".#.", ".#.", ".#."],
		"U": ["#.#", "#.#", "#.#", "#.#", "###"],
		"V": ["#.#", "#.#", "#.#", "#.#", ".#."],
		"W": ["#.#", "#.#", "#.#", "###", "#.#"],
		"X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
		"Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
		"Z": ["###", "..#", ".#.", "#..", "###"],
	}


func _text_px(x: int, y: int, text: String, scale: int, color: Color) -> void:
	var shown := text.to_upper()
	var cx := x
	for i in shown.length():
		var ch := shown[i]
		var rows: Array = glyphs.get(ch, glyphs[" "])
		for row in 5:
			var line: String = rows[row]
			for col in 3:
				if line[col] == "#":
					draw_rect(Rect2(cx + col * scale, y + row * scale, scale, scale), color)
		cx += 4 * scale


func _ink(x: int, y: int, text: String, scale: int) -> void:
	if scale > 1:
		_text_px(x + scale, y + scale, text, scale, PAPER)
	_text_px(x, y, text, scale, INK)


func _ink_center(y: int, text: String, scale: int) -> void:
	var w := text.to_upper().length() * 4 * scale
	_ink(int((view_w - w) * 0.5), y, text, scale)


func _meters(meters: float) -> String:
	return "%d M" % maxi(0, int(meters))


const PINE_ROWS: Array = [
	".......O.......",
	"......OGO......",
	".....OGGGO.....",
	"....OGDDDGO....",
	"...OGGDDDGGO...",
	"....OGDDDGO....",
	"...OGGDDDGGO...",
	"..OGDDDDDDDGO..",
	".OGGGDDDDDGGO..",
	"..OGDDDDDDDGO..",
	".OGGDDDDDDDGO..",
	"OGGGDDDDDDDDGGO",
	".OGGDDDDDDDGGO.",
	"OGGGDDDDDDDDGGO",
	".OGGDDDDDDDDGO.",
	"OGGGDDDDDDDDGGO",
	".OGDDDDDDDDDGO.",
	"..OGGDDDDDGGO..",
	"...OGDDDDDGO...",
	"....OGDDDGO....",
	".....OGGGO.....",
	"......OGO......",
	"......OTO......",
	"......OTO......",
	"......OTO......",
	"......OTO......",
	"......OTO......",
	".....OTTTO.....",
	".....OTTTO.....",
	".....OOOOO.....",
	"......OOO......",
]
const ROCK_ROWS: Array = [
	"...OOOOO...",
	"..OGGGGGO..",
	".OGWWWWWGO.",
	".OGWWWWWGO.",
	"..OGGGGGO..",
	"...OOOOO...",
]
const STUMP_ROWS: Array = [
	"..OOOOO..",
	".OTTTTTO.",
	".OTWWWTO.",
	".OTTTTTO.",
	"..OOOOO..",
	"...OTO...",
	"...OTO...",
]
const TABLE_ROWS: Array = [
	".OOOOOOOOOOOO.",
	"OTTTTTTTTTTTTO",
	"OTTTTTTTTTTTTO",
	"O..O......O..O",
]
const DECK_SIDE: Array = [
	"..........OOO.............",
	".........O.K.O............",
	"..........OOO.............",
	".........OKKKO............",
	"........O.KKK.O...........",
	"...........O.O............",
	"..........O...O...........",
	".........O.....O..........",
	"..OWWWWWWWWWWWWWWWWWWWWO..",
	"..OBWWWWWWWWWWWWWWWWWWBO..",
	".....OBO............OBO...",
	".....OOO............OOO...",
]
const BIKE_SIDE: Array = [
	"...........OOO..................",
	"..........O.K.O.................",
	"...........OOO..................",
	"..........OKKKO.................",
	".........OOOOOOOOOOOOOOOOOO.....",
	"............O............OO.....",
	".............O...........O......",
	"........OWWWWO...........O......",
	".......OOOOOOOOOOOOOOOOOOO......",
	"...OOO....................OOO...",
	"..O...O..................O...O..",
	".O..B..O................O..B..O.",
	".O..B..O................O..B..O.",
	"..O...O..................O...O..",
	"...OOO....................OOO...",
]
const THUMPER_SIDE: Array = [
	"..............OOO.................",
	".............O.K.O................",
	"..............OOO.................",
	".............OKKKKO...............",
	"............OOOOOOOOOOOOOOOO......",
	"...............O............OO....",
	"................O...........O.....",
	".................O..........O.....",
	".............OWWWWO.........O.....",
	"..OOOO.......OTTTTO.........OOOO..",
	".O....O......OTTTTO........O....O.",
	".O.BB.O......OTTTTO........O.BB.O.",
	".O.BB.O......OOOOOO........O.BB.O.",
	".O....O....................O....O.",
	"..OOOO......................OOOO..",
]
const DECK_ROWS: Array = [
	".....OOO.....",
	"....O.K.O....",
	"....OKKKO....",
	".....OOO.....",
	"....OKKKO....",
	"...OKKKKKO...",
	"....OKKKO....",
	".....O.O.....",
	".....O.O.....",
	"....O...O....",
	"...OWWWWWO...",
	"..OBWWWWWBO..",
	".OBWWWWWWWBO.",
	"..OOOOOOOOO..",
]
const BIKE_ROWS: Array = [
	".....OBO.....",
	"....OO.OO....",
	".....O.O.....",
	"...OOOOOOO...",
	"....O.K.O....",
	"....OKKKO....",
	"...OKKKKKO...",
	"....OKKKO....",
	".....O.O.....",
	"....O.O.O....",
	"...O..O..O...",
	"..OBBB.BBBO..",
	".OBBBBBBBBBO.",
	"..OBBBBBBBO..",
	"...OOOOOOO...",
]
const THUMPER_ROWS: Array = [
	"......OBO......",
	".....OO.OO.....",
	"......O.O......",
	"...OOOOOOOOO...",
	".....O.K.O.....",
	".....OKKKO.....",
	"....OKKKKKO....",
	"...OKKKKKKKO...",
	"....OKKKKKO....",
	"......O.O......",
	".....O.O.O.....",
	"....OWWWWWO....",
	"..OBBBBBBBBBO..",
	".OBBBBBBBBBBBO.",
	"..OBBBBBBBBBO..",
	"...OOOOOOOOO...",
]
const DECK_GRAB: Array = [
	"O.O.......O.O",
	".O.........O.",
	"..O..OOO..O..",
	".O..O.K.O..O.",
	".O..OKKKO..O.",
	"..O.OKKKO.O..",
	".O.O.KKK.O.O.",
	"...O.....O...",
	"..O.......O..",
	"...OWWWWWO...",
	"..OBWWWWWBO..",
	".OBWWWWWWWBO.",
	"..OOOOOOOOO..",
]

const BIKE_GRAB: Array = [
	"O.O.......O.O",
	".O.........O.",
	"..O..OOO..O..",
	".O..O.K.O..O.",
	".O..OKKKO..O.",
	"..O..OOO..O..",
	"...O.....O...",
	"..O.......O..",
	"...OOOOOOO...",
	"....O...O....",
	"..OBBB.BBBO..",
	".OBBBBBBBBBO.",
	"..OBBBBBBBO..",
	"...OOOOOOO...",
]

const THUMPER_GRAB: Array = [
	"O.O.........O.O",
	".O...........O.",
	"..O...OOO...O..",
	".O...O.K.O...O.",
	".O...OKKKO...O.",
	"..O..OKKKO..O..",
	"...O.......O...",
	"..O.........O..",
	"....OWWWWWO....",
	"...O.......O...",
	"..OBBBBBBBBBO..",
	".OBBBBBBBBBBBO.",
	"..OBBBBBBBBBO..",
	"...OOOOOOOOO...",
]
const DECK_SLIGHT: Array = [
	"......OOO......",
	".....O.K.O.....",
	".....OKKKO.....",
	"......OOO......",
	".....OKKKO.....",
	"....OKKKKKO....",
	".....OKKKO.....",
	"......O.O......",
	".....O..O......",
	"....OWWWWO.....",
	"...OBWWWWBO....",
	"..OBWWWWBO.....",
	".OOOOOOO.......",
]
const DECK_MEDIUM: Array = [
	"....OOO........",
	"...O.K.O.......",
	"...OKKKO.......",
	"....OOO........",
	"...OKKKKO......",
	"....OKKKO......",
	".....O.O.......",
	"....O...O......",
	"...OWWWWWO.....",
	"..OBWWWWWBO....",
	".OBWWWWWWBO....",
	"..OOOOOOOO.....",
]
const DECK_HARD: Array = [
	"..........OOO..",
	".........O.K.O.",
	".........OKKKO.",
	"..........OOO..",
	"........OKKKKO.",
	"........O.O.O..",
	".......O.....O.",
	"OWWWWWWWWWWWWWO",
	"OBWWWWWWWWWWWBO",
	".OOOOOOOOOOOOO.",
]
const DECK_SKATE: Array = [
	"...........OOO.",
	"..........O.K.O",
	"..........OKKKO",
	"...........OOO.",
	".........OKKKKO",
	".........O.O.O.",
	"........O.....O",
	"OWWWWWWWWWWWWWW",
	"OBWWWWWWWWWWWWB",
	".OOOOOOOOOOOOOO",
]
const DECK_CLIMB: Array = [
	"..........OOO..",
	".........O.K.O.",
	".........OKKKO.",
	"..........OOO..",
	"........OKK.KO.",
	"........O...O..",
	".......O.....O.",
	"............O..",
	"OWWWWWWWWWWWWWO",
	"OBWWWWWWWWWWWBO",
	".OOOOOOOOOOOOO.",
]
const DECK_SPREAD: Array = [
	"O.....OOO.....O",
	".O...O.K.O...O.",
	"..O..OKKKO..O..",
	"....OKKKKKO....",
	".....OKKKO.....",
	"......O.O......",
	".....O...O.....",
	"....OWWWWWO....",
	"...OBWWWWWBO...",
	"..OBWWWWWWWBO..",
	"...OOOOOOOOO...",
]
const DECK_AIR: Array = [
	"...OOO.........",
	"..O.K.O........",
	"..OKKKO........",
	"...OOO.........",
	"..OKKKKO.......",
	"...O.O.O.......",
	"..O.....O......",
	".OWWWWWWWWO....",
	"OBWWWWWWWWWBO..",
	".OOOOOOOOOOOO..",
]
const BIKE_SLIGHT: Array = [
	".....OBO.......",
	"....OO.OO......",
	".....O.O.......",
	"...OOOOOOO.....",
	"....O.K.O......",
	"....OKKKO......",
	"...OKKKKKO.....",
	"....OKKKO......",
	".....O.O.......",
	"....O.O.O......",
	"...O..O..O.....",
	"..OBB..OBBO....",
	".OBBBB.OBBBO...",
	"..OOO...OOO....",
]
const BIKE_MEDIUM: Array = [
	"...OBO.........",
	"..OO.OO........",
	"...O.O.........",
	".OOOOOOO.......",
	"..O.K.O........",
	"..OKKKO........",
	".OKKKKKO.......",
	"..OKKKO........",
	"...O.O.........",
	"..O.O.O........",
	".O..O..O.......",
	"OBB...OBBO.....",
	"OBBB..OBBBO....",
	".OO....OOO.....",
]
const BIKE_HARD: Array = [
	"..OOO..........",
	".O.K.O.........",
	".OKKKO.........",
	"..OOO..........",
	".OKKKKO........",
	"..O.O.O........",
	".O..O..O.......",
	"OBBO....OBBO...",
	"OBBBO..OBBBO...",
	".OOO....OOO....",
]
const BIKE_SKATE: Array = [
	".OOO...........",
	"O.K.O..........",
	"OKKKO..........",
	".OOO...........",
	"OKKKKO.........",
	".O.O.O.........",
	"O..O..O........",
	"BBO....OBBO....",
	"BBBO..OBBBO....",
	"OOO....OOO.....",
]
const BIKE_CLIMB: Array = [
	"..OOO..........",
	".O.K.O.........",
	".OKKKO.........",
	"..OOO..........",
	".OK.KKO........",
	"..O...O........",
	".O..O..O.......",
	"OBBO....OBBO...",
	"OBBBO..OBBBO...",
	".OOO....OOO....",
]
const BIKE_SPREAD: Array = [
	"O.....OBO.....O",
	".O...OO.OO...O.",
	"..O...O.O...O..",
	"....OOOOOOO....",
	"....O.K.O......",
	"....OKKKO......",
	"...OKKKKKO.....",
	"....OKKKO......",
	".....O.O.......",
	"....O.O.O......",
	"...OBB.OBBO....",
	"..OBBB.OBBBO...",
	"...OO...OO.....",
]
const BIKE_AIR: Array = [
	"...OBO.........",
	"..OO.OO........",
	"...O.O.........",
	".OOOOOOO.......",
	"..O.K.O........",
	"..OKKKO........",
	".OKKKKKO.......",
	"..OKKKO........",
	"...O.O.........",
	"..O.O.O........",
	".OBB..OBBO.....",
	"OBBBB.OBBBO....",
	".OO....OOO.....",
]
const THUMPER_SLIGHT: Array = [
	".....OBO.......",
	"....OO.OO......",
	".....O.O.......",
	"...OOOOOOO.....",
	".....O.K.O.....",
	"....OKKKKO.....",
	"...OKKKKKKO....",
	"..OKKKKKKKKO...",
	"...OKKKKKKO....",
	".....O.O.......",
	"....O.O.O......",
	"...OWWWWWO.....",
	"..OBBB.BBBBO...",
	".OBBBBB.BBBBO..",
	"..OOO...OOO....",
]
const THUMPER_MEDIUM: Array = [
	"...OBO.........",
	"..OO.OO........",
	"...O.O.........",
	".OOOOOOO.......",
	"...O.K.O.......",
	"..OKKKKO.......",
	".OKKKKKKO......",
	"OKKKKKKKKO.....",
	".OKKKKKKO......",
	"...O.O.........",
	"..O.O.O........",
	".OWWWWWWO......",
	"OBBBB.BBBBO....",
	"OBBBBB.BBBBO...",
	".OO....OOO.....",
]
const THUMPER_HARD: Array = [
	"..OOO..........",
	".O.K.O.........",
	".OKKKKO........",
	"..OOO..........",
	".OKKKKKKO......",
	"..O.O.O........",
	".OWWWWWWWWWWO..",
	"OBBBO....OBBBO.",
	"OBBBBO..OBBBBO.",
	".OOO......OOO..",
]
const THUMPER_SKATE: Array = [
	".OOO...........",
	"O.K.O..........",
	"OKKKKO.........",
	".OOO...........",
	"OKKKKKKO.......",
	".O.O.O.........",
	"OWWWWWWWWWWWO..",
	"BBBO....OBBBO..",
	"BBBBO..OBBBBO..",
	"OOO......OOO...",
]
const THUMPER_CLIMB: Array = [
	"..OOO..........",
	".O.K.O.........",
	".OKKKKO........",
	"..OOO..........",
	".OK.KKKO.......",
	"..O...O........",
	".OWWWWWWWWWWO..",
	"OBBBO....OBBBO.",
	"OBBBBO..OBBBBO.",
	".OOO......OOO..",
]
const THUMPER_SPREAD: Array = [
	"O.....OBO.....O",
	".O...OO.OO...O.",
	"..O...O.O...O..",
	"....OOOOOOO....",
	"....O.K.O......",
	"...OKKKKKO.....",
	"..OKKKKKKKO....",
	"...OKKKKKKO....",
	".....O.O.......",
	"....OWWWWWO....",
	"...OBBB.BBBO...",
	"..OBBBBBBBBBO..",
	"...OOO.OOO.....",
]
const THUMPER_AIR: Array = [
	"...OBO.........",
	"..OO.OO........",
	"...O.O.........",
	".OOOOOOOOO.....",
	"...O.K.O.......",
	"..OKKKKKO......",
	".OKKKKKKKO.....",
	"..OKKKKKO......",
	"...O.O.........",
	"..OWWWWWWO.....",
	".OBBBB.BBBBO...",
	"OBBBBBB.BBBBO..",
	".OO....OOO.....",
]
const TRUNK_ACROSS: Array = [
	".OOOOOOOOOOOOOOOOOOO.",
	"OTWWWWWWWWWWWWWWWWWTO",
	"OTTTTTTTTTTTTTTTTTTTO",
	"OTWWWWWWWWWWWWWWWWWTO",
	".OOOOOOOOOOOOOOOOOOO.",
]
const RISE_ROWS: Array = [
	"......FFFF......",
	"....FFFFFFFF....",
	"..FFFFFFFFFFFF..",
	".EEEEEEEEEEEEEE.",
]
const RISE_BIG_ROWS: Array = [
	"........FFFFFFFF........",
	"......FFFFFFFFFFFF......",
	".....FFFFFFFFFFFFFF.....",
	"....FFFFFFFFFFFFFFFF....",
	"...FFFFFFFFFFFFFFFFFF...",
	"..FFFFFFFFFFFFFFFFFFFF..",
	".FFFFFFFFFFFFFFFFFFFFFF.",
	"EEEEEEEEEEEEEEEEEEEEEEEE",
]
const BIGFOOT_RUN_A: Array = [
	"......OOOOOOO......",
	".....OGGDGGDGO.....",
	".....OODGGDGOO.....",
	".....OOOOOOOOO.....",
	".....OGGRGDGRGO....",
	"......OGGDGGO......",
	".....OYOYOYOYO.....",
	"......OOOOOOO......",
	"....OOGDGGDGGOO....",
	"....O.OGGGDGO..O...",
	".OOO..ODGGGGO..O...",
	"O.O.O.OGGGDGO..O...",
	"......OGDDGGO..OOO.",
	"......OGGGGGO.O.O.O",
	"......O.....O......",
	"......O....OOO.....",
	"......O...O.O.O....",
	"......O...G.G.G....",
	".....OOO...........",
	"....O.O.O..........",
	"....G.G.G..........",
]

const BIGFOOT_RUN_B: Array = [
	"......OOOOOOO......",
	".....OGDGGDGGO.....",
	".....OOGDGGDOO.....",
	".....OOOOOOOOO.....",
	"....OGRGDGRGGO.....",
	"......OGGDGGO......",
	".....OYOYOYOYO.....",
	"......OOOOOOO......",
	"....OOGGDGGDGOO....",
	"...O..OGDGGGO.O....",
	"...O..OGGGGDO..OOO.",
	"...O..OGDGGGO.O.O.O",
	".OOO..OGGDDGO......",
	"O.O.O.OGGGGGO......",
	"......O.....O......",
	".....OOO....O......",
	"....O.O.O...O......",
	"....G.G.G...O......",
	"...........OOO.....",
	"..........O.O.O....",
	"..........G.G.G....",
]

const BIGFOOT_LIFT_A: Array = [
	"O.O.O...............O.O.O",
	".OOO.................OOO.",
	"..O...................O..",
	"...O.................O...",
	"....O...............O....",
	".....O.............O.....",
	"......O..OOOOOOO...O.....",
	"......O.OGGDGGDGO..O.....",
	"......O.OODGGDGOO..O.....",
	"......O.OOOOOOOOO..O.....",
	"......O.OGGRGDGRGO.O.....",
	"......O..OGGDGGO...O.....",
	"......O.OYOYOYOYO..O.....",
	"......O..OOOOOOO...O.....",
	".......OOGDGGDGGOOO......",
	".........OGGGDGO.........",
	".........ODGGGGO.........",
	".........OGGGDGO.........",
	".........OGDDGGO.........",
	".........OGGGGGO.........",
	".........O.....O.........",
	".........O.....O.........",
	".........O.....O.........",
	"........OOO...OOO........",
	".......O.O.O.O.O.O.......",
	".......G.G.G.G.G.G.......",
]

const BIGFOOT_LIFT_B: Array = [
	"..O.O.O...........O.O.O..",
	"...OOO.............OOO...",
	"....O...............O....",
	".....O.............O.....",
	"......O............O.....",
	"......O............O.....",
	"......O..OOOOOOO...O.....",
	"......O.OGGDGGDGO..O.....",
	"......O.OODGGDGOO..O.....",
	"......O.OOOOOOOOO..O.....",
	"......O.OGGRGDGRGO.O.....",
	"......O..OGGDGGO...O.....",
	"......O.OYOYOYOYO..O.....",
	"......O..OOOOOOO...O.....",
	".......OOGDGGDGGOOO......",
	".........OGGGDGO.........",
	".........ODGGGGO.........",
	".........OGGGDGO.........",
	".........OGDDGGO.........",
	".........OGGGGGO.........",
	".........O.....O.........",
	".........O.....O.........",
	".........O.....O.........",
	"........OOO...OOO........",
	".......O.O.O.O.O.O.......",
	".......G.G.G.G.G.G.......",
]

const BIGFOOT_THROW: Array = [
	"......OOOOOOO......",
	".....OGGDGGDGO.....",
	".....OODGGDGOO.....",
	".....OOOOOOOOO.....",
	".....OGGRGDGRGO....",
	"......OGGDGGO......",
	".....OYOYOYOYO.....",
	"......OOOOOOO......",
	"....OOGDGGDGGOO....",
	"....O.OGGGDGO.O....",
	"....O.ODGGGGO.O....",
	"....O.OGGDGGO.O....",
	"....O.OGGDDGO.O....",
	"...OOO.......OOO...",
	"..O.O.O.....O.O.O..",
	"......O.....O......",
	"......O.....O......",
	"......O.....O......",
	".....OOO...OOO.....",
	"....O.O.O.O.O.O....",
	"....G.G.G.G.G.G....",
]
const BIGFOOT_ROWS: Array = [
	"......OOOOOOO......",
	".....OGGDGGDGO.....",
	".....OODGGDGOO.....",
	".....OOOOOOOOO.....",
	".....OGGRGDGRGO....",
	"......OGGDGGO......",
	".....OYOYOYOYO.....",
	"......OOOOOOO......",
	"....OOGDGGDGGOO....",
	"...O..OGGGDGO..O...",
	"..O...ODGGGGO...O..",
	".OOO..OGGGDGO..OOO.",
	"O.O.O.OGGDGGO.O.O.O",
	"......OGDDGGO......",
	"......OGGGGGO......",
	"......O.....O......",
	"......O.....O......",
	"......O.....O......",
	".....OOO...OOO.....",
	"....O.O.O.O.O.O....",
	"....G.G.G.G.G.G....",
]
const WRECK_ROWS: Array = [
	"...............",
	"..OOO..........",
	".O.K.O.........",
	".OKKKKO........",
	"OKKKKKKKO......",
	".OKKKKKO.......",
	"..O.O.O........",
	".OOOOOOO.......",
	"..BB..BB.......",
]
