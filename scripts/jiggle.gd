class_name Jiggle
extends SkeletonModifier3D

## 흔들림 체인. 본을 스프링으로 매달아 캐릭터가 움직이면 따라 흔들립니다.
##
## # 무엇을 흔드는가
##
## 머리카락과 치맛단입니다. test3 가 그 정점들을 군집으로 나눠 체인 본을
## 만들어 두고, 물리 파라미터(stiffness/damping/gravity)까지 rig.json 에
## 넣어 둡니다. 그 값을 그대로 씁니다.
##
## 걷기·대기는 본 클립이 맡고, 이 체인들은 **클립이 건드리지 않는 부분**이라
## 여기서 따로 흔듭니다. 서진과 블랙은 원피스라 치마 체인이 8개 더 있어서,
## 걸을 때 치맛단이 따라 흔들리는 것이 가장 눈에 띕니다.
##
## # 왜 SkeletonModifier3D 인가
##
## 본 포즈는 애니메이션이 매 프레임 덮어씁니다. _process 에서 값을 써 넣으면
## 실행 순서에 따라 먹었다 안 먹었다 합니다. SkeletonModifier3D 는 스켈레톤
## 갱신 과정에서 불리므로 순서 문제가 없습니다.

## rig.json 의 hair 체인 기본값.
const STIFFNESS := 0.35
const DAMPING := 0.55

## 관성(가속도)과 항력(속도)의 세기. 항력이 더 큰 이유는, 일정한 속도로
## 달릴 때 가속도는 0 이기 때문입니다. 가속도만 보면 뛰는 내내 머리카락이
## 가만히 있습니다 - 실제로 그랬습니다.
const ACCEL_GAIN := 0.016
const SPEED_GAIN := 0.030
## 상하 반동이 만드는 출렁임.
const BOB_GAIN := 0.004

## 스프링 상수로 옮길 때의 배율. rig.json 값은 0~1 정규화라 그대로 쓰면
## 너무 느리게 흔들립니다.
const STIFF_SCALE := 190.0
const DAMP_SCALE := 26.0

## 흔들림 각도 상한(라디안). 이걸 넘기면 머리카락이 머리를 뚫습니다.
const MAX_ANGLE := 0.55

var prefixes: Array = ["hair_", "skirt_"]

var _bones: PackedInt32Array = PackedInt32Array()
var _rest: Array[Quaternion] = []
var _depth: PackedFloat32Array = PackedFloat32Array()
var _angle: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()

var _prev_origin := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _body_vel := Vector3.ZERO
var _accel := Vector3.ZERO
var _primed := false

## --jiggle-log 로 실행하면 흔들림 각도를 주기적으로 찍습니다. 흔들림은
## 정지 화면으로는 확인이 안 돼서, 돌고 있는지 숫자로 봅니다.
var _log := false
var _log_tick := 0


func _ready() -> void:
	_collect()
	_log = OS.get_cmdline_user_args().has("--jiggle-log")
	if _log:
		print("[jiggle] 본 %d개 잡음 (%s)" % [_bones.size(), prefixes])


func _collect() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	for i in skel.get_bone_count():
		var name := skel.get_bone_name(i)
		var matched := false
		for prefix in prefixes:
			if name.begins_with(prefix):
				matched = true
				break
		if not matched:
			continue
		# 체인의 첫 본(_0)은 두피에 붙어 있습니다. 그것까지 흔들면 머리카락
		# 전체가 머리에서 떨어져 나온 것처럼 보입니다.
		var parts := name.split("_")
		var index := int(parts[parts.size() - 1])
		if index < 1:
			continue
		_bones.append(i)
		_rest.append(skel.get_bone_rest(i).basis.get_rotation_quaternion())
		# 끝으로 갈수록 크게 흔들립니다.
		_depth.append(clampf(float(index) / 2.0, 0.35, 1.0))
		_angle.append(Vector2.ZERO)
		_vel.append(Vector2.ZERO)


func _process_modification_with_delta(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or _bones.is_empty() or delta <= 0.0:
		return

	_track_motion(skel, delta)

	# 스켈레톤 로컬로 바꿔야 캐릭터가 어느 쪽을 보든 관성이 맞습니다.
	#
	# **이 리그는 위쪽이 -Z 입니다.** 그래서 수평면은 X(좌우) 와 Y(앞뒤)이고,
	# Z 는 위아래입니다. 여기서 X/Z 를 수평으로 착각하면 상하 반동이 좌우
	# 흔들림으로 들어가서, 뛰든 서 있든 각도가 똑같이 나옵니다.
	var basis_inv := skel.global_transform.basis.inverse()
	var acc: Vector3 = basis_inv * _accel
	var speed_local: Vector3 = basis_inv * _body_vel

	# 머리카락은 진행 방향의 **반대**로 끌립니다. 앞으로 달리면 뒤로 날립니다.
	var drive := Vector2(acc.y, -acc.x) * ACCEL_GAIN
	drive += Vector2(speed_local.y, -speed_local.x) * SPEED_GAIN
	drive.x += acc.z * BOB_GAIN

	var stiff := STIFFNESS * STIFF_SCALE
	var damp := DAMPING * DAMP_SCALE
	# 큰 delta 한 번에 적분하면 스프링이 발산합니다. 잘라서 여러 번 밟습니다.
	var steps := clampi(int(ceil(delta / 0.008)), 1, 6)
	var step := delta / float(steps)

	for n in _bones.size():
		var target := drive * _depth[n]
		var angle := _angle[n]
		var vel := _vel[n]
		for _s in steps:
			var accel := (target - angle) * stiff - vel * damp
			vel += accel * step
			angle += vel * step
		angle.x = clampf(angle.x, -MAX_ANGLE, MAX_ANGLE)
		angle.y = clampf(angle.y, -MAX_ANGLE, MAX_ANGLE)
		_angle[n] = angle
		_vel[n] = vel
		var offset := Quaternion(Vector3.RIGHT, angle.x) * Quaternion(Vector3.FORWARD, angle.y)
		skel.set_bone_pose_rotation(_bones[n], _rest[n] * offset)

	if _log:
		_log_tick += 1
		if _log_tick % 60 == 0:
			var peak := 0.0
			for a in _angle:
				peak = maxf(peak, a.length())
			print("[jiggle] 최대 %.3f rad (%.1f도), 속도 %.1f m/s, 가속 %.1f m/s^2"
				% [peak, rad_to_deg(peak), _body_vel.length(), _accel.length()])


func _track_motion(skel: Skeleton3D, delta: float) -> void:
	var origin := skel.global_transform.origin
	if not _primed:
		_primed = true
		_prev_origin = origin
		return
	var vel := (origin - _prev_origin) / delta
	_prev_origin = origin
	# 가속도는 프레임마다 튀므로 완만하게 섞습니다. 날것으로 쓰면 머리카락이 떱니다.
	var raw := (vel - _prev_vel) / delta
	_prev_vel = vel
	_accel = _accel.lerp(raw.limit_length(90.0), clampf(delta * 14.0, 0.0, 1.0))
	_body_vel = _body_vel.lerp(vel.limit_length(20.0), clampf(delta * 12.0, 0.0, 1.0))


func kick(impulse: Vector3) -> void:
	## 피격이나 구르기처럼 순간적인 사건에 직접 힘을 넣습니다. 위치 변화만
	## 보고 있으면 짧은 충격은 놓칩니다.
	var skel := get_skeleton()
	if skel == null:
		return
	var local: Vector3 = skel.global_transform.basis.inverse() * impulse
	var push := Vector2(local.y, -local.x)
	for n in _vel.size():
		_vel[n] += push * _depth[n]
