class_name Projectile
extends Node3D

## 침 뱉는 적이 쏘는 가시. 물리 몸체 대신 격자를 직접 물어봅니다 - 벽이
## 격자에 딱 맞으므로 이쪽이 싸고, 빠른 탄이 벽을 뚫는 사고도 없습니다.

## 가시도 주인공과 같은 비율로 낮췄습니다(11.0 -> 8.8 -> 5.3).
## 주인공만 느려지면 피할 수 없는 탄이 됩니다.
const SPEED := 5.3
const LIFETIME := 4.0
const HIT_RADIUS := 0.75

var damage := 8.0
var dir := Vector3.FORWARD
var dungeon: Dungeon
var _life := LIFETIME
## 무적인 사람을 통과한 적이 있는가. 한 번 지나갔으면 무적이 풀려도 그 탄은
## 다시 맞히지 않습니다 - 몸 안에 들어와 있다가 튀어나오며 때리는 꼴이 됩니다.
var _passed := false


func launch(from: Vector3, direction: Vector3, dmg: float, level: Dungeon) -> void:
	global_position = from
	dir = direction.normalized()
	damage = dmg
	dungeon = level

	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 1.0, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.45)
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	add_child(mi)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 1.0, 0.5)
	glow.light_energy = 1.2
	glow.omni_range = 3.0
	add_child(glow)


func _physics_process(delta: float) -> void:
	# 적이 멈추는 동안에는 날아오던 가시도 멈춥니다. 적만 세우고 탄은
	# 날아오면, 피할 수 없는 상태에서 맞는 것은 그대로입니다.
	var who := get_tree().get_nodes_in_group("player")
	if who.size() > 0 and who[0].has_method("is_reading") and who[0].is_reading():
		return
	# 고르기·상점 화면이 뜨는 프레임의 틈을 막습니다(enemy.gd 와 같은 이유).
	if Game.instance != null and (Game.instance.phase != Game.Phase.PLAYING
			or Game.instance.world_frozen):
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	var step := dir * SPEED * delta
	global_position += step

	if dungeon != null:
		var c := dungeon.world_to_cell(global_position)
		if dungeon.is_solid(c.x, c.y):
			_pop(Color(0.6, 1.0, 0.6))
			return

	if _passed:
		return          # 이미 몸을 지나간 탄입니다. 다시 맞히지 않습니다.
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0] as Node3D
		var to: Vector3 = player.global_position + Vector3(0, 0.8, 0) - global_position
		if to.length() < HIT_RADIUS:
			# **맞을 수 없는 상태면 그냥 지나갑니다.**
			#
			# 예전에는 여기서 take_damage 를 부르고 곧바로 터뜨렸습니다.
			# 무적이면 take_damage 가 아무 일도 안 하는데 탄은 사라져서,
			# 구르기가 "안 아픈 방패" 가 됐습니다 - 탄을 몸으로 지우는 셈이라
			# 뒤에 있던 사람도 안전했습니다.
			#
			# 충돌을 끄는 방식이 아닙니다. 이 탄은 물리 몸체가 아니라 거리로
			# 재는 것이라, 여기서 건너뛰기만 하면 실제로 몸을 통과합니다 -
			# 구르는 동안 적을 통과하는 문제와는 아무 상관이 없습니다.
			if bool(player.call("is_invulnerable")):
				_passed = true
				return
			player.call("take_damage", damage, global_position)
			_pop(Color(0.7, 1.0, 0.6))


func _pop(color: Color) -> void:
	Fx.burst(get_parent(), global_position, color, 7, 2.4)
	queue_free()
