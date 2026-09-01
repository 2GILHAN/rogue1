class_name Shopkeeper
extends Node3D

## 물물교환하는 아이. **풀장 한가운데에 서서 물장난을 칩니다.**
##
## 안전한 방에 두는 것이 규칙입니다. 싸우면서 물건을 고를 수는 없고, 고르는
## 시간이 곧 다음 층을 준비하는 호흡이기 때문입니다.
##
## 서서 기다리는 상인이 아니라 **놀고 있는 또래**입니다 - 물에 들어가 두 팔로
## 번갈아 첨벙거리다가, 지나가는 아이가 오면 그제야 말을 섞습니다.
##
## **풀장이 곧 이 아이입니다.** 물가 어디에서 잡기를 눌러도 교환 창이 열립니다
## (`game.gd` 의 `_near_waterpark`) - 예전에는 풀장이 따로 값을 받는 회복
## 자리였고, 같은 버튼으로 반걸음 차이에 다른 것이 나왔습니다.

signal player_near_changed(near: bool)

## 말이 닿는 거리.
##
## 아이가 풀장 한가운데(반지름 1.84)에 서므로 **물가에서 닿아야 합니다** -
## 1.7 로 좁혀 두던 시절에는 물놀이터와 교환이 서로 다른 일이라 반걸음
## 차이로 갈랐는데, 이제 둘이 같은 것입니다.
const RANGE := 2.6
## 팔을 좌우로 바꾸는 주기(초).
##
## 0.28초면 여섯 번쯤 첨벙거립니다 - 더 느리면 체조이고, 더 빠르면 떠는
## 것처럼 보입니다. 주인공이 물에 들어가던 시절에 골라 둔 값입니다.
const SPLASH_SWAP := 0.28
## 물에 잠기는 깊이(m). 발바닥이 수면에 딱 붙으면 물 위에 선 것으로 보입니다.
##
## 정강이가 조금 잠겨야 **들어가 있는** 것이 됩니다. 더 담그면 테두리(1.20m)
## 뒤로 몸이 내려가 위쪽만 남습니다 - 수면이 0.50m 이고 아이 키가 1.25m 라
## 여유가 크지 않습니다.
const WADE := 0.14

var _near := false
var _time := 0.0
## 팔을 바꾸기까지 남은 시간과, 지금 어느 쪽 팔이 물을 치고 있나.
var _swap := 0.0
var _left := true
var _pivot: Node3D
var _pose: PoseOverride = null


func _ready() -> void:
	_pivot = Node3D.new()
	# **얼굴이 이쪽을 보게 180도 돌립니다.**
	#
	# Godot 모델은 -Z 를 앞으로 봅니다. 이 아이는 화면에서 먼 쪽(-Z) 물가에
	# 등을 대고 앉으므로, 그대로 두면 카메라에 등만 보입니다.
	_pivot.rotation.y = PI
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
	# **상체만 덮습니다.** 물장난 자세는 다리를 안 건드리므로 서 있는 클립이
	# 그대로 돌고, 그러면 물속에서 발을 놀리는 것으로 읽힙니다 - 다리까지
	# 고정하면 물에 꽂아 둔 인형이 됩니다.
	var skel := Models.find_skeleton(model)
	if skel != null:
		_pose = PoseOverride.new()
		_pose.pose = PoseOverride.SPLASH_A.duplicate()
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


func stand_in(pool: Prop) -> void:
	## **풀장 한가운데, 수면 위에 세웁니다.**
	##
	## 높이를 눈으로 고르지 않고 풀장에게 물어봅니다(`Prop.water_y`) - 소품
	## 크기가 바뀌면 수면도 같이 움직이는데, 여기 숫자를 박아 두면 그때
	## 아이만 물 위에 뜨거나 잠깁니다.
	if pool == null or not is_instance_valid(pool):
		return
	global_position = pool.global_position + Vector3(0.0, pool.water_y() - WADE, 0.0)


func _process(delta: float) -> void:
	_time += delta
	if _pose != null:
		# **팔을 번갈아 물에 넣습니다.** 자세 둘을 오가는 것이 곧 물장난이라,
		# 한 자세로 두면 팔을 든 채 굳은 그림이 됩니다.
		_swap -= delta
		if _swap <= 0.0:
			_swap = SPLASH_SWAP
			_left = not _left
			_splash_burst()
		_pose.pose = (PoseOverride.SPLASH_A if _left else PoseOverride.SPLASH_B).duplicate()
		# 고개는 앞을 본 채로 아주 조금 더. 두리번거리면 노는 것이 아니라
		# 무언가를 찾는 것으로 보입니다.
		var head: Vector3 = _pose.pose["Head"]
		_pose.pose["Head"] = head + Vector3(sin(_time * 0.9) * 3.0, sin(_time * 0.5) * 6.0, 0)
		# 팔을 바꿀 때마다 **덜 섞인 데서 출발**합니다. 1.0 에 붙여 두면 두
		# 자세 사이를 미끄러지듯 오가서 첨벙거리는 맛이 없습니다.
		_pose.weight = lerpf(_pose.weight, 1.0, 1.0 - exp(-16.0 * delta))

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


func _splash_burst() -> void:
	## 팔을 바꿀 때마다 물이 튑니다. 자세만 오가면 소리 없는 체조입니다.
	##
	## **소리는 안 냅니다.** 이 아이는 층 내내 첨벙거리고 있어서, 소리까지
	## 내면 방 하나가 통째로 시끄러워집니다 - 물장난은 눈으로 보이면 됩니다.
	if get_parent() == null:
		return
	Fx.burst(get_parent(), global_position + Vector3(0, 0.35, 0),
		Color(0.62, 0.88, 1.0), 8, 2.2)
