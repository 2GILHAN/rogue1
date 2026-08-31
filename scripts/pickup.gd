class_name Pickup
extends Node3D

## 적이 떨구는 금화. 잠깐 튀었다가 플레이어에게 빨려 갑니다.
##
## 자석으로 만든 이유: 줍기 위해 멈춰 서면 전투 흐름이 끊기고, 놓친 금화가
## 방 구석에 남으면 청소하러 돌아가야 합니다. 둘 다 재미가 아닙니다.

const MAGNET_RANGE := 5.5
const MAGNET_SPEED := 14.0

var amount := 5
var _delay := 0.35
var _velocity := Vector3.ZERO
var _spin := 0.0
var _mesh: MeshInstance3D


func setup(gold: int, at: Vector3) -> void:
	amount = gold
	global_position = at + Vector3(0, 0.6, 0)
	_velocity = Vector3(randf_range(-2.0, 2.0), 4.0, randf_range(-2.0, 2.0))

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.18
	mesh.height = 0.05
	mesh.radial_segments = 12
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Fx.GOLD_COLOR
	mat.metallic = 0.9
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.6, 0.1)
	mat.emission_energy_multiplier = 0.5
	_mesh.material_override = mat
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_spin += delta * 6.0
	_mesh.rotation.y = _spin

	if _delay > 0.0:
		_delay -= delta
		_velocity.y -= 16.0 * delta
		global_position += _velocity * delta
		if global_position.y < 0.35:
			global_position.y = 0.35
			_velocity = Vector3(_velocity.x * 0.4, absf(_velocity.y) * 0.35, _velocity.z * 0.4)
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	var to: Vector3 = player.global_position + Vector3(0, 0.7, 0) - global_position
	var dist := to.length()
	if dist < 0.7:
		Game.add_gold(amount)
		Fx.burst(get_parent(), global_position, Fx.GOLD_COLOR, 5, 1.6)
		queue_free()
		return
	if dist < MAGNET_RANGE:
		# 가까울수록 빨라집니다. 일정 속도로 오면 굼떠 보입니다.
		var pull := MAGNET_SPEED * (1.0 - dist / MAGNET_RANGE) + 3.0
		global_position += to.normalized() * pull * delta
	else:
		global_position.y = 0.35 + sin(_spin) * 0.08
