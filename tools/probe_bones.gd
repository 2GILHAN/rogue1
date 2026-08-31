extends SceneTree

## 임포트된 모델의 실제 본 이름을 봅니다. glTF 임포터가 이름을 손대는 경우가
## 있어, 리그 json 의 이름을 그대로 믿으면 안 됩니다.
##
##   godot --headless --path . --script res://tools/probe_bones.gd

func _initialize() -> void:
	for path in ["res://assets/models/dowon.glb",
			"res://assets/models/enemy_sprout.glb"]:
		print("=== ", path)
		var packed: PackedScene = load(path)
		if packed == null:
			print("  (못 불러옴)")
			continue
		var root: Node = packed.instantiate()
		var skel := _find(root)
		if skel == null:
			print("  (Skeleton3D 없음)")
			continue
		print("  본 %d개" % skel.get_bone_count())
		var names := PackedStringArray()
		for i in skel.get_bone_count():
			names.append("%d:%s" % [i, skel.get_bone_name(i)])
		print("  ", ", ".join(names))
	quit()


func _find(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null
