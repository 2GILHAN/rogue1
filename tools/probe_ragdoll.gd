extends SceneTree

## PhysicalBone3D 가 어떤 배치에서 본을 찾는지 시험합니다.
## get_bone_id() 가 -1 이면 못 찾은 것이고, 그 상태로 두면 매 프레임
## "p_bone = -1" 오류가 쏟아집니다.
##
##   godot --headless --path . --script res://tools/probe_ragdoll.gd

func _find(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null


func _try(label: String, skel: Skeleton3D, use_sim: bool, name_first: bool) -> void:
	var host: Node = skel
	if use_sim:
		var sim := PhysicalBoneSimulator3D.new()
		skel.add_child(sim)
		host = sim
	var bone := PhysicalBone3D.new()
	if name_first:
		bone.name = "Hips"
		host.add_child(bone)
	else:
		host.add_child(bone)
		bone.name = "Hips"
	print("  %-40s bone_id = %d" % [label, bone.get_bone_id()])
	bone.queue_free()
	if use_sim:
		host.queue_free()


func _initialize() -> void:
	var packed: PackedScene = load("res://assets/models/dowon.glb")
	var model: Node = packed.instantiate()
	root.add_child(model)
	var skel := _find(model)
	print("스켈레톤: ", skel, " 본 ", skel.get_bone_count(), "개, find_bone(Hips)=",
		skel.find_bone("Hips"))
	_try("시뮬레이터 아래 / 이름 먼저", skel, true, true)
	_try("시뮬레이터 아래 / 이름 나중", skel, true, false)
	_try("스켈레톤 직속 / 이름 먼저", skel, false, true)
	_try("스켈레톤 직속 / 이름 나중", skel, false, false)
	quit()
