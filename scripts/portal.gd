class_name Portal
extends Node3D

## 다음 층으로 가는 문. 층의 적을 모두 정리해야 열립니다.
##
## 잠긴 상태에서도 보이게 둡니다. 목적지를 알고 싸우는 것과 모르고 헤매는
## 것은 다른 게임이고, 로그라이크에서는 전자가 낫습니다.

signal entered

const RADIUS := 1.5

var unlocked := false

var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _time := 0.0
var _fired := false


func _ready() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = 0.12
	mesh.radial_segments = 32
	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.35, 0.45, 0.6)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring.material_override = _mat
	_ring.position = Vector3(0, 0.07, 0)
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.6, 1.0)
	_light.light_energy = 0.4
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.2, 0)
	add_child(_light)


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_mat.albedo_color = Color(0.45, 0.75, 1.0, 0.95)
	_light.light_energy = 2.5
	Fx.ring(get_parent(), global_position, Color(0.5, 0.8, 1.0), 5.0, 0.7)
	Fx.popup_text(get_parent(), global_position + Vector3(0, 2.0, 0),
		"길이 열렸다", Color(0.6, 0.85, 1.0))


func _process(delta: float) -> void:
	_time += delta
	var pulse := 1.0 + sin(_time * (4.0 if unlocked else 1.5)) * (0.10 if unlocked else 0.03)
	_ring.scale = Vector3(pulse, 1.0, pulse)
	if unlocked:
		_light.light_energy = 2.0 + sin(_time * 4.0) * 0.8

	if not unlocked or _fired:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node3D
	var d := Vector2(p.global_position.x - global_position.x,
		p.global_position.z - global_position.z).length()
	if d < RADIUS * 0.9:
		_fired = true
		entered.emit()
