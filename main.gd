extends Node2D

const W := 430.0
const H := 760.0
const PLAYER_Y := 675.0
const BREACH_LINE := 600.0
const GAME_FONT: Font = preload("res://assets/NotoSansJP-Regular.otf")

var started := false
var game_over := false
var player_x := W / 2.0
var target_x := W / 2.0
var score := 0
var wave := 1
var player_damage := 1
var fire_interval := 0.32
var projectile_count := 1
var shot_width := 4.0
var upgrade_open := false
var upgrade_choices: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var enemy_direction := 1.0
var enemy_step_clock := 0.0
var shot_clock := 0.0
var touch_active := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	spawn_wave()
	queue_redraw()

func spawn_wave() -> void:
	enemies.clear()
	shots.clear()
	enemy_direction = 1.0
	var rows := mini(5, 3 + wave / 2)
	for row in rows:
		for column in 7:
			var mutant := row == 0 and column == 3
			var durability := 2 + row + wave / 2
			if mutant:
				durability += 3
			enemies.append({"pos": Vector2(58 + column * 52, 130 + row * 46), "kind": 3 if mutant else row % 3, "hp": durability, "max_hp": durability, "mutant": mutant})

func begin() -> void:
	started = true
	game_over = false
	score = 0
	wave = 1
	player_damage = 1
	fire_interval = 0.32
	projectile_count = 1
	shot_width = 4.0
	upgrade_open = false
	player_x = W / 2.0
	target_x = player_x
	spawn_wave()

func _process(delta: float) -> void:
	if started and not game_over and not upgrade_open:
		player_x = move_toward(player_x, clamp(target_x, 28.0, W - 28.0), 460.0 * delta)
		shot_clock -= delta
		if shot_clock <= 0.0:
			shoot()
			shot_clock = fire_interval
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
		if enemy.pos.y > BREACH_LINE:
			game_over = true
			break

func advance_shots(delta: float) -> void:
	for shot in shots:
		shot.pos.y -= 680.0 * delta
	shots = shots.filter(func(shot): return shot.pos.y > -20.0)
	var dead: Array[Dictionary] = []
	for shot in shots:
		for enemy in enemies:
			if enemy not in dead and shot.pos.distance_to(enemy.pos) < 22.0 + shot_width:
				enemy.hp -= player_damage
				shot.pos.y = -100.0
				if enemy.hp <= 0:
					dead.append(enemy)
					score += 10
					if enemy.mutant:
						open_upgrades()
	if not dead.is_empty():
		for enemy in dead:
			enemies.erase(enemy)
	if enemies.is_empty():
		wave += 1
		spawn_wave()

func shoot() -> void:
	for i in projectile_count:
		var offset := (i - (projectile_count - 1) / 2.0) * 13.0
		shots.append({"pos": Vector2(player_x + offset, PLAYER_Y - 24)})

func open_upgrades() -> void:
	var pool: Array[Dictionary] = [
		{"id": "damage", "title": "攻撃細胞", "text": "弾丸のダメージ +1"},
		{"id": "rapid", "title": "高速分裂", "text": "発射間隔を 18% 短縮"},
		{"id": "multi", "title": "多重核", "text": "同時発射数 +1"},
		{"id": "pulse", "title": "細胞パルス", "text": "弾丸の幅 +4"},
		{"id": "overload", "title": "過剰分裂", "text": "発射数 +2"}
	]
	pool.shuffle()
	upgrade_choices = [pool[0], pool[1], pool[2]]
	upgrade_open = true

func choose_upgrade(index: int) -> void:
	var upgrade: Dictionary = upgrade_choices[index]
	match upgrade.id:
		"damage": player_damage += 1
		"rapid": fire_interval = max(0.09, fire_interval * 0.82)
		"multi": projectile_count += 1
		"pulse": shot_width += 4.0
		"overload": projectile_count += 2
	upgrade_open = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not started or game_over:
				begin()
			elif upgrade_open:
				choose_upgrade_at(event.position * W / get_viewport_rect().size.x)
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
		elif upgrade_open:
			choose_upgrade_at(event.position * W / get_viewport_rect().size.x)
		else:
			target_x = event.position.x * W / get_viewport_rect().size.x
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and started and not game_over:
		if not upgrade_open:
			target_x = event.position.x * W / get_viewport_rect().size.x

func choose_upgrade_at(p: Vector2) -> void:
	for i in upgrade_choices.size():
		var card := Rect2(42, 285 + i * 86, W - 84, 70)
		if card.has_point(p):
			choose_upgrade(i)
			return

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("07151b"))
	for x in range(0, int(W), 43):
		draw_line(Vector2(x, 0), Vector2(x, H), Color("12363b"), 1.0)
	for y in range(0, int(H), 43):
		draw_line(Vector2(0, y), Vector2(W, y), Color("12363b"), 1.0)
	draw_string(GAME_FONT, Vector2(20, 35), "CELL INVADER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("a6ffcf"))
	draw_string(GAME_FONT, Vector2(20, 61), "SCORE %05d  DAMAGE %d" % [score, player_damage], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8fb7af"))
	draw_string(GAME_FONT, Vector2(305, 61), "WAVE %02d" % wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8fb7af"))
	draw_line(Vector2(12, BREACH_LINE), Vector2(W - 12, BREACH_LINE), Color("ff7192"), 3)
	draw_string(GAME_FONT, Vector2(144, BREACH_LINE - 8), "このラインを越えたら培養失敗", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ff9eaf"))
	if started:
		draw_player()
		for enemy in enemies:
			draw_enemy(enemy)
		for shot in shots:
			draw_rect(Rect2(shot.pos - Vector2(shot_width / 2.0, 12), Vector2(shot_width, 15)), Color("f5f899"))
		if touch_active:
			draw_line(Vector2(player_x, 724), Vector2(target_x, 724), Color("69e8ba"), 3)
	if not started:
		draw_panel("CELL INVADER", "下で左右に動いて、細胞を撃ち落とせ。", "画面をタップして開始")
	elif game_over:
		draw_panel("CULTURE LOST", "ライン突破  /  SCORE %d" % score, "画面をタップしてリトライ")
	else:
		draw_string(GAME_FONT, Vector2(70, 742), "画面を横にドラッグして移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("79a59d"))
	if upgrade_open:
		draw_upgrade_panel()

func draw_player() -> void:
	var p := Vector2(player_x, PLAYER_Y)
	var ship := PackedVector2Array([p + Vector2(0, -23), p + Vector2(-24, 22), p + Vector2(24, 22)])
	draw_colored_polygon(ship, Color("77f6be"))
	draw_circle(p + Vector2(0, 3), 7, Color("e8fff4"))

func draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos
	var kind: int = enemy.kind
	var colors := [Color("ff7498"), Color("ffcf6d"), Color("9b8cff"), Color("d67cff")]
	var c: Color = colors[kind]
	draw_circle(p, 17, c)
	draw_circle(p + Vector2(-6, -2), 3, Color("07151b"))
	draw_circle(p + Vector2(6, -2), 3, Color("07151b"))
	draw_line(p + Vector2(-7, 7), p + Vector2(7, 7), Color("07151b"), 2)
	draw_rect(Rect2(p.x - 17, p.y - 27, 34, 4), Color("351d28"))
	draw_rect(Rect2(p.x - 17, p.y - 27, 34.0 * float(enemy.hp) / enemy.max_hp, 4), Color("aaffca"))
	draw_string(GAME_FONT, p + Vector2(-16, -32), "HP %d" % enemy.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("eafff5"))
	if enemy.mutant:
		draw_string(GAME_FONT, p + Vector2(-19, 34), "変異細胞", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f0aaff"))

func draw_upgrade_panel() -> void:
	draw_rect(Rect2(18, 185, W - 36, 410), Color("07151bf2"))
	draw_rect(Rect2(18, 185, W - 36, 410), Color("71eab9"), false, 2)
	draw_string(GAME_FONT, Vector2(86, 235), "CELL EVOLUTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("b8ffda"))
	draw_string(GAME_FONT, Vector2(93, 264), "強化をひとつ選択", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c3d8d2"))
	for i in upgrade_choices.size():
		var card := Rect2(42, 285 + i * 86, W - 84, 70)
		draw_rect(card, Color("16373a"))
		draw_rect(card, Color("4ba881"), false, 1)
		var choice: Dictionary = upgrade_choices[i]
		draw_string(GAME_FONT, card.position + Vector2(14, 28), "%d. %s" % [i + 1, choice.title], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d0ffe4"))
		draw_string(GAME_FONT, card.position + Vector2(14, 51), choice.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a7cbc1"))

func draw_panel(title: String, text: String, action: String) -> void:
	draw_rect(Rect2(22, 258, W - 44, 210), Color("07151be8"))
	draw_rect(Rect2(22, 258, W - 44, 210), Color("55cba0"), false, 2)
	draw_string(GAME_FONT, Vector2(55, 322), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color("b2ffd4"))
	draw_string(GAME_FONT, Vector2(55, 365), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c3d8d2"))
	draw_rect(Rect2(55, 396, 320, 43), Color("65dca9"))
	draw_string(GAME_FONT, Vector2(95, 423), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("07151b"))
