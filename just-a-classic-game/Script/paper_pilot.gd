extends Node2D

const W := 480.0
const H := 270.0
const PLANE_X := 130.0
const GRAVITY := 900.0
const FLAP := -290.0
const PENCIL_W := 24.0
const EDGE := 32.0

const PAPER := Color("f4efe1")
const RULE := Color("bcd4f0")
const MARGIN := Color("f3a0a8")
const INK := Color("1a1423")
const WHITE := Color("fff7e8")
const GREY := Color("8b8aa6")
const GREY_DARK := Color("55526e")
const RED := Color("e84a5f")
const YELLOW := Color("ffd23f")
const BLUE := Color("4aa3ff")
const BLUE_DARK := Color("2e5aa8")
const PINK := Color("ff6f9c")
const LIME := Color("8ee05a")
const ORANGE := Color("ff8a3d")
const WOOD := Color("e0a068")
const SKINS := [["Classic", 0, "fff7e8", "a9c4e8", "e84a5f"], ["Sky", 40, "bfe3ff", "6fa8dc", "2e5aa8"], ["Lemon", 60, "fff3a8", "ffd23f", "ff8a3d"], ["Mint", 80, "d4f7d0", "8ee05a", "2f8f5b"], ["Candy", 120, "ffd6e6", "ff6f9c", "fff7e8"], ["Midnight", 160, "3a3556", "1a1423", "ffd23f"], ["Gold", 250, "ffe58a", "e0a830", "fff7e8"], ["Rainbow", 400, "", "", ""]]
const SHOP_X := 25.0
const SHOP_Y := 52.0
const TILE := Vector2(100, 78)

var state := "menu"
var plane_y := H / 2.0
var vel := 0.0
var pencils: Array = []
var doodles: Array = []
var parts: Array = []
var pops: Array = []
var scroll := 0.0
var score := 0
var best := 0
var new_best := false
var shake := 0.0
var t := 0.0
var crash_rot := 0.0
var over_t := 0.0
var flash := 0.0
var font: Font
var snd := {}
var players: Array = []
var paused := false
var raining := false
var rain_left := 0
var rain_amt := 0.0
var drops: Array = []
var fogging := false
var fog_amt := 0.0
var msg := ""
var pending := ""
var cash := 0
var run_cash := 0
var owned: Array = [0]
var skin := 0
var coin_pops: Array = []
var shop_msg := ""
var shop_msg_t := 0.0
var massing := false
var mass_amt := 0.0
var erasers: Array = []
var eraser_t := 0.0
var since_riser := 0.0
var msg_t := 0.0


func _ready() -> void:
	var win := get_tree().root
	win.content_scale_size = Vector2i(int(W), int(H))
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	win.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	randomize()
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://font.ttf"):
		font = load("res://font.ttf")
	_load_best()
	_make_sounds()
	for i in 14:
		doodles.append([Vector2(randf_range(0, W), randf_range(30, H - 30)), randi() % 5])
	_reset()


func _reset() -> void:
	plane_y = H / 2.0
	vel = 0.0
	score = 0
	new_best = false
	run_cash = 0
	raining = false
	rain_left = 0
	rain_amt = 0.0
	fogging = false
	fog_amt = 0.0
	msg = ""
	pending = ""
	msg_t = 0.0
	crash_rot = 0.0
	pencils.clear()
	massing = false
	mass_amt = 0.0
	erasers.clear()
	eraser_t = 1.5
	since_riser = 0.0
	var x := W + 40.0
	while x < W * 2.2:
		_add_pencil(x)
		x += _spacing()


func _gap() -> float:
	return maxf(118.0 - score * 1.6, 70.0)


func _speed() -> float:
	return minf(115.0 + score * 3.0, 230.0)


func _spacing() -> float:
	return maxf(190.0 - score * 1.2, 150.0)


func _add_pencil(x: float) -> void:
	var g := _gap()
	var m := g / 2.0 + 18.0
	var last: float = H / 2.0
	if not pencils.is_empty():
		last = pencils.back()[1]
	var wiggle := minf(55.0 + score * 2.0, 110.0)
	var c := clampf(last + randf_range(-wiggle, wiggle), m, H - m)
	var col: Color = [YELLOW, BLUE, PINK, LIME, ORANGE].pick_random()
	var moving := score >= 15 and randf() < minf(0.15 + (score - 15) * 0.02, 0.5)
	pencils.append([x, c, g, false, col, moving, randf() * TAU, 0, 0, 0.0, 0.0])


func _unhandled_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_Z, KEY_ENTER])
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F11:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if e.keycode == KEY_ESCAPE and state == "shop":
			state = "menu"
			return
		if e.keycode == KEY_ESCAPE or e.keycode == KEY_P:
			if state == "play":
				paused = not paused
				_play("point", 0.7)
			return
		if e.keycode == KEY_M:
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
			return
	if not tap:
		return
	if paused:
		paused = false
		return
	var mp := get_global_mouse_position()
	var clicked: bool = e is InputEventMouseButton
	match state:
		"menu":
			if clicked and _shop_btn().has_point(mp):
				state = "shop"
				_play("point", 1.0)
			elif not clicked or _start_btn().has_point(mp):
				_start()
		"shop":
			if clicked:
				_shop_click(mp)
		"ready":
			state = "play"
			_flap()
		"play":
			_flap()
		"over":
			if over_t > 0.6:
				_reset()
				state = "ready"
				_play("point", 1.2)


func _start() -> void:
	_reset()
	state = "ready"
	_play("point", 1.2)


func _flap() -> void:
	vel = FLAP * (1.0 - 0.35 * rain_amt)
	_play("flap", randf_range(0.9, 1.15))
	for i in 3:
		parts.append([Vector2(PLANE_X - 14, plane_y + 4), Vector2(randf_range(-90, -50), randf_range(10, 50)), 0.35, 0.35, Color(WHITE, 0.9), 4.0])


func _process(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta * 2.5)
	flash = maxf(0.0, flash - delta * 3.0)
	if not paused:
		msg_t = maxf(0.0, msg_t - delta)
	if paused:
		queue_redraw()
		return
	var sp := 60.0
	if state == "play":
		sp = _speed()
	elif state == "over":
		sp = 0.0
	scroll += sp * delta
	var target := 1.0 if raining and state == "play" else 0.0
	if state == "over" and raining:
		target = 1.0
	rain_amt = move_toward(rain_amt, target, delta * 0.6)
	var ftarget := 1.0 if fogging and (state == "play" or state == "over") else 0.0
	fog_amt = move_toward(fog_amt, ftarget, delta * 0.5)
	var mtarget := 1.0 if massing and (state == "play" or state == "over") else 0.0
	mass_amt = move_toward(mass_amt, mtarget, delta * 1.5)
	if rain_amt > 0.0:
		var want := int(rain_amt * 140.0)
		while drops.size() < want:
			drops.append([Vector2(randf_range(-40, W + 40), randf_range(-H, 0)), randf_range(380, 520), randf_range(6, 12)])
	for d in drops:
		d[0].y += d[1] * delta
		d[0].x -= (d[1] * 0.25 + sp * 0.5) * delta
	drops = drops.filter(func(d): return d[0].y < H + 10 and d[0].x > -20)
	for d in doodles:
		d[0].x -= sp * 0.4 * delta
		if d[0].x < -30:
			d[0].x += W + 60
			d[0].y = randf_range(30, H - 30)
	match state:
		"menu", "ready":
			plane_y = H / 2.0 + sin(t * 3.0) * 8.0
			vel = cos(t * 3.0) * 24.0
		"play":
			_update_play(delta, sp)
		"over":
			over_t += delta
			vel += GRAVITY * delta
			plane_y = minf(plane_y + vel * delta, H - 10)
			crash_rot += delta * 8.0
	for p in parts:
		p[0] += p[1] * delta
		p[1] *= 0.92
		p[2] -= delta
	parts = parts.filter(func(p): return p[2] > 0.0)
	for p in pops:
		p[0].y -= 30.0 * delta
		p[2] -= delta
	pops = pops.filter(func(p): return p[2] > 0.0)
	for c in coin_pops:
		c[0].y -= 22.0 * delta
		c[2] -= delta
	coin_pops = coin_pops.filter(func(c): return c[2] > 0.0)
	shop_msg_t = maxf(0.0, shop_msg_t - delta)
	queue_redraw()


func _update_play(delta: float, sp: float) -> void:
	for p in pencils:
		p[0] -= sp * delta
		if p[5]:
			p[6] += delta * 1.6
		if p[7] == 2 and p[0] < PLANE_X + 230:
			p[9] = move_toward(p[9], p[10], 170.0 * delta)
	while pencils.back()[0] < W + 40:
		var last: Array = pencils.back()
		if massing:
			if last[7] == 0:
				_add_row(last[0] + _spacing())
			else:
				_add_row(last[0] + PENCIL_W + 2)
		else:
			_add_pencil(last[0] + (_spacing() if last[7] == 0 else _spacing() + 20))
	_update_erasers(delta, sp)
	if pencils[0][0] < -60:
		pencils.pop_front()
	vel += GRAVITY * (1.0 + 0.5 * rain_amt) * delta
	vel = minf(vel, 520.0 + 120.0 * rain_amt)
	plane_y += vel * delta
	for p in pencils:
		if not p[3] and p[0] + PENCIL_W < PLANE_X - 10:
			p[3] = true
			if p[7] == 1:
				continue
			score += 1
			_play("point", 1.0 + (score % 5) * 0.06)
			pops.append([Vector2(PLANE_X, plane_y - 20), "+1", 0.6])
			if score % 10 == 0:
				_earn(5)
				flash = 1.0
				_play("level", 1.0)
				pops.append([Vector2(W / 2.0, H / 2.0 - 40), "%d!" % score, 1.0])
			_rain_check()
	if plane_y > H - 6 or plane_y < 4:
		_crash()
		return
	for p in pencils:
		if _hit(p):
			_crash()
			return
	for e in erasers:
		if e[4] <= 0.0 and e[0].distance_to(Vector2(PLANE_X, plane_y)) < 13.0:
			_crash()
			return


func _add_row(x: float) -> void:
	var col: Color = [YELLOW, BLUE, PINK, LIME, ORANGE].pick_random()
	since_riser += PENCIL_W + 2
	var kind := 1
	var side := 0
	var ext := 0.0
	if since_riser > 120.0 and (randf() < 0.14 or since_riser > 240.0):
		kind = 2
		side = 1 if randf() < 0.5 else -1
		ext = randf_range(60.0, 125.0)
		since_riser = 0.0
	pencils.append([x, H / 2.0, H - EDGE * 2.0, false, col, false, 0.0, kind, side, 0.0, ext])


func _update_erasers(delta: float, sp: float) -> void:
	if massing:
		eraser_t -= delta
		if eraser_t <= 0.0:
			eraser_t = randf_range(0.9, 1.6)
			_spawn_eraser()
	for e in erasers:
		if e[4] > 0.0:
			e[4] -= delta
			continue
		e[0] += e[1] * delta
		e[2] += e[3] * delta
	erasers = erasers.filter(func(e): return e[4] > 0.0 or (e[0].x > -40 and e[0].x < W + 60))


func _spawn_eraser() -> void:
	var start := Vector2(W + 15, randf_range(EDGE + 15, H - EDGE - 15))
	var aim := Vector2(PLANE_X, clampf(plane_y + randf_range(-60, 60), EDGE + 15, H - EDGE - 15))
	var dir := (aim - start).normalized()
	var k := (start.x + 40.0) / maxf(-dir.x, 0.2)
	var finish := start + dir * k
	erasers.append([start, dir * randf_range(260, 320), dir.angle(), randf_range(-8, 8), 0.9, start, finish])


func _rain_check() -> void:
	if pending != "":
		rain_left = randi_range(5, 15)
		if pending == "rain":
			raining = true
		elif pending == "fog":
			fogging = true
		else:
			massing = true
			since_riser = 0.0
			rain_left = randi_range(8, 12)
			flash = 1.0
			shake = 0.4
		pending = ""
		return
	var nxt := score + 1
	if nxt == 50 and not massing:
		raining = false
		fogging = false
		pending = "mass"
		msg = "Everything snaps into line..."
		msg_t = 3.5
		return
	if raining or fogging or massing:
		rain_left -= 1
		if rain_left <= 0:
			if massing:
				_earn(25)
			else:
				_earn(10)
			raining = false
			fogging = false
			massing = false
		return
	if nxt == 10:
		pending = "rain"
	elif nxt > 10 and (nxt - 10) % 9 == 0 and randf() < 0.1:
		pending = "fog"
	elif nxt > 10 and (nxt - 10) % 13 == 0 and randf() < 0.1:
		pending = "rain"
	if pending == "rain":
		msg = "The skies grow darker..."
		msg_t = 3.5
	elif pending == "fog":
		msg = "A fog is visible in the distance..."
		msg_t = 3.5


func _bounds(p: Array) -> Vector2:
	if p[7] != 0:
		var top := EDGE
		var bot := H - EDGE
		if p[8] == -1:
			top += p[9]
		elif p[8] == 1:
			bot -= p[9]
		return Vector2(top, bot)
	var c := _gap_center(p)
	return Vector2(c - p[2] / 2.0, c + p[2] / 2.0)


func _gap_center(p: Array) -> float:
	if p[5]:
		var m: float = p[2] / 2.0 + 18.0
		return clampf(p[1] + sin(p[6]) * 34.0, m, H - m)
	return p[1]


func _hit(p: Array) -> bool:
	var px: float = p[0]
	if PLANE_X + 11 < px + 2 or PLANE_X - 11 > px + PENCIL_W - 2:
		return false
	var b := _bounds(p)
	var top: float = b.x
	var bot: float = b.y
	return plane_y - 5 < top or plane_y + 5 > bot


func _crash() -> void:
	state = "over"
	over_t = 0.0
	vel = -160.0
	shake = 0.6
	_play("crash", 1.0)
	for i in 22:
		var a := randf() * TAU
		parts.append([Vector2(PLANE_X, plane_y), Vector2.from_angle(a) * randf_range(60, 200), 0.6, 0.6, [WHITE, GREY, RED].pick_random(), randf_range(3, 6)])
	if score > best:
		best = score
		new_best = true
	_save_best()


func _draw() -> void:
	var so := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 8.0
	draw_set_transform(so)
	draw_rect(Rect2(-20, -20, W + 40, H + 40), PAPER)
	var ry := 26.0
	while ry < H + 20:
		draw_rect(Rect2(-20, ry, W + 40, 1), RULE)
		ry += 18.0
	var mx := fposmod(60.0 - scroll, W + 120.0) - 60.0
	draw_rect(Rect2(mx, -20, 2, H + 40), MARGIN)
	for i in 4:
		draw_circle(Vector2(mx - 20, 40 + i * 64), 6, Color("d9d2c0"))
	for d in doodles:
		_doodle(d[0], d[1])
	if state != "menu":
		for p in pencils:
			if p[0] > -60 and p[0] < W + 20:
				_pencil(p)
	for p in parts:
		var a: float = p[2] / p[3]
		draw_rect(Rect2(p[0] - Vector2.ONE * p[5] / 2.0, Vector2.ONE * p[5]), Color(p[4], a))
	for e in erasers:
		if e[4] > 0.0:
			_warn_path(e)
		else:
			_eraser(e[0], e[2])
	if state != "shop":
		_plane(Vector2(PLANE_X, plane_y) + so)
	if rain_amt > 0.0:
		draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(0.2, 0.25, 0.35, 0.22 * rain_amt))
		for d in drops:
			var dp: Vector2 = d[0]
			draw_line(dp, dp + Vector2(-d[2] * 0.3, d[2]), Color(0.45, 0.6, 0.85, 0.7 * rain_amt), 1.5)
	if fog_amt > 0.0:
		_draw_fog()
	draw_set_transform(Vector2.ZERO)
	for p in pops:
		_text(p[1], p[0], 16 if p[1] == "+1" else 32, BLUE_DARK, true)
	for c in coin_pops:
		var ca := clampf(c[2], 0.0, 1.0)
		_coin(c[0] + Vector2(-16, -5), 6.0, ca)
		_text(c[1], c[0] + Vector2(6, 0), 16, Color(ORANGE, ca), true, 3, Color(INK, ca))
	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, flash * 0.25))
	match state:
		"menu":
			_draw_menu()
		"ready":
			_score_box()
			_banner("GET READY", "tap, click or press space to flap")
		"shop":
			_draw_shop()
		"play":
			_score_box()
			_cash_box()
			_scenario_box()
			_caption()
		"over":
			_draw_over()
	if paused:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
		_text("PAUSED", Vector2(W / 2.0, H / 2.0 - 10), 32, WHITE, true)
		_text("click or space to continue", Vector2(W / 2.0, H / 2.0 + 20), 12, WHITE, true)


func _plane(base: Vector2) -> void:
	var rot := clampf(vel / 500.0, -0.5, 0.8)
	if state == "over":
		draw_set_transform(base, crash_rot)
		draw_circle(Vector2.ZERO, 12, INK)
		draw_circle(Vector2.ZERO, 10.5, WHITE)
		draw_line(Vector2(-5, -3), Vector2(3, 2), GREY, 1.5)
		draw_line(Vector2(-2, 5), Vector2(5, -5), GREY, 1.5)
		draw_line(Vector2(-6, 3), Vector2(-1, -6), GREY, 1.5)
		draw_set_transform(Vector2.ZERO)
		return
	var top := PackedVector2Array([Vector2(18, 0), Vector2(-15, -13), Vector2(-7, 0)])
	var under := PackedVector2Array([Vector2(18, 0), Vector2(-7, 0), Vector2(-15, 10)])
	for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		draw_set_transform(base + o, rot)
		draw_colored_polygon(top, INK)
		draw_colored_polygon(under, INK)
	draw_set_transform(base, rot)
	_plane_paint(skin)
	draw_set_transform(Vector2.ZERO)


func _plane_paint(id: int) -> void:
	var top := PackedVector2Array([Vector2(18, 0), Vector2(-15, -13), Vector2(-7, 0)])
	var under := PackedVector2Array([Vector2(18, 0), Vector2(-7, 0), Vector2(-15, 10)])
	var cols := _skin_cols(id)
	draw_colored_polygon(top, cols[0])
	draw_colored_polygon(under, cols[1])
	draw_line(Vector2(-12, -7), Vector2(7, -2), cols[2], 3)
	draw_line(Vector2(17, 0), Vector2(-7, 0), GREY_DARK, 1.5)


func _skin_cols(id: int) -> Array:
	var sk: Array = SKINS[id]
	if sk[2] == "":
		var h := fposmod(t * 0.4, 1.0)
		return [Color.from_hsv(h, 0.35, 1.0), Color.from_hsv(fposmod(h + 0.33, 1.0), 0.6, 0.95), Color.from_hsv(fposmod(h + 0.66, 1.0), 0.8, 0.95)]
	return [Color(sk[2]), Color(sk[3]), Color(sk[4])]


func _plane_preview(base: Vector2, id: int, sc: float) -> void:
	var top := PackedVector2Array([Vector2(18, 0), Vector2(-15, -13), Vector2(-7, 0)])
	var under := PackedVector2Array([Vector2(18, 0), Vector2(-7, 0), Vector2(-15, 10)])
	var rot := sin(t * 2.0 + id) * 0.08
	for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		draw_set_transform(base + o, rot, Vector2(sc, sc))
		draw_colored_polygon(top, INK)
		draw_colored_polygon(under, INK)
	draw_set_transform(base, rot, Vector2(sc, sc))
	_plane_paint(id)
	draw_set_transform(Vector2.ZERO)


func _pencil(p: Array) -> void:
	var x: float = p[0]
	var b := _bounds(p)
	var top: float = floor(b.x)
	var bot: float = floor(b.y)
	var col: Color = p[4]
	_pencil_body(x, -20.0, top - 18, col)
	_pencil_tip(x, top - 18, 1)
	_pencil_body(x, bot + 18, H + 20.0, col)
	_pencil_tip(x, bot + 18, -1)
	if p[5]:
		draw_rect(Rect2(x + 6, top - 40, 12, 3), Color(INK, 0.3))
		draw_rect(Rect2(x + 6, bot + 37, 12, 3), Color(INK, 0.3))


func _warn_path(e: Array) -> void:
	var s0: Vector2 = e[5]
	var s1: Vector2 = e[6]
	var n := (s1 - s0).normalized().orthogonal() * 9.0
	var blink := 0.55 + 0.45 * sin(t * 18.0)
	var pts := PackedVector2Array([s0 + n, s1 + n, s1 - n, s0 - n])
	draw_colored_polygon(pts, Color(RED, 0.12 * blink))
	pts.append(s0 + n)
	draw_polyline(pts, Color(RED, 0.9 * blink), 2.0)


func _eraser(c: Vector2, rot: float) -> void:
	_quad(c, Vector2(20, 11), rot, INK)
	_quad(c, Vector2(17, 8), rot, PINK)
	_quad(c + Vector2(4, 0).rotated(rot), Vector2(7, 8), rot, BLUE)


func _quad(c: Vector2, size: Vector2, rot: float, col: Color) -> void:
	var hx := Vector2(size.x / 2.0, 0).rotated(rot)
	var hy := Vector2(0, size.y / 2.0).rotated(rot)
	draw_colored_polygon(PackedVector2Array([c - hx - hy, c + hx - hy, c + hx + hy, c - hx + hy]), col)


func _pencil_body(x: float, y0: float, y1: float, col: Color) -> void:
	if y1 <= y0:
		return
	draw_rect(Rect2(x, y0, PENCIL_W, y1 - y0), INK)
	draw_rect(Rect2(x + 2, y0, PENCIL_W - 4, y1 - y0), col)
	draw_rect(Rect2(x + 7, y0, 2, y1 - y0), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(x + 15, y0, 3, y1 - y0), Color(0, 0, 0, 0.15))
	if y0 >= 0:
		draw_rect(Rect2(x, y1 - 16, PENCIL_W, 6), GREY)
		draw_rect(Rect2(x + 2, y1 - 10, PENCIL_W - 4, 10), PINK)
	else:
		draw_rect(Rect2(x, y0 + 10, PENCIL_W, 6), GREY)
		draw_rect(Rect2(x + 2, y0, PENCIL_W - 4, 10), PINK)


func _pencil_tip(x: float, y: float, d: int) -> void:
	var cx := x + PENCIL_W / 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + PENCIL_W, y), Vector2(cx, y + 18 * d)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y), Vector2(x + PENCIL_W - 2, y), Vector2(cx, y + 16 * d)]), WOOD)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 3, y + 11 * d), Vector2(cx + 3, y + 11 * d), Vector2(cx, y + 18 * d)]), GREY_DARK)


func _doodle(p: Vector2, kind: int) -> void:
	var c := Color(BLUE_DARK, 0.3)
	match kind:
		0:
			var pts := PackedVector2Array()
			for i in 11:
				var r := 8.0 if i % 2 == 0 else 3.5
				pts.append(p + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
			draw_polyline(pts, c, 1.5)
		1:
			draw_arc(p, 8, 0, TAU, 16, c, 1.5)
			draw_rect(Rect2(p + Vector2(-3, -3), Vector2(2, 2)), c)
			draw_rect(Rect2(p + Vector2(2, -3), Vector2(2, 2)), c)
			draw_arc(p + Vector2(0, 1), 4, 0.3, PI - 0.3, 8, c, 1.5)
		2:
			_text("A+", p, 14, c, true)
		3:
			draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), c, 1.5)
			draw_line(p + Vector2(3, -5), p + Vector2(8, 0), c, 1.5)
			draw_line(p + Vector2(3, 5), p + Vector2(8, 0), c, 1.5)
		4:
			draw_arc(p, 6, 0, TAU, 12, c, 1.5)
			draw_arc(p + Vector2(8, 0), 6, 0, TAU, 12, c, 1.5)


func _earn(n: int) -> void:
	cash += n
	run_cash += n
	coin_pops.append([Vector2(PLANE_X + 30, plane_y - 30), "+%d" % n, 1.2])
	_play("level", 1.4)
	_save_best()


func _coin(c: Vector2, r: float, a: float) -> void:
	draw_circle(c, r + 1.5, Color(INK, a))
	draw_circle(c, r, Color(YELLOW, a))
	draw_circle(c, r * 0.55, Color(ORANGE, a * 0.6))


func _cash_box() -> void:
	_coin(Vector2(18, 18), 7.0, 1.0)
	_text(str(cash), Vector2(30, 24), 16, WHITE, false, 3)


func _start_btn() -> Rect2:
	return Rect2(W / 2.0 - 75, 150, 150, 40)


func _shop_btn() -> Rect2:
	return Rect2(W / 2.0 - 55, 202, 110, 30)


func _back_btn() -> Rect2:
	return Rect2(W / 2.0 - 50, 234, 100, 28)


func _tile(i: int) -> Rect2:
	return Rect2(Vector2(SHOP_X + (i % 4) * (TILE.x + 10), SHOP_Y + int(i / 4) * (TILE.y + 8)), TILE)


func _shop_click(mp: Vector2) -> void:
	if _back_btn().has_point(mp):
		state = "menu"
		_play("point", 0.9)
		return
	for i in SKINS.size():
		if not _tile(i).has_point(mp):
			continue
		if i in owned:
			skin = i
			_play("point", 1.2)
		elif cash >= SKINS[i][1]:
			cash -= SKINS[i][1]
			owned.append(i)
			skin = i
			_play("level", 1.0)
			shop_msg = "Unlocked " + SKINS[i][0] + "!"
			shop_msg_t = 1.5
		else:
			_play("crash", 1.8)
			shop_msg = "Not enough cash"
			shop_msg_t = 1.2
		_save_best()
		return


func _button(r: Rect2, label: String, col: Color, size: int) -> void:
	draw_rect(r.grow(3), INK)
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(1, 1, 1, 0.5))
	_text(label, r.get_center() + Vector2(0, size * 0.36), size, INK, true)


func _draw_shop() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(PAPER, 0.85))
	_text("SHOP", Vector2(W / 2.0, 36), 30, RED, true, 3)
	_coin(Vector2(W - 70, 24), 7.0, 1.0)
	_text(str(cash), Vector2(W - 58, 30), 16, INK, false)
	for i in SKINS.size():
		var r := _tile(i)
		var sel := i == skin
		draw_rect(r.grow(3 if sel else 2), RED if sel else INK)
		draw_rect(r, WHITE)
		_plane_preview(r.position + Vector2(r.size.x / 2.0, 26), i, 1.2)
		_text(SKINS[i][0], r.position + Vector2(r.size.x / 2.0, 54), 13, INK, true)
		if sel:
			_text("EQUIPPED", r.position + Vector2(r.size.x / 2.0, 70), 11, RED, true)
		elif i in owned:
			_text("OWNED", r.position + Vector2(r.size.x / 2.0, 70), 11, BLUE_DARK, true)
		else:
			var can: bool = cash >= SKINS[i][1]
			_coin(r.position + Vector2(r.size.x / 2.0 - 16, 66), 5.0, 1.0)
			_text(str(SKINS[i][1]), r.position + Vector2(r.size.x / 2.0 + 4, 71), 12, INK if can else GREY, true)
	_button(_back_btn(), "BACK", YELLOW, 16)
	if shop_msg_t > 0.0:
		_text(shop_msg, Vector2(W / 2.0, 225), 12, Color(ORANGE, clampf(shop_msg_t * 2.0, 0.0, 1.0)), true, 3)


func _draw_menu() -> void:
	var bob := sin(t * 2.0) * 3.0
	_text("PAPER PILOT", Vector2(W / 2.0 + 3, 100 + bob + 3), 48, Color(INK, 0.25), true)
	_text("PAPER PILOT", Vector2(W / 2.0, 100 + bob), 48, RED, true, 4)
	var r := _start_btn()
	var pulse := 1.0 + sin(t * 5.0) * 0.04
	var rr := Rect2(r.get_center() - r.size * pulse / 2.0, r.size * pulse)
	draw_rect(rr.grow(3), INK)
	draw_rect(rr, YELLOW)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 4)), Color(1, 1, 1, 0.5))
	_text("START", rr.get_center() + Vector2(0, 10), 28, INK, true)
	_button(_shop_btn(), "SHOP", BLUE, 18)


func _draw_over() -> void:
	var a := clampf(over_t * 3.0, 0.0, 1.0)
	var r := Rect2(W / 2.0 - 110, 46, 220, 180)
	draw_rect(r.grow(3), Color(INK, a))
	draw_rect(r, Color(WHITE, a))
	for i in 6:
		draw_rect(Rect2(r.position.x, r.position.y + 30 + i * 22, r.size.x, 1), Color(RULE, a))
	_text("CRASHED!", Vector2(W / 2.0, 84), 30, Color(RED, a), true)
	_text("SCORE", Vector2(W / 2.0 - 50, 116), 12, Color(GREY_DARK, a), true)
	_text(str(score), Vector2(W / 2.0 - 50, 146), 30, Color(INK, a), true)
	_text("BEST", Vector2(W / 2.0 + 50, 116), 12, Color(GREY_DARK, a), true)
	_text(str(best), Vector2(W / 2.0 + 50, 146), 30, Color(INK, a), true)
	if new_best:
		_text("NEW BEST!", Vector2(W / 2.0, 170), 16, Color(ORANGE, a * (0.6 + 0.4 * sin(t * 8.0))), true)
	_coin(Vector2(W / 2.0 - 30, 188), 6.0, a)
	_text("+%d cash" % run_cash, Vector2(W / 2.0 + 8, 193), 14, Color(INK, a), true)
	if over_t > 0.6:
		_text("click or space to fly again", Vector2(W / 2.0, 214), 12, Color(BLUE_DARK, 0.6 + 0.4 * sin(t * 4.0)), true)


func _draw_fog() -> void:
	var fc := Color(0.74, 0.77, 0.82)
	draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(fc, 0.3 * fog_amt))
	var x0 := PLANE_X + 190.0
	var x1 := PLANE_X + 260.0
	var strips := 20
	var sw := (x1 - x0) / strips
	for i in strips:
		var k := float(i + 1) / strips
		draw_rect(Rect2(x0 + i * sw, -20, sw + 1, H + 40), Color(fc, k * fog_amt))
	draw_rect(Rect2(x1, -20, W + 40 - x1, H + 40), Color(fc, fog_amt))
	for i in 7:
		var bx := fposmod(i * 97.0 - t * 22.0, W + 160.0) - 80.0
		var by := 30.0 + fposmod(i * 61.0, H - 60.0) + sin(t * 0.7 + i) * 10.0
		draw_circle(Vector2(bx, by), 46.0 + (i % 3) * 14.0, Color(fc, 0.25 * fog_amt))


func _caption() -> void:
	if msg_t <= 0.0 or msg == "":
		return
	var a := clampf(minf(msg_t, 3.5 - msg_t) * 2.0, 0.0, 1.0)
	var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var r := Rect2(W / 2.0 - w / 2.0 - 14, H - 40, w + 28, 28)
	draw_rect(r, Color(INK, 0.55 * a))
	_text(msg, Vector2(W / 2.0, H - 20), 16, Color(WHITE, a), true)


func _scenario_box() -> void:
	var amt := maxf(maxf(rain_amt, fog_amt), mass_amt)
	if amt <= 0.0:
		return
	var a := clampf(amt * 1.5, 0.0, 1.0)
	var slide := (1.0 - a) * 140.0
	var r := Rect2(W - 132 + slide, 12, 120, 44)
	draw_rect(r.grow(2), Color(INK, a))
	draw_rect(r, Color(0.85, 0.92, 1.0, a))
	draw_rect(Rect2(r.position, Vector2(5, r.size.y)), Color(0.3, 0.5, 0.85, a))
	var blink := 0.8 + 0.2 * sin(t * 6.0)
	_text("SCENARIO ACTIVE", r.position + Vector2(64, 17), 11, Color(RED, a * blink), true)
	var label := "RAIN"
	if mass_amt > 0.0:
		label = "MASS RESET"
	elif fog_amt > rain_amt:
		label = "FOG"
	_text(label, r.position + Vector2(64, 35), 14, Color(INK, a), true)


func _score_box() -> void:
	_text(str(score), Vector2(W / 2.0, 44), 36, WHITE, true, 5)


func _banner(title: String, sub: String) -> void:
	_text(title, Vector2(W / 2.0, 92), 28, BLUE_DARK, true, 3, WHITE)
	_text(sub, Vector2(W / 2.0, 200), 12, GREY_DARK, true)


func _text(s: String, pos: Vector2, size: int, col: Color, center: bool = false, outline: int = 0, outline_col: Color = INK) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if center:
		p.x -= w / 2.0
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(outline_col, col.a))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _make_sounds() -> void:
	snd.flap = _tone(500.0, 900.0, 0.08, "square", 0.12)
	snd.point = _tone(880.0, 1320.0, 0.09, "square", 0.1)
	snd.level = _tone(660.0, 1760.0, 0.35, "square", 0.12)
	snd.crash = _tone(300.0, 60.0, 0.45, "noise", 0.4)
	for i in 6:
		var a := AudioStreamPlayer.new()
		add_child(a)
		players.append(a)


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / rate
		var s := 0.0
		if wave == "square":
			s = 1.0 if sin(phase) > 0.0 else -1.0
		else:
			s = randf_range(-1.0, 1.0) * (0.6 + 0.4 * sin(phase))
		s *= vol * (1.0 - k) * minf(1.0, i / 120.0)
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	return w


func _play(name: String, pitch: float) -> void:
	for a: AudioStreamPlayer in players:
		if not a.playing:
			a.stream = snd[name]
			a.pitch_scale = pitch
			a.play()
			return


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://paper_pilot.save") == OK:
		best = cf.get_value("score", "best", 0)
		cash = cf.get_value("shop", "cash", 0)
		owned = cf.get_value("shop", "owned", [0])
		skin = cf.get_value("shop", "skin", 0)
		if skin < 0 or skin >= SKINS.size() or not skin in owned:
			skin = 0


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "best", best)
	cf.set_value("shop", "cash", cash)
	cf.set_value("shop", "owned", owned)
	cf.set_value("shop", "skin", skin)
	cf.save("user://paper_pilot.save")
