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

## ── 휘두르기 ────────────────────────────────────────────────
##
## **누르면 바로 나가지 않습니다.** 감았다가(선딜) 지나가고(판정) 되돌립니다
## (후딜). 그 0.66초 동안 발이 묶이므로, 언제 휘두를지가 매번 선택이 됩니다 -
## 소울라이크의 핵심은 공격이 세다는 것이 아니라 **되돌릴 수 없다**는 것입니다.
##
## 밀기(달려들기)나 고함(즉발 부채꼴)을 안 쓴 이유가 그것입니다. 둘 다 누르면
## 그 자리에서 결과가 나서, 적의 패턴을 읽을 이유가 생기지 않습니다.
const SWING_WINDUP := 0.26
const SWING_ACTIVE := 0.10
const SWING_RECOVER := 0.30
## 휘두르는 동안의 걸음 배율. 0 으로 묶지 않은 이유는 고함 때와 같습니다 -
## 아예 못 움직이면 예고를 보고 피하는 것과 겨룰 수가 없습니다.
const SWING_MOVE := 0.30
const SWING_ARC := 120.0
const SWING_REACH := 1.9
const SWING_DAMAGE := 9.0
const SWING_BREATH := 25.0

## ── 베개를 드는 자세 ────────────────────────────────────────
##
## **한 귀퉁이를 잡고 늘어뜨립니다.** 앞으로 반듯이 들면 방패로 보이고, 그러면
## 휘두르는 물건이라는 게 안 읽힙니다.
const HANG_POS := Vector3(0.26, 0.44, -0.06)
const HANG_ROT := Vector3(18.0, 0.0, 64.0)
## 감았을 때와 지나간 뒤. 몸을 축으로 도는 각입니다.
const SWING_BACK := 78.0
const SWING_THROUGH := -86.0

## ── 상대의 패턴 ────────────────────────────────────────────
##
## **한 아이가 셋으로 때립니다.** `Enemy.stats` 의 `attack` 을 갈아 끼우면
## 예고 그림까지 통째로 따라옵니다 - 적 코드를 한 줄도 안 고칩니다.
##
## 셋을 고른 기준은 **대처가 서로 달라야 한다**입니다.
##
##   내려치기  채워진 원이 커진다   -> 원 밖으로 걸어 나간다
##   후려치기  앞 부채꼴            -> 뒤로 돌아 들어간다
##   달려들기  바닥에 띠            -> 옆으로 구른다
##
## 셋이 같은 답을 가지면 패턴이 여럿인 뜻이 없습니다.
const PATTERNS := [
	{"name": "내려치기", "attack": "slam", "range": 2.1,
		"windup": 0.72, "cooldown": 1.9},
	{"name": "후려치기", "attack": "melee", "range": 1.7,
		"windup": 0.42, "cooldown": 1.4},
	{"name": "달려들기", "attack": "charge", "range": 5.2,
		"windup": 0.58, "cooldown": 2.3,
		"charge_dist": 5.0, "charge_turn": 150.0},
]

## 떨어진 베개로 쓰는 소품. `soft` 이라 던져도 안 아픕니다 - 베개는 주우러
## 가는 물건이지 무기가 아닙니다(무기 노릇은 손에 든 동안 합니다).
const DROP_KIND := "daycare_starcushion"

## 놓친 베개가 떨어지는 거리. 발밑에 놓으면 맞자마자 다시 밟고 서 있게 되어
## "놓쳤다" 가 안 읽힙니다.
const DROP_AWAY := 1.6

## 놓친 직후에는 못 줍습니다. 없으면 맞는 순간 그 자리에서 다시 주워 아무
## 일도 안 일어난 것이 됩니다.
const PICKUP_LOCK := 0.8

## 베개를 줍는 거리. **버튼이 아니라 다가가면 줍습니다.**
##
## 처음에는 주인공만 잡기 버튼으로 줍게 했습니다. 그 버튼이 휘두르기가 되면서
## 주울 길이 통째로 사라졌는데 - 규칙에는 "먼저 줍는 쪽이 임자" 라고 적어
## 두고 손에는 주울 방법이 없었습니다.
##
## 버튼을 하나 더 만들지 않은 이유: 소울라이크에서 손에 있는 것은 공격·회피·
## 막기 셋이면 충분하고, 넷째가 늘면 그만큼 앞의 셋을 누를 여유가 줍니다.
## 다가가면 줍는 쪽이 **둘 다 같은 규칙**이라 겨루기도 공평합니다.
const PICKUP_NEAR := 1.15
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

## 휘두르기가 시작된 뒤 지난 시간. 음수면 안 휘두르는 중입니다.
var _swing := -1.0
var _swing_hit := false
## 지난 프레임의 적 예고 상태. 공격이 끝나는 순간을 잡아 다음 패턴을 고릅니다.
var _foe_was_winding := false
var _pattern := ""


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
	_rest_pillow()

	# **입력을 가로챕니다.** 이 고리가 걸린 동안에만 공격 버튼이 휘두르기가
	# 됩니다(`player.gd` 의 `attack_hook`).
	player.attack_hook = self
	_next_pattern()


func _rest_pillow() -> void:
	## 한 귀퉁이를 잡고 늘어뜨린 자리로 되돌립니다.
	if _player_pillow == null:
		return
	_player_pillow.position = HANG_POS
	_player_pillow.rotation_degrees = HANG_ROT


func swing() -> void:
	## 공격 버튼. **되돌릴 수 없는 한 동작**입니다.
	if over or _swing >= 0.0:
		return
	# 구르는 중·막는 중에는 안 나갑니다. 소울라이크에서 회피와 공격이 겹치면
	# 둘 다 값이 없어집니다.
	if float(player.get("_roll_time")) > 0.0 or float(player.get("_guard_pose")) > 0.0:
		return
	if not player_has:
		# **베개가 없으면 휘두를 것이 없습니다.** 주우러 가야 합니다.
		return
	var st = player.state
	if float(st.breath) < SWING_BREATH:
		player.emit_signal("breath_empty")
		return
	st.breath = maxf(0.0, float(st.breath) - SWING_BREATH)
	_swing = 0.0
	_swing_hit = false
	Sfx.play(Sfx.PUSH, -3.0, 0.0)


func _drive_swing(delta: float) -> void:
	if _swing < 0.0:
		player.ext_move_scale = 1.0
		return
	_swing += delta
	player.ext_move_scale = SWING_MOVE

	var total := SWING_WINDUP + SWING_ACTIVE + SWING_RECOVER
	# 베개가 실제로 호를 그립니다. **판정과 같은 시계**를 봅니다 - 따로 두면
	# 보이는 것과 맞는 것이 갈립니다.
	var yaw := 0.0
	if _swing < SWING_WINDUP:
		yaw = lerpf(0.0, SWING_BACK, _swing / SWING_WINDUP)
	elif _swing < SWING_WINDUP + SWING_ACTIVE:
		yaw = lerpf(SWING_BACK, SWING_THROUGH,
			(_swing - SWING_WINDUP) / SWING_ACTIVE)
	else:
		yaw = lerpf(SWING_THROUGH, 0.0,
			(_swing - SWING_WINDUP - SWING_ACTIVE) / SWING_RECOVER)
	if _player_pillow != null:
		_player_pillow.rotation_degrees = HANG_ROT + Vector3(0, yaw, 0)
		# 감을 때 뒤로, 지나갈 때 앞으로 나갑니다.
		_player_pillow.position = HANG_POS + Vector3(
			-sin(deg_to_rad(yaw)) * 0.34, 0, -cos(deg_to_rad(yaw)) * 0.18 + 0.18)

	# 판정은 **지나가는 0.10초에 한 번**입니다.
	if not _swing_hit and _swing >= SWING_WINDUP 			and _swing < SWING_WINDUP + SWING_ACTIVE:
		_swing_hit = true
		_resolve_swing()

	if _swing >= total:
		_swing = -1.0
		player.ext_move_scale = 1.0
		_rest_pillow()


func _resolve_swing() -> void:
	if not is_instance_valid(foe):
		return
	var face: Vector3 = -player.pivot.global_transform.basis.z
	var to: Vector3 = foe.global_position - player.global_position
	to.y = 0.0
	var reach: float = SWING_REACH + float(foe.get_meta("body_radius", 0.4))
	if to.length() > reach:
		return
	if to.normalized().dot(face) < cos(deg_to_rad(SWING_ARC) * 0.5):
		return
	# `from_pos` 를 줍니다. 안 주면 앞을 막는 상대도 못 막습니다.
	foe.take_damage(SWING_DAMAGE, false, Vector3.ZERO, 0.0, player.global_position)


func _next_pattern() -> void:
	## 다음에 쓸 패턴을 고릅니다. **바로 앞의 것은 안 고릅니다** - 같은 것이
	## 이어 나오면 외울 것이 없어집니다.
	var pick: Dictionary = PATTERNS[randi() % PATTERNS.size()]
	var guard := 0
	while String(pick["name"]) == _pattern and guard < 8:
		pick = PATTERNS[randi() % PATTERNS.size()]
		guard += 1
	_pattern = String(pick["name"])
	# **덮어씁니다, 갈아 끼우지 않습니다.** `guard_arc` 처럼 이 판에서 따로
	# 바꿔 둔 값이 패턴을 고를 때마다 되살아나면 안 됩니다.
	for k in pick:
		if k == "name":
			continue
		foe.stats[k] = pick[k]


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
	_drive_swing(delta)

	# **상대의 공격이 끝나면 다음 패턴을 고릅니다.** 공격이 시작될 때 갈면
	# 이미 `stats` 를 읽은 뒤라(`_begin_attack`) 예고와 판정이 갈립니다.
	var winding := float(foe.get("_windup")) >= 0.0
	if _foe_was_winding and not winding:
		_next_pattern()
	_foe_was_winding = winding

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
	# **고리를 뗍니다.** 안 떼면 제목으로 돌아가 어린이집 탐험을 시작해도
	# 공격 버튼이 이 판의 휘두르기로 남습니다.
	player.attack_hook = null
	player.ext_move_scale = 1.0
	if game != null and game.has_method("on_pillow_over"):
		game.on_pillow_over(winner)


func _drop_pillow(is_player: bool) -> void:
	## 맞은 쪽이 베개를 놓칩니다.
	var who: Node3D = player if is_player else foe
	if is_player:
		player_has = false
		_swing = -1.0
		player.ext_move_scale = 1.0
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

	# **다가가면 줍습니다.** 휘두르는 도중에는 안 줍습니다 - 그러면 감았다가
	# 지나가는 사이에 저절로 손이 차서, 되돌릴 수 없다는 규칙이 무너집니다.
	if not player_has and _swing < 0.0 			and player.global_position.distance_to(_drop.global_position) < PICKUP_NEAR:
		player_has = true
		if _player_pillow != null:
			_player_pillow.visible = true
			_rest_pillow()
		_drop.visible = false
		Sfx.play(Sfx.PICK, -2.0, 0.0)
		return

	# 적은 가까워지면 줍습니다. 걸어오는 것은 원래 하던 일이라 그대로 둡니다.
	if not foe_has and foe.global_position.distance_to(_drop.global_position) < FOE_PICKUP:
		foe_has = true
		foe.stats["guard_arc"] = _foe_guard_arc
		if foe.get("_pillow") != null:
			(foe.get("_pillow") as Node3D).visible = true
		_drop.visible = false
