class_name Ragdoll
extends RefCounted

## 죽을 때 캐릭터를 물리에 넘깁니다.
##
## # 왜 본 하나하나에 물리 몸을 다는가
##
## 쓰러지는 연출을 트윈으로 하면 늘 똑같이 넘어집니다. 어디서 맞았는지,
## 벽이 뒤에 있는지에 따라 다르게 쓰러져야 마지막 순간이 기억에 남습니다.
##
## # 어느 본까지 넣는가
##
## 몸통·머리·다리만 넣고 **팔은 넣지 않습니다.** 도원 리그의 팔 본은 메시와
## 어긋나 있어서(jiggle.gd 주석 참고) 물리에 넘기면 팔이 아니라 셔츠가 따로
## 날아갑니다. 팔 본을 빼면 어깨는 가슴 본을 따라가므로, 몸통에 붙은 채로
## 같이 쓰러집니다 - 부러진 것보다 이쪽이 낫습니다.
## PackedStringArray(...) 는 상수식이 아니라 const 에 못 넣습니다. 평범한
## 배열로 둡니다 - has() 는 어차피 둘 다 있습니다.
const BODY_BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftUpLeg", "LeftLeg", "LeftFoot",
	"RightUpLeg", "RightLeg", "RightFoot",
]

const MIN_LENGTH := 0.05


static func build(skel: Skeleton3D, bones: Array = BODY_BONES) -> PhysicalBoneSimulator3D:
	## 시뮬레이터와 물리 본을 만들어 둡니다. 아직 시뮬레이션은 켜지 않습니다 -
	## 살아 있는 동안은 스켈레톤이 포즈를 결정해야 합니다.
	if skel == null:
		return null
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skel.add_child(sim)

	for name in bones:
		var idx := skel.find_bone(name)
		if idx < 0:
			continue
		var bone := PhysicalBone3D.new()
		bone.mass = 1.0
		bone.friction = 0.9
		bone.bounce = 0.0
		bone.linear_damp = 0.4
		bone.angular_damp = 1.2
		# 벽·바닥하고만 부딪힙니다. 적이나 살아 있는 몸과 부딪히면 시체가
		# 밀려다니며 전투를 방해합니다.
		bone.collision_layer = 1 << 5
		bone.collision_mask = 1
		_fit(skel, idx, bone, bones)
		# PhysicalBone3D 는 **노드 이름으로** 본을 찾습니다 - 설정 항목이
		# 아닙니다. 트리에 들어가는 순간 조회하므로 이름이 먼저여야 합니다.
		bone.name = name
		sim.add_child(bone)
		# 관절은 한 프레임 미뤄서 만듭니다. 본 번호는 트리에 들어간 뒤에야
		# 정해지는데, 그 전에 관절을 만들면 엔진이 본 -1 을 조회하면서
		# "p_bone = -1" 오류를 11번 뱉습니다(본 개수만큼).
		bone.set_deferred("joint_type", PhysicalBone3D.JOINT_TYPE_CONE)
	return sim


static func _fit(skel: Skeleton3D, idx: int, bone: PhysicalBone3D,
		bones: Array) -> void:
	## 캡슐을 본 위에 얹습니다. 본의 길이와 방향은 **자식 본까지의 거리**로
	## 잽니다 - 스켈레톤에는 꼬리(tail) 정보가 없습니다.
	var here := skel.get_bone_global_rest(idx)
	var direction := Vector3.ZERO
	var length := 0.0
	var count := 0
	for child in skel.get_bone_children(idx):
		if not bones.has(skel.get_bone_name(child)):
			continue
		var delta := skel.get_bone_global_rest(child).origin - here.origin
		direction += delta
		length += delta.length()
		count += 1
	if count > 0:
		direction /= float(count)
		length /= float(count)
	if length < MIN_LENGTH:
		# 말단 본(발, 머리)은 자식이 없습니다. 부모 방향을 이어 씁니다.
		var parent := skel.get_bone_parent(idx)
		if parent >= 0:
			direction = here.origin - skel.get_bone_global_rest(parent).origin
		length = maxf(length, 0.12)
	if direction.length_squared() < 0.000001:
		direction = Vector3.UP
	direction = direction.normalized()

	var capsule := CapsuleShape3D.new()
	capsule.height = maxf(length, MIN_LENGTH * 2.0)
	capsule.radius = clampf(length * 0.34, 0.025, 0.11)

	var shape := CollisionShape3D.new()
	shape.shape = capsule
	# 캡슐은 자기 Y 축을 따라 섭니다. 본 방향으로 눕히고 절반만큼 밀어
	# 머리(본 원점)와 꼬리 사이에 놓습니다.
	var local_dir: Vector3 = here.basis.inverse() * direction
	shape.transform = Transform3D(_aim_y(local_dir), local_dir * (length * 0.5))
	bone.add_child(shape)

	# body_offset / joint_offset 은 건드리지 않습니다. 둘 다 기본값이 항등이라
	# 같은 값을 다시 넣는 셈인데, 그 설정자가 관절을 다시 만들면서 아직
	# 정해지지 않은 본 번호(-1)를 조회해 오류만 남깁니다.


static func _aim_y(direction: Vector3) -> Basis:
	## +Y 를 direction 으로 돌리는 회전.
	var up := direction.normalized()
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var side := reference.cross(up).normalized()
	return Basis(side, up, side.cross(up).normalized())


static func topple(sim: PhysicalBoneSimulator3D, impulse: Vector3) -> void:
	## 물리로 넘깁니다. 맞은 방향으로 밀어 줘야 "그쪽에서 맞아서 쓰러졌다"로
	## 읽힙니다.
	if sim == null or sim.is_simulating_physics():
		return
	sim.physical_bones_start_simulation([])
	if impulse.length_squared() < 0.0001:
		return
	for child in sim.get_children():
		if child is PhysicalBone3D:
			child.apply_central_impulse(impulse * child.mass)
