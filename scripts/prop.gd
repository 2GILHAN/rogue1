class_name Prop
extends RigidBody3D

## 보육원 소품. 집어 던지거나 밀 수 있습니다.
##
## # 왜 RigidBody3D 인가
##
## 던진 물건은 굴러야 합니다. 직접 적분하면 벽 튕김과 회전을 다 짜야 하는데,
## 물리 몸체에 맡기면 공짜로 됩니다. 대신 **피해 판정은 물리 접촉이 아니라
## 거리로** 봅니다 - 접촉 신호는 한 프레임에 여러 번 오거나 아예 안 오기도
## 해서, 같은 적을 두 번 때리거나 스쳐 지나가는 일이 생깁니다.
##
## # 사람과의 충돌은 한쪽 방향으로만
##
## 소품이 사람을 밀 수 있으면 발밑에 굴러온 인형이 플레이어를 벽으로 밀어
## 넣습니다. 그래서 **사람이 소품을 미는 방향만** 둡니다 - 소품의 마스크에는
## 사람이 없고, 대신 사람 쪽이 부딪히면서 충격을 넣어 줍니다.

signal picked_up(prop: Prop)

## 손에 들었을 때 손에서 얼마나 떨어져 있을지(m). 손 위치를 그대로 쓰면
## 소품 중심이 손과 겹쳐 손이 물건 속에 파묻힙니다.
const HAND_CLEAR := 0.12
## 던지는 거리는 **크기가 정합니다.** 작은 것은 멀리, 큰 것은 가깝게.
##
## 기준점 둘로 곡선을 맞췄습니다 - 1층 적(키 1.25m)은 그 키의 두 배인 2.5m,
## 가장 작은 소품(0.15m)은 한 화면쯤인 10m 입니다. 두 점을 지나는 거듭제곱
## 곡선의 지수가 0.654 입니다.
##
##     거리 = 2.5 * (1.25 / 크기) ^ 0.654
##
## 크기는 가로세로높이의 세제곱근(부피의 한 변)입니다. 가장 긴 변으로 재면
## 납작한 담요가 기차보다 크게 잡혀서, 덩치와 상관없이 안 날아갑니다.
const THROW_REF_SIZE := 1.25
const THROW_REF_DIST := 2.5
const THROW_SIZE_POWER := 0.654
## 아주 작은 것이 화면 밖으로 날아가지 않도록.
const THROW_MAX_DIST := 11.0

## 거리는 속도가 아니라 **체공 시간**으로 만듭니다. 수평으로 빠르게 쏘면
## 총알처럼 보이므로, 위로 크게 띄우고 수평 속도만 거리에 맞춥니다.
##
## 재서 얻은 환산: 띄우는 높이를 2.6 으로 두면 1초쯤 떠 있어서, 수평 속도
## 1 당 대략 1.22m 를 갑니다.
const THROW_SPEED_PER_M := 0.817
const THROW_LIFT := 2.6
const PUSH_SPEED := 6.5
## 이 속도 아래로 떨어지면 더 이상 아프지 않습니다.
##
## 3.0 이었을 때는 **던진 것이 거의 안 아팠습니다.** 비거리를 크기로 정하면서
## 수평 속도가 2~8 로 내려왔는데(예전에는 9 고정), 감쇠까지 걸려서 날아가는
## 도중에 문턱 아래로 떨어졌습니다. 던져서 맞히면 아파야 합니다.
const HURT_SPEED := 1.2
## 다 쓴 자동차가 연기를 뿜는 주기(초). 잦으면 불난 것으로 보이고, 뜸하면
## 무엇이 달라졌는지 모릅니다.
const SMOKE_EVERY := 0.55

## 소품마다 성격이 다릅니다. 무거운 것은 못 들고 밀기만 합니다.
##
##   light  단단한 장난감. 잘 날아가고 제일 아픕니다.
##   soft   인형·쿠션·담요. 덜 아픈 대신 맞은 적이 잠깐 멈춥니다.
##   heavy  가구. 들 수 없고, 밀어서 굴리면 지나가는 적을 칩니다.
##
## 비거리는 여기 적지 않습니다. **크기에서 나옵니다**(throw_size) - 손으로
## 적어 두면 모델을 바꿨을 때 반드시 어긋납니다. 예전에는 fly 라는 배수를
## 종류마다 적어 뒀는데, 담요가 기차보다 크다는 사실과 따로 놀았습니다.
## 여기 남은 것은 크기로 알 수 없는 것들뿐입니다 -
## 무엇을 집을지가 "무엇을 하고 싶은지" 로 갈리게 하는 값입니다.
const KINDS := {
	"daycare_traintoy":    {"class": "light", "damage": 1.10, "stun": 0.0, "lay": true},
	"daycare_shiptoy":     {"class": "light", "damage": 1.00, "stun": 0.0, "lay": true},
	"daycare_pandatoy":    {"class": "soft",  "damage": 0.55, "stun": 0.9, "lay": true},
	"daycare_starcushion": {"class": "soft",  "damage": 0.45, "stun": 1.1},
	"daycare_blanket":     {"class": "soft",  "damage": 0.25, "stun": 1.6, "lay": true},
	"daycare_leafbedding": {"class": "soft",  "damage": 0.25, "stun": 1.4, "lay": true},
	"daycare_kidchair":    {"class": "heavy", "damage": 1.35, "stun": 0.3},
	"daycare_toybox":      {"class": "heavy", "damage": 1.50, "stun": 0.4},
	"daycare_catbusbed":   {"class": "heavy", "damage": 1.25, "stun": 0.5},

	# 우유. **던지는 물건이 아니라 마시는 물건입니다.**
	#
	# `heal` 이 있으면 잡기가 집기가 아니라 마시기가 됩니다. 다른 소품과 같은
	# 강체로 두는 이유는 그래야 바닥에 굴러다니고, 밀리고, 적이 던진 것에
	# 맞아 굴러가기 때문입니다 - 눈에 띄는 자리에 놓이는 것이 아니라 방에
	# 섞여 있어야 찾는 재미가 됩니다.
	# 원본이 11cm 라 바닥에 놓으면 무엇인지 알아볼 수 없었습니다. 4배(44cm)는
	# 알아보기는 쉬웠지만 아이 키(0.85m)의 절반이라 들면 머리를 가렸습니다.
	# 2.4배(26cm)가 그 사이입니다 - 갑 모양은 남고 손에 들 만합니다.
	"milk": {"class": "light", "damage": 0.30, "stun": 0.0, "heal": 25.0,
		"scale": 2.4, "lure": "맛있는 냄새"},

	# 물놀이 풀장. **붙박이입니다** - 밀리지도, 잡히지도, 던져지지도 않습니다.
	#
	# 방에 놓인 지형에 가깝습니다. 다른 소품이 전부 "쓸 수 있는 것" 이라면
	# 이건 **못 쓰는 것**이고, 그래서 몸으로 부딪히는 벽이 방 안에 하나
	# 생깁니다 - 돌진해 오는 서진을 끼고 도는 자리가 됩니다.
	# 벽시계. 액자와 같은 규약인데 더 높이 걸립니다 - 시계는 눈높이보다
	# 위에 있는 물건이고, 액자와 높이가 같으면 둘이 한 줄로 서서 벽이
	# 진열장이 됩니다.
	"clock": {"class": "fixed", "damage": 0.0, "stun": 0.0,
		"wall": true, "mount": 1.85, "scale": 2.5},

	# 아이들 그림 액자. 벽 **위쪽**에 걸립니다.
	#
	# `mount` 는 액자 아랫변이 걸리는 높이(m)입니다. 1.5m 면 아이 키(0.85m)
	# 보다 한참 위라 지나다니는 데 걸리지 않고, 벽 높이(2.8m) 안에 들어옵니다.
	#
	# 걸린 것에는 **충돌이 없습니다**(mount 가 있으면 setup 이 꺼 줍니다).
	# 손이 닿지 않는 높이의 장식이라, 충돌체를 두면 벽에서 튀어나온 보이지
	# 않는 턱이 생깁니다.
	# 원본이 30cm 라 벽에 붙이면 우표만 했습니다. 2.5배면 0.75m - 아이 키의
	# 8할이라 방 건너에서도 무엇이 그려졌는지 보입니다.
	#
	# `mount`(아랫변 높이)는 그대로 둡니다. 커진 만큼 윗변이 올라가지만
	# frame 2.25m, frame2 2.35m 로 벽 높이(2.8m) 안에 들어옵니다.
	"frame":  {"class": "fixed", "damage": 0.0, "stun": 0.0,
		"wall": true, "mount": 1.50, "scale": 2.5},
	"frame2": {"class": "fixed", "damage": 0.0, "stun": 0.0,
		"wall": true, "mount": 1.45, "scale": 2.5},

	# 책장. 풀장과 같은 붙박이인데 **벽에만 붙습니다**.
	#
	# 방 한가운데 선 책장은 가구가 아니라 기둥입니다. 벽에 붙어 있어야
	# 방이 방처럼 보이고, 등지고 싸울 벽이 하나 늘어나는 것이기도 합니다.
	"bookshelf": {"class": "fixed", "damage": 0.0, "stun": 0.0,
		"wall": true, "read": true, "lure": "배움의 갈망"},

	# ── assets/source 의 4면도에서 구운 보육원 가구·장난감 ──────────────
	#
	# `tools/make_source_props.py` 가 test3 로 굽습니다. 가르는 기준은 하나
	# 뿐입니다 - **가구는 못 움직이고, 장난감은 움직입니다.**
	#
	# 가구를 `heavy`(밀리는 가구)가 아니라 `fixed`(붙박이)로 둔 이유: 옷장과
	# 미끄럼틀이 방을 굴러다니면 방이 방으로 안 보입니다. 붙박이라야 그 자리가
	# 지형이 되고, 등지고 싸울 벽이 하나 늘어납니다.

	# 크기는 전부 **1.47배**입니다. 실물 크기로 구웠는데(장롱 1.8m, 옷장 1.2m)
	# 이 게임의 아이는 실물 0.85m 를 1.25m 로 키운 것이라(models.gd 의 HERO),
	# 실물 가구를 그대로 두면 아이 옆에서 한 치수 작아 보입니다. 캐릭터에 쓴
	# 것과 **같은 수**를 같은 이유로 씁니다.

	# 서 있는 가구. 벽에 등을 붙입니다 - 방 한가운데 선 옷장은 가구가 아니라
	# 기둥입니다(책장과 같은 규칙).
	"wardrobe":  {"class": "fixed", "damage": 0.0, "stun": 0.0, "wall": true, "scale": 1.47},
	"toyshelf":  {"class": "fixed", "damage": 0.0, "stun": 0.0, "wall": true, "scale": 1.47},
	"kidcloset": {"class": "fixed", "damage": 0.0, "stun": 0.0, "wall": true, "scale": 1.47},
	# 미끄럼틀만 방 안에 섭니다. 벽에 붙이면 타고 내려올 앞이 벽이라,
	# 이 물건이 무엇인지가 화면에서 사라집니다.
	"slide": {"class": "fixed", "damage": 0.0, "stun": 0.0, "scale": 1.47},

	# 바닥에 깔리는 것. 붙박이지만 **막지 않습니다**(`flat`).
	#
	# 카페트를 다른 붙박이처럼 두면 방 한가운데 보이지 않는 벽이 생깁니다 -
	# 눈에는 바닥인데 발이 걸리는 물건은 고장으로 보입니다. 못 움직이는 것과
	# 못 지나가는 것은 다른 이야기라, 여기서 갈라 둡니다.
	"rug":     {"class": "fixed", "damage": 0.0, "stun": 0.0,
		"lay": true, "flat": true, "scale": 1.47},
	"playmat": {"class": "fixed", "damage": 0.0, "stun": 0.0,
		"lay": true, "flat": true, "scale": 1.47},

	# 장난감. 가구가 아니므로 움직입니다.
	#
	# 둘 다 바퀴가 달려 있어 `heavy`(들 수는 없고 밀어서 굴리는 것)가 맞습니다 -
	# 굴러가며 지나가는 적을 칩니다. 아이가 번쩍 들어 던지는 물건은 아닙니다.
	"toybox":  {"class": "heavy", "damage": 1.40, "stun": 0.4, "scale": 1.47},
	"ridecar": {"class": "heavy", "damage": 1.55, "stun": 0.5, "scale": 1.47},

	"pool": {"class": "fixed", "damage": 0.0, "stun": 0.0,
		# 원본 메시가 지름 0.92m 라 아이(키 0.85m) 옆에서 대야만 했습니다.
		# 4배면 지름 3.7m - 방(10~18m) 안에서 돌아 들어갈 만한 크기입니다.
		"scale": 4.0, "water": true},
}

var kind := "daycare_toybox"
var stats := {}
var held_by: Node3D = null
## **한 번 타고 나면 다시 못 탑니다**(자동차). 연기를 내며 서 있습니다.
##
## 다시 탈 수 있으면 방 하나가 무한한 무적 시간이 됩니다 - 타고 내려서 다시
## 타면 되니까요. 한 번뿐이라야 "언제 쓸까" 가 생깁니다.
var spent := false
var _smoke := 0.0

var _damage := 0.0
var _hit: Dictionary = {}
var _armed := false
var _mesh_root: Node3D


static func path_for(prop_kind: String) -> String:
	return "res://assets/props/%s.glb" % prop_kind


func setup(prop_kind: String) -> void:
	kind = prop_kind
	stats = KINDS.get(kind, KINDS["daycare_toybox"])

	var packed: PackedScene = load(path_for(kind))
	if packed == null:
		push_error("소품을 불러오지 못했습니다: %s" % kind)
		return
	_mesh_root = packed.instantiate()
	add_child(_mesh_root)

	# 납작한 소품은 눕힙니다.
	#
	# 이 소품들은 그림 한 장에서 만들어져 두께가 3~11cm 뿐입니다. 세워 두면
	# 70도로 내려다보는 카메라에서 **얇은 모서리만 보여** 종잇조각처럼
	# 나옵니다(실제로 그랬습니다). 눕히면 그려진 면이 카메라를 향하고,
	# 담요나 바닥에 굴러다니는 장난감으로도 자연스럽습니다.
	if bool(stats.get("lay", false)):
		_mesh_root.rotation.x = -PI * 0.5

	# GLB 는 Y 가 위이고 바닥이 y=0 입니다. 물리 몸체의 원점은 가운데가
	# 편하므로, 눕힌 뒤의 실제 경계를 재서 절반만 내려 답니다.
	# 종류마다의 크기 배율. 메시를 다시 굽지 않고 여기서 키웁니다 - 원본
	# 파일은 test3 가 낸 그대로 두는 편이 나중에 다시 받을 때 헷갈리지
	# 않습니다.
	# 벽에 붙는 것은 **벽과 같은 규칙으로 비칩니다.**
	#
	# 시계와 액자는 벽 위쪽에 걸리는데, 그 벽은 캐릭터를 가릴 때 성기게
	# 비칩니다(wall_fade.gdshader). 걸린 물건만 그대로 불투명하면 벽이
	# 비친 자리에 액자만 남아 캐릭터를 가립니다 - 가려서 안 보이는 것을
	# 없애려던 규칙이 반쪽이 됩니다.
	# 키가 아이만 한 붙박이는 벽에 안 붙어도 비칩니다.
	#
	# 미끄럼틀은 방 한가운데 서는데 높이가 1.8m 라 아이(1.25m)를 통째로
	# 가립니다. 벽에 붙었느냐가 아니라 **가리느냐**가 기준이라야 맞습니다.
	if wants_wall() or (is_fixed()
			and _bounds().y * float(stats.get("scale", 1.0)) >= 1.0):
		_make_fadeable(_mesh_root)

	var size_mult := float(stats.get("scale", 1.0))
	if size_mult != 1.0:
		_mesh_root.scale = Vector3.ONE * size_mult
	# 경계에도 같은 배율을 곱합니다. `_local_aabb` 는 `_mesh_root` **자신의**
	# 변환을 빼고 재기 때문에, 여기서 곱해 주지 않으면 충돌체만 원래 크기로
	# 남아 큰 풀장을 그냥 통과합니다.
	var box := _bounds() * size_mult
	_mesh_root.position.y -= _min_y() * size_mult

	var shape := CollisionShape3D.new()
	var body := BoxShape3D.new()
	body.size = box
	shape.shape = body
	add_child(shape)

	mass = 3.0 if is_heavy() else 1.0
	if mount_height() > 0.0:
		# 벽에 걸린 것은 부딪히지도 않습니다. 위 주석 참고 - 사람 키보다
		# 높은 자리라 막을 것이 없고, 충돌체만 남으면 벽이 두꺼워집니다.
		set_solid(false)
		freeze = true
	if is_flat():
		# 바닥에 깔린 것. 못 움직이지만 **막지도 않습니다.**
		#
		# 벽에 걸린 액자와 같은 처리입니다 - 손이 닿지 않는 자리의 장식에
		# 충돌체를 두면 보이지 않는 턱이 생깁니다. 카페트는 그 턱이 방
		# 한가운데에 생깁니다.
		set_solid(false)
		freeze = true
	if is_fixed():
		# 얼려 두면 어떤 충격을 줘도 안 움직입니다. 질량을 크게 주는 것과
		# 다릅니다 - 무겁기만 하면 계속 밀다 보면 조금씩 밀려나서, 안 밀리는
		# 물건이 아니라 "아주 무거운 물건" 이 됩니다.
		freeze = true
	# 벽/바닥(1)과 다른 소품(1<<4). 사람 쪽은 사람이 부딪혀 와서 밀어 줍니다 -
	# 강체가 사람을 미는 것이 아니라 사람이 강체를 미는 방향이라야, 발밑의
	# 인형이 플레이어를 벽으로 밀어 넣는 일이 없습니다.
	if mount_height() <= 0.0 and not is_flat():
		set_solid(true)
	contact_monitor = false
	can_sleep = true
	linear_damp = 0.8 if is_heavy() else 0.4
	angular_damp = 1.2
	if bool(stats.get("water", false)):
		_add_water(box)
	_lure_text = String(stats.get("lure", ""))
	if _lure_text != "":
		_add_lure()
	add_to_group("props")


## 물이 든 것처럼 보이게 하는 원판과, 그 흔들림.
var _water: MeshInstance3D
var _water_y := 0.0
var _water_t := 0.0

## 물이 벽 안쪽으로 얼마나 들어와 있는가(바깥 반지름 대비). 튜브 벽 두께가
## 반지름의 3할쯤이라 그만큼 좁힙니다 - 벽에 딱 붙이면 물이 벽을 뚫고
## 나온 것처럼 보입니다.
const WATER_INSET := 0.68
## 물 높이(벽 높이 대비). 가득 채우면 벽이 안 보여 접시가 되고, 너무 낮으면
## 바닥 무늬처럼 보입니다.
const WATER_LEVEL := 0.42


## 우유가 있다고 알리는 것들. 빛 하나와 피어오르는 조각, 그리고 가끔 뜨는 말.
var _glow: OmniLight3D
var _glow_t := 0.0
var _puff_t := 0.0
var _smell_t := 0.0
## 부르는 문구. 비어 있으면 이 물건은 아무것도 안 합니다.
var _lure_text := ""
## 조각이 생기는 높이. 갑 꼭대기 바로 위입니다(크기에 따라 달라집니다).
var _puff_from := 0.12

## 조각이 하나 올라가는 간격과, "맛있는 냄새" 가 뜨는 간격(초).
const PUFF_GAP := 0.34
const SMELL_GAP := 5.0


func _add_lure() -> void:
	## 회복 아이템은 **찾아가는 것**이라 멀리서 보여야 합니다. 바닥에 굴러
	## 다니기만 하면 방에 두 개뿐인 우유를 못 보고 지나칩니다 - 있는 줄
	## 몰랐던 자원은 없는 것과 같습니다.
	##
	## 처음에는 발밑에 큰 고리를 깔았는데 **너무 셌습니다.** 고리는 잡기
	## 신호로 이미 쓰고 있어서 뜻이 겹치기도 했습니다. 지금은 김이 오르듯
	## 조각이 피어오르는 쪽입니다 - 눈에는 띄지만 화면을 차지하지 않습니다.
	# 아지랑이가 오를 자리는 물건 꼭대기입니다. 크기에 따라 달라지므로
	# 경계에서 뽑습니다 - 고정값으로 두면 큰 물건 속에서 조각이 생깁니다.
	_puff_from = (_bounds() * float(stats.get("scale", 1.0))).y * 0.9 + 0.06
	# 우유가 여럿이면 문구가 한꺼번에 뜨지 않도록 시작을 흩습니다.
	_smell_t = randf() * SMELL_GAP
	# **빛은 마시는 것에만** 답니다. 책장은 층마다 셋이라 다 빛나면 방이
	# 밝아지고, 무엇보다 "가져갈 수 있는 것" 과 구분이 사라집니다.
	if not is_drink():
		return
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.96, 0.78)
	_glow.light_energy = 1.1
	_glow.omni_range = 2.6
	_glow.shadow_enabled = false
	_glow.position.y = 0.3
	add_child(_glow)


func _spawn_puff() -> void:
	## 작은 네모 하나가 아지랑이처럼 올라갔다 사라집니다.
	##
	## 조각을 **부모(방)에 답니다.** 우유갑에 달면 갑이 굴러갈 때 조각까지
	## 같이 끌려가서, 피어오르는 것이 아니라 매달린 것이 됩니다.
	var parent := get_parent()
	if parent == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.97, 0.82, 0.75)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 카툰 옵션이 조각마다 검은 테두리를 두르면 아지랑이가 아니라 벽돌이 됩니다.
	mi.set_meta("flat", true)
	parent.add_child(mi)
	var side := Vector3(randf_range(-0.09, 0.09), 0.0, randf_range(-0.09, 0.09))
	mi.global_position = global_position + Vector3(0, _puff_from, 0) + side
	mi.rotation.y = randf() * TAU

	var up := mi.global_position + Vector3(side.x * 1.6, 0.62, side.z * 1.6)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", up, 1.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mi, "rotation:y", mi.rotation.y + 2.4, 1.15)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.15).set_delay(0.25)
	tw.chain().tween_callback(mi.queue_free)


func _add_water(box: Vector3) -> void:
	## 얇은 원판 하나에 **물결 셰이더**를 씌웁니다.
	##
	## 처음에는 반투명 파란 판이었습니다. "물이 들었다" 는 됐지만 가만히 있는
	## 색면이라, 화면이 멈추면 그냥 칠해 놓은 바닥으로 보였습니다 - 물은 색이
	## 아니라 **움직임**으로 알아봅니다.
	##
	## 정점은 안 흔듭니다. 63도로 내려다보는 카메라에서는 수면의 높낮이가
	## 실루엣에 거의 안 나타나는데, 흔들려면 원판을 수백 조각으로 쪼개야
	## 합니다 - 폰에서 그 값을 내고 얻는 것이 없습니다.
	var disc := CylinderMesh.new()
	var radius: float = minf(box.x, box.z) * 0.5 * WATER_INSET
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 24

	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/water.gdshader")

	_water = MeshInstance3D.new()
	_water.mesh = disc
	_water.material_override = mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 카툰 옵션이 물에 검은 테두리를 두르지 않게 합니다. 발밑 그림자와 같은
	# 이유입니다 - 테두리가 생기면 물이 아니라 파란 판때기가 됩니다.
	_water.set_meta("flat", true)
	_water_y = _mesh_root.position.y + box.y * WATER_LEVEL
	_water.position.y = _water_y
	add_child(_water)


func _local_aabb() -> AABB:
	## _mesh_root 기준의 경계. 자식이 중첩돼 있어도 변환을 누적해 내려갑니다 -
	## 부모 변환을 빼먹으면 눕힌 소품의 경계가 세워진 채로 나옵니다.
	var found := false
	var total := AABB()
	var stack: Array = [[_mesh_root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xform: Transform3D = entry[1]
		if node is MeshInstance3D and node.mesh != null:
			var box: AABB = xform * node.get_aabb()
			total = box if not found else total.merge(box)
			found = true
		for child in node.get_children():
			var next := xform
			if child is Node3D:
				next = xform * child.transform
			stack.append([child, next])
	return total if found else AABB(Vector3(-0.15, 0, -0.15), Vector3(0.3, 0.3, 0.3))


func _bounds() -> Vector3:
	return _local_aabb().size.maxf(0.12)


func _min_y() -> float:
	return _local_aabb().position.y


func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node == null:
		return out
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out


func mount_height() -> float:
	## 벽에 걸리는 높이(아랫변 기준). 0 이면 바닥에 놓입니다.
	return float(stats.get("mount", 0.0))


## 한 번 읽으면 다시 읽히지 않습니다. 같은 책장 앞에서 계속 누르면 지식이
## 무한정 나오므로, 방을 도는 것이 아니라 한 자리에 서 있는 것이 답이 됩니다.
var was_read := false


func can_read() -> bool:
	return bool(stats.get("read", false)) and not was_read


## 캐릭터를 가릴 때 비치는 재질들. 매 프레임 두 점을 넣어 줍니다.
var _fade_mats: Array[ShaderMaterial] = []


func _make_fadeable(root: Node) -> void:
	## 메시의 재질을 벽과 같은 셰이더로 바꿔 답니다.
	##
	## 원래 재질에서 **알베도 텍스처와 색만** 옮겨 옵니다. 그림이 그대로
	## 나오면서 걷어내는 규칙만 벽과 같아집니다.
	##
	## `flatten` 은 0 입니다. 그 값은 넓은 벽면끼리의 밝기 차이를 지우려고
	## 넣은 것이라, 작은 물건에 걸면 그림자가 사라져 스티커처럼 보입니다.
	var shader: Shader = load(Dungeon.WALL_SHADER)
	if shader == null:
		return
	for node in _all_meshes(root):
		var mi := node as MeshInstance3D
		for i in maxi(mi.get_surface_override_material_count(), 1):
			var src := mi.get_active_material(i)
			var mat := ShaderMaterial.new()
			mat.shader = shader
			var tex: Texture2D = null
			var tint := Color(1, 1, 1)
			if src is BaseMaterial3D:
				tex = (src as BaseMaterial3D).albedo_texture
				tint = (src as BaseMaterial3D).albedo_color
			mat.set_shader_parameter("has_texture", tex != null)
			if tex != null:
				mat.set_shader_parameter("albedo_tex", tex)
			mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
			mat.set_shader_parameter("rough", 0.9)
			mat.set_shader_parameter("flatten", 0.0)
			mi.set_surface_override_material(i, mat)
			_fade_mats.append(mat)


func set_fade_focus(camera_position: Vector3, player_position: Vector3,
		radius: float) -> void:
	## 던전의 같은 이름 함수와 **같은 값**을 받아야 벽과 액자가 같은 자리에서
	## 함께 비칩니다.
	for mat in _fade_mats:
		mat.set_shader_parameter("cam_pos", camera_position)
		mat.set_shader_parameter("player_pos", player_position)
		mat.set_shader_parameter("fade_radius", radius)


func wants_wall() -> bool:
	## 벽에 붙어야 하는가.
	return bool(stats.get("wall", false))


func depth() -> float:
	## 앞뒤 두께. 벽에 등을 붙일 때 얼마나 밀어 넣을지 정하는 값입니다.
	if _mesh_root == null:
		return 0.3
	return (_bounds() * float(stats.get("scale", 1.0))).z


func scale_of() -> float:
	return float(stats.get("scale", 1.0))


func standing_height() -> float:
	## 놓인 뒤의 실제 높이. 눕힌 것은 두께가 높이가 됩니다 - `_bounds` 는
	## _mesh_root 자신의 회전을 빼고 재기 때문에, 그대로 읽으면 1.5m 짜리
	## 매트가 서 있는 것으로 나옵니다.
	var box := _bounds() * scale_of()
	return box.z if bool(stats.get("lay", false)) else box.y


func is_flat() -> bool:
	## 바닥에 깔리는가. 붙박이면서 막지 않는 것들입니다(카페트·놀이매트).
	return bool(stats.get("flat", false))


func footprint_radius() -> float:
	## 바닥에 차지하는 반지름. 큰 붙박이를 놓을 자리를 고를 때 씁니다 -
	## 얼린 물건은 밀려나지 못해서, 벽에 걸치게 놓으면 그대로 박힙니다.
	if _mesh_root == null:
		return 0.3
	var box := _bounds() * float(stats.get("scale", 1.0))
	# 눕힌 것은 **눕힌 뒤의** 바닥 넓이로 잽니다. `_bounds` 는 _mesh_root 자신의
	# 회전을 빼고 재기 때문에, 눕기 전 기준으로는 앞뒤 두께(z)가 잡혀서
	# 1.5m 짜리 매트가 5cm 로 나옵니다 - 벽에 반쯤 걸쳐 놓게 됩니다.
	if bool(stats.get("lay", false)):
		return maxf(box.x, box.y) * 0.5
	return maxf(box.x, box.z) * 0.5


func is_fixed() -> bool:
	## 붙박이인가. 잡기·밀기·던지기가 모두 이 하나로 막힙니다.
	return String(stats.get("class", "")) == "fixed"


func is_drink() -> bool:
	## 마시는 물건인가. 이 하나로 잡기가 갈립니다.
	return stats.has("heal")


func heal_amount() -> float:
	return float(stats.get("heal", 0.0))


func is_heavy() -> bool:
	return String(stats.get("class", "heavy")) == "heavy"


# ---------------------------------------------------------------- 들기/던지기

func grab(by: Node3D) -> bool:
	## 누가 줍든 **맞는 쪽은 다시 정해집니다.** 적이 던져 놓은 물건을 주인공이
	## 주워 던졌는데 그게 주인공을 치면, 물건에 주인이 남아 있는 셈입니다.
	## 무거운 가구도 잡힙니다. 대신 **드는 값**이 비쌉니다 - 들고 있으면
	## 발이 느려지고 숨이 빨리 닳습니다(player.gd).
	##
	## 예전에는 아예 안 잡히고 밀기로 넘어갔는데, 화면에서는 인형이든 상자든
	## 그냥 "바닥의 물건" 이라 눌렀는데 안 잡히는 것으로만 느껴졌습니다.
	## 규칙이 보이지 않으면 규칙이 아니라 고장입니다.
	if held_by != null or is_fixed():
		return false
	held_by = by
	hostile = by is Enemy
	freeze = true
	_armed = false
	_hit.clear()
	set_solid(false)
	picked_up.emit(self)
	return true


func set_solid(on: bool) -> void:
	## 들고 있는 동안에는 **충돌 세계에서 빠집니다.**
	##
	## 들린 소품은 매 프레임 손 위치로 순간이동합니다. 그런데 얼린 강체는
	## 정적 장애물이라, 들고 있는 사람의 캡슐 안으로 순간이동하면 사람이
	## 그것을 밀어내려다 옆으로 튕겨 나갑니다 - 큰 소품(담요·나뭇잎이불)을
	## 들면 캐릭터가 날아가는 것처럼 보이던 것이 이것입니다.
	##
	## 손에 붙은 물건이 주인을 밀 이유는 없으므로, 들려 있는 동안은 레이어와
	## 마스크를 통째로 비웁니다. 놓거나 던지는 순간 되돌립니다.
	collision_layer = (1 << 4) if on else 0
	collision_mask = (1 | (1 << 4)) if on else 0


func carry_to(point: Vector3, delta: float) -> void:
	## 들고 있는 동안의 위치. **손을 따라갑니다.** 딱 붙이지 않고 조금 늦게
	## 따라오게 하면 뛸 때 물건이 살짝 흔들려 들고 있는 느낌이 납니다.
	##
	## 머리 위에 얹지 않는 이유는 밀기 동작 때문입니다. 팔을 뻗는데 물건은
	## 정수리에 붙어 있으면 두 동작이 따로 놉니다.
	global_position = global_position.lerp(
		point + Vector3(0, HAND_CLEAR, 0), 1.0 - exp(-26.0 * delta))
	rotation.y += delta * 1.2


func throw(direction: Vector3, damage: float) -> void:
	held_by = null
	freeze = false
	set_solid(true)
	_damage = damage
	_armed = true
	_hit.clear()
	# 띄우는 높이는 소품과 상관없이 같고, 수평 속도만 다릅니다. 그래야
	# 날아가는 거리가 크기에 그대로 비례합니다 - 둘 다 크기로 바꾸면
	# 제곱으로 벌어집니다.
	linear_velocity = direction * (throw_distance() * THROW_SPEED_PER_M) 		+ Vector3.UP * THROW_LIFT
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))


## 폭죽 놀이(축복). 0 이면 그냥 물건이고, 값이 들어가면 맞는 순간 터집니다.
## 축복을 여러 번 뽑으면 값이 쌓여 더 세집니다.
## 적이 던진 물건인가. 맞는 쪽이 뒤집힙니다.
var hostile := false

var blast := 0.0

## 터지는 범위와, 맞은 대상에게 주는 피해 배율.
##
## 범위는 넓게(3m), 피해는 얕게 잡았습니다. 직격보다 센 광역이면 그냥
## 아무렇게나 던지는 것이 답이 됩니다 - 터지는 것은 **여럿을 건드리는**
## 수단이지 더 아픈 수단이 아닙니다.
const BLAST_RADIUS := 3.0
const BLAST_MULT := 0.55


func _explode() -> void:
	## 맞은 자리에서 터집니다. 직격한 적은 이미 맞았으므로 제외합니다.
	Fx.ring(get_parent(), global_position, Color(1.0, 0.72, 0.3), BLAST_RADIUS, 0.32)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.4, 0),
		Color(1.0, 0.85, 0.45), 18, 5.0)
	Game.shake(0.35, 0.24)
	# 터지는 것은 주인공의 축복(폭죽 놀이)뿐이라 언제나 적을 칩니다.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if not is_instance_valid(enemy) or _hit.has(enemy.get_instance_id()):
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() > BLAST_RADIUS:
			continue
		_hit[enemy.get_instance_id()] = true
		var away := to.normalized() if to.length() > 0.05 else Vector3.FORWARD
		enemy.call("take_damage", _damage * BLAST_MULT * blast, false, away)
	# 터진 물건은 사라집니다. 남겨 두면 같은 소품을 주워 다시 던질 때마다
	# 터져서, 방 하나에 폭탄이 무한히 생깁니다.
	_armed = false
	queue_free()


func is_flying() -> bool:
	## 지금 날아가는 중인가(맞으면 아픈 상태인가).
	##
	## 던진 직후에 잡기를 다시 누르면 **방금 던진 물건을 도로 잡습니다.**
	## 손을 떠난 지 얼마 안 돼 아직 몸 옆에 있기 때문입니다 - 던진 것이
	## 아니라 손에서 튕겼다 돌아온 것으로 보입니다.
	return _armed and linear_velocity.length() > HURT_SPEED


func throw_size() -> float:
	## 던지기에서 쓰는 "크기". 경계 상자 부피의 한 변입니다.
	##
	## 가장 긴 변으로 재면 납작한 담요가 기차보다 크게 나와서, 덩치와 상관없이
	## 안 날아갑니다. 세제곱근이 덩치에 가깝습니다.
	var b := _bounds()
	return clampf(pow(maxf(b.x * b.y * b.z, 0.0001), 1.0 / 3.0), 0.10, 1.6)


func throw_distance() -> float:
	return minf(THROW_REF_DIST * pow(THROW_REF_SIZE / throw_size(), THROW_SIZE_POWER),
		THROW_MAX_DIST)


func push(direction: Vector3, damage: float) -> void:
	## 무거운 소품을 밀어 굴립니다. 들 수 없는 것에 주는 대안입니다.
	held_by = null
	freeze = false
	set_solid(true)
	_damage = damage
	_armed = true
	_hit.clear()
	linear_velocity = direction * PUSH_SPEED + Vector3.UP * 0.4
	angular_velocity = Vector3(randf_range(-3, 3), 0.0, randf_range(-3, 3))


func drop() -> void:
	## 방향 없이 놓습니다. 던지는 것과 달리 그 자리에 툭 내려놓습니다.
	held_by = null
	freeze = false
	set_solid(true)
	_armed = false
	linear_velocity = Vector3(0, -0.5, 0)
	angular_velocity = Vector3.ZERO


# ---------------------------------------------------------------- 피해

func _lure_active() -> bool:
	## 아직 부를 이유가 있는가. 손에 든 우유와 이미 읽은 책장은 조용합니다 -
	## 다 쓴 물건이 계속 부르면 화면이 거짓말을 합니다.
	if held_by != null:
		return false
	if bool(stats.get("read", false)):
		return can_read()
	return true


func mark_spent() -> void:
	## 다 쓴 자동차. 연기를 내기 시작합니다.
	spent = true
	# 앞머리를 살짝 기울여 세워 둡니다. 연기만으로는 지나가다 못 알아봅니다 -
	# 멀쩡히 서 있는 것과 모양이 달라야 합니다.
	rotation.x = deg_to_rad(-7.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.5, 0),
		Color(0.62, 0.62, 0.66), 14, 2.4)


func _drive_smoke(delta: float) -> void:
	## 다 쓴 자동차가 연기를 냅니다. 파티클 대신 조각을 띄엄띄엄 띄웁니다 -
	## 층마다 두 대뿐이라 값이 문제가 되지 않고, 이미 있는 길을 씁니다.
	_smoke -= delta
	if _smoke > 0.0:
		return
	_smoke = SMOKE_EVERY
	Fx.burst(get_parent(), global_position + Vector3(0, 0.55, 0),
		Color(0.60, 0.60, 0.64), 4, 1.2)


func _process(delta: float) -> void:
	if spent:
		_drive_smoke(delta)
	if _lure_text != "":
		## 숨 쉬듯 밝아졌다 어두워집니다. 깜빡이면 경고로 읽히고, 가만히
		## 있으면 배경으로 읽힙니다 - 느리게 오르내려야 "부르는" 것이 됩니다.
		_glow_t += delta
		if _glow != null:
			_glow.light_energy = 1.1 + sin(_glow_t * 2.2) * 0.35
		if _lure_active():
			_puff_t -= delta
			if _puff_t <= 0.0:
				_puff_t = PUFF_GAP
				_spawn_puff()
			_smell_t -= delta
			if _smell_t <= 0.0:
				_smell_t = SMELL_GAP
				Fx.popup_text(get_parent(),
					global_position + Vector3(0, _puff_from + 0.45, 0),
					_lure_text, Color(1.0, 0.93, 0.72))

	## 물결. 위아래로 아주 조금 오르내리고 천천히 돕니다.
	##
	## 진폭이 1.2cm 뿐입니다. 크게 흔들면 물이 아니라 **판이 덜컹거리는**
	## 것으로 보입니다 - 물은 가장자리가 벽에 붙어 있어서 가운데만 조금
	## 오르내립니다.
	if _water == null:
		return
	_water_t += delta
	_water.position.y = _water_y + sin(_water_t * 1.6) * 0.012
	_water.rotation.y += delta * 0.15


func _physics_process(_delta: float) -> void:
	if not _armed or held_by != null:
		return
	var speed := linear_velocity.length()
	if speed < HURT_SPEED:
		# 느려지면 그냥 굴러다니는 물건으로 돌아갑니다.
		_armed = false
		return

	# 누가 던졌느냐에 따라 맞는 쪽이 다릅니다. 적이 던진 것은 주인공을,
	# 주인공이 던진 것은 적을 칩니다 - 같은 물건이 양쪽을 다 치면 적이
	# 자기 편을 맞히고 죽어서, 던지는 적이 자해 장치가 됩니다.
	var targets: Array = []
	if hostile:
		var pl: Node3D = Game.instance.player if Game.instance != null else null
		if pl != null and is_instance_valid(pl):
			targets = [pl]
	else:
		targets = get_tree().get_nodes_in_group("enemies")

	for node in targets:
		var enemy := node as Node3D
		if not is_instance_valid(enemy) or _hit.has(enemy.get_instance_id()):
			continue
		# **수평 거리와 높이를 따로 봅니다.**
		#
		# 예전에는 3D 거리 하나로 쟀는데, 적의 원점은 발밑이고 던진 물건은
		# 1m 쯤 떠서 날아갑니다. 그래서 머리를 정통으로 지나가도 원점까지는
		# 1m 가 넘어 빗나간 것으로 처리됐습니다.
		var to: Vector3 = enemy.global_position - global_position
		var high: float = float(enemy.get_meta("body_height", 1.3))
		if to.y > 0.35 or to.y < -high - 0.2:
			continue          # 발밑을 지나가거나 머리 위로 넘어갔습니다
		to.y = 0.0
		var reach: float = 0.35 + speed * 0.03 			+ float(enemy.get_meta("body_radius", 0.3)) + throw_size() * 0.5
		if to.length() > reach:
			continue
		_hit[enemy.get_instance_id()] = true
		var dir := linear_velocity.normalized()
		if hostile:
			# 주인공의 take_damage 는 인자가 다릅니다(맞은 자리, 밀리는 세기).
			enemy.call("take_damage", _damage, global_position, 7.0)
		else:
			# 던진 물건도 **자리**를 넘깁니다. 앞을 막는 적(베개)에게
			# 정면으로 던지면 막힙니다 - 손으로 치는 것과 같은 규칙이라야
			# "앞이 막혀 있다" 가 한 가지 규칙으로 읽힙니다.
			enemy.call("take_damage", _damage, false, dir, 0.0, global_position)
			var stun := float(stats.get("stun", 0.0))
			if stun > 0.0 and enemy.has_method("stagger_for"):
				enemy.stagger_for(stun)
		Fx.burst(get_parent(), global_position, Color(1.0, 0.9, 0.6), 8, 3.0)
		Game.shake(0.18, 0.12)
		if blast > 0.0:
			_explode()
			return
		# 맞은 뒤에는 힘이 빠집니다. 하나가 방을 쓸어버리면 안 됩니다.
		linear_velocity *= 0.45
		_damage *= 0.6
