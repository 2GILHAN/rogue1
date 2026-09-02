class_name Trap
extends Node3D

## 바닥에 놓인 함정. 엔진 기본 도형으로 그 자리에서 만듭니다.
##
## # 왜 물리 몸체가 아닌가
##
## 가시(Projectile)와 같은 이유입니다. 함정은 **바닥의 동그란 자리**일 뿐이라
## 거리 하나로 충분하고, 강체로 만들면 밀리거나 사람을 밀어냅니다.
##
## # 왜 적도 맞는가
##
## 함정이 나만 아프면 그냥 피해 다니는 장애물입니다. 적도 맞으면 **적을 함정
## 쪽으로 몰아넣는** 놀이가 생기고, 밀기·고함의 넉백이 그 자리에서 쓸모를
## 얻습니다. 로그라이크에서 함정이 재미있는 이유가 그것입니다.

const KINDS := {
	# 압정. 예고 → 솟음 → 내려감을 되풀이합니다. 지나갈 수 있는 자리이므로
	# **박자를 읽으면 그냥 지나가는** 것이 정답입니다.
	"tack": {
		"cycle": 2.6, "warn": 0.7, "up": 0.9,
		"damage": 12.0, "radius": 0.85, "knock": 4.0,
		"color": Color(0.85, 0.84, 0.80),
	},
	# 쏟아진 우유. 늘 켜져 있고 아프지는 않지만, 밟으면 **미끄러집니다.**
	# 구르기로 건너뛰거나 돌아가야 합니다.
	"puddle": {
		"cycle": 0.0, "slip": 1.0, "radius": 1.05,
		"color": Color(0.92, 0.95, 1.0),
	},
}

var kind := "tack"
var stats := {}

## 주기 안에서의 위치(초). 함정마다 다르게 시작해야 방 전체가 같은 박자로
## 솟았다 내려가지 않습니다.
var _t := 0.0
var _spikes: Array[Node3D] = []
var _plate: MeshInstance3D
var _plate_mat: StandardMaterial3D
## 같은 사람을 한 번 솟을 때 여러 번 찌르지 않게 기억해 둡니다.
var _bitten: Dictionary = {}
var _was_up := false


func setup(trap_kind: String, rng: RandomNumberGenerator) -> void:
	kind = trap_kind
	stats = KINDS.get(kind, KINDS["tack"])
	_t = rng.randf() * maxf(float(stats.get("cycle", 1.0)), 0.001)
	add_to_group("traps")
	if kind == "puddle":
		_build_puddle()
	else:
		_build_tack()


# ---------------------------------------------------------------- 생김새

func _build_puddle() -> void:
	## 납작한 원반 하나. 물처럼 반투명하고 아주 조금 일렁입니다.
	var disc := CylinderMesh.new()
	var r: float = float(stats["radius"])
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.02
	disc.radial_segments = 20
	_plate_mat = _flat_material(Color(0.92, 0.95, 1.0, 0.55))
	_plate = MeshInstance3D.new()
	_plate.mesh = disc
	_plate.material_override = _plate_mat
	_plate.position.y = 0.02
	_add_flat(_plate)


func _build_tack() -> void:
	## 바닥 판 + 솟아오르는 압정 다섯.
	##
	## 판이 먼저 보여야 합니다. 압정만 있으면 내려가 있는 동안 아무 표시가
	## 없어서, 밟고 나서야 함정인 줄 압니다 - 예고 없는 함정은 함정이 아니라
	## 벌금입니다.
	var r: float = float(stats["radius"])
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.02
	disc.radial_segments = 18
	_plate_mat = _flat_material(Color(0.55, 0.42, 0.36, 0.85))
	_plate = MeshInstance3D.new()
	_plate.mesh = disc
	_plate.material_override = _plate_mat
	_plate.position.y = 0.015
	_add_flat(_plate)

	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(stats["color"])
	spike_mat.roughness = 0.4
	spike_mat.metallic = 0.3
	for i in 5:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.075
		cone.height = 0.30
		cone.radial_segments = 7
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = spike_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 가운데 하나, 둘레에 넷.
		if i > 0:
			var a := TAU * float(i - 1) / 4.0
			mi.position = Vector3(cos(a), 0.0, sin(a)) * r * 0.5
		mi.position.y = -0.30          # 처음에는 바닥 아래에 숨어 있습니다
		add_child(mi)
		_spikes.append(mi)


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _add_flat(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 카툰 옵션이 바닥 표시에 검은 테두리를 두르면 접시가 됩니다.
	mi.set_meta("flat", true)
	add_child(mi)


# ---------------------------------------------------------------- 동작

func _physics_process(delta: float) -> void:
	# 필살 모드 동안에는 가시도 멈춥니다 - 세상이 멈췄는데 발밑에서만
	# 압정이 오르내리면 그 한 가지가 규칙 밖에 있는 것으로 보입니다.
	if Game.instance != null and Game.instance.world_frozen:
		return
	if kind == "puddle":
		_drive_puddle(delta)
	else:
		_drive_tack(delta)


func _drive_puddle(delta: float) -> void:
	_t += delta
	if _plate_mat != null:
		_plate_mat.albedo_color.a = 0.5 + sin(_t * 1.8) * 0.08
	for who in _bodies_in_range(float(stats["radius"])):
		if who.has_method("slip_on"):
			who.slip_on(float(stats.get("slip", 1.0)))


func _drive_tack(delta: float) -> void:
	var cycle: float = float(stats["cycle"])
	var warn: float = float(stats["warn"])
	var up_time: float = float(stats["up"])
	_t = fmod(_t + delta, cycle)

	# 주기 안에서 지금이 어디인가. 예고 -> 솟음 -> 내려감 순입니다.
	var height := -0.30
	var up := false
	if _t < warn:
		# 예고. 판이 붉어지고 압정이 살짝 올라옵니다 - 눈으로 보이는 예고가
		# 없으면 박자를 읽을 수가 없습니다.
		var u := _t / warn
		height = -0.30 + 0.06 * u
		if _plate_mat != null:
			_plate_mat.albedo_color = Color(0.55, 0.42, 0.36, 0.85).lerp(
				Color(0.95, 0.35, 0.30, 0.95), u)
	elif _t < warn + up_time:
		up = true
		# 솟음. 앞의 15% 동안 튀어 오르고 나머지는 서 있습니다.
		var u: float = clampf((_t - warn) / (up_time * 0.15), 0.0, 1.0)
		height = lerpf(-0.24, 0.16, u * u)
	else:
		# 내려감.
		var u: float = clampf((_t - warn - up_time) / maxf(cycle - warn - up_time, 0.01),
			0.0, 1.0)
		height = lerpf(0.16, -0.30, u)
		if _plate_mat != null:
			_plate_mat.albedo_color = Color(0.95, 0.35, 0.30, 0.95).lerp(
				Color(0.55, 0.42, 0.36, 0.85), u)

	for s in _spikes:
		s.position.y = height

	if up and not _was_up:
		# 막 솟았습니다. 이번 솟음의 기록을 지웁니다.
		_bitten.clear()
		# **가까이 있을 때만 소리를 냅니다.**
		#
		# 층마다 여섯 개가 각자 2.6초 주기로 도는데, 거리를 안 보면 방 반대편
		# 압정까지 전부 울립니다 - 8층 봇 3000프레임에서 `warn.wav` 가 79번,
		# 0.6초에 한 번꼴로 났습니다. 가만히 서 있어도 "띠릿띠릿" 이 끊이지
		# 않고, 그러면 **적의 공격 예고와 구분이 안 됩니다** - 같은 소리라서
		# 몸을 피해야 할 때도 그냥 함정이겠거니 하게 됩니다.
		#
		# 소리가 필요한 거리는 "밟을 뻔한 거리" 입니다. 화면에 보이는 것만으로
		# 충분한 먼 함정은 눈이 알려 줍니다.
		if _player_near(SOUND_RANGE):
			Sfx.play(Sfx.WARN, -17.0, 0.16)
	_was_up = up
	if not up:
		return
	for who in _bodies_in_range(float(stats["radius"])):
		var id: int = who.get_instance_id()
		if _bitten.has(id):
			continue
		_bitten[id] = true
		_bite(who)


func _bite(who: Node3D) -> void:
	## 한 번 찌릅니다. 주인공과 적을 **같은 값으로** 다룹니다 - 함정이 양쪽
	## 모두에게 같으면 적을 몰아넣는 놀이가 성립합니다.
	var dmg: float = float(stats["damage"])
	var dir: Vector3 = who.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
	Fx.burst(get_parent(), global_position + Vector3(0, 0.3, 0),
		Color(1.0, 0.85, 0.6), 6, 2.2)
	if who is Enemy:
		(who as Enemy).take_damage(dmg, false, dir, 0.3)
	elif who.has_method("take_damage"):
		who.call("take_damage", dmg, global_position,
			float(stats.get("knock", 4.0)), "바닥의 압정")


## 소리가 들리는 거리. 압정 반지름(0.85)의 네 배쯤 - 걸어서 한 걸음
## 반이면 닿는 거리입니다.
const SOUND_RANGE := 3.6


func _player_near(radius: float) -> bool:
	## 주인공이 이 안에 있는지. 소리를 낼지 정할 때만 씁니다.
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if not is_instance_valid(who):
			continue
		var to: Vector3 = who.global_position - global_position
		to.y = 0.0
		if to.length() <= radius:
			return true
	return false


func _bodies_in_range(radius: float) -> Array:
	## 함정 위에 서 있는 것들. 사람과 적만 봅니다 - 소품까지 찌르면 방에
	## 굴러다니는 인형이 계속 터집니다.
	var out: Array = []
	for group in ["player", "enemies"]:
		for n in get_tree().get_nodes_in_group(group):
			var who := n as Node3D
			if not is_instance_valid(who):
				continue
			var to: Vector3 = who.global_position - global_position
			to.y = 0.0
			if to.length() <= radius:
				out.append(who)
	return out
