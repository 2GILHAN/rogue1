extends SceneTree

## 랙돌 API 이름 확인용. 기억 대신 엔진에 묻습니다.
##
##   godot --headless --path . --script res://tools/probe_api.gd

func _initialize() -> void:
	print("=== PhysicalBone3D 상수")
	for k in ClassDB.class_get_integer_constant_list("PhysicalBone3D", true):
		print("  ", k, " = ", ClassDB.class_get_integer_constant("PhysicalBone3D", k))
	print("=== Skeleton3D 자식/부모 조회")
	for m in ClassDB.class_get_method_list("Skeleton3D", true):
		var n: String = m["name"]
		if n.contains("children") or n.contains("parent") or n.contains("global_rest"):
			print("  ", n)
	print("=== PhysicalBoneSimulator3D 상속")
	print("  ", ClassDB.get_parent_class("PhysicalBoneSimulator3D"))
	quit()
