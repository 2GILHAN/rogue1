class_name Models
extends RefCounted

## test3(img2model) 카탈로그가 낸 GLB 를 게임에서 쓸 수 있게 손봅니다.
##
## 두 가지 규약 차이를 여기서 흡수합니다. 다른 곳은 전부 Godot 규약
## (Y 가 위, -Z 가 앞)으로만 씁니다.
##
##   1. 위쪽 축. 이 GLB 들은 머리가 -Z, 발이 0 입니다(실측: AABB z 가
##      -1.5~0). X 를 +90도 돌리면 -Z 가 +Y 로 가서 똑바로 섭니다.
##   2. 앞쪽 축. 세우고 나면 모델의 앞이 Godot 의 앞(-Z)과 어긋날 수
##      있어, 아래 값으로 맞춥니다.
##
## 두 회전을 노드 하나에 몰면 오일러 적용 순서(Godot 기본 YXZ)에 걸려
## 결과가 헷갈립니다. 그래서 바깥 노드가 방향, 안쪽 노드가 세우기를 맡습니다.
const MODEL_PITCH := PI / 2.0
## 실측: 세우고 나면 모델의 앞이 +Z 입니다. Godot 의 앞은 -Z 라 180도 돌립니다.
const MODEL_YAW := PI

const HERO := "res://assets/characters/hero.glb"
## 이전 주인공. 되돌리려면 위 HERO 를 이 값으로 바꾸면 됩니다.
const DOWON := "res://art_src/unused/dowon.glb"
## 적으로 쓰는 아이들. **이름은 하는 일에서 옵니다** - 파일도 상수도 같은 말을
## 씁니다(`foe_charger.glb` / `FOE_CHARGER`).
##
## 예전에는 사람 이름(`seojin`)과 색 이름(`black`)이었습니다. 무엇을 하는
## 적인지가 이름에 없어서 코드를 열어 봐야 했고, 무엇보다 **남의 이름이 게임
## 파일에 그대로 실려 나갔습니다.**
const FOE_CHARGER := "res://assets/characters/foe_charger.glb"
const FOE_THROWER := "res://assets/characters/foe_thrower.glb"
## 새로 들어온 적 셋. 전부 원본이 0.72~0.75m 로 작게 나와서 SIZE 에 배율을
## 적어 둡니다(주인공과 같은 사정).
const FOE_BLOCKER := "res://assets/characters/foe_blocker.glb"
const FOE_SHOUTER := "res://assets/characters/foe_shouter.glb"
const FOE_CLINGER := "res://assets/characters/foe_clinger.glb"
## 선생님. 유일한 어른이라 키가 1.65m 로 아이들(1.25m)보다 확연히 큽니다.
const BOSS_TEACHER := "res://assets/characters/boss_teacher.glb"
## 물물교환하는 여자아이. **어린이집에도 아군은 있습니다.**
##
## 예전 상인(npc_shopkeeper)은 어른이었습니다. 이 게임의 적이 전부 또래
## 아이들인데 도와주는 쪽만 어른이면, 아이들 사이의 일이라는 것이 흐려집니다.
const SHOPKEEPER := "res://assets/characters/npc_trader.glb"
## 안 쓰는 이전 에셋. `art_src/unused/` 에 있어 **빌드에 안 들어갑니다** -
## 되돌리고 싶으면 `assets/characters/` 로 옮기고 여기 경로를 고칩니다.
const HERO_EMBERLING := "res://art_src/unused/hero_emberling.glb"
const ENEMY_SPROUT := "res://art_src/unused/enemy_sprout.glb"

## 카탈로그 asset.json 의 collider 값. 캡슐 충돌체를 메시에 맞추는 데 씁니다.
## 모델을 갈아 끼울 때 여기 항목을 빠뜨리기 쉬워서, 읽기는 size_of() 로만 합니다.
const SIZE := {
	# 도원: 키 1.25m 의 아이. 실측 폭 0.94 는 A 포즈로 벌린 팔까지 포함한 값이라
	# 그대로 반지름으로 쓰면 복도를 못 지나갑니다. 몸통 기준으로 잡습니다.
	# 새 주인공은 원본이 0.85m 로 작게 나왔습니다. 게임 안에서의 크기는
	# 예전과 같아야 하므로(1.25m) 메시만 1.47배로 키웁니다 - 충돌체와
	# 사거리 같은 규칙 값은 height 를 그대로 쓰니 건드릴 것이 없습니다.
	HERO: {"height": 1.25, "radius": 0.24, "scale": 1.25 / 0.85},
	DOWON: {"height": 1.25, "radius": 0.24},
	FOE_CHARGER: {"height": 1.25, "radius": 0.25},
	FOE_THROWER: {"height": 1.25, "radius": 0.25},
	# 새 주인공과 같은 사정입니다 - 원본이 0.715m 로 작게 나와, 게임 안에서
	# 다른 아이들과 같은 키(1.25m)로 서도록 메시만 키웁니다. 규칙 값(충돌체·
	# 사거리)은 height 를 그대로 쓰므로 여기만 고치면 됩니다.
	FOE_BLOCKER: {"height": 1.25, "radius": 0.25, "scale": 1.25 / 0.715},
	FOE_SHOUTER: {"height": 1.25, "radius": 0.25, "scale": 1.25 / 0.728},
	FOE_CLINGER: {"height": 1.25, "radius": 0.25, "scale": 1.25 / 0.754},
	BOSS_TEACHER: {"height": 1.65, "radius": 0.30},
	# 다른 아이들과 **화면에서 같은 키**(1.25m)로 세웁니다.
	#
	# 0.76 으로 적어 뒀다가 겉보기 1.59m 가 됐습니다(주인공 1.25). 0.76 은
	# GLB 접근자의 min/max 를 읽은 값인데 그 숫자는 **노드 변환을 안 셉니다** -
	# 모델 안에서 한 번 더 키워 놓았으면 그려지는 크기와 다릅니다.
	#
	# 0.967 은 **화면에서 잰 값**입니다(`--pose=balance` 의 `[아이]` 줄).
	# 원본을 다시 구우면 그 줄을 보고 이 값을 고칩니다.
	#
	# **모자를 포함해 맞춥니다.** 뼈로만 보면 몸은 이미 주인공과 거의 같지만
	# (발~머리뼈 0.955 대 0.924), 모자가 머리뼈 위로 0.58m 올라가서 - 주인공은
	# 0.33m 입니다 - 나란히 서면 이 아이만 커 보입니다. 눈에 보이는 것은
	# 실루엣이라 그쪽을 맞춥니다.
	SHOPKEEPER: {"height": 1.25, "radius": 0.40, "scale": 1.25 / 0.967},
	HERO_EMBERLING: {"height": 1.5, "radius": 0.43},
	ENEMY_SPROUT: {"height": 1.1, "radius": 0.42},
}


static func size_of(path: String) -> Dictionary:
	## 등록되지 않은 모델이면 사람 크기로 가정합니다. 충돌체가 조금 안 맞는 것은
	## 눈에 잘 안 띄지만, 여기서 멈추면 게임이 아예 안 뜹니다.
	if SIZE.has(path):
		return SIZE[path]
	push_warning("모델 치수가 등록되지 않았습니다: %s" % path)
	return {"height": 1.5, "radius": 0.4}


static func spawn(path: String, scale_mult: float = 1.0) -> Node3D:
	## SIZE 에 scale 이 적혀 있으면 함께 곱합니다. 원본 크기가 제각각인 모델을
	## 게임 안에서 같은 키로 세우기 위한 것이고, 부르는 쪽은 몰라도 됩니다.
	scale_mult *= float(size_of(path).get("scale", 1.0))
	var holder := Node3D.new()
	holder.name = "Model"
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("모델을 불러오지 못했습니다: %s" % path)
		return holder
	var node: Node3D = packed.instantiate()
	node.rotation = Vector3(MODEL_PITCH, 0.0, 0.0)
	holder.rotation = Vector3(0.0, MODEL_YAW, 0.0)
	holder.scale = Vector3.ONE * scale_mult
	holder.add_child(node)
	_make_loops(node)
	return holder


static func find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := find_anim(c)
		if found != null:
			return found
	return null


static func _make_loops(node: Node) -> void:
	## 걷기와 대기는 주기 동작인데 glTF 는 반복 여부를 담지 않습니다.
	## 여기서 켜 두지 않으면 한 번 재생하고 얼어붙습니다.
	var ap := find_anim(node)
	if ap == null:
		return
	for name in ap.get_animation_list():
		# 한 번 재생하고 끝나는 동작(밀기)은 반복시키면 안 됩니다. 계속 밀고
		# 있는 것처럼 보입니다.
		if String(name).to_lower().contains("push"):
			continue
		var anim := ap.get_animation(name)
		if anim != null and anim.loop_mode == Animation.LOOP_NONE:
			anim.loop_mode = Animation.LOOP_LINEAR


static func clip(ap: AnimationPlayer, wanted: String) -> String:
	## 익스포터에 따라 "Walk" 가 "Armature|Walk" 처럼 나오기도 합니다.
	## 이름을 정확히 알 수 없으니 부분 일치로 찾습니다.
	if ap == null:
		return ""
	var names := ap.get_animation_list()
	for n in names:
		if n == wanted:
			return n
	var low := wanted.to_lower()
	for n in names:
		if String(n).to_lower().contains(low):
			return n
	return names[0] if names.size() > 0 else ""


static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var found := find_skeleton(c)
		if found != null:
			return found
	return null


static func add_jiggle(model_root: Node3D,
		prefixes: Array = ["hair_", "skirt_"]) -> Jiggle:
	## 흔들림 체인을 붙입니다. 스켈레톤이 없거나 해당 본이 없으면 조용히
	## 넘어갑니다 - 모델마다 체인이 있을 수도, 없을 수도 있습니다.
	##
	## 치마까지 넣는 이유: 서진과 블랙은 원피스라 test3 가 치마 체인을 8개
	## 더 만들어 뒀습니다(도원은 머리카락 6개뿐). 걸을 때 치맛단이 따라
	## 흔들리는 것이 이 캐릭터들에서는 가장 눈에 띄는 움직임입니다.
	var skel := find_skeleton(model_root)
	if skel == null:
		return null
	var j := Jiggle.new()
	j.name = "Jiggle"
	j.prefixes = prefixes
	skel.add_child(j)
	return j


static func add_shadow(parent: Node3D, radius: float) -> MeshInstance3D:
	## 발밑에 까는 **가짜 그림자**. 캐릭터가 바닥에 붙어 있는 것으로 보이게
	## 하는 것이 전부입니다.
	##
	## 왜 해 그림자로 안 하는가: 폰과 웹(Compatibility 렌더러)에서는 방향광의
	## 그림자를 끄고 있습니다 - 화면 전체를 한 번 더 그리는 작업이라 폰에서
	## 프레임을 가장 많이 먹습니다. 켠다 해도 해가 비스듬해서 그림자가 발이
	## 아니라 옆에 눕습니다. 발밑에 있어야 "여기 서 있다" 가 됩니다.
	##
	## 가운데가 진하고 가장자리로 갈수록 사라지는 원 하나입니다. 사각형이
	## 그대로 보이면 종이를 깔아 둔 것처럼 보이므로 방사형 그라디언트를 씁니다.
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.46))
	g.set_color(1, Color(0, 0, 0, 0.0))
	# 가운데의 진한 부분을 조금 넓게 둡니다. 바로 옅어지면 얼룩처럼 보입니다.
	g.add_point(0.55, Color(0, 0, 0, 0.30))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 곱하기 합성을 쓰면 안 됩니다. 알파가 0 인 자리도 **색은 검정**이라
	# 그대로 곱해져서, 부드러운 원이 아니라 검은 사각형이 깔립니다
	# (실제로 그렇게 나왔습니다). 보통 알파 합성으로 검정을 옅게 얹습니다.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(0, 0, 0, 1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 바닥과 겹쳐 깜빡이지 않게 살짝 띄우고, 깊이는 쓰되 쓰지는 않습니다.
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)

	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = quad
	mi.material_override = mat
	mi.rotation_degrees.x = -90.0        # 눕힙니다
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 카툰 옵션이 외곽선을 두르지 않게 표시해 둡니다. 그림자에 검은 테두리가
	# 생기면 발밑에 접시를 깔아 둔 것이 됩니다.
	mi.set_meta("flat", true)
	parent.add_child(mi)
	return mi


static func add_anchor(model_root: Node3D, bone: String) -> BoneAttachment3D:
	## 본을 따라다니는 빈 노드. **자세 층이 적용된 뒤의** 위치를 읽으려면
	## 이것이 필요합니다.
	##
	## `Skeleton3D.get_bone_global_pose()` 는 SkeletonModifier3D 가 손대기
	## 전의 포즈를 돌려줍니다. 그걸로 손 위치를 읽으면, 팔을 앞으로 뻗는
	## 자세를 걸어 놓고도 손은 몸 옆에 있는 것으로 계산됩니다.
	var skel := find_skeleton(model_root)
	if skel == null or skel.find_bone(bone) < 0:
		return null
	var a := BoneAttachment3D.new()
	a.name = "Anchor_" + bone
	a.bone_name = bone
	skel.add_child(a)
	return a


static func add_pose(model_root: Node3D) -> PoseOverride:
	## 클립 위에 자세를 덮어씌우는 층(pose_override.gd). Jiggle 뒤에 붙습니다 -
	## 서로 다른 본을 건드리므로 순서는 상관없지만, 사람 몸을 먼저 정하고
	## 머리카락이 그 위에서 흔들리는 편이 읽기 쉽습니다.
	var skel := find_skeleton(model_root)
	if skel == null:
		return null
	var po := PoseOverride.new()
	po.name = "PoseOverride"
	skel.add_child(po)
	return po


static func tint(root: Node3D, color: Color, strength: float = 0.55) -> void:
	## 같은 메시로 다른 종류를 만들기 위한 색조. 적 세 종류가 한 모델에서
	## 나오므로, 무엇에게 맞고 있는지 색으로 구분되어야 합니다.
	var meshes: Array[MeshInstance3D] = []
	_collect(root, meshes)
	for m in meshes:
		var overlay := StandardMaterial3D.new()
		overlay.albedo_color = Color(color.r, color.g, color.b, strength)
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.material_overlay = overlay


static func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)
