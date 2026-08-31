class_name Fx
extends RefCounted

## 타격감을 만드는 잔재주들. 게임 규칙과는 무관하지만, 이것이 없으면
## 때리는 느낌이 나지 않아 "플레이 가능"의 문턱을 못 넘습니다.

const CRIT_COLOR := Color(1.0, 0.82, 0.30)
const HIT_COLOR := Color(1.0, 0.95, 0.90)
const HURT_COLOR := Color(1.0, 0.35, 0.32)
const GOLD_COLOR := Color(1.0, 0.84, 0.35)


static func damage_number(parent: Node3D, at: Vector3, amount: float,
		crit: bool = false, color: Color = HIT_COLOR) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label3D.new()
	label.text = ("%d!" % int(round(amount))) if crit else str(int(round(amount)))
	label.font = UiTheme.font()
	label.font_size = 96 if crit else 64
	label.outline_size = 24
	label.modulate = CRIT_COLOR if crit else color
	label.outline_modulate = Color(0.05, 0.03, 0.03, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0032 if crit else 0.0026
	label.position = at + Vector3(randf_range(-0.25, 0.25), 0.2, randf_range(-0.25, 0.25))
	parent.add_child(label)

	var rise := 1.1 if crit else 0.8
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + rise, 0.7) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tween.tween_property(label, "scale", Vector3.ONE * 1.35, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(label.queue_free)


static func popup_text(parent: Node3D, at: Vector3, text: String, color: Color) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label3D.new()
	label.text = text
	label.font = UiTheme.font()
	label.font_size = 56
	label.outline_size = 20
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.03, 0.03, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0026
	label.position = at
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, 1.1)
	tween.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


static func punch(node: Node3D, amount: float = 0.22, time: float = 0.16) -> void:
	## 맞은 쪽이 잠깐 부풀었다 돌아옵니다. 프레임 정지 대신 쓰는 값싼 반응.
	if not is_instance_valid(node):
		return
	var base: Vector3 = node.get_meta("fx_base_scale", node.scale)
	node.set_meta("fx_base_scale", base)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", base * (1.0 + amount), time * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, time * 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


static func flash(root: Node3D, color: Color, time: float = 0.12,
		opacity: float = 1.0) -> void:
	## 메시 전체를 잠깐 단색으로 덮습니다. 텍스처가 어두운 캐릭터라
	## 색조 변경보다 이쪽이 훨씬 잘 보입니다.
	##
	## opacity 로 세기를 나눕니다. 피격은 1.0(완전히 하얗게, 아주 짧게)이지만,
	## 공격 예고는 0.5 대로 둡니다 - 예고 중에 실루엣까지 지워지면 무엇이
	## 덤비는지 안 보여서 예고의 목적이 사라집니다.
	if not is_instance_valid(root):
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	if meshes.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6 * opacity
	if opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, opacity)
	# 오버레이 자리는 적의 색조(Models.tint)도 씁니다. null 로 되돌리면 붉은 적이
	# 한 번 맞고 색을 잃습니다.
	#
	# 되돌릴 값은 **처음 한 번만** 기억합니다. 호출 시점의 값을 기억하면, 예고
	# 번쩍임이 끝나기 전에 피격 번쩍임이 겹칠 때 "번쩍임 재질"이 기준으로
	# 잡혀 캐릭터가 흰 덩어리로 굳습니다. 실제로 그렇게 굳었습니다.
	for m in meshes:
		if not m.has_meta("fx_base_overlay"):
			m.set_meta("fx_base_overlay", m.material_overlay)
		m.material_overlay = mat
	var timer := root.get_tree().create_timer(time)
	timer.timeout.connect(func() -> void:
		for m in meshes:
			# 나보다 늦은 번쩍임이 이미 덮었으면 그쪽이 되돌립니다.
			if is_instance_valid(m) and m.material_overlay == mat:
				m.material_overlay = m.get_meta("fx_base_overlay", null))


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)


## 이펙트 메시는 모양이 늘 같습니다. 호출마다 새로 만들면 그때마다 정점을 다시
## 올려서 프레임이 튑니다. 한 번 만들어 두고 돌려씁니다 - 재질만 매번 새로
## 만들면 되고, 색과 투명도는 재질에 있습니다.
static var _cached_ring: TorusMesh = null
static var _cached_shard: BoxMesh = null


## 밀기·구르기가 쓰는 파랑. 세 곳에서 같은 색을 써야 "이건 같은 힘" 으로
## 읽힙니다(구르기 잔상 · 미는 선 · 고함 구슬).
const RUSH_COLOR := Color(0.34, 0.66, 1.0)


static func speed_lines(parent: Node3D, at: Vector3, dir: Vector3,
		count: int = 7, length: float = 1.6, strong: bool = false) -> void:
	## **뒤로 흘러가는 직선 여러 개.** 미는 순간 실루엣 뒤에 깔립니다.
	##
	## 만화가 속도를 그리는 방법 그대로입니다 - 물체는 그대로 두고 뒤에 선을
	## 그으면 그 방향으로 세게 나간 것이 됩니다. 고리(원)로는 "퍼졌다" 는
	## 되지만 "이쪽으로 밀었다" 가 안 됩니다.
	##
	## 선은 **미는 쪽의 반대**로 뻗습니다. 지나온 자리에 남는 자국이라야
	## 앞으로 나간 것으로 읽힙니다.
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	for i in count:
		var mesh := BoxMesh.new()
		var len_i := length * randf_range(0.55, 1.0) * (1.35 if strong else 1.0)
		# 두께 0.035 로는 화면에서 실 한 올이라 안 보였습니다. 이 게임은
		# 6m 위에서 내려다보므로, 눈에 걸리려면 손가락만 해야 합니다.
		mesh.size = Vector3(0.085, 0.085, len_i)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(RUSH_COLOR.r, RUSH_COLOR.g, RUSH_COLOR.b,
			1.0 if strong else 0.8)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("flat", true)
		parent.add_child(mi)
		# 실루엣을 따라 옆으로 흩고 높이도 흩습니다 - 한 줄로 겹치면 선이
		# 아니라 막대 하나로 보입니다.
		var off := side * randf_range(-0.42, 0.42) 			+ Vector3.UP * randf_range(0.15, 1.05)
		mi.global_position = at + off - flat * (len_i * 0.5 + 0.15)
		mi.look_at(mi.global_position + flat, Vector3.UP)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		# 뒤로 흘러가며 사라집니다.
		tw.tween_property(mi, "global_position",
			mi.global_position - flat * (0.7 if strong else 0.45), 0.30)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.30)
		tw.chain().tween_callback(mi.queue_free)


## 밀린 대상이 남기는 잔상 색. **어두운 보라**입니다 - 파랑(구르기·고함)과
## 갈라 놓아야 "미는 힘" 이 따로 읽힙니다.
const SHOVE_GHOST := Color(0.34, 0.16, 0.48)


## 아지랑이가 돌려 쓰는 상자와 재질. **하나만 만들어 나눠 씁니다.**
static var _shimmer_mesh: BoxMesh = null
static var _shimmer_mat: StandardMaterial3D = null


static func warm_up(parent: Node3D) -> void:
	## 이펙트를 **미리 한 번 그려 둡니다.** 층을 만들 때 부릅니다.
	##
	## 아지랑이의 첫 호출이 5.9ms 였고 그 뒤로는 0.1ms 였습니다 - 상자와
	## 재질을 나눠 쓰게 고친 뒤에도 **처음 그리는 한 번**은 그만큼 듭니다
	## (셰이더 변형을 그때 만듭니다). 그 한 번이 싸우는 도중에 오면 화면이
	## 끊기므로, 층이 만들어지는 동안 치릅니다.
	##
	## 바닥 아래에서 그립니다 - 보이지 않지만 그리기는 합니다.
	shimmer(parent, Vector3(0, -40, 0), Vector3.FORWARD, 1, false)


static func shimmer(parent: Node3D, at: Vector3, dir: Vector3,
		count: int = 9, strong: bool = false) -> void:
	## **아지랑이.** 작은 조각이 피어올랐다 사라집니다.
	##
	## 밀친 직후 아이의 다리 뒤에 깝니다. 선을 긋는 것보다 조용하고, 무엇보다
	## **끊기지 않습니다** - 직선은 0.3초 만에 딱 끊기는데 피어오르는 것은
	## 스러지므로 눈에 남는 인상이 부드럽습니다.
	##
	## 우유의 냄새 표시와 같은 방법입니다(prop.gd) - 이 게임에서 "무언가
	## 피어오른다" 는 이미 이 모양으로 정해져 있습니다.
	##
	## 색은 **파랑**입니다(구르기 잔상·고함과 같은 색). 아이가 낸 힘이므로
	## 다른 기술과 한 줄기로 읽혀야 합니다 - 어두운 보라는 **밀려나는 적**에게
	## 붙는 표시이지 아이 쪽 표시가 아닙니다.
	##
	## # 상자와 재질을 돌려 씁니다
	##
	## 조각마다 새로 만들었더니 **한 번에 6.3ms** 였습니다 - 16.7ms 짜리
	## 프레임의 3분의 1이 밀치는 순간에 통째로 날아가서, 이펙트가 아니라
	## 화면이 끊겼습니다. 상자와 재질은 열두 조각이 다 같은 것을 쓰면 되고,
	## 조각마다 다른 것은 **자리·크기·사라지는 때**뿐입니다.
	##
	## 옅어지는 것은 재질이 아니라 **`transparency`**(조각별 값)로 합니다.
	## 재질을 나눠 쓰면서도 하나씩 따로 스러지게 하는 유일한 길입니다.
	if _shimmer_mesh == null:
		_shimmer_mesh = BoxMesh.new()
		_shimmer_mesh.size = Vector3.ONE * 0.06
		_shimmer_mat = StandardMaterial3D.new()
		_shimmer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shimmer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shimmer_mat.albedo_color = Color(RUSH_COLOR.r, RUSH_COLOR.g,
			RUSH_COLOR.b, 0.9)
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var side := Vector3(-flat.z, 0.0, flat.x)
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _shimmer_mesh
		mi.material_override = _shimmer_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("flat", true)
		parent.add_child(mi)
		# **다리 뒤**입니다 - 미는 쪽의 반대, 발치 높이에서 시작합니다.
		mi.global_position = at - flat * randf_range(0.15, 0.55) 			+ side * randf_range(-0.3, 0.3) + Vector3.UP * randf_range(0.0, 0.15)
		mi.scale = Vector3.ONE * randf_range(0.75, 1.4) * (1.35 if strong else 1.0)
		var life := randf_range(0.45, 0.8)
		var tw := mi.create_tween()
		tw.tween_interval(randf_range(0.0, 0.12))
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position",
			mi.global_position + Vector3.UP * randf_range(0.5, 0.95)
			- flat * randf_range(0.1, 0.3), life)
		tw.tween_property(mi, "rotation",
			Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), life)
		tw.tween_property(mi, "transparency", 1.0, life)
		tw.chain().tween_callback(mi.queue_free)


static func arm_streak(parent: Node3D, hands: Vector3, dir: Vector3,
		strong: bool = false) -> void:
	## **팔이 지나온 자리에 남는 파란 띠.**
	##
	## # 왜 몸을 복제하지 않는가
	##
	## 처음에는 구르기 잔상처럼 몸을 통째로 복제하고 셰이더로 손 근처만
	## 남겼습니다. **한 번에 175ms** 가 걸렸습니다(구르기 잔상은 같은 복제로
	## 1.8ms - 차이는 셰이더 재질 쪽입니다). 열 프레임이 통째로 날아가서,
	## 손이 닿는 순간마다 화면이 걸렸습니다.
	##
	## 잔상이 보여 주려는 것은 "팔이 이 자리를 지나갔다" 하나뿐입니다. 그
	## 자리에 띠를 두 개 그으면 같은 말을 0.2ms 에 합니다.
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(RUSH_COLOR.r, RUSH_COLOR.g, RUSH_COLOR.b,
		0.95 if strong else 0.7)
	# 재질 하나를 두 띠가 나눠 씁니다. 하나씩 만들면 그만큼 값이 붙습니다.
	for s in [-1.0, 1.0]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.30 if strong else 0.24, 0.9)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("flat", true)
		parent.add_child(mi)
		mi.global_position = hands + side * (0.20 * s) - flat * 0.30
		mi.look_at(mi.global_position + flat, Vector3.UP)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		# 앞으로 뻗어 나가며 사라집니다 - 팔이 나간 쪽입니다.
		tw.tween_property(mi, "global_position",
			mi.global_position + flat * 0.55, 0.26)
		tw.tween_property(mi, "scale", Vector3(0.4, 0.4, 1.5), 0.26)
		tw.chain().tween_callback(mi.queue_free)
	# 색이 옅어지는 것은 재질 하나에만 걸면 됩니다. `Material` 에는
	# `create_tween` 이 없으므로 화면 노드에서 받아 씁니다.
	var fade: Tween = parent.create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.26)


## 고함 Lv5 에서 튀어나오는 호랑이. 아이가 지르는 소리가 커진 만큼
## **소리가 짐승이 되어** 앞으로 달려 나갑니다.
## 옆얼굴 그림과 그것을 그리는 셰이더.
const TIGER_TEX := "res://assets/textures/tiger_side.png"
const TIGER_SHADER := "res://assets/shaders/tiger_roar.gdshader"
## 그림의 세로/가로 비. 원본이 425 x 375 이라 0.88 인데, 조금 눌러야
## 바닥에 누웠을 때 길게 뻗은 것으로 보입니다.
const TIGER_ASPECT := 0.72
## 판의 가로축을 진행 방향으로 돌리는 각. 네 값을 나란히 찍어 골랐습니다.
##
##   90 / -90 / 0  입이 아이 쪽에 오고 목이 앞으로 갑니다 - 거꾸로입니다
##   180           **고른 값.** 아이 머리 쪽이 흐리고 앞으로 갈수록 뚜렷합니다
const TIGER_YAW := 180.0
## 목 쪽이 흐려지기 시작하는 자리(0 = 입, 1 = 목).
const TIGER_FADE := 0.28
## 목 쪽 끝의 폭(m). **아이 머리만 하게** 좁힙니다 - 키 1.25m 인 아이의
## 머리가 0.4m 남짓입니다. 네모난 판으로 두면 목이 머리 옆으로 한참
## 삐져나와, 소리가 입에서 나온 것으로 보이지 않습니다.
const TIGER_NECK := 0.42
## 머리가 끝나는 자리(U). 여기까지는 원래 폭을 그대로 두고, 그 뒤로만
## 좁힙니다 - 안 그러면 머리 윗통수와 목이 시작하는 아래 윤곽까지 눌립니다.
##
## 그림에서 쟀습니다: 칼럼별 세로 두께가 U=0.8 까지 0.9 언저리로 유지되다
## U=0.9 에서 0.65, U=1.0 에서 0.03 으로 떨어집니다.
const TIGER_HEAD_END := 0.85
## 정면 얼굴의 가로/세로 비. 원본이 444 x 415 라 1.07 인데, 바닥에 누우면
## 카메라가 세로를 눌러 보므로 조금 길게 잡습니다.
const TIGER_FRONT_ASPECT := 0.85
## 정면 얼굴이 뜨는 자리(사거리의 몇 배 앞). 부채꼴 한가운데입니다 -
## 아이 한가운데에 띄우면 아이를 덮고, 어디를 치는 것인지도 안 보입니다.
const TIGER_FRONT_AT := 0.55
## 그림을 위아래로 뒤집을지(1 = 뒤집음).
##
## 바닥에 눕힌 판이라 어느 쪽이 화면 위로 가는지는 판을 어떻게 돌렸느냐에
## 달려 있습니다. 두 값을 나란히 찍어 골랐습니다 - 0 은 눈이 아래로 가고
## 벌린 입이 위에 옵니다. **1 이 눈을 화면 위쪽에** 둡니다.
const TIGER_FLIP := 1.0
## 입이 아이를 향하도록 판을 그 자리에서 더 돌리는 각.
##
## **재서 얻은 값입니다.** 그림에서 코 끝은 (1, 155), 턱 끝은 (52, 186)
## 이고, 그 둘을 이은 선은 가로축에서 31.3도 기울어 있습니다. 벌린 입의
## 한가운데에서 그은 수직선이 아이의 얼굴로 가려면 그 선이 공격 축과
## 직각이어야 하므로, 90 - 31.3 = **58.7도**를 더 돌립니다.
const TIGER_MOUTH_TILT := 58.7   # 부호는 두 값을 찍어 골랐습니다(-58.7 은 입이 반대로 갑니다)


## 정면 얼굴 그림과, 어느 쪽을 쓸지.
##
## 옆얼굴과 정면은 **다른 그림**입니다 - 옆얼굴은 입에서 뻗어 나가는 모양이
## 되고, 정면은 아이 머리에서 얼굴이 솟아 앞으로 달려드는 모양이 됩니다.
## **기본은 정면**입니다. 내려다보는 화면에서 옆얼굴은 바닥에 누운 그림이라
## 무엇인지 알아보기 어렵고, 정면은 아이 앞에서 얼굴이 솟습니다.
## 옆얼굴은 `--tiger=side` 나 테스트 방의 「호랑이」 버튼으로 볼 수 있습니다.
const TIGER_FRONT_TEX := "res://assets/textures/tiger_front.png"
static var face_front := true


static func tiger(parent: Node3D, at: Vector3, dir: Vector3, reach: float,
		centered: bool = false) -> void:
	if face_front:
		tiger_front(parent, at, dir, reach, centered)
		return
	_tiger_side(parent, at, dir, reach)


static func tiger_front(parent: Node3D, at: Vector3, dir: Vector3,
		reach: float, centered: bool = false) -> void:
	## **정면 얼굴이 아이 자리에서 커졌다 사라집니다.**
	##
	## 옆얼굴과 달리 **모아 주지도, 돌리지도 않습니다.**
	##
	## 옆얼굴은 입에서 뻗어 나가는 그림이라 목이 아이 머리에서 모여야 하고
	## 시전 방향으로 누워야 합니다. 정면 얼굴은 그냥 **얼굴**입니다 - 어느
	## 쪽으로 지르든 같은 얼굴이 같은 자리에 뜨는 편이 낫습니다. 방향에 따라
	## 돌리면 얼굴이 옆으로 눕거나 거꾸로 서서, 정면으로 만든 뜻이 사라집니다.
	##
	## 그래서 바닥에 눕히되 **세계 축에 맞춥니다** - 귀가 늘 화면 위쪽입니다
	## (판의 V 축이 +Z 를 따라가고, 그림은 V=0 이 이마입니다).
	##
	## **자리는 아이가 아니라 때리는 자리입니다.** 아이 한가운데에 띄우면
	## 아이를 덮어 버리고, 무엇보다 그 얼굴이 어디를 치는 것인지 안 보입니다 -
	## 부채꼴 한가운데(사거리의 0.55배 앞)에 놓으면 맞는 자리와 겹칩니다.
	## 도는 것은 안 하고 **놓는 자리만** 방향을 씁니다.
	var shader: Shader = load(TIGER_SHADER)
	var tex: Texture2D = load(TIGER_FRONT_TEX)
	if shader == null or tex == null:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	# `centered` 면 앞으로 안 밀고 **준 자리 그대로** 놓습니다. 필살기의
	# 포효가 그렇습니다 - 부채꼴이 아니라 아이를 가운데 둔 원이라, 때리는
	# 자리가 곧 아이의 발밑입니다.
	var spot := at if centered else at + flat * (reach * TIGER_FRONT_AT)
	for i in 3:
		var span := reach * (0.80 + 0.08 * float(i))
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(span * TIGER_FRONT_ASPECT, span)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("tint", Color(RUSH_COLOR.r, RUSH_COLOR.g,
			RUSH_COLOR.b, 0.85 - 0.2 * float(i)))
		# 흐려지는 자리를 아예 두지 않습니다(1.0 = 끝까지 뚜렷).
		mat.set_shader_parameter("fade_start", 1.0)
		mat.set_shader_parameter("fade_axis", 1.0)
		mat.set_shader_parameter("neck_u", 1.0)
		mat.set_shader_parameter("flip_v", 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("flat", true)
		parent.add_child(mi)
		mi.global_position = spot
		var life := 0.34 + 0.06 * float(i)
		mi.scale = Vector3.ONE * 0.35
		var tw := mi.create_tween()
		tw.tween_interval(0.045 * float(i))
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE, life * 0.5) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "shader_parameter/tint:a", 0.0, life)
		tw.chain().tween_callback(mi.queue_free)


static func _tiger_side(parent: Node3D, at: Vector3, dir: Vector3, reach: float) -> void:
	## **호랑이 옆얼굴이 아이의 입에서 뻗어 나갑니다.**
	##
	## 3D 머리를 늘여 쓰다 그림 한 장으로 바꿨습니다 - 63도로 내려다보는
	## 카메라에서는 머리를 어떻게 굴려도 정수리에 가까워서, 벌린 입이
	## 안 보였습니다. 옆얼굴은 옆에서 봐야 옆얼굴입니다.
	##
	## 바닥에 눕혀 깝니다(고함 부채꼴과 같은 자리). 길이는 사거리에 맞추고,
	## **목 쪽은 흐려져 아이 머리에서 모이고 입 쪽은 뚜렷하게** 남습니다
	## (tiger_roar.gdshader).
	##
	## 석 장을 시차를 두고 겹칩니다 - 한 장이면 그림이고, 겹치면 잔상입니다.
	var shader: Shader = load(TIGER_SHADER)
	var tex: Texture2D = load(TIGER_TEX)
	if shader == null or tex == null:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	for i in 3:
		# 가로가 길이(입 -> 목), 세로가 얼굴 높이입니다.
		var span := reach * (0.92 + 0.06 * float(i))
		var mesh := _taper_quad(span, span * TIGER_ASPECT, TIGER_NECK)

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("tint", Color(RUSH_COLOR.r, RUSH_COLOR.g,
			RUSH_COLOR.b, 0.85 - 0.2 * float(i)))
		mat.set_shader_parameter("fade_start", TIGER_FADE)
		mat.set_shader_parameter("flip_v", TIGER_FLIP)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("flat", true)
		parent.add_child(mi)

		# 목이 아이 머리에 오도록 놓습니다. 판의 한가운데가 원점이므로
		# 앞으로 절반만큼 밀어 주면 목 끝이 아이 자리에 옵니다.
		mi.global_position = at + flat * (span * 0.5)
		mi.look_at(mi.global_position + flat, Vector3.UP)
		# 판은 XZ 평면에 눕혀 있고 가로가 X 입니다. `look_at` 은 -Z 를
		# 겨누므로, 가로축을 그쪽으로 돌려 세웁니다.
		mi.rotate_object_local(Vector3.UP, deg_to_rad(TIGER_YAW + TIGER_MOUTH_TILT))

		var life := 0.34 + 0.06 * float(i)
		var tw := mi.create_tween()
		tw.tween_interval(0.045 * float(i))
		tw.set_parallel(true)
		# 앞으로 조금 더 뻗으며 사라집니다.
		tw.tween_property(mi, "global_position",
			mi.global_position + flat * (reach * 0.12), life)
		tw.tween_property(mat, "shader_parameter/tint:a", 0.0, life)
		tw.chain().tween_callback(mi.queue_free)


static func _taper_quad(length: float, mouth_h: float, neck_h: float) -> ArrayMesh:
	## 입에서 **머리 끝까지는 원래 폭**, 그 뒤로만 좁아지는 판.
	##
	## 처음에는 입에서 목까지 곧바로 좁혔습니다. 그러면 **머리 윗통수와 목이
	## 시작하는 아래 윤곽까지 같이 눌려서** 호랑이가 납작해집니다 - 좁혀야
	## 하는 것은 머리가 아니라 그 뒤로 흐르는 목입니다.
	##
	## 어디까지가 머리인지는 그림에서 쟀습니다. 칼럼별 세로 두께가
	## U=0.4 에서 0.92, U=0.8 에서 0.94 로 그대로다가 U=0.9 에서 0.65,
	## U=1.0 에서 0.03 으로 떨어집니다 - 머리는 0.85 언저리에서 끝납니다.
	##
	## 판은 XZ 평면에 눕습니다(PlaneMesh 와 같은 규약). 가로가 X, 세로가 Z,
	## U 가 X 를 따라갑니다.
	var hx := length * 0.5
	var m := mouth_h * 0.5
	var n := neck_h * 0.5
	# 머리가 끝나는 자리의 X 와 U.
	var hu := TIGER_HEAD_END
	var hxx := -hx + length * hu
	var verts := PackedVector3Array([
		Vector3(-hx, 0.0, -m), Vector3(-hx, 0.0, m),      # 입 끝
		Vector3(hxx, 0.0, m), Vector3(hxx, 0.0, -m),      # 머리 끝(같은 폭)
		Vector3(hx, 0.0, n), Vector3(hx, 0.0, -n),        # 목 끝(좁힘)
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, 1.0),
		Vector2(hu, 1.0), Vector2(hu, 0.0),
		Vector2(1.0, 1.0), Vector2(1.0, 0.0),
	])
	var idx := PackedInt32Array([
		0, 1, 2, 0, 2, 3,     # 입 ~ 머리 끝
		3, 2, 4, 3, 4, 5,     # 머리 끝 ~ 목
	])
	var normals := PackedVector3Array()
	for _i in verts.size():
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _meshes_of(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			out.append(node)
		for c in node.get_children():
			stack.append(c)
	return out


static func orbs(parent: Node3D, at: Vector3, dir: Vector3, reach: float,
		count: int = 8, strong: bool = false) -> void:
	## **파란 구슬이 퍼져 나갔다 아지랑이처럼 사라집니다.** 고함에 붙습니다.
	##
	## 고리(파문)와 달리 구슬은 **날아가는 것**이라, 소리가 앞으로 밀려 나가는
	## 그림이 됩니다. 색은 구르기 잔상·미는 선과 같은 파랑입니다 - 세 기술이
	## 같은 힘에서 나온 것으로 읽히게.
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	for i in count:
		var mesh := SphereMesh.new()
		var r := randf_range(0.10, 0.20) * (1.4 if strong else 1.0)
		mesh.radius = r
		mesh.height = r * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(RUSH_COLOR.r, RUSH_COLOR.g, RUSH_COLOR.b, 0.75)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("flat", true)
		parent.add_child(mi)
		mi.global_position = at + Vector3.UP * randf_range(0.0, 0.25) 			+ side * randf_range(-0.25, 0.25)
		# 부채꼴 안쪽으로 흩어져 나갑니다.
		var spread := side * randf_range(-0.55, 0.55)
		var far: Vector3 = mi.global_position 			+ (flat + spread).normalized() * reach * randf_range(0.55, 1.0) 			+ Vector3.UP * randf_range(0.2, 0.7)
		var life := randf_range(0.30, 0.46)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", far, life) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# 사라질 때 부풀립니다 - 꺼지는 것이 아니라 **풀리는** 것으로 보입니다.
		tw.tween_property(mi, "scale", Vector3.ONE * 1.8, life)
		tw.tween_property(mat, "albedo_color:a", 0.0, life)
		tw.chain().tween_callback(mi.queue_free)


## 필살 모드 동안 몸을 두르는 **파란 기운**.
##
## 주인공 노드에 붙여 따라다니게 합니다 - 자리를 매 프레임 옮기면 빠르게
## 움직일 때 기운이 뒤에 처집니다.
static func aura(parent: Node3D, who: Node3D) -> Node3D:
	var holder := Node3D.new()
	who.add_child(holder)
	holder.position = Vector3(0, 0.6, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.85
	mesh.height = 1.9
	mesh.radial_segments = 18
	mesh.rings = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(RUSH_COLOR.r, RUSH_COLOR.g, RUSH_COLOR.b, 0.20)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# 안쪽 면을 그립니다. 바깥 면을 그리면 몸이 파란 공 속에 갇혀 안 보입니다.
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("flat", true)
	holder.add_child(mi)
	# 숨쉬듯 부풉니다. 가만있으면 붙여 놓은 공으로 보입니다.
	var tw := holder.create_tween().set_loops()
	tw.tween_property(holder, "scale", Vector3.ONE * 1.12, 0.45)
	tw.tween_property(holder, "scale", Vector3.ONE * 0.96, 0.45)
	return holder


## 몸 모양 그대로의 잔상 한 장. 구르기·필살기가 같이 씁니다.
##
## 스킨 메시는 뼈대를 따라 그려지므로 메시만 복제하면 살아 있는 뼈대를 따라와
## 제자리에 겹칩니다. **뼈대까지 통째로** 복제하고 애니메이션을 떼어 그 자세
## 에서 멈춰 세웁니다(한 장에 1.7~2.1ms).
static func body_ghost(parent: Node3D, body: Node3D, tone: Color,
		alpha: float = 0.5) -> void:
	ghost_at(parent, body, body.global_position, tone, alpha)


static func ghost_at(parent: Node3D, body: Node3D, at: Vector3, tone: Color,
		alpha: float = 0.5) -> void:
	if body == null or parent == null:
		return
	var ghost := body.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	if ghost == null:
		return
	for node in _all(ghost):
		if node is AnimationPlayer or node is SkeletonModifier3D:
			node.queue_free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tone.r, tone.g, tone.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node in _all(ghost):
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("flat", true)
	parent.add_child(ghost)
	ghost.global_position = at
	ghost.scale = body.global_transform.basis.get_scale()
	var tw := ghost.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tw.tween_callback(ghost.queue_free)


static func _all(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out.append_array(_all(c))
	return out


static func shout_fan(parent: Node3D, at: Vector3, dir: Vector3,
		radius: float, arc_deg: float) -> void:
	## 주인공이 지른 **그 순간의 판정 범위**를 바닥에 칠합니다.
	##
	## 퍼져 나가는 고리 셋을 걷어낸 자리입니다. 고리는 "소리가 퍼진다" 는
	## 그림으로는 좋았지만 **어디까지 닿는지**를 못 가르쳤습니다 - 테두리는
	## 선 위가 위험한 것처럼 읽히고, 셋이 시차를 두고 나가니 어느 고리가
	## 사거리인지도 알 수 없었습니다. 적의 호통이 이미 칠한 부채꼴을 쓰고
	## 있어서(enemy.gd), 같은 그림을 같은 뜻으로 쓰면 배울 것이 하나로
	## 줄어듭니다.
	##
	## 크기와 각도를 **판정에서 그대로 받습니다.** 여기서 숫자를 따로 정하면
	## 사거리를 고쳤을 때 그림만 옛날 값으로 남습니다.
	if parent == null:
		return
	var fan := MeshInstance3D.new()
	fan.mesh = fan_mesh(radius, arc_deg)
	var mat := fan_material()
	mat.albedo_color = Color(1.0, 0.90, 0.55, 0.34)
	fan.material_override = mat
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 카툰 외곽선이 바닥 판을 두르면 판이 아니라 구멍이 됩니다.
	fan.set_meta("flat", true)
	parent.add_child(fan)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	fan.global_position = at + Vector3(0, 0.05, 0)
	fan.rotation.y = atan2(-flat.x, -flat.z)
	# 번쩍 떴다 스러집니다. 남아 있으면 다음에 지를 때 겹쳐서, 몇 번을
	# 질렀는지가 바닥에 쌓입니다.
	var tw := fan.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tw.tween_callback(fan.queue_free)


static func lane_mesh(length: float, width: float) -> ArrayMesh:
	## 바닥에 까는 **띠**. 돌진이 지나갈 길을 그대로 칠합니다.
	##
	## 부채꼴(`fan_mesh`)과 같은 규약입니다 - 앞은 -Z 이고, 부르는 쪽에서
	## yaw 만 맞추면 됩니다. 시작은 원점(적의 발밑)입니다.
	var hw := width * 0.5
	var verts := PackedVector3Array([
		Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0),
		Vector3(hw, 0.0, -length), Vector3(-hw, 0.0, -length),
	])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func fan_mesh(radius: float, arc_deg: float, steps: int = 20) -> ArrayMesh:
	## 바닥에 까는 **부채꼴 판**. 공격이 실제로 닿는 범위를 그대로 칠합니다.
	##
	## 고리(테두리)로 그리던 것을 판으로 바꿨습니다. 테두리는 "이 선 위가
	## 위험" 처럼 읽혀서, 선 사이의 빈 곳이 안전해 보입니다 - 실제로는 부채꼴
	## 안쪽이 전부 판정 범위입니다. 칠하면 그 오해가 없습니다.
	##
	## 앞은 -Z 입니다(Godot 관습). 부르는 쪽에서 yaw 만 맞추면 됩니다.
	var half := deg_to_rad(arc_deg) * 0.5
	var verts := PackedVector3Array()
	verts.append(Vector3.ZERO)
	for i in range(steps + 1):
		var a2 := lerpf(-half, half, float(i) / float(steps))
		verts.append(Vector3(sin(a2) * radius, 0.0, -cos(a2) * radius))
	var idx := PackedInt32Array()
	for i in range(1, steps + 1):
		idx.append(0)
		idx.append(i)
		idx.append(i + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func fan_material() -> StandardMaterial3D:
	## 바닥 판에 쓰는 재질. 빛을 안 받고, 깊이를 안 쓰고, 양면입니다.
	##
	## 깊이를 쓰면(depth_draw) 바닥과 다투어 지지직거리고, 양면이 아니면
	## 감는 방향을 틀렸을 때 통째로 안 보입니다 - 납작한 판에 감는 방향을
	## 맞추느라 시간을 쓸 이유가 없습니다.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	return mat


static func _ring_mesh() -> TorusMesh:
	if _cached_ring == null:
		var m := TorusMesh.new()
		m.inner_radius = 0.86
		m.outer_radius = 1.0
		m.rings = 24
		_cached_ring = m
	return _cached_ring


static func _shard_mesh() -> BoxMesh:
	if _cached_shard == null:
		var m := BoxMesh.new()
		m.size = Vector3(0.11, 0.11, 0.11)
		_cached_shard = m
	return _cached_shard


static func ring(parent: Node3D, at: Vector3, color: Color, radius: float = 2.0,
		time: float = 0.35) -> void:
	## 바닥에 퍼지는 고리. 폭발/착지/처치 같은 순간의 위치를 알려 줍니다.
	if not is_instance_valid(parent):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = at + Vector3(0, 0.08, 0)
	mi.scale = Vector3(0.2, 0.2, 0.2)
	parent.add_child(mi)
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 0.4, radius), time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, time)
	tween.chain().tween_callback(mi.queue_free)


static func burst(parent: Node3D, at: Vector3, color: Color, count: int = 12,
		speed: float = 4.0) -> void:
	## 조각이 튀는 효과. 파티클 시스템을 쓰지 않는 이유는 한 번 쓰고 버리는
	## 소량이라 노드 몇 개가 더 싸고 제어가 쉽기 때문입니다.
	if not is_instance_valid(parent):
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mesh := _shard_mesh()
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = at
		parent.add_child(mi)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		var target := at + dir * speed * randf_range(0.3, 0.7)
		target.y = maxf(0.15, target.y)
		var tween := mi.create_tween()
		tween.set_parallel(true)
		tween.tween_property(mi, "position", target, 0.45) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(mi, "scale", Vector3.ZERO, 0.45)
		tween.chain().tween_callback(mi.queue_free)
