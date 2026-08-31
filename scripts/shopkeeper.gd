class_name Shopkeeper
extends Node3D

## 상인. 서 있고, 가까이 가면 말을 겁니다.
##
## 상점을 안전한 방에 두는 것이 규칙입니다. 싸우면서 물건을 고를 수는 없고,
## 고르는 시간이 곧 다음 층을 준비하는 호흡이기 때문입니다.

signal player_near_changed(near: bool)

const RANGE := 3.2

var _near := false
var _time := 0.0
var _pivot: Node3D


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var model := Models.spawn(Models.SHOPKEEPER)
	_pivot.add_child(model)
	var ap := Models.find_anim(model)
	if ap != null:
		var idle := Models.clip(ap, "Idle")
		if idle != "":
			ap.play(idle)

	# 발밑에 깔개. 이 방이 다른 방과 다르다는 신호가 필요합니다.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.35, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mesh := CylinderMesh.new()
	mesh.top_radius = RANGE
	mesh.bottom_radius = RANGE
	mesh.height = 0.08
	mesh.radial_segments = 28
	var rug := MeshInstance3D.new()
	rug.mesh = mesh
	rug.material_override = mat
	rug.position = Vector3(0, 0.05, 0)
	add_child(rug)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.45)
	lamp.light_energy = 2.2
	lamp.omni_range = 7.0
	lamp.position = Vector3(0, 2.2, 0)
	add_child(lamp)

	var sign_label := Label3D.new()
	sign_label.text = "상점"
	sign_label.font_size = 48
	sign_label.outline_size = 16
	sign_label.modulate = Color(1.0, 0.85, 0.5)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.pixel_size = 0.004
	sign_label.position = Vector3(0, 2.1, 0)
	add_child(sign_label)


func _process(delta: float) -> void:
	_time += delta
	# 서 있는 대기 동작이 짧아 지루하지 않게 아주 조금 흔들어 둡니다.
	_pivot.rotation.y = sin(_time * 0.7) * 0.25

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node3D
	var d := Vector2(p.global_position.x - global_position.x,
		p.global_position.z - global_position.z).length()
	var near_now := d < RANGE
	if near_now != _near:
		_near = near_now
		player_near_changed.emit(_near)


func is_near() -> bool:
	return _near
