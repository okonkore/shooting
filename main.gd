extends Node2D

const W := 430.0
const H := 760.0
const PLAYER_Y := 675.0

var started := false
var game_over := false
var player_x := W / 2.0
var target_x := W / 2.0
var health := 3
var score := 0
var wave := 1
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var enemy_shots: Array[Dictionary] = []
var enemy_direction := 1.0
var enemy_step_clock := 0.0
var shot_clock := 0.0
var invader_shot_clock := 0.0
var touch_active := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	spawn_wave()
	queue_redraw()

func spawn_wave() -> void:
	enemies.clear()
	shots.clear()
	enemy_shots.clear()
	enemy_direction = 1.0
	var rows := mini(5, 3 + wave / 2)
	for row in rows:
		for column in 7:
			enemies.append({"pos": Vector2(58 + column * 52, 130 + row * 46), "kind": row % 3})

func begin() -> void:
	started = true
	game_over = false
	health = 3
	score = 0
	wave = 1
	player_x = W / 2.0
	target_x = player_x
	spawn_wave()

func _process(delta: float) -> void:
	if started and not game_over:
		player_x = move_toward(player_x, clamp(target_x, 28.0, W - 28.0), 460.0 * delta)
		shot_clock -= delta
		if shot_clock <= 0.0:
			shots.append({"pos": Vector2(player_x, PLAYER_Y - 24)})
			shot_clock = 0.32
		advance_invaders(delta)
		advance_shots(delta)
	queue_redraw()

func advance_invaders(delta: float) -> void:
	enemy_step_clock += delta
	if enemy_step_clock > max(0.17, 0.52 - wave * 0.025):
		enemy_step_clock = 0.0
		var at_edge := false
		for enemy in enemies:
			var x: float = enemy.pos.x + enemy_direction * 13.0
			if x < 30.0 or x > W - 30.0:
				at_edge = true
		if at_edge:
			enemy_direction *= -1.0
			for enemy in enemies:
				enemy.pos.y += 18.0
		else:
			for enemy in enemies:
				enemy.pos.x += enemy_direction * 13.0
	for enemy in enemies:
		if enemy.pos.y > PLAYER_Y - 42:
			lose_life()
			break
	invader_shot_clock -= delta
	if invader_shot_clock <= 0.0 and not enemies.is_empty():
		var shooter: Dictionary = enemies[rng.randi_range(0, enemies.size() - 1)]
		enemy_shots.append({"pos": shooter.pos + Vector2(0, 14)})
		invader_shot_clock = max(0.42, 1.15 - wave * 0.05)

func advance_shots(delta: float) -> void:
	for shot in shots:
		shot.pos.y -= 680.0 * delta
	for shot in enemy_shots:
		shot.pos.y += 320.0 * delta
	shots = shots.filter(func(shot): return shot.pos.y > -20.0)
	enemy_shots = enemy_shots.filter(func(shot): return shot.pos.y < H + 20.0)
	var dead: Array[Dictionary] = []
	for shot in shots:
		for enemy in enemies:
			if enemy not in dead and shot.pos.distance_to(enemy.pos) < 24.0:
				dead.append(enemy)
				shot.pos.y = -100.0
				score += 10
	if not dead.is_empty():
		for enemy in dead:
			enemies.erase(enemy)
	for shot in enemy_shots:
		if shot.pos.distance_to(Vector2(player_x, PLAYER_Y)) < 27.0:
			shot.pos.y = H + 100.0
			lose_life()
	if enemies.is_empty():
		wave += 1
		spawn_wave()

func lose_life() -> void:
	health -= 1
	enemy_shots.clear()
	if health <= 0:
		game_over = true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not started or game_over:
				begin()
			else:
				touch_active = true
				target_x = event.position.x * W / get_viewport_rect().size.x
		else:
			touch_active = false
	elif event is InputEventScreenDrag and started and not game_over:
		target_x = event.position.x * W / get_viewport_rect().size.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not started or game_over:
			begin()
		else:
			target_x = event.position.x * W / get_viewport_rect().size.x
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and started and not game_over:
		target_x = event.position.x * W / get_viewport_rect().size.x

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("07151b"))
	for x in range(0, int(W), 43):
		draw_line(Vector2(x, 0), Vector2(x, H), Color("12363b"), 1.0)
	for y in range(0, int(H), 43):
		draw_line(Vector2(0, y), Vector2(W, y), Color("12363b"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(20, 35), "CELL INVADER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("a6ffcf"))
	draw_string(ThemeDB.fallback_font, Vector2(20, 61), "SCORE %05d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8fb7af"))
	draw_string(ThemeDB.fallback_font, Vector2(305, 61), "WAVE %02d" % wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8fb7af"))
	for heart in health:
		draw_circle(Vector2(365 + heart * 18, 28), 6, Color("ff6f91"))
	if started:
		draw_player()
		for enemy in enemies:
			draw_enemy(enemy.pos, int(enemy.kind))
		for shot in shots:
			draw_rect(Rect2(shot.pos - Vector2(2, 12), Vector2(4, 15)), Color("f5f899"))
		for shot in enemy_shots:
			draw_rect(Rect2(shot.pos - Vector2(2, 2), Vector2(4, 14)), Color("ff7192"))
		if touch_active:
			draw_line(Vector2(player_x, 724), Vector2(target_x, 724), Color("69e8ba"), 3)
	if not started:
		draw_panel("CELL INVADER", "下で左右に動いて、細胞を撃ち落とせ。", "画面をタップして開始")
	elif game_over:
		draw_panel("CULTURE LOST", "SCORE %d  /  WAVE %d" % [score, wave], "画面をタップしてリトライ")
	else:
		draw_string(ThemeDB.fallback_font, Vector2(70, 742), "画面を横にドラッグして移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("79a59d"))

func draw_player() -> void:
	var p := Vector2(player_x, PLAYER_Y)
	var ship := PackedVector2Array([p + Vector2(0, -23), p + Vector2(-24, 22), p + Vector2(24, 22)])
	draw_colored_polygon(ship, Color("77f6be"))
	draw_circle(p + Vector2(0, 3), 7, Color("e8fff4"))

func draw_enemy(p: Vector2, kind: int) -> void:
	var colors := [Color("ff7498"), Color("ffcf6d"), Color("9b8cff")]
	var c: Color = colors[kind]
	draw_circle(p, 17, c)
	draw_circle(p + Vector2(-6, -2), 3, Color("07151b"))
	draw_circle(p + Vector2(6, -2), 3, Color("07151b"))
	draw_line(p + Vector2(-7, 7), p + Vector2(7, 7), Color("07151b"), 2)

func draw_panel(title: String, text: String, action: String) -> void:
	draw_rect(Rect2(22, 258, W - 44, 210), Color("07151be8"))
	draw_rect(Rect2(22, 258, W - 44, 210), Color("55cba0"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(55, 322), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color("b2ffd4"))
	draw_string(ThemeDB.fallback_font, Vector2(55, 365), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c3d8d2"))
	draw_rect(Rect2(55, 396, 320, 43), Color("65dca9"))
	draw_string(ThemeDB.fallback_font, Vector2(95, 423), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("07151b"))
