class_name PillowMatch
extends Node

## **1:1 베개싸움.** 어린이집 탐험과 따로 도는 한 판입니다.
##
## # 왜 따로 두는가
##
## 재미없으면 버릴 것이기 때문입니다. `game.gd` 안에 규칙을 섞어 두면 버릴 때
## 무엇이 이 판의 것이고 무엇이 원래 게임의 것인지 갈라내야 합니다. 이 파일과
## `Game.pillow_mode` 몇 줄만 지우면 흔적이 없어야 합니다.
##
## # 규칙
##
## 둘 다 베개를 듭니다.
##
##   막고 있으면          튕깁니다
##   안 막고 맞으면       **베개를 놓칩니다** (바닥에 떨어집니다)
##   베개가 없으면        못 막습니다
##   베개 없이 또 맞으면  집니다
##
## 떨어진 베개는 **먼저 줍는 쪽이 임자**입니다. 그래서 한 대 맞은 뒤가 이 판의
## 고비입니다 - 주우러 갈지, 상대가 줍기 전에 한 대를 더 넣을지.
##
## # 체력으로 안 한 이유
##
## 체력바로 하면 그냥 지금 게임입니다. **베개 하나가 판 위의 유일한 자원**이면
## 잡기·던지기·나르기·구르기가 전부 그 자원을 둘러싼 동작이 됩니다 - 이
## 프로젝트가 가장 깊게 만들어 둔 넷이 그대로 쓰입니다.
##
## 그리고 누가 이기는 중인지 **숫자가 아니라 화면으로** 압니다. 베개가 누구
## 손에 있나 하나만 보면 됩니다.
##
## # 어떻게 재는가
##
## 맞았는지는 **체력이 줄었는지**로 압니다. 새 판정을 만들지 않습니다 - 지금
## 판정이 이미 막는 각(`Enemy.guard_blocks`)과 사거리를 다 보고 있어서, 그
## 옆에 두 번째 규칙을 두면 눈에 보이는 것과 갈라집니다.
##
## 그래서 둘 다 체력을 아주 크게 둡니다. **아무도 안 죽습니다** - 지는 것은
## 체력이 0 이 되는 것이 아니라 베개 없이 맞는 것입니다.

## 떨어진 베개로 쓰는 소품. `soft` 이라 던져도 안 아픕니다 - 베개는 주우러
## 가는 물건이지 무기가 아닙니다(무기 노릇은 손에 든 동안 합니다).
const DROP_KIND := "daycare_starcushion"

## 놓친 베개가 떨어지는 거리. 발밑에 놓으면 맞자마자 다시 밟고 서 있게 되어
## "놓쳤다" 가 안 읽힙니다.
const DROP_AWAY := 1.6

## 놓친 직후에는 못 줍습니다. 없으면 맞는 순간 그 자리에서 다시 주워 아무
## 일도 안 일어난 것이 됩니다.
const PICKUP_LOCK := 0.8

## 적이 베개를 주우러 가는 거리. 이보다 가까우면 줍습니다.
const FOE_PICKUP := 1.3

## 이 판의 체력. **줄어들자마자 되돌립니다** - 지는 조건이 체력이 아니라
## 베개이기 때문입니다.
##
## 큰 수(99999)로 두었다가 물렀습니다. 죽지는 않는데 **화면에 그 숫자가
## 그대로 떴습니다** - 규칙에 없는 값이 화면에서 제일 큰 글자가 됩니다.
## 평범한 수를 두고 맞을 때마다 채우면, 막대는 늘 가득하고 "체력은 이 판의
## 규칙이 아니다" 가 화면으로 읽힙니다.
const MATCH_HP := 100.0

var game: Node = null
var player: Node3D = null
var foe: Node3D = null

## 각자 베개를 들고 있나.
var player_has := true
var foe_has := true

var over := false
var winner := ""

var _player_pillow: Node3D = null
var _drop: Node3D = null
var _drop_lock := 0.0
## 지난 프레임의 체력. 줄었으면 맞은 것입니다.
var _last_player_hp := 0.0
var _last_foe_hp := 0.0
var _foe_guard_arc := 0.0


func setup(g: Node, p: Node3D, f: Node3D) -> void:
	game = g
	player = p
	foe = f

	# **표를 고치기 전에 베낍니다.**
	#
	# `Enemy.stats` 는 `KINDS` 의 항목을 **그대로 가리킵니다**. 여기서 고치면
	# 그 종류의 적 전부가 바뀌고, 어린이집 탐험의 베개 아기까지 따라 바뀝니다.
	foe.stats = (foe.stats as Dictionary).duplicate()
	_foe_guard_arc = float(foe.stats.get("guard_arc", 100.0))
	foe.max_hp = MATCH_HP
	foe.hp = MATCH_HP

	var st = player.state
	st.max_hp = MATCH_HP
	st.hp = MATCH_HP
	_last_player_hp = MATCH_HP
	_last_foe_hp = MATCH_HP

	_player_pillow = _build_pillow()
	player.pivot.add_child(_player_pillow)
	_player_pillow.position = Vector3(0, 0.62, -0.34)


func _build_pillow() -> Node3D:
	## 주인공이 드는 베개. **적의 것과 같은 크기·같은 색**입니다
	## (`Enemy._build_pillow`). 둘이 다르게 생기면 뺏고 뺏기는 것이 같은
	## 물건이라는 게 안 읽힙니다.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.70, 0.46, 0.20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 1.0)
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# 카툰 외곽선이 이 판을 검게 두르면 베개가 아니라 상자로 보입니다.
	mi.set_meta("flat", true)
	var root := Node3D.new()
	root.name = "PlayerPillow"
	root.add_child(mi)
	return root


func _process(delta: float) -> void:
	if over or not is_instance_valid(player) or not is_instance_valid(foe):
		return
	_drop_lock = maxf(0.0, _drop_lock - delta)

	var st = player.state
	# 맞았나. **체력이 줄었으면** 판정이 뚫린 것입니다(막는 각·사거리는 이미
	# 그쪽에서 봤습니다).
	if float(st.hp) < _last_player_hp - 0.01:
		# **먼저 채우고 나서 판정합니다.** 판정 안에서 판이 끝나면 그 뒤로
		# 아무것도 안 도는데, 채우는 것이 뒤에 있으면 진 화면에 깎인 막대가
		# 남습니다.
		st.hp = MATCH_HP
		player.emit_signal("health_changed", st.hp, st.max_hp)
		_got_hit(true)
	_last_player_hp = float(st.hp)
	if float(foe.hp) < _last_foe_hp - 0.01:
		foe.hp = MATCH_HP
		_got_hit(false)
	_last_foe_hp = float(foe.hp)

	_drive_pickup()


func _got_hit(is_player: bool) -> void:
	var has := player_has if is_player else foe_has
	if has:
		_drop_pillow(is_player)
		return
	# 베개 없이 맞았습니다.
	over = true
	winner = "적" if is_player else "나"
	if game != null and game.has_method("on_pillow_over"):
		game.on_pillow_over(winner)


func _drop_pillow(is_player: bool) -> void:
	## 맞은 쪽이 베개를 놓칩니다.
	var who: Node3D = player if is_player else foe
	if is_player:
		player_has = false
		if _player_pillow != null:
			_player_pillow.visible = false
	else:
		foe_has = false
		# **막는 각을 0 으로 만듭니다.** 베개가 없으면 막을 것이 없습니다 -
		# 그림만 지우고 판정을 남기면 "왜 안 맞지" 가 됩니다.
		foe.stats["guard_arc"] = 0.0
		if foe.get("_pillow") != null:
			(foe.get("_pillow") as Node3D).visible = false

	# 이미 떨어진 것이 있으면 그것을 옮깁니다. 판 위의 베개는 늘 하나여야
	# 줍는 경쟁이 성립합니다.
	if _drop == null or not is_instance_valid(_drop):
		_drop = Prop.new()
		who.get_parent().add_child(_drop)
		(_drop as Object).call("setup", DROP_KIND)
		_drop.add_to_group("props")
	var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	_drop.global_position = who.global_position + away.normalized() * DROP_AWAY
	_drop.visible = true
	_drop_lock = PICKUP_LOCK


func _drive_pickup() -> void:
	if _drop == null or not is_instance_valid(_drop) or not _drop.visible:
		return
	if _drop_lock > 0.0:
		return

	# **주인공은 원래 방식으로 줍습니다.** 소품 집기가 이미 있으므로 새 규칙을
	# 만들지 않습니다 - 손에 들렸는지만 봅니다.
	if not player_has and player.get("_held") == _drop:
		player_has = true
		if _player_pillow != null:
			_player_pillow.visible = true
		player.set("_held", null)
		_drop.visible = false
		return

	# 적은 가까워지면 줍습니다. 걸어오는 것은 원래 하던 일이라 그대로 둡니다.
	if not foe_has and foe.global_position.distance_to(_drop.global_position) < FOE_PICKUP:
		foe_has = true
		foe.stats["guard_arc"] = _foe_guard_arc
		if foe.get("_pillow") != null:
			(foe.get("_pillow") as Node3D).visible = true
		_drop.visible = false
