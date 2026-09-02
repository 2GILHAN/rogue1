class_name PillowRig
extends RefCounted

## **두 손으로 베개를 쥔 팔.** 각도를 적지 않고 **손이 갈 자리**를 적습니다.
##
## # 왜 자세표가 아닌가
##
## 여태 이 게임의 동작은 `PoseOverride` 의 표였습니다 - 어깨 X 78도, 팔꿈치
## Z 90도처럼 **뼈마다 각도를 적어** 둔 것입니다. 서 있는 자세 하나를 만드는
## 데는 그것으로 충분합니다.
##
## 그런데 **휘두르기는 자세가 아니라 길입니다.** 베개는 몸 주위로 호를 그리고,
## 어깨와 팔꿈치는 그 호를 따라가느라 굽는 것이지 정해진 각도가 있는 것이
## 아닙니다. 각도표로 그리려면 호 위의 점마다 자세를 한 벌씩 적어야 하는데,
## 그렇게 적은 각도가 실제로 어디를 가리키는지는 **찍어 보기 전에는
## 모릅니다**(이 프로젝트가 팔 앞뒤·무릎 방향에서 이미 겪은 일입니다).
##
## 그래서 반대로 놓습니다. **베개가 갈 자리를 정하고 팔은 풀어서 따라가게**
## 합니다 - 발이 지형을 따라가는 것과 같은 방식입니다.
##
##     그립(두 손이 쥔 자리)  ← 우리가 정합니다. 몸 둘레의 호 위 한 점
##     어깨 · 팔꿈치          ← TwoBoneIK3D 가 풉니다
##     허리 · 골반            ← 호의 각도에 비례해 같이 틉니다
##
## # 사람의 한계가 공짜로 따라옵니다
##
## 팔은 어깨에서 손목까지가 정해진 길이라 그보다 먼 자리는 **못 잡습니다.**
## IK 는 그때 팔을 쭉 펴고 멈춥니다 - 우리가 한계를 적어 넣은 것이 아니라
## 뼈 길이가 그렇게 만듭니다. 그래서 이 판의 사거리도 고른 숫자가 아니라
## **잰 값**입니다:
##
##     사거리 = 어깨에서 손까지(팔) + 베개 길이
##
## 팔 길이는 `attach` 가 뼈에서 잽니다. 모델마다 다릅니다 - 주인공과 상대의
## 팔 길이가 실제로 다르고, 그래서 사거리도 다릅니다.
##
## # 늘어뜨렸을 때는 사거리가 없습니다
##
## 걸을 때 베개는 손에서 **아래로 늘어집니다.** 그때 베개 끝은 발밑에 있으므로
## 사거리에 안 보태집니다. 휘두르는 동안에만 베개가 팔을 잇는 선으로 펴지고,
## 그때 비로소 팔 + 베개가 됩니다. 규칙("휘둘러야 닿는다")이 그림에서 그대로
## 나옵니다.

## 베개의 긴 축. 손에서 이만큼 뻗어 나갑니다. `Enemy._build_pillow` 의
## BoxMesh 와 같은 값입니다 - 둘이 갈라지면 보이는 길이와 닿는 길이가
## 달라집니다.
const PILLOW_LEN := 0.70
const PILLOW_TALL := 0.46
const PILLOW_THICK := 0.20

## 두 손 사이. 쥔 자리를 가운데 두고 좌우로 나눠 섭니다.
const GRIP_HALF := 0.055
## 손목(뼈)에서 베개가 시작하는 데까지. 손 안에 베개가 파묻히지 않게 합니다.
const GRIP_GAP := 0.05
## 팔을 다 펴지 않고 남기는 몫. 아래 `_live_radius` 에 이유가 있습니다.
const SLACK := 0.94

var skel: Skeleton3D = null
var grip: Node3D = null
var pillow: MeshInstance3D = null
var ik: TwoBoneIK3D = null

## 어깨에서 손목까지. **뼈에서 잽니다.**
var arm := 0.0
## host 기준 어깨 높이와, 몸 가운데에서 어깨까지.
var shoulder_y := 0.0
var shoulder_x := 0.0
## 두 손이 **함께** 닿을 수 있는 가장 먼 자리(몸 축에서). 어깨가 몸 가운데가
## 아니라서 팔 길이보다 짧습니다 - 어깨 옆폭만큼 빗변으로 먹힙니다.
var span := 0.0

## 상체 각도. 자세 층에 그대로 넘깁니다. **팔은 안 들어 있습니다** - IK 가
## 뒤에서 덮어쓰므로 여기 적어 봐야 지워집니다.
var torso: Dictionary = {}

var _root: Node3D = null
var _host: Node3D = null
## **지금 어깨가 있는 자리.** 쉼 자세의 값이 아니라 클립과 상체 각도까지 다
## 들어간 자리입니다(`Models.add_anchor` 가 그래서 있습니다).
var _l_shoulder: BoneAttachment3D = null
var _r_shoulder: BoneAttachment3D = null
var _l_target: Node3D = null
var _r_target: Node3D = null
var _l_pole: Node3D = null
var _r_pole: Node3D = null
## 쉴 때 그립이 있는 각. **몸이 얼마나 틀었나**를 여기서부터 셉니다.
var rest_yaw := 0.0
## 지금 몸통이 튼 각. `aim` 이 정하고 `lean` 이 씁니다 - 둘이 따로 세면
## 어긋납니다.
var _twist := 0.0
## 지금 그립이 있는 자리. 부드럽게 옮길 때 씁니다.
var _yaw := 0.0
var _lift := 0.0
var _extend := 0.0
var _hang := 0.0


static func attach(root: Node3D, host: Node3D, model_root: Node3D) -> PillowRig:
	## `root` 는 사거리를 재는 기준(주인공/적 자신), `host` 는 그립을 매다는
	## 몸통 노드입니다. 둘이 다른 이유는 주인공의 몸통이 허리 높이에 떠 있기
	## 때문입니다(`Player.body`). 어깨 높이를 **재서** 쓰므로 부르는 쪽은 그
	## 사정을 몰라도 됩니다.
	var rig := PillowRig.new()
	rig._root = root
	rig._host = host
	rig.skel = Models.find_skeleton(model_root)
	if rig.skel == null:
		push_warning("베개 리그: 뼈대를 못 찾았습니다")
		return rig

	# ── 팔을 잽니다 ──────────────────────────────────────────
	var to_host := host.global_transform.affine_inverse() * rig.skel.global_transform
	var sh := rig._rest_at(to_host, "LeftArm")
	var el := rig._rest_at(to_host, "LeftForeArm")
	var wr := rig._rest_at(to_host, "LeftHand")
	rig.arm = sh.distance_to(el) + el.distance_to(wr)
	rig.shoulder_y = sh.y
	rig.shoulder_x = absf(sh.x)
	# 두 손을 몸 앞 한 점에 모으면 어깨에서 그 점까지가 빗변입니다.
	rig.span = sqrt(maxf(rig.arm * rig.arm - rig.shoulder_x * rig.shoulder_x, 0.01))

	# ── 그립과 베개 ──────────────────────────────────────────
	rig.grip = Node3D.new()
	rig.grip.name = "PillowGrip"
	host.add_child(rig.grip)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(PILLOW_THICK, PILLOW_TALL, PILLOW_LEN)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 1.0)
	mat.roughness = 1.0
	rig.pillow = MeshInstance3D.new()
	rig.pillow.name = "Pillow"
	rig.pillow.mesh = mesh
	rig.pillow.material_override = mat
	# 카툰 외곽선이 이 판을 검게 두르면 베개가 아니라 상자로 보입니다.
	rig.pillow.set_meta("flat", true)
	rig.pillow.position = Vector3(0, 0, -(PILLOW_LEN * 0.5 + GRIP_GAP))
	rig.grip.add_child(rig.pillow)

	# ── 손이 갈 자리와 팔꿈치가 향할 쪽 ──────────────────────
	rig._l_target = rig._mark(rig.grip, "GripL", Vector3(-GRIP_HALF, 0, 0))
	rig._r_target = rig._mark(rig.grip, "GripR", Vector3(GRIP_HALF, 0, 0))
	rig._l_pole = rig._mark(host, "PoleL", Vector3.ZERO)
	rig._r_pole = rig._mark(host, "PoleR", Vector3.ZERO)
	rig._l_shoulder = Models.add_anchor(model_root, "LeftArm")
	rig._r_shoulder = Models.add_anchor(model_root, "RightArm")

	# ── IK ───────────────────────────────────────────────────
	#
	# **자세 층보다 뒤에 답니다.** 스켈레톤은 자식 순서대로 층을 돌리므로,
	# 자세 층(PoseOverride)이 어깨 각도를 적어 두면 그것이 먼저 들어가고
	# 여기서 다시 풉니다. 순서가 반대면 자세표가 IK 를 지웁니다.
	rig.ik = TwoBoneIK3D.new()
	rig.ik.name = "PillowIK"
	rig.skel.add_child(rig.ik)
	rig.ik.setting_count = 2
	rig._chain(0, "Left", rig._l_target, rig._l_pole)
	rig._chain(1, "Right", rig._r_target, rig._r_pole)

	rig.aim(0.0, -0.30, 0.55, 0.0)
	return rig


func _rest_at(to_host: Transform3D, bone: String) -> Vector3:
	var i := skel.find_bone(bone)
	if i < 0:
		return Vector3.ZERO
	return to_host * skel.get_bone_global_rest(i).origin


func _mark(parent: Node3D, mark_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = mark_name
	n.position = pos
	parent.add_child(n)
	return n


func _chain(i: int, side: String, target: Node3D, pole: Node3D) -> void:
	ik.set_root_bone_name(i, side + "Arm")
	ik.set_middle_bone_name(i, side + "ForeArm")
	ik.set_end_bone_name(i, side + "Hand")
	ik.set_target_node(i, ik.get_path_to(target))
	ik.set_pole_node(i, ik.get_path_to(pole))


func active(on: bool) -> void:
	## 베개를 놓치면 팔을 풀어 줍니다. 빈손인데 두 손이 모여 있으면 아직
	## 들고 있는 것으로 보입니다.
	if ik != null:
		ik.active = on
	if pillow != null:
		pillow.visible = on


func aim(yaw_deg: float, lift: float, extend: float, hang: float,
		rate: float = 0.0, delta: float = 0.0) -> void:
	## 그립을 호 위의 한 점에 둡니다.
	##
	##     yaw     0 이 정면, **양수가 오른쪽**입니다
	##     lift    어깨 높이에서 위아래로 (m)
	##     extend  0 이면 몸에 붙이고 1 이면 팔을 다 폅니다
	##     hang    0 이면 아래로 늘어지고 1 이면 팔을 잇는 선, 2 면 위를 봅니다
	##
	## `rate` 를 주면 그 자리로 **부드럽게** 갑니다(상대의 자세가 뚝뚝 바뀌는
	## 것을 막습니다). 주인공의 휘두르기는 이미 곡선이라 그대로 씁니다.
	if grip == null:
		return
	if rate > 0.0 and delta > 0.0:
		var k := 1.0 - exp(-rate * delta)
		_yaw = lerpf(_yaw, yaw_deg, k)
		_lift = lerpf(_lift, lift, k)
		_extend = lerpf(_extend, extend, k)
		_hang = lerpf(_hang, hang, k)
	else:
		_yaw = yaw_deg
		_lift = lift
		_extend = extend
		_hang = hang

	# **몸이 먼저 틉니다.** 그러면 어깨도 같이 돌아가므로, 팔이 닿는 거리는
	# 「몸에서 본 그립의 각」으로 재야 맞습니다 - 이걸 안 빼고 쉴 때 각으로
	# 쟀더니 다 편 순간에 먼 손이 4cm 벌어져 있었습니다(어깨선이 도는 각
	# 26도에 어깨 옆폭 0.09 를 곱한 값이 정확히 그만큼입니다).
	_twist = clampf((_yaw - rest_yaw) * TWIST_SHARE, -TWIST_MAX, TWIST_MAX)
	var y := deg_to_rad(_yaw)
	var r: float = _live_radius(y, _lift) * clampf(_extend, 0.0, 1.0)
	grip.position = Vector3(sin(y) * r, shoulder_y + _lift, -cos(y) * r)
	# hang 0 = 아래로 늘어짐, 1 = 앞으로 폄. 그립의 **-Z 가 베개가 가는 쪽**입니다.
	# hang 1 을 넘으면 베개가 **위를 봅니다**(2 면 똑바로 위) - 내려치기 예고가
	# 그 자리입니다.
	grip.rotation = Vector3(deg_to_rad(lerpf(-90.0, 0.0, clampf(_hang, 0.0, 2.0))), y, 0.0)

	# 팔꿈치는 **아래 바깥**을 봅니다. 두 손으로 물건을 잡으면 팔꿈치가 위로
	# 뜨지 않습니다 - 위로 두면 팔이 뒤집힌 그림이 나옵니다.
	var g := grip.position
	_l_pole.position = Vector3(lerpf(-shoulder_x * 2.2, g.x, 0.5),
		shoulder_y - 0.40, lerpf(0.05, g.z, 0.5))
	_r_pole.position = Vector3(lerpf(shoulder_x * 2.2, g.x, 0.5),
		shoulder_y - 0.40, lerpf(0.05, g.z, 0.5))


func _live_radius(y: float, lift: float) -> float:
	## **지금 어깨가 있는 자리에서** 두 손이 함께 닿는 가장 먼 반지름.
	##
	## 어깨는 가만히 있지 않습니다 - 대기 클립이 가슴을 움직이고, 우리가 건
	## 상체 각도가 또 돌립니다. 쉼 자세의 어깨로 재면 다 편 순간에 먼 손이
	## **3cm 벌어진 채**로 남았습니다(재 봤습니다: 어깨에서 그립까지 0.353 인데
	## 팔은 0.329).
	##
	## 손이 갈 자리는 그립에서 옆으로 GRIP_HALF 만큼 비켜 있으므로, 어깨를
	## 그만큼 **거꾸로 옮겨** 놓고 풀면 그 몫까지 정확히 들어갑니다.
	##
	##     |S - (d·r + h)| = arm      d 는 그립이 가는 쪽, h 는 높이
	##     r = b + sqrt(b² - c)       b = S·d,  c = |S_xz|² + dy² - arm²
	if _l_shoulder == null or _r_shoulder == null:
		return reach_at(rad_to_deg(y) - _twist, lift)
	var d := Vector3(sin(y), 0.0, -cos(y))
	var side := Vector3(cos(y), 0.0, sin(y)) * GRIP_HALF
	var best := 9.9
	for i in 2:
		var anchor: BoneAttachment3D = _l_shoulder if i == 0 else _r_shoulder
		var sp: Vector3 = _host.to_local(anchor.global_position)
		# 손이 갈 자리 기준으로 옮깁니다. 왼손 목표는 그립에서 -side 이므로
		# |S - (G - side)| = |(S + side) - G| - 어깨를 **반대로** 옮깁니다.
		sp += side if i == 0 else -side
		var dy: float = shoulder_y + lift - sp.y
		var b: float = sp.x * d.x + sp.z * d.z
		var c: float = sp.x * sp.x + sp.z * sp.z + dy * dy - arm * arm
		var inside: float = b * b - c
		var r: float = 0.02 if inside <= 0.0 else b + sqrt(inside)
		best = minf(best, r)
	# **다 펴지 않고 조금 남깁니다.**
	#
	# 상체 각도는 자세 층이 섞어 넣는 것이라 한 박자 늦게 따라옵니다. 가장
	# 빠른 구간(0.10초에 136도)에서는 그 지연이 어깨를 몇 cm 옮기고, 딱 맞춰
	# 풀어 두면 그만큼 손이 벌어집니다(재 봤습니다: 4cm). 사람도 휘두를 때
	# 팔꿈치를 완전히 펴지는 않습니다.
	return clampf(best * SLACK, 0.02, arm + shoulder_x)


func reach_at(yaw_deg: float, lift: float) -> float:
	## **옆으로 돌리거나 아래로 내리면 팔이 짧아집니다.**
	##
	## 두 손이 한 점을 잡으므로 **먼 쪽 어깨**가 한계를 정합니다. 정면이면 두
	## 어깨가 똑같이 떨어져 있지만, 오른쪽으로 돌리면 왼 어깨가 몸통 너비만큼
	## 더 멀어집니다. 아래로 내리는 것도 같습니다 - 어깨보다 30cm 낮은 자리를
	## 잡으면 그 30cm 가 팔 길이에서 먼저 빠집니다.
	##
	## 이 둘을 안 빼면 먼 쪽 손이 그립에 **못 닿은 채로** 허공을 잡습니다
	## (실제로 9cm 벌어져 있었습니다 - 늘어뜨린 자세에서 어깨에서 그립까지가
	## 0.414 인데 팔은 0.329 였습니다).
	##
	## 어깨에서 그립까지가 딱 팔 길이가 되는 반지름을 풉니다:
	##
	##     r² + 2·r·sx·|sin(yaw)| + sx² + lift² = arm²
	##
	## 뿌리는 아래와 같습니다. yaw 0, lift 0 이면 sqrt(arm² - sx²) 로 `span`
	## 과 같고, 90도로 돌리면 arm - sx 가 됩니다.
	var sn := absf(sin(deg_to_rad(yaw_deg)))
	var cs := cos(deg_to_rad(yaw_deg))
	var inside: float = arm * arm - lift * lift - shoulder_x * shoulder_x * cs * cs
	return maxf(-shoulder_x * sn + sqrt(maxf(inside, 0.0001)), 0.01)


## 어깨선이 돌 수 있는 한계. 휘두르기는 그립이 130도를 지나가는데, 몸이 그
## 각을 다 따라 돌면 **아이가 아니라 팽이**가 됩니다.
const TWIST_MAX := 26.0
## 그립이 돈 각 대비 몸이 도는 몫.
const TWIST_SHARE := 0.40


func lean(bend: float) -> Dictionary:
	## 호를 따라 **허리와 골반이 같이 틉니다.**
	##
	## 팔만 도는 그림은 사람이 아니라 인형입니다. 그리고 실제로도 이쪽이
	## 먼저입니다 - 두 손으로 무언가를 휘두를 때 팔은 붙잡고 있을 뿐이고
	## 도는 것은 몸통입니다.
	##
	## 나눠 맡깁니다. 골반이 가장 적게 틀고(발이 바닥에 붙어 있어야 합니다),
	## 등이 가장 많이 틀며, **고개는 반대로 돌려** 상대를 계속 봅니다. 셋의
	## 몫을 더하면 1 이라, 어깨선이 도는 각이 곧 `_twist` 입니다.
	##
	## 각은 `aim` 이 정해 둡니다 - **트는 각과 팔이 닿는 거리가 같은 값에서**
	## 나와야 몸이 돌아간 만큼 손이 따라갈 수 있습니다.
	##
	## **부호를 재서 뒤집었습니다.** 뼈 각도의 Y 양수는 이 리그에서 **왼쪽**
	## 으로 도는 것이라(`--pose=pillowrig` 로 어깨선을 재 보니 그립을 오른쪽
	## 40도로 보냈는데 어깨가 +31도, 즉 반대로 돌고 있었습니다), 그립과 같은
	## 쪽으로 돌리려면 빼야 합니다.
	var t := _twist
	torso["Hips"] = Vector3(0, -t * 0.22, 0)
	torso["Spine"] = Vector3(bend * 0.5, -t * 0.36, 0)
	torso["Chest"] = Vector3(bend * 0.5, -t * 0.42, 0)
	torso["Neck"] = Vector3(-bend * 0.3, t * 0.30, 0)
	torso["Head"] = Vector3(-bend * 0.3, t * 0.24, 0)
	return torso


func tip() -> Vector3:
	## 베개 끝(월드). 판정이 보는 자리입니다.
	if grip == null:
		return Vector3.ZERO
	return grip.global_position - grip.global_transform.basis.z * (PILLOW_LEN + GRIP_GAP)


func hands() -> Vector3:
	if grip == null:
		return Vector3.ZERO
	return grip.global_position


func reach() -> float:
	## 지금 이 순간 몸 중심에서 베개 끝까지(수평). 늘어뜨리고 있으면 짧고
	## 휘두르는 동안 길어집니다.
	if grip == null or _root == null:
		return 0.0
	var to := tip() - _root.global_position
	to.y = 0.0
	return to.length()


func full_reach(lift: float = 0.0) -> float:
	## 팔을 다 펴고 베개까지 폈을 때. **사거리 표가 보는 숫자**입니다.
	##
	## 여기만 잰 값이 아니라 **셈한 값**입니다(`reach_at`). 자리를 잡을 때는
	## 지금 어깨를 읽지만(`_live_radius`), 사거리는 매 프레임 흔들리면 안
	## 됩니다 - 상대의 예고 원이 숨쉬기에 맞춰 커졌다 작아졌다 하게 됩니다.
	##
	## **정면 기준**입니다. 옆으로 돌리면 조금 짧아집니다.
	return reach_at(0.0, lift) * SLACK + PILLOW_LEN + GRIP_GAP
