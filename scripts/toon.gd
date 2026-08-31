class_name Toon
extends RefCounted

## 카툰 렌더링 옵션. 켜고 끄는 것이 전부입니다.
##
## # 무엇이 "카툰"을 만드는가
##
## 세 가지를 같이 겁니다. 하나만 해서는 잘 안 됩니다.
##
##   1. **외곽선.** 만화처럼 보이게 하는 것의 대부분입니다. 메시를 법선 방향으로
##      살짝 부풀린 뒤 앞면을 잘라 내고 검게 칠하면(inverted hull), 뒤집힌
##      껍데기의 가장자리만 원본 밖으로 삐져나와 선이 됩니다.
##   2. **띠 진 명암.** `DIFFUSE_TOON` 이 밝기를 계단으로 끊습니다. 부드러운
##      그라데이션이 사라지면서 색면으로 읽힙니다.
##   3. **후처리 걷어내기.** 안개와 글로우는 사진처럼 보이게 하는 장치라,
##      카툰에서는 오히려 방해가 됩니다.
##
## # 왜 외곽선을 던전에는 안 거는가
##
## 던전 바닥과 벽은 층 전체가 **메시 하나**입니다. 부풀린 껍데기를 씌우면
## 방 하나만 한 검은 덩어리가 카메라를 덮습니다. 그래서 외곽선은 사람과
## 소품처럼 덩어리가 작고 실루엣이 중요한 것에만 겁니다.

const OUTLINE_COLOR := Color(0.06, 0.05, 0.06)
## 부풀리는 정도(m). 이 값은 **머리카락이 정합니다.**
##
## 머리카락은 가느다란 가닥이라, 크게 부풀리면 가닥 사이가 메워져 머리가
## 검은 덩어리가 됩니다(0.018 에서 실제로 그랬습니다). 0.011 이면 실루엣은
## 잡히면서 가닥이 남습니다.
const OUTLINE_GROW := 0.011

## 원래 값. 끌 때 그대로 되돌려 놓습니다 - 재질은 GLB 에서 온 공유
## 자원이라 되돌리지 않으면 옵션을 꺼도 카툰인 채로 남습니다.
static var _saved: Dictionary = {}
static var _env_saved: Dictionary = {}
static var enabled := false


static func apply(root: Node, env: Environment, on: bool) -> void:
	enabled = on
	_apply_world(root, on)
	_apply_env(env, on)
	if not on:
		# 끌 때는 기억해 둔 것을 통째로 비웁니다. 층이 바뀌면 그 층의 바닥·벽
		# 재질은 사라지는데, 그 항목이 남아 있으면 계속 쌓이기만 합니다.
		_saved.clear()


static func refresh(root: Node) -> void:
	## 층이 새로 만들어지면 새 메시들에도 다시 걸어 줍니다.
	##
	## **판이 도는 중에 생긴 것에도 불러 줘야 합니다.** 테스트 방은 적을
	## 계속 새로 내보내는데, 층을 지을 때 한 번만 걸어 두면 그 뒤에 나온
	## 적들만 **테두리 없이** 남습니다 - 주인공은 카툰인데 적은 아닌 화면이
	## 그것입니다. 노드 하나를 넘겨도 됩니다(그 아래만 훑습니다).
	if enabled:
		_apply_world(root, true)


# ---------------------------------------------------------------- 재질

static func _apply_world(root: Node, on: bool) -> void:
	if root == null:
		return
	for entry in _collect(root):
		var mesh: MeshInstance3D = entry[0]
		var outline_wanted: bool = entry[1]
		for i in mesh.get_surface_override_material_count():
			var mat := mesh.get_active_material(i)
			if mat != null:
				_set_material(mat, on, outline_wanted)
		if mesh.material_override != null:
			_set_material(mesh.material_override, on, outline_wanted)


static func _set_material(mat: Material, on: bool, outline: bool) -> void:
	## **`BaseMaterial3D` 만이 아니라 아무 재질이나 받습니다.**
	##
	## 예전에는 `BaseMaterial3D` 가 아니면 통째로 건너뛰었습니다. 벽에 걸린
	## 소품(시계·액자·책장)이 캐릭터를 가릴 때 비치도록 셰이더 재질로 바꾸면서,
	## 그것들만 **카툰이 아닌 채로** 남았습니다 - 외곽선도 없고 명암도 부드러워
	## 다른 그림에서 오려 붙인 것처럼 보입니다.
	##
	## 띠 진 명암(`DIFFUSE_TOON`)은 붙박이 재질의 값이라 셰이더 재질에는 걸 수
	## 없습니다. 하지만 **외곽선은 걸 수 있습니다** - `next_pass` 는 모든
	## 재질에 있습니다. 그리고 카툰으로 보이게 하는 것의 대부분이 외곽선입니다.
	var id := mat.get_instance_id()
	var base := mat as BaseMaterial3D
	if on:
		if not _saved.has(id):
			_saved[id] = {
				"diffuse": base.diffuse_mode if base != null else 0,
				"specular": base.specular_mode if base != null else 0,
				"next": mat.next_pass,
			}
		if base != null:
			base.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			base.specular_mode = BaseMaterial3D.SPECULAR_TOON
		var outlined := mat.next_pass is BaseMaterial3D 			and (mat.next_pass as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_FRONT
		if outline and not outlined:
			mat.next_pass = _outline_material()
	elif _saved.has(id):
		var old: Dictionary = _saved[id]
		if base != null:
			base.diffuse_mode = old["diffuse"]
			base.specular_mode = old["specular"]
		mat.next_pass = old["next"]
		_saved.erase(id)


static var _outline: StandardMaterial3D = null


static func _outline_material() -> StandardMaterial3D:
	## 하나를 만들어 돌려씁니다. 재질마다 새로 만들면 셰이더 변형이 그만큼
	## 늘어나 처음 켤 때 화면이 멈춥니다.
	if _outline == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = OUTLINE_COLOR
		# 앞면을 잘라 내고 부풀립니다. 뒷면만 남아 원본 밖으로 삐져나온
		# 가장자리가 선이 됩니다.
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = OUTLINE_GROW
		m.disable_receive_shadows = true
		m.no_depth_test = false
		_outline = m
	return _outline


static func _collect(root: Node) -> Array:
	## [메시, 외곽선을 걸까] 목록. 사람과 소품에만 외곽선을 겁니다.
	var out: Array = []
	var stack: Array = [[root, false]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var inside_body: bool = entry[1]
		# CharacterBody3D(사람)와 RigidBody3D(소품) 아래면 덩어리가 작습니다.
		# 상인도 외곽선을 답니다. `Node3D` 라 몸체 검사에 안 걸려서 **혼자
		# 카툰이 아니었습니다** - 서 있기만 하는 사람이라 물리 몸체가 필요
		# 없었을 뿐, 화면에서는 다른 아이들과 같은 사람입니다.
		var body := inside_body or node is CharacterBody3D or node is RigidBody3D 			or node is Shopkeeper
		if node is MeshInstance3D and not node.has_meta("flat"):
			out.append([node, body])
		for c in node.get_children():
			stack.append([c, body])
	return out


# ---------------------------------------------------------------- 환경

static func _apply_env(env: Environment, on: bool) -> void:
	if env == null:
		return
	if on:
		if _env_saved.is_empty():
			_env_saved = {
				"fog": env.fog_enabled,
				"glow": env.glow_enabled,
				"tonemap": env.tonemap_mode,
				"white": env.tonemap_white,
				"ambient": env.ambient_light_energy,
			}
		# 안개와 글로우는 사진처럼 보이게 하는 장치라 카툰에서는 뺍니다.
		env.fog_enabled = false
		env.glow_enabled = false
		# 톤매핑도 선형으로. ACES 는 밝은 쪽을 부드럽게 눕히는데, 그러면
		# 색면이 다시 그라데이션으로 번집니다.
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		# 1.0 으로 두면 방 안의 등(2.0) 이 그대로 흰색으로 잘려서 캐릭터가
		# 흰 덩어리가 됩니다. 조금 올려 밝은 쪽에 여유를 둡니다.
		env.tonemap_white = 1.35
		# 그림자 쪽이 검게 죽지 않도록 환경광을 조금 올립니다.
		# 환경광을 너무 올리면 DIFFUSE_TOON 의 띠가 안 보입니다. 명암 대비가
		# 있어야 계단이 생기므로, 그림자가 죽지 않을 만큼만 올립니다.
		env.ambient_light_energy = 0.9
	elif not _env_saved.is_empty():
		env.fog_enabled = _env_saved["fog"]
		env.glow_enabled = _env_saved["glow"]
		env.tonemap_mode = _env_saved["tonemap"]
		env.tonemap_white = _env_saved["white"]
		env.ambient_light_energy = _env_saved["ambient"]
		_env_saved.clear()
