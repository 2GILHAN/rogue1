class_name PillowMatch
extends Node

## **1:1 베개싸움.** 어린이집 탐험과 따로 도는 한 판입니다.
##
## # 왜 따로 두는가
##
## 재미없으면 버릴 것이기 때문입니다. `game.gd` 안에 규칙을 섞어 두면 버릴 때
## 무엇이 이 판의 것이고 무엇이 원래 게임의 것인지 갈라내야 합니다. 이 파일과
## `scripts/pillow_rig.gd`, `Game.pillow_mode` 몇 줄만 지우면 흔적이 없어야
## 합니다.
##
## # 규칙
##
## 둘 다 베개를 듭니다. **한쪽 끝을 두 손으로 쥐고 늘어뜨린 채** 걷습니다.
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
const SWING_DAMAGE := 9.0
const SWING_BREATH := 25.0

## ── 베개가 지나는 길 ────────────────────────────────────────
##
## **각도표가 아니라 길입니다.** 어깨와 팔꿈치는 `PillowRig` 의 IK 가 풀고,
## 여기서는 두 손이 쥔 자리(그립)가 몸 둘레 어디를 지나는지만 적습니다.
##
##   쉼    오른쪽 옆에 늘어뜨림          걸을 때 베개가 발치에서 흔들립니다
##   감기  오른쪽 뒤로, 조금 올림        "지금 친다" 가 보여야 피할 수 있습니다
##   지남  왼쪽으로 가로질러, 팔을 폄    이때만 팔 + 베개가 한 선이 됩니다
##   되돌림 다시 오른쪽 옆으로           후딜. 여기서 맞으면 못 막습니다
##
## 양수가 오른쪽입니다. **오른쪽으로 감았다가 왼쪽으로** 지나갑니다.
const REST_YAW := 26.0
const WIND_YAW := 62.0
const THROUGH_YAW := -74.0
## 그립의 높이(어깨에서). 늘어뜨렸을 때는 배 높이, 칠 때는 가슴 높이입니다.
##
## -0.30 으로 뒀다가 물렀습니다. 이 아이의 팔이 0.33m 라 어깨에서 30cm 아래는
## **팔을 다 쓴 자리**여서 두 손이 몸에 붙어 버리고, 거기서 0.70m 짜리 베개를
## 늘어뜨리면 **끝이 바닥 아래로 15cm 들어갑니다.**
const REST_LIFT := -0.16
const WIND_LIFT := -0.08
const HIT_LIFT := -0.02
## 팔을 얼마나 펴는가. **칠 때만 1.0** 입니다 - 그 순간에만 사거리가 다 납니다.
const REST_EXTEND := 0.55
const WIND_EXTEND := 0.72
## 쉴 때 베개가 늘어지는 각. 0 이면 똑바로 아래인데, 그러면 이 아이 키(1.25m)
## 에 0.70m 짜리 베개라 **끝이 바닥을 뚫습니다.** 0.30 이면 63도쯤 기울어
## 끝이 바닥을 스칩니다 - 질질 끄는 그림이 이 판에 맞습니다.
const REST_HANG := 0.30

## 베개의 두께·폭 몫. 판정은 **손에서 베개 끝까지의 선분**과 상대 몸의 거리로
## 보는데, 베개는 선이 아니라 두께가 있는 물건이라 그만큼 더 줍니다.
const PILLOW_HALF := 0.12

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
##
## **사거리는 여기 안 적혀 있습니다.** 상대도 주인공과 같은 규칙을 씁니다 -
## 팔 길이 + 베개 길이이고, 그것은 뼈에서 잰 값입니다(`_set_range`).
const PATTERNS := [
	{"name": "내려치기", "attack": "slam", "windup": 0.72, "cooldown": 1.9},
	{"name": "후려치기", "attack": "melee", "windup": 0.42, "cooldown": 1.4},
	{"name": "달려들기", "attack": "charge", "windup": 0.58, "cooldown": 2.3,
		"range": 5.2, "charge_dist": 5.0, "charge_turn": 150.0},
]

## 패턴을 다시 고르기까지. **때린 직후가 아니라 조금 뒤**입니다.
##
## 예전에는 예고가 끝나는 순간 갈았는데, 내려치기의 뒷동작(`_slam_time` 0.28초)
## 과 후려치기의 follow-through 가 아직 도는 중이었습니다 - 베개를 내리꽂는
## 그림이 나오기도 전에 이미 다음 패턴의 몸이 되어 있었습니다.
const REPICK_AFTER := 0.45
## 후려친 뒤 베개가 끝까지 지나가는 시간.
const FOLLOW_TIME := 0.26

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

## 두 손과 베개. 주인공과 상대가 **같은 리그**를 씁니다 - 사거리 규칙이 둘
## 다 「팔 + 베개」 이려면 같은 코드에서 나와야 합니다.
var rig: PillowRig = null
var foe_rig: PillowRig = null

var _drop: Node3D = null
var _drop_lock := 0.0
## 지난 프레임의 체력. 줄었으면 맞은 것입니다.
var _last_player_hp := 0.0
var _last_foe_hp := 0.0
var _foe_guard_arc := 0.0

## 휘두르기가 시작된 뒤 지난 시간. 음수면 안 휘두르는 중입니다.
var _swing := -1.0
var _swing_hit := false
## 지난 프레임의 적 예고 상태. 공격이 끝나는 순간을 잡습니다.
var _foe_was_winding := false
var _foe_follow := 0.0
var _repick := 0.0
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

	rig = PillowRig.attach(player, player.body, player.body)
	foe_rig = PillowRig.attach(foe, foe.get("_pivot"), foe.get("_pivot"))
	# 몸이 얼마나 틀었나는 **쉴 때 각에서부터** 셉니다.
	rig.rest_yaw = REST_YAW
	foe_rig.rest_yaw = REST_YAW

	# **상대가 원래 들고 있던 베개를 치웁니다.**
	#
	# 그 베개는 `_pivot` 좌표로 옮겨 다니는 것이라(`Enemy._drive_pillow`) 손과
	# 상관없이 놓입니다. 두 손으로 쥐는 판에서는 손이 정하는 자리에 있어야
	# 하므로 리그가 만든 것 하나만 씁니다.
	#
	# **몸(충돌체)도 끕니다.** 탐험에서는 베개가 몸을 막아 "뚫고 들어가지
	# 마라" 를 말했는데, 여기서는 둘 다 베개를 휘두릅니다 - 휘두르는 상자가
	# 상대를 밀어내면 겨루기가 패턴 읽기가 아니라 몸싸움이 됩니다. 앞이
	# 막혀 있다는 규칙은 각도(`guard_blocks`)가 그대로 지킵니다.
	var old = foe.get("_pillow")
	if old != null:
		(old as Node3D).visible = false
	var shape = foe.get("_pillow_shape")
	if shape != null:
		(shape as CollisionShape3D).disabled = true

	# **입력을 가로챕니다.** 이 고리가 걸린 동안에만 공격 버튼이 휘두르기가
	# 됩니다(`player.gd` 의 `attack_hook`).
	player.attack_hook = self
	_next_pattern()


## ── 주인공의 휘두르기 ───────────────────────────────────────

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


func busy() -> bool:
	## 휘두르는 중인가. `player.gd` 의 구르기가 물어봅니다 - **되돌릴 수 없다**
	## 는 것이 이 판의 규칙이라, 구르기로 후딜을 지울 수 있으면 안 됩니다.
	return _swing >= 0.0


func _drive_swing(delta: float) -> void:
	if rig == null:
		return
	if _swing < 0.0:
		player.ext_move_scale = 1.0
		# 이미 비어 있으면 그대로 둡니다. 매 프레임 새 사전을 만들면 판 내내
		# 쓰레기가 쌓입니다.
		if not player.ext_pose.is_empty():
			player.ext_pose = {}
		if player_has:
			rig.aim(REST_YAW, REST_LIFT, REST_EXTEND, REST_HANG, 12.0, delta)
		return
	_swing += delta
	player.ext_move_scale = SWING_MOVE

	var total := SWING_WINDUP + SWING_ACTIVE + SWING_RECOVER
	# **베개가 실제로 호를 그립니다.** 판정도 같은 시계를 봅니다 - 따로 두면
	# 보이는 것과 맞는 것이 갈립니다.
	var yaw := REST_YAW
	var lift := REST_LIFT
	var extend := REST_EXTEND
	var hang := REST_HANG
	if _swing < SWING_WINDUP:
		# 감기. 뒤로 갈수록 느려집니다(끝에서 한 박자 멈춰야 "온다" 가 보입니다).
		var t := _swing / SWING_WINDUP
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		yaw = lerpf(REST_YAW, WIND_YAW, e)
		lift = lerpf(REST_LIFT, WIND_LIFT, e)
		extend = lerpf(REST_EXTEND, WIND_EXTEND, e)
		hang = lerpf(REST_HANG, 0.45, e)
	elif _swing < SWING_WINDUP + SWING_ACTIVE:
		# 지나가기. **가속합니다** - 등속으로 돌면 미는 것으로 보입니다.
		var t := (_swing - SWING_WINDUP) / SWING_ACTIVE
		var e := t * t * (3.0 - 2.0 * t)
		yaw = lerpf(WIND_YAW, THROUGH_YAW, e)
		lift = lerpf(WIND_LIFT, HIT_LIFT, e)
		extend = lerpf(WIND_EXTEND, 1.0, minf(t * 2.5, 1.0))
		# 베개는 **먼저 펴지고** 몸이 따라옵니다. 늘어진 채로 도는 것이 아니라
		# 원심력으로 펴져 나가는 그림입니다.
		hang = lerpf(0.45, 1.0, minf(t * 3.0, 1.0))
	else:
		var t := (_swing - SWING_WINDUP - SWING_ACTIVE) / SWING_RECOVER
		yaw = lerpf(THROUGH_YAW, REST_YAW, t)
		lift = lerpf(HIT_LIFT, REST_LIFT, t)
		extend = lerpf(1.0, REST_EXTEND, t)
		hang = lerpf(1.0, REST_HANG, t)
	rig.aim(yaw, lift, extend, hang)
	# **허리와 골반이 같이 틉니다.** 앞으로 숙이는 몫은 지나가는 구간에서만
	# 줍니다 - 감을 때 숙이면 이미 친 것으로 보입니다.
	player.ext_pose = rig.lean(10.0 * clampf(hang, 0.0, 1.0))

	# 판정은 **지나가는 0.10초 동안 매 프레임** 봅니다. 한 번만 보면 그
	# 프레임에 어디 있었느냐가 전부라, 베개가 훑고 지나간 자리는 안 세어집니다.
	if not _swing_hit and _swing >= SWING_WINDUP \
			and _swing < SWING_WINDUP + SWING_ACTIVE:
		if is_instance_valid(foe) and _pillow_hits(rig, foe):
			_swing_hit = true
			# `from_pos` 를 줍니다. 안 주면 앞을 막는 상대도 못 막습니다.
			foe.take_damage(SWING_DAMAGE, false, Vector3.ZERO, 0.0,
				player.global_position)

	if _swing >= total:
		_swing = -1.0
		player.ext_move_scale = 1.0
		player.ext_pose = {}


func _pillow_hits(from: PillowRig, other: Node3D) -> bool:
	## **손에서 베개 끝까지의 선분**이 상대 몸에 닿았나.
	##
	## 부채꼴이 아닙니다. 부채꼴은 「앞쪽 몇 도 안」 이라는 규칙이라 늘어뜨리고
	## 있든 다 편 뒤든 같은 값이 나오는데, 여기서는 **베개가 지금 어디 있는지**
	## 가 곧 사거리입니다 - 늘어뜨린 베개는 발치에 있어 아무에게도 안 닿습니다.
	var a := from.hands()
	var b := from.tip()
	a.y = 0.0
	b.y = 0.0
	var p := other.global_position
	p.y = 0.0
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var pad: float = float(other.get_meta("body_radius", 0.4)) + PILLOW_HALF
	return (a + ab * t).distance_to(p) <= pad


## ── 상대 ────────────────────────────────────────────────────

func _drive_foe_rig(delta: float) -> void:
	## **상대의 베개도 손이 정합니다.** 패턴 셋이 각각 다른 길을 그립니다 -
	## 그림이 다르면 대처도 다르다는 것이 몸으로 읽혀야 합니다.
	if foe_rig == null:
		return
	if not foe_has:
		# **빈손이면 팔을 풀어 줍니다.** 이 적은 늘 막는 자세(`GUARD`)라 팔이
		# 가슴 앞에 모여 있는데, 베개가 없어진 뒤에도 그대로 두면 **없는 것을
		# 안고 있는** 그림이 됩니다. 주인공 쪽과 같은 규칙입니다.
		var empty = foe.get("_pose")
		if empty != null and float(foe.get("_flinch_time")) <= 0.0 				and float(foe.get("_windup")) < 0.0:
			empty.weight = 0.0
		return
	var mode: String = foe.stats.get("attack", "melee")
	var wind := float(foe.get("_windup"))
	var total: float = maxf(float(foe.stats.get("windup", 0.5)), 0.01)
	var slam_t := float(foe.get("_slam_time"))
	var charge := float(foe.get("_charge"))

	var yaw := REST_YAW
	var lift := REST_LIFT
	var extend := REST_EXTEND
	var hang := REST_HANG
	var rate := 14.0

	if wind >= 0.0 and mode == "melee":
		# 후려치기. 감았다가 **예고가 끝나는 순간 정면을 지납니다** - 판정이
		# 그때 나므로(`Enemy._strike`), 베개도 그때 거기 있어야 합니다.
		var t := clampf(1.0 - wind / total, 0.0, 1.0)
		if t < 0.70:
			var e := t / 0.70
			yaw = lerpf(REST_YAW, WIND_YAW, e)
			lift = lerpf(REST_LIFT, WIND_LIFT, e)
			extend = lerpf(REST_EXTEND, WIND_EXTEND, e)
			hang = lerpf(REST_HANG, 0.45, e)
		else:
			var e := (t - 0.70) / 0.30
			yaw = lerpf(WIND_YAW, -24.0, e * e * (3.0 - 2.0 * e))
			lift = lerpf(WIND_LIFT, HIT_LIFT, e)
			extend = lerpf(WIND_EXTEND, 1.0, minf(e * 2.0, 1.0))
			hang = lerpf(0.45, 1.0, minf(e * 2.5, 1.0))
		rate = 0.0
	elif wind >= 0.0 and mode == "slam":
		# 내려치기. **머리 위로 세웁니다**(hang 2 면 베개가 위를 봅니다).
		var t := clampf(1.0 - wind / total, 0.0, 1.0)
		yaw = lerpf(REST_YAW, 0.0, t)
		lift = lerpf(REST_LIFT, 0.30, t)
		extend = lerpf(REST_EXTEND, 0.34, t)
		hang = lerpf(REST_HANG, 1.85, t)
		rate = 0.0
	elif slam_t > 0.0:
		# 내리꽂은 자리. 앞 아래로 눌러 놓습니다 - 바닥에 그린 원이 그 자리입니다.
		yaw = 0.0
		lift = -0.34
		extend = 1.0
		hang = 1.0
		rate = 26.0
	elif wind >= 0.0 and mode == "charge":
		# 달려들기 예고. 뒤로 조금 감고 몸을 낮춥니다.
		yaw = 20.0
		lift = -0.18
		extend = 0.60
		hang = 0.40
	elif charge > 0.0:
		# 달리는 중. **베개를 앞으로 내밀고** 옵니다.
		yaw = 0.0
		lift = -0.12
		extend = 1.0
		hang = 1.0
		rate = 24.0
	elif _foe_follow > 0.0:
		# 후려친 뒤. 끝까지 지나가고 나서 돌아옵니다.
		var t := 1.0 - _foe_follow / FOLLOW_TIME
		if t < 0.4:
			yaw = lerpf(-24.0, THROUGH_YAW, t / 0.4)
			extend = 1.0
			lift = HIT_LIFT
			hang = 1.0
		else:
			var e := (t - 0.4) / 0.6
			yaw = lerpf(THROUGH_YAW, REST_YAW, e)
			lift = lerpf(HIT_LIFT, REST_LIFT, e)
			extend = lerpf(1.0, REST_EXTEND, e)
			hang = lerpf(1.0, REST_HANG, e)
		rate = 0.0

	foe_rig.aim(yaw, lift, extend, hang, rate, delta)

	# 상체. **들썩임(맞은 자세)이 돌 때는 비켜 줍니다** - 하나의 층에 둘이
	# 같이 쓰면 나중에 쓴 쪽이 앞의 것을 지웁니다.
	var layer = foe.get("_pose")
	if layer != null and float(foe.get("_flinch_time")) <= 0.0:
		layer.pose = foe_rig.lean(10.0 * clampf(hang, 0.0, 1.0))
		layer.weight = 1.0


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
	_set_range(String(pick["attack"]))


func _set_range(attack: String) -> void:
	## **상대의 사거리도 잰 값입니다.** 주인공과 같은 규칙이라, 팔이 긴 쪽이
	## 실제로 더 멀리서 때립니다(상대가 주인공보다 팔이 깁니다).
	##
	## `Enemy` 는 `range` 를 그대로 쓰지 않고 공격마다 조금씩 더합니다. 그래서
	## **닿는 거리에서 거꾸로** 풉니다 - 여기서 어림하면 그려지는 예고와 맞는
	## 자리가 갈라집니다.
	##
	##   후려치기  판정 = range + 0.4
	##   내려치기  원의 바깥 끝 = (range + 0.4) x 1.05   (중심 0.55 + 반지름 0.5)
	if foe_rig == null:
		return
	var hit: float = foe_rig.full_reach(HIT_LIFT) + float(player.get("_body_radius"))
	match attack:
		"melee":
			foe.stats["range"] = maxf(hit - 0.4, 0.4)
		"slam":
			foe.stats["range"] = maxf(hit / 1.05 - 0.4, 0.4)
		_:
			pass          # 달려들기는 방 크기가 정합니다(패턴 표의 5.2m)


## ── 판 ──────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if over or not is_instance_valid(player) or not is_instance_valid(foe):
		return
	_drop_lock = maxf(0.0, _drop_lock - delta)
	_foe_follow = maxf(0.0, _foe_follow - delta)
	_drive_swing(delta)
	_drive_foe_rig(delta)

	# **공격이 끝나면 뒷동작을 걸고, 조금 뒤에 다음 패턴을 고릅니다.**
	# 예고가 끝나는 순간 갈면 이미 `stats` 를 읽은 뒤라(`_begin_attack`)
	# 뒷동작이 다음 패턴의 몸으로 나옵니다.
	var winding := float(foe.get("_windup")) >= 0.0
	if _foe_was_winding and not winding:
		if foe.stats.get("attack", "melee") == "melee":
			_foe_follow = FOLLOW_TIME
		_repick = REPICK_AFTER
	_foe_was_winding = winding
	if _repick > 0.0:
		_repick = maxf(0.0, _repick - delta)
		if _repick <= 0.0:
			_next_pattern()

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
	player.ext_pose = {}
	if game != null and game.has_method("on_pillow_over"):
		game.on_pillow_over(winner)


func _drop_pillow(is_player: bool) -> void:
	## 맞은 쪽이 베개를 놓칩니다. **팔도 같이 풀립니다** - 빈손인데 두 손이
	## 모여 있으면 아직 들고 있는 것으로 보입니다.
	var who: Node3D = player if is_player else foe
	if is_player:
		player_has = false
		_swing = -1.0
		player.ext_move_scale = 1.0
		player.ext_pose = {}
		if rig != null:
			rig.active(false)
	else:
		foe_has = false
		# **막는 각을 0 으로 만듭니다.** 베개가 없으면 막을 것이 없습니다 -
		# 그림만 지우고 판정을 남기면 "왜 안 맞지" 가 됩니다.
		foe.stats["guard_arc"] = 0.0
		if foe_rig != null:
			foe_rig.active(false)

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
	if not player_has and _swing < 0.0 \
			and player.global_position.distance_to(_drop.global_position) < PICKUP_NEAR:
		player_has = true
		if rig != null:
			rig.active(true)
			rig.aim(REST_YAW, REST_LIFT, REST_EXTEND, REST_HANG)
		_drop.visible = false
		Sfx.play(Sfx.PICK, -2.0, 0.0)
		return

	# 적은 가까워지면 줍습니다. 걸어오는 것은 원래 하던 일이라 그대로 둡니다.
	if not foe_has and foe.global_position.distance_to(_drop.global_position) < FOE_PICKUP:
		foe_has = true
		foe.stats["guard_arc"] = _foe_guard_arc
		if foe_rig != null:
			foe_rig.active(true)
		_drop.visible = false
