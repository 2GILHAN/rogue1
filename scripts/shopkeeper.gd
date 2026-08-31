class_name Shopkeeper
extends Node3D

## 물물교환하는 아이. **풀장 안에 기대앉아** 있고, 가까이 가면 말을 겁니다.
##
## 안전한 방에 두는 것이 규칙입니다. 싸우면서 물건을 고를 수는 없고, 고르는
## 시간이 곧 다음 층을 준비하는 호흡이기 때문입니다.
##
## 서서 기다리는 상인이 아니라 **놀고 있는 또래**입니다 - 팔을 물가에 T 자로
## 걸치고 고개를 젖힌 채, 지나가는 아이가 오면 그제야 말을 섞습니다.

signal player_near_changed(near: bool)

## 말이 닿는 거리.
##
## **3.2 에서 1.7 로 좁혔습니다.** 이 아이가 풀장 안에 앉으면서 물놀이터와
## 자리가 겹쳤습니다 - 넓게 두면 물가에 서기만 해도 교환 창이 열려서, 물에
## 들어갈 방법이 없어집니다.
##
## 좁히면 규칙이 자리로 갈립니다: **가까운 쪽(물가)에서는 물놀이, 이 아이
## 앞까지 돌아가면 물물교환**입니다.
const RANGE := 1.7
## 풀장 테두리의 높이(m). **재서 넣은 값**입니다(`--pose=balance` 가 찍습니다).
##
## 1.20m 는 아이 키(1.25m)와 거의 같습니다 - 안에 앉히면 무엇을 해도 테두리에
## 가려서, 위에 걸터앉는 쪽으로 바꿨습니다.
const RIM_TOP := 1.20
## 이 아이의 엉덩이 높이(m). 모델 원점이 발밑이라, 걸터앉히려면 이만큼
## 내려야 엉덩이가 테두리에 놓입니다.
const HIP_HEIGHT := 0.40

var _near := false
var _time := 0.0
var _pivot: Node3D
var _pose: PoseOverride = null


func _ready() -> void:
	_pivot = Node3D.new()
	# **얼굴이 이쪽을 보게 180도 돌립니다.**
	#
	# Godot 모델은 -Z 를 앞으로 봅니다. 이 아이는 화면에서 먼 쪽(-Z) 물가에
	# 등을 대고 앉으므로, 그대로 두면 카메라에 등만 보입니다.
	_pivot.rotation.y = PI
	# **테두리 위로 올려 앉힙니다.**
	#
	# 모델의 원점은 발밑입니다. 걸터앉으면 엉덩이가 테두리에 놓이므로,
	# 원점을 테두리 높이에서 엉덩이 높이만큼 내려 둡니다.
	_pivot.position.y = RIM_TOP - HIP_HEIGHT
	add_child(_pivot)
	var model := Models.spawn(Models.SHOPKEEPER)
	_pivot.add_child(model)
	var ap := Models.find_anim(model)
	if ap != null:
		var idle := Models.clip(ap, "Idle")
		if idle != "":
			ap.play(idle)
	# **기대앉은 자세를 클립 위에 덮습니다.**
	#
	# 앉은 모양은 다리도 상체도 서 있는 클립과 전부 달라서 섞을 것이 없으므로
	# 100% 로 덮습니다. 그래도 클립을 계속 돌리는 이유는 그 위에서 숨쉬기 같은
	# 작은 움직임이 남기 때문입니다 - 아래 `_process` 가 발과 고개를 조금 더
	# 흔들어 굳은 인형처럼 보이지 않게 합니다.
	var skel := Models.find_skeleton(model)
	if skel != null:
		_pose = PoseOverride.new()
		_pose.pose = PoseOverride.POOL_SIT.duplicate()
		_pose.weight = 1.0
		skel.add_child(_pose)

	# **깔개와 조명을 걷어냈습니다.**
	#
	# 깔개는 "이 방이 다르다" 는 신호였는데, 이 아이가 풀장 안에 앉으면서
	# 풀장 자체가 그 신호가 됐습니다 - 물 위에 겹친 주황색 원반은 표시가
	# 아니라 얼룩으로 보입니다.
	#
	# 조명도 뺐습니다. 방마다 놓인 점광원이 이미 분위기를 만들고 있어서,
	# 여기만 밝히면 물 색이 튀고 물놀이터가 무대처럼 보입니다.

	var sign_label := Label3D.new()
	sign_label.text = "물물교환"
	sign_label.font_size = 48
	sign_label.outline_size = 16
	sign_label.modulate = Color(1.0, 0.85, 0.5)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.pixel_size = 0.004
	sign_label.position = Vector3(0, 2.1, 0)
	add_child(sign_label)


func _process(delta: float) -> void:
	_time += delta
	# **몸통은 안 돌립니다.** 물가에 팔을 걸치고 기댄 자세라, 몸이 좌우로
	# 흔들리면 걸친 팔이 벽을 뚫고 드나듭니다.
	#
	# 대신 **발과 고개만** 조금씩 움직입니다. 완전히 굳어 있으면 인형이고,
	# 크게 움직이면 앉아 쉬는 것이 아니라 발버둥으로 보입니다 - 물장구는
	# 발끝이 몇 도 까딱이는 정도입니다.
	#
	# 두 발의 주기를 다르게 둡니다(1.7 과 1.3). 같으면 두 발이 한 몸처럼
	# 붙어 움직여서 기계로 보입니다.
	if _pose != null:
		# **무릎을 걷듯이 폈다 굽힙니다.** 두 다리가 반 바퀴 어긋나 있어서
		# 하나가 펴질 때 다른 하나가 굽습니다 - 같이 움직이면 걷는 것이
		# 아니라 뛰는 것이 되고, 앉아서 뛰면 발버둥으로 보입니다.
		var swing := sin(_time * 1.6)
		_pose.pose["LeftLeg"] = Vector3(
			PoseOverride.POOL_KNEE + swing * PoseOverride.POOL_KNEE_SWING, 0, 0)
		_pose.pose["RightLeg"] = Vector3(
			PoseOverride.POOL_KNEE - swing * PoseOverride.POOL_KNEE_SWING, 0, 0)
		# 발끝은 무릎을 따라갑니다. 종아리만 움직이고 발이 굳어 있으면
		# 관절이 하나 빠진 것으로 보입니다.
		_pose.pose["LeftFoot"] = Vector3(12.0 - swing * 8.0, 0, 0)
		_pose.pose["RightFoot"] = Vector3(12.0 + swing * 8.0, 0, 0)
		# 고개는 앞을 본 채로 아주 조금. 두리번거리면 기다리는 것이 아니라
		# 무언가를 찾는 것으로 보입니다.
		_pose.pose["Head"] = Vector3(-2.0 + sin(_time * 0.9) * 3.0,
			sin(_time * 0.5) * 8.0, 0)

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
