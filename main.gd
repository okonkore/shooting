extends Node2D

const W := 430.0
const H := 760.0
const PLAYER_Y := 675.0
const GAME_FONT: Font = preload("res://assets/NotoSansJP-Regular.otf")

var started := false
var game_over := false
var upgrade_open := false
var player_x := W / 2.0
var target_x := W / 2.0
var score := 0
var stage := 1
var player_damage := 1
var horizontal_shots := 1
var charge_multiplier := 8
var charge_radius := 32.0
var cell_respawn_delay := 4.5
var core_hp := 0
var core_max_hp := 0
var core_armor := 0
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var upgrade_choices: Array[Dictionary] = []
var press_active := false
var press_elapsed := 0.0
var gesture_moved := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	setup_stage()
	queue_redraw()

func setup_stage() -> void:
	enemies.clear()
	shots.clear()
	core_armor = 10 + stage * 4
	core_max_hp = 44 + stage * 28
	core_hp = core_max_hp
	var rows := mini(5, 3 + stage / 2)
	for row in rows:
		for column in 7:
			var durability: int = 2 + row + stage
			var evolution := rng.randf() < 0.16
			enemies.append({"pos": Vector2(58 + column * 52, 175 + row * 46), "kind": row % 3, "hp": durability, "max_hp": durability, "alive": true, "respawn": 0.0, "evolution": evolution})

func begin() -> void:
	started = true
	game_over = false
	upgrade_open = false
	score = 0
	stage = 1
	player_damage = 1
	horizontal_shots = 1
	charge_multiplier = 8
	charge_radius = 32.0
	cell_respawn_delay = 4.5
	player_x = W / 2.0
	target_x = player_x
	setup_stage()

func _process(delta: float) -> void:
	if started and not game_over and not upgrade_open:
		player_x = move_toward(player_x, clamp(target_x, 28.0, W - 28.0), 460.0 * delta)
		if press_active:
			press_elapsed = min(1.2, press_elapsed + delta)
		advance_cells(delta)
		advance_shots(delta)
	queue_redraw()

func advance_cells(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive:
			enemy.respawn -= delta
			if enemy.respawn <= 0.0:
				enemy.alive = true
				enemy.hp = enemy.max_hp

func advance_shots(delta: float) -> void:
	for shot in shots:
		shot.pos.y -= shot.speed * delta
	shots = shots.filter(func(shot): return shot.pos.y > -45.0)
	for shot in shots:
		var hit := false
		for enemy in enemies:
			if enemy.alive and enemy not in shot.hit_enemies and shot.pos.distance_to(enemy.pos) < 18.0 + shot.radius:
				enemy.hp -= shot.damage
				shot.hit_enemies.append(enemy)
				hit = true
				if enemy.hp <= 0:
					destroy_cell(enemy)
				break
		if not shot.hit_core and shot.pos.distance_to(Vector2(W / 2.0, 95.0)) < 35.0 + shot.radius:
			hit = true
			shot.hit_core = true
			if shot.damage >= core_armor:
				core_hp -= shot.damage
				if core_hp <= 0:
					stage += 1
					setup_stage()
		if hit and not shot.charged:
			shot.pos.y = -100.0

func destroy_cell(enemy: Dictionary) -> void:
	enemy.alive = false
	enemy.respawn = cell_respawn_delay
	score += 10
	if enemy.evolution:
		open_upgrades()

func fire_normal() -> void:
	for i in horizontal_shots:
		var offset := (i - (horizontal_shots - 1) / 2.0) * 16.0
		shots.append({"pos": Vector2(player_x + offset, PLAYER_Y - 24), "speed": 720.0, "damage": player_damage, "radius": 4.0, "charged": false, "hit_enemies": [], "hit_core": false})

func fire_charged() -> void:
	shots.append({"pos": Vector2(player_x, PLAYER_Y - 28), "speed": 480.0, "damage": player_damage * charge_multiplier, "radius": charge_radius, "charged": true, "hit_enemies": [], "hit_core": false})

func open_upgrades() -> void:
	var pool: Array[Dictionary] = [
		{"id": "damage", "title": "攻撃細胞", "text": "通常弾の火力 +1"},
		{"id": "split", "title": "横分裂", "text": "同時発射を横方向に +1"},
		{"id": "charge", "title": "濃縮膜", "text": "溜め弾の火力倍率 +2"},
		{"id": "radius", "title": "膨張核", "text": "溜め弾の範囲 +10"},
		{"id": "recovery", "title": "再生阻害", "text": "敵の再生まで +1.2秒"}
	]
	pool.shuffle()
	upgrade_choices = [pool[0], pool[1], pool[2]]
	upgrade_open = true
	press_active = false

func choose_upgrade(index: int) -> void:
	var upgrade: Dictionary = upgrade_choices[index]
	match upgrade.id:
		"damage": player_damage += 1
		"split": horizontal_shots += 1
		"charge": charge_multiplier += 2
		"radius": charge_radius += 10.0
		"recovery": cell_respawn_delay += 1.2
	upgrade_open = false

func start_press() -> void:
	press_active = true
	press_elapsed = 0.0
	gesture_moved = false

func release_press() -> void:
	if not press_active:
		return
	if press_elapsed >= 0.38:
		fire_charged()
	elif not gesture_moved:
		fire_normal()
	press_active = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not started or game_over:
				begin()
			elif upgrade_open:
				choose_upgrade_at(event.position * W / get_viewport_rect().size.x)
			else:
				start_press()
		else:
			release_press()
	elif event is InputEventScreenDrag and started and not game_over and not upgrade_open:
		var delta_x: float = event.relative.x * W / get_viewport_rect().size.x
		target_x = clamp(target_x + delta_x, 28.0, W - 28.0)
		if abs(delta_x) > 1.0:
			gesture_moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not started or game_over:
				begin()
			elif upgrade_open:
				choose_upgrade_at(event.position * W / get_viewport_rect().size.x)
			else:
				start_press()
		else:
			release_press()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and started and not game_over and not upgrade_open:
		var mouse_delta_x: float = event.relative.x * W / get_viewport_rect().size.x
		target_x = clamp(target_x + mouse_delta_x, 28.0, W - 28.0)
		if abs(mouse_delta_x) > 1.0:
			gesture_moved = true

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
	draw_string(GAME_FONT, Vector2(20, 35), "CELL CORE BREAKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("a6ffcf"))
	draw_string(GAME_FONT, Vector2(20, 61), "SCORE %05d  FIRE %d" % [score, player_damage], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8fb7af"))
	draw_string(GAME_FONT, Vector2(318, 61), "STAGE %02d" % stage, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8fb7af"))
	draw_core()
	if started:
		draw_player()
		for enemy in enemies:
			draw_enemy(enemy)
		for shot in shots:
			draw_shot(shot)
	if not started:
		draw_panel("CELL CORE BREAKER", "連打で通常弾、長押しして離すと溜め弾。", "画面をタップして開始")
	elif game_over:
		draw_panel("CULTURE LOST", "SCORE %d" % score, "画面をタップしてリトライ")
	elif not upgrade_open:
		draw_string(GAME_FONT, Vector2(59, 742), "連打: 通常弾   長押し→離す: 範囲溜め弾", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("79a59d"))
	if upgrade_open:
		draw_upgrade_panel()

func draw_core() -> void:
	var p := Vector2(W / 2.0, 95.0)
	draw_circle(p, 30, Color("3e2152"))
	draw_circle(p, 22, Color("c96dff"))
	draw_circle(p, 8, Color("f5d5ff"))
	draw_rect(Rect2(p.x - 62, 132, 124, 6), Color("351d43"))
	draw_rect(Rect2(p.x - 62, 132, 124.0 * core_hp / core_max_hp, 6), Color("d893ff"))
	draw_string(GAME_FONT, Vector2(130, 153), "最奥コア  必要火力 %d" % core_armor, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9b4f4"))

func draw_player() -> void:
	var p := Vector2(player_x, PLAYER_Y)
	var ship := PackedVector2Array([p + Vector2(0, -23), p + Vector2(-24, 22), p + Vector2(24, 22)])
	draw_colored_polygon(ship, Color("77f6be"))
	draw_circle(p + Vector2(0, 3), 7, Color("e8fff4"))
	if press_active:
		var power: float = clampf(press_elapsed / 0.9, 0.0, 1.0)
		draw_arc(p, 31, -PI / 2.0, -PI / 2.0 + TAU * power, 20, Color("f9dc80"), 4)
		draw_string(GAME_FONT, p + Vector2(-30, 48), "溜め %.0f%%" % (power * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f9dc80"))

func draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos
	if not enemy.alive:
		draw_arc(p, 17, 0, TAU, 18, Color("2d5755"), 2)
		draw_string(GAME_FONT, p + Vector2(-16, 4), "再生中", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("6ea19a"))
		return
	var colors := [Color("ff7498"), Color("ffcf6d"), Color("9b8cff")]
	var c: Color = colors[int(enemy.kind)]
	if enemy.evolution:
		c = Color("52d7ff")
	draw_circle(p, 17, c)
	draw_circle(p + Vector2(-6, -2), 3, Color("07151b"))
	draw_circle(p + Vector2(6, -2), 3, Color("07151b"))
	draw_line(p + Vector2(-7, 7), p + Vector2(7, 7), Color("07151b"), 2)
	draw_rect(Rect2(p.x - 17, p.y - 27, 34, 4), Color("351d28"))
	draw_rect(Rect2(p.x - 17, p.y - 27, 34.0 * float(enemy.hp) / enemy.max_hp, 4), Color("aaffca"))
	draw_string(GAME_FONT, p + Vector2(-16, -32), "HP %d" % enemy.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("eafff5"))
	if enemy.evolution:
		draw_string(GAME_FONT, p + Vector2(-24, 34), "進化細胞", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("99eaff"))

func draw_shot(shot: Dictionary) -> void:
	var color := Color("f5f899") if not shot.charged else Color("ffbd71")
	draw_circle(shot.pos, shot.radius, color)
	if shot.charged:
		draw_arc(shot.pos, shot.radius + 5, 0, TAU, 20, Color("ffe7ae"), 2)

func draw_upgrade_panel() -> void:
	draw_rect(Rect2(18, 185, W - 36, 410), Color("07151bf2"))
	draw_rect(Rect2(18, 185, W - 36, 410), Color("71eab9"), false, 2)
	draw_string(GAME_FONT, Vector2(86, 235), "EVOLUTION MATERIAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("b8ffda"))
	draw_string(GAME_FONT, Vector2(93, 264), "進化をひとつ選択", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c3d8d2"))
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
	draw_string(GAME_FONT, Vector2(48, 322), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("b2ffd4"))
	draw_string(GAME_FONT, Vector2(42, 365), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c3d8d2"))
	draw_rect(Rect2(55, 396, 320, 43), Color("65dca9"))
	draw_string(GAME_FONT, Vector2(95, 423), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("07151b"))
