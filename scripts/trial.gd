class_name Trial
extends Node

## **시련.** 가구를 열었다가 걸리는 것입니다.
##
## # 왜 필요한가
##
## 층을 도는 일이 "적을 다 잡고 문으로 간다" 하나뿐이라 금방 같아집니다.
## 시련은 **방 하나를 잠깐 다른 규칙으로** 바꿉니다 - 같은 방인데 무엇을
## 해야 하는지가 달라지면, 이미 있는 기술들이 새 자리에서 다시 쓰입니다.
##
## # 왜 방을 닫는가
##
## 안 닫으면 답이 늘 "걸어 나간다" 하나입니다. 나갈 수 없어야 손에 있는
## 것으로 버티는 일이 되고, 그때 막기·구르기·패링이 처음으로 값을 합니다.
##
## # 왜 셋인가
##
## 하나면 두 번째 판에 이미 압니다. 셋을 고른 기준은 **손이 하는 일이 서로
## 달라야 한다**입니다.
##
##   버티기   맞지 않고 살아 있기   ->  구르기·막기
##   모으기   돌아다니며 줍기       ->  이동·길 고르기
##   무결점   한 대도 안 맞기       ->  패링·거리 재기
##
## 셋이 같은 답을 가지면 종류가 여럿인 뜻이 없습니다.

signal finished(won: bool, kind: String)

## 시련 종류. 화면 이름과 길이가 여기 한 곳에 있습니다.
const KINDS := {
	"hold": {
		"label": "버티기", "time": 60.0,
		"note": "60초를 버텨라. 하늘에서 공이 떨어진다.",
	},
	"gather": {
		"label": "모으기", "time": 45.0,
		"note": "흩어진 사탕을 모두 주워라.",
	},
	"flawless": {
		"label": "무결점", "time": 40.0,
		"note": "40초 동안 한 대도 맞지 마라.",
	},
}

## 방을 가두는 울타리 색. 반투명한 노랑입니다 - 붉으면 아픈 것으로 읽힙니다.
const WALL_TINT := Color(1.0, 0.82, 0.32, 0.22)
## 방 안쪽으로 이만큼 들어온 자리까지만 갈 수 있습니다.
const WALL_INSET := 0.9

## 버티기: 적을 다시 세우는 간격과 한 번에 몇을 세우나.
const HOLD_SPAWN := 4.5
const HOLD_BATCH := 2
## 이보다 많으면 더 안 세웁니다. 무한히 쌓이면 버티기가 아니라 끼는 놀이가
## 되고, 폰에서는 그것이 그대로 값입니다(유닛 하나에 콜 열셋).
const HOLD_CAP := 7

## 버티기: 공이 떨어지는 간격과 예고 시간.
const BALL_EVERY := 1.5
const BALL_WARN := 0.9
const BALL_RADIUS := 1.05
const BALL_DAMAGE := 14.0

## 모으기: 흩어 놓는 사탕 수.
const GATHER_COUNT := 12

var kind := "hold"
var left := 0.0
var running := false

var _game: Node = null
var _player: Node3D = null
var _center := Vector3.ZERO
var _half := Vector2.ZERO

var _spawn_t := 0.0
var _ball_t := 0.0
var _balls: Array = []
var _hp_at_start := 0.0
var _fence: Node3D = null
## 떨군 공의 수. 재는 자리에서 씁니다 - 공은 0.9초만 살아서, 어느 한
## 순간에 세면 있을 때도 없을 때도 있습니다.
var balls_dropped := 0


func start(game: Node, player: Node3D, room: Rect2i, trial_kind: String) -> void:
	_game = game
	_player = player
	kind = trial_kind
	left = float(KINDS[kind]["time"])
	running = true
	_hp_at_start = float(player.state.hp)

	var dungeon = game.dungeon
	var a: Vector3 = dungeon.cell_to_world(Vector2i(room.position.x, room.position.y))
	var b: Vector3 = dungeon.cell_to_world(Vector2i(
		room.position.x + room.size.x - 1, room.position.y + room.size.y - 1))
	_center = (a + b) * 0.5
	_half = Vector2(absf(b.x - a.x), absf(b.z - a.z)) * 0.5 - Vector2(WALL_INSET, WALL_INSET)
	_half.x = maxf(_half.x, 1.5)
	_half.y = maxf(_half.y, 1.5)

	_build_fence()
	if kind == "gather":
		_scatter_candy()


func _build_fence() -> void:
	## 방을 닫는 울타리. **그림만**입니다.
	##
	## 물리 몸체로 만들지 않은 이유: 가두는 일은 자리를 되밀어서 합니다
	## (`_keep_inside`). 몸체면 적과 공이 같이 걸려서, 방 안이 아니라 울타리
	## 앞이 싸움터가 됩니다.
	_fence = Node3D.new()
	_fence.name = "TrialFence"
	_game.world.add_child(_fence)
	_fence.global_position = _center
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WALL_TINT
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		var along: float = _half.x if i < 2 else _half.y
		box.size = Vector3(along * 2.0, 2.2, 0.08)
		wall.mesh = box
		wall.material_override = mat
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.set_meta("flat", true)
		match i:
			0: wall.position = Vector3(0, 1.1, -_half.y)
			1: wall.position = Vector3(0, 1.1, _half.y)
			2:
				wall.position = Vector3(-_half.x, 1.1, 0)
				wall.rotation.y = PI * 0.5
			3:
				wall.position = Vector3(_half.x, 1.1, 0)
				wall.rotation.y = PI * 0.5
		_fence.add_child(wall)


func _scatter_candy() -> void:
	## 모으기: 방 안에 사탕을 흩습니다. **줍는 것은 원래 방식 그대로**입니다
	## (`Pickup`) - 새 규칙을 만들면 손이 배울 것이 하나 늘어납니다.
	for i in GATHER_COUNT:
		var ang := TAU * float(i) / float(GATHER_COUNT) + randf() * 0.5
		var r := 0.45 + randf() * 0.5
		var at := _center + Vector3(
			cos(ang) * _half.x * r, 0.0, sin(ang) * _half.y * r)
		var coin := Pickup.new()
		_game.world.add_child(coin)
		coin.setup(3, at)
		coin.add_to_group("trial_candy")


func tick(delta: float) -> void:
	if not running or not is_instance_valid(_player):
		return
	left -= delta
	_keep_inside()
	match kind:
		"hold":
			_drive_hold(delta)
		"gather":
			_drive_gather()
		"flawless":
			# 한 대라도 맞으면 그 자리에서 끝입니다. **체력으로 봅니다** - 새
			# 판정을 만들면 막기가 30% 새는 것까지 따로 세야 합니다.
			if float(_player.state.hp) < _hp_at_start - 0.01:
				_end(false)
				return
			_drive_hold(delta)
	_drive_balls(delta)
	if left <= 0.0:
		# 모으기는 시간이 다 되면 실패, 나머지는 버텨 냈으니 성공입니다.
		_end(kind != "gather")


func _keep_inside() -> void:
	## 방 밖으로 못 나갑니다. **몸을 되밀어** 가둡니다.
	var p: Vector3 = _player.global_position
	var dx := clampf(p.x - _center.x, -_half.x, _half.x)
	var dz := clampf(p.z - _center.z, -_half.y, _half.y)
	var want := Vector3(_center.x + dx, p.y, _center.z + dz)
	if want.distance_squared_to(p) > 0.0001:
		_player.global_position = want


func _drive_hold(delta: float) -> void:
	## 적이 계속 나옵니다. **방 안에만** 세웁니다 - 밖에 세우면 울타리 너머에
	## 서서 아무 일도 안 일어납니다.
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = HOLD_SPAWN
	if _game.get_tree().get_nodes_in_group("enemies").size() >= HOLD_CAP:
		return
	for _i in HOLD_BATCH:
		var ang := randf() * TAU
		var at := _center + Vector3(
			cos(ang) * _half.x * 0.85, 0.0, sin(ang) * _half.y * 0.85)
		_game.spawn_trial_foe(at)


func _drive_gather() -> void:
	if _game.get_tree().get_nodes_in_group("trial_candy").size() <= 0:
		_end(true)


func _drive_balls(delta: float) -> void:
	## 하늘에서 공이 떨어집니다. **먼저 바닥에 자국이 뜹니다** - 예고 없이
	## 떨어지면 피할 수 없고, 피할 수 없는 것은 어렵지 않고 억울합니다.
	if kind != "hold":
		return
	_ball_t -= delta
	if _ball_t <= 0.0:
		_ball_t = BALL_EVERY
		balls_dropped += 1
		_spawn_ball()
	for i in range(_balls.size() - 1, -1, -1):
		var b: Dictionary = _balls[i]
		b["t"] = float(b["t"]) - delta
		var mark: Node3D = b["mark"]
		var ball: Node3D = b["ball"]
		if not is_instance_valid(mark) or not is_instance_valid(ball):
			_balls.remove_at(i)
			continue
		var u := 1.0 - clampf(float(b["t"]) / BALL_WARN, 0.0, 1.0)
		mark.scale = Vector3(0.35 + u * 0.65, 1.0, 0.35 + u * 0.65)
		ball.global_position = Vector3(ball.global_position.x,
			lerpf(7.0, 0.35, u * u), ball.global_position.z)
		if float(b["t"]) <= 0.0:
			_land_ball(ball.global_position)
			mark.queue_free()
			ball.queue_free()
			_balls.remove_at(i)


func _spawn_ball() -> void:
	var at := _center + Vector3(
		randf_range(-_half.x, _half.x) * 0.9, 0.0,
		randf_range(-_half.y, _half.y) * 0.9)
	var mark := MeshInstance3D.new()
	mark.mesh = Fx.fan_mesh(BALL_RADIUS, 360.0, 24)
	var mm := Fx.fan_material()
	mm.albedo_color = Enemy.WARN_LATE
	mark.material_override = mm
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.set_meta("flat", true)
	_game.world.add_child(mark)
	mark.global_position = at + Vector3(0, 0.05, 0)

	var ball := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.34
	sph.height = 0.68
	sph.radial_segments = 12
	sph.rings = 7
	ball.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.94, 0.46, 0.30)
	bm.roughness = 0.85
	ball.material_override = bm
	_game.world.add_child(ball)
	ball.global_position = at + Vector3(0, 7.0, 0)
	_balls.append({"t": BALL_WARN, "mark": mark, "ball": ball})


func _land_ball(at: Vector3) -> void:
	Fx.burst(_game.world, at + Vector3(0, 0.3, 0), Color(0.94, 0.6, 0.4), 12, 2.6)
	Sfx.play(Sfx.PUSH, -4.0, -0.2)
	# **적도 맞습니다.** 나만 아프면 그냥 피해 다니는 장애물이고, 적도 맞으면
	# 적을 공 밑으로 몰아넣는 놀이가 생깁니다(함정과 같은 사정입니다).
	if is_instance_valid(_player) and _player.global_position.distance_to(at) < BALL_RADIUS:
		_player.take_damage(BALL_DAMAGE, at)
	for n in _game.get_tree().get_nodes_in_group("enemies"):
		var foe := n as Node3D
		if is_instance_valid(foe) and foe.global_position.distance_to(at) < BALL_RADIUS:
			foe.take_damage(BALL_DAMAGE, false, Vector3.ZERO, 0.0, at)


func _end(won: bool) -> void:
	if not running:
		return
	running = false
	for b in _balls:
		for k in ["mark", "ball"]:
			var n: Node = b[k]
			if is_instance_valid(n):
				n.queue_free()
	_balls.clear()
	if is_instance_valid(_fence):
		_fence.queue_free()
	for n in _game.get_tree().get_nodes_in_group("trial_candy"):
		if is_instance_valid(n):
			(n as Node).queue_free()
	finished.emit(won, kind)
