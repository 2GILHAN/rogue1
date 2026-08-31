class_name PoseOverride
extends SkeletonModifier3D

## 클립 위에 **자세 하나를 덮어씌우는** 층입니다.
##
## # 왜 필요한가
##
## 걷기·대기·밀기는 구운 클립이 있지만, 구르기와 "몹을 잡고 있는 자세" 는
## 클립이 없습니다. 그렇다고 클립을 새로 구우면 문제가 생깁니다 - 구르는
## 동안에도 다리는 걷기 클립이 돌고 있어야 착지 뒤가 자연스럽고, 몹을 잡은
## 채로도 걸어야 하기 때문입니다. **팔만, 상체만** 덮어써야 합니다.
##
## 그래서 클립은 그대로 두고 그 위에 특정 본만 목표 자세로 당깁니다.
## `weight` 로 얼마나 당길지를 정하므로 동작의 시작과 끝에서 부드럽게
## 섞입니다.
##
## # 왜 SkeletonModifier3D 인가
##
## Jiggle 과 같은 이유입니다. 본 포즈는 애니메이션이 매 프레임 덮어쓰므로
## `_process` 에서 써 넣으면 실행 순서에 따라 먹었다 안 먹었다 합니다.
##
## # 각도 규약
##
## test3 가 굽는 동작 데이터와 같습니다 - 본의 **로컬 오일러(도), XYZ 순서**
## 이고 `X 양수가 앞`, `Z 는 좌우로 벌리는 축`(좌우가 거울이라 부호 반대)
## 입니다. 그래서 test3 의 동작(`make_kids.py`)과 같은 감각으로 적을 수
## 있습니다.
##
## 값은 **쉬는 자세(rest) 기준의 절대 자세**입니다. 클립이 지금 무엇을 하고
## 있든 목표가 같아야, 걷는 도중에 구르든 서서 구르든 같은 모양이 나옵니다.

## 지금 겹칠 자세. 본 이름 -> 오일러(도).
var pose: Dictionary = {}
## 0 이면 클립 그대로, 1 이면 자세 그대로.
var weight := 0.0

## 본 이름 -> 인덱스. 이름으로 찾는 일은 한 번만 합니다.
var _index: Dictionary = {}
var _looked_up: Dictionary = {}


func _process_modification_with_delta(_delta: float) -> void:
	## 이름이 `_process_modification` 이 아닙니다. 이 엔진 판에서는 델타를 받는
	## 쪽이 불립니다 - 잘못 쓰면 **조용히 한 번도 안 불립니다**(실제로 그랬고,
	## 자세가 안 먹는 원인을 찾는 데 한참 걸렸습니다).
	if weight <= 0.001 or pose.is_empty():
		return
	var skel := get_skeleton()
	if skel == null:
		return
	var k := clampf(weight, 0.0, 1.0)
	for name in pose:
		var idx := _bone(skel, String(name))
		if idx < 0:
			continue
		var target: Quaternion = skel.get_bone_rest(idx).basis.get_rotation_quaternion() \
			* _euler_xyz(pose[name])
		skel.set_bone_pose_rotation(idx,
			skel.get_bone_pose_rotation(idx).slerp(target, k))


func _bone(skel: Skeleton3D, name: String) -> int:
	if not _looked_up.has(name):
		_looked_up[name] = true
		_index[name] = skel.find_bone(name)
	return int(_index.get(name, -1))


## 두 자세를 섞어 `dst` 에 채웁니다.
##
## `pose` 를 통째로 갈아 끼우면 그 프레임에 각도가 **순간이동합니다.**
## `weight` 는 클립과 자세 사이를 섞는 값이라 자세끼리는 못 섞습니다 - 밀기에서
## 팔이 뒤(-75도)에서 앞(+84도)으로 159도를 한 프레임에 건너뛰던 것이 이것
## 이었습니다. 중간이 없으니 "뻗는 동작" 이 아니라 두 장의 그림이었습니다.
##
## 값이 **쉬는 자세 기준의 절대 각도**라 그냥 선형 보간하면 됩니다. 한쪽에만
## 있는 본은 없는 쪽을 0(쉬는 자세)으로 봅니다.
##
## 매 프레임 새 사전을 만들지 않으려고 받은 것을 채워 돌려줍니다.
static func mix_into(dst: Dictionary, a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	dst.clear()
	for name in a:
		dst[name] = (a[name] as Vector3).lerp(b.get(name, Vector3.ZERO), k)
	for name in b:
		if not dst.has(name):
			dst[name] = (b[name] as Vector3) * k
	return dst


static func _euler_xyz(degrees: Vector3) -> Quaternion:
	## 블렌더의 XYZ 순서에 맞춥니다(test3 의 walk_worker 가 그 순서로 굽습니다).
	## Godot 의 기본은 YXZ 라 그대로 쓰면 축이 섞인 자세가 나옵니다.
	return Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y),
		deg_to_rad(degrees.z)), EULER_ORDER_XYZ).get_rotation_quaternion()


# ---------------------------------------------------------------- 자세들

## 구르기. 몸을 ㄷ 자로 말아 쥡니다.
##
## 일자로 회전하면 구르는 것이 아니라 막대가 도는 것으로 보입니다. 사람이
## 구를 때 실제로 하는 일은 **접히는 것**이고, 그 접힌 모양이 회전보다 먼저
## 읽힙니다. 그래서 넷을 같이 접습니다 - 고개를 숙이고, 등을 말고, 허벅지를
## 가슴으로 올리고, 팔을 앞으로 모읍니다.
const ROLL := {
	"Spine": Vector3(26, 0, 0),
	"Chest": Vector3(24, 0, 0),
	"Neck": Vector3(22, 0, 0),
	"Head": Vector3(16, 0, 0),
	"LeftArm": Vector3(78, 0, 42), "RightArm": Vector3(78, 0, -42),
	"LeftForeArm": Vector3(26, 0, 0), "RightForeArm": Vector3(26, 0, 0),
	"LeftUpLeg": Vector3(82, 0, 0), "RightUpLeg": Vector3(82, 0, 0),
	"LeftLeg": Vector3(-78, 0, 0), "RightLeg": Vector3(-78, 0, 0),
}

## 달려들 때. 두 팔을 앞으로 내밀고 몸을 앞으로 기울입니다.
##
## 잡는 자세(CARRY)와 팔은 비슷하지만 몸통이 다릅니다 - 이쪽은 **앞으로
## 쏠려 있어야** 달려드는 것으로 보입니다. 잡은 뒤에는 몸이 서고, 그
## 차이가 "덤벼드는 중" 과 "들고 있는 중" 을 갈라 줍니다.
const LUNGE := {
	"Spine": Vector3(18, 0, 0), "Chest": Vector3(10, 0, 0),
	"Neck": Vector3(-8, 0, 0), "Head": Vector3(-6, 0, 0),
	"LeftArm": Vector3(84, 0, 10), "RightArm": Vector3(84, 0, -10),
	"LeftForeArm": Vector3(10, 0, 0), "RightForeArm": Vector3(10, 0, 0),
}


## 책장으로 **오른손을 뻗는** 자세. 다가가면서 취합니다.
##
## 한 손만 뻗습니다 - 두 손을 다 뻗으면 책을 꺼내는 것이 아니라 벽을 짚는
## 모양이 됩니다. 왼손은 자연스럽게 내려 둡니다.
const READ_REACH_POSE := {
	"Spine": Vector3(6, 0, 0), "Chest": Vector3(4, 0, 0),
	"Neck": Vector3(4, 0, 0), "Head": Vector3(2, 0, 0),
	"RightArm": Vector3(86, 0, -8), "RightForeArm": Vector3(0, 0, 0),
	"LeftArm": Vector3(6, 0, 20), "LeftForeArm": Vector3(0, 0, 0),
}

## 꺼낸 책을 **오른손만으로** 든 자세. 책은 아직 덮여 있습니다.
const READ_HOLD := {
	"Spine": Vector3(6, 0, 0), "Chest": Vector3(4, 0, 0),
	"Neck": Vector3(12, 0, 0), "Head": Vector3(10, 0, 0),
	"RightArm": Vector3(72, 0, -22), "RightForeArm": Vector3(0, 0, 0),
	"LeftArm": Vector3(10, 0, 22), "LeftForeArm": Vector3(0, 0, 0),
}

## 두 손으로 펼쳐 든 자세. READ_HOLD 에서 여기로 섞여 오면서 **왼손이 책 위로
## 올라오고**, 그 손이 벌어지는 만큼 책도 펼쳐집니다.
##
## 팔은 펴서(팔꿈치 0) 앞아래 45도로 내립니다. 각도는 손 위치를 재서
## 골랐습니다 - 어깨 74 / 벌림 24 에서 두 손 사이가 책 한 권 폭이 됩니다.
const READ := {
	"Spine": Vector3(8, 0, 0), "Chest": Vector3(6, 0, 0),
	"Neck": Vector3(16, 0, 0), "Head": Vector3(14, 0, 0),
	"LeftArm": Vector3(74, 0, 24), "RightArm": Vector3(74, 0, -24),
	"LeftForeArm": Vector3(0, 0, 0), "RightForeArm": Vector3(0, 0, 0),
}


## 우유를 마시는 자세. 두 손을 입가로 올리고 고개를 젖힙니다.
##
## 두 손인 이유는 들고 있는 물건이 **두 손의 가운데**를 따라오기 때문입니다
## (`_hands_point`). 한 손으로 들게 하면 우유갑이 손과 몸 사이 허공에 뜹니다.
## 아이가 우유갑을 두 손으로 감싸 쥐는 모양이기도 합니다.
##
## 고개는 고함과 같은 쪽(-)으로 젖히되 얕게 둡니다. 크게 젖히면 마시는 것이
## 아니라 들이붓는 것이 됩니다.
##
## 팔 각도는 손 위치를 재서 골랐습니다(--pose=drinkscan). 어깨만 앞으로
## 올리면 팔이 **쭉 뻗은 채** 올라가 손이 얼굴에서 0.27m 앞에 섭니다 - 잔을
## 든 것이 아니라 무언가를 내미는 모양입니다. 팔꿈치를 크게 접어야(135도)
## 손이 얼굴 앞 0.09m 로 돌아옵니다.
##
##   어깨 62 / 팔꿈치  78 -> 앞뒤 +0.274  간격 0.094
##   어깨 80 / 팔꿈치 135 -> 앞뒤 +0.092  간격 0.005   <- 고른 값
##   어깨 95 / 팔꿈치 -80 -> 앞뒤 +0.218  간격 0.459   (팔꿈치를 반대로 접으면 벌어집니다)
const DRINK := {
	"Spine": Vector3(-6, 0, 0), "Chest": Vector3(-4, 0, 0),
	"Neck": Vector3(-18, 0, 0), "Head": Vector3(-14, 0, 0),
	"LeftArm": Vector3(80, 0, 12), "RightArm": Vector3(80, 0, -12),
	"LeftForeArm": Vector3(135, 0, 0), "RightForeArm": Vector3(135, 0, 0),
}


## 몹을 잡고 있는 자세. 두 팔을 앞으로 모읍니다.
##
## 다리는 건드리지 않습니다 - 잡은 채로 걸어야 하므로 걷기 클립이 그대로
## 돌아야 합니다.
## 각도는 후보를 훑어 화면으로 골랐습니다(X 를 키우면 팔이 앞으로 나오고,
## Z 를 넣으면 몸 쪽으로 접힙니다). Z 를 넣으면 앞으로 나가던 것이 도로
## 몸에 붙어 버려서 0 입니다.
const CARRY := {
	"Spine": Vector3(6, 0, 0),
	"LeftArm": Vector3(72, 0, 0), "RightArm": Vector3(72, 0, 0),
	"LeftForeArm": Vector3(14, 0, 0), "RightForeArm": Vector3(14, 0, 0),
}


## 고함을 지르는 자세. 고개를 젖히고, 허리를 굽히고, 두 팔을 뒤로 뺍니다.
##
## 셋이 한 벌입니다. 아이가 소리를 지를 때 실제로 하는 일은 **가슴을 내밀기
## 위해 나머지를 뒤로 보내는 것**입니다 - 고개를 젖혀 목을 열고, 허리를 접어
## 배에 힘을 주고, 팔은 그 반작용으로 뒤에 남습니다. 하나만 하면 자세가 아니라
## 실수처럼 보입니다(고개만 젖히면 하늘을 보는 것, 허리만 굽히면 배가 아픈 것).
##
## 팔의 각도는 **손 위치를 재서** 골랐습니다. 스크린샷으로는 앞뒤를 잘못
## 읽습니다 - 내려다보는 카메라에서 팔이 몸에 가려 어느 쪽인지 구분되지 않아,
## 한 번은 뒤로 보낸 줄 알고 앞으로 뻗어 두었습니다.
##
## 손 본에 앵커(BoneAttachment3D)를 붙여 조준 방향으로 투영한 값(양수가 앞):
##
##     어깨 X    -100     -70     -45       0     +45     +90
##     손 앞뒤  -0.173  -0.151  -0.092  +0.069  +0.219  +0.272
##
## 뒤로 가장 멀리 가는 것은 -100 이지만 그 자세는 **두 손이 등 뒤에서 모입니다**
## (손 간격 0.064m). 팔이 뒤로 가면서 안쪽으로도 감기기 때문입니다. 벌어져야
## 소리를 내지르는 자세로 읽히므로, 세 축을 같이 봤습니다:
##
##     X / Y / Z      뒤로    높이   손 간격
##     -100 /  0 / 34  -0.166  0.817   0.064   <- 등 뒤에서 모임
##      -75 /  0 / 34  -0.169  0.797   0.277
##      -75 / 15 / 50  -0.137  0.700   0.345
##      -75 / 35 / 50  -0.108  0.712   0.494
##      -75 / 45 / 50  -0.091  0.728   0.561   <- 지금 값
##      -75 / 55 / 50  -0.071  0.750   0.621
##
## X 를 -100 에서 -75 로 줄이면 팔이 덜 올라가고(0.82 -> 0.73) 벌어집니다.
## Z(50)가 높이를 마저 내리고, Y 가 손끝을 바깥으로 돌려 간격을 벌립니다.
##
## 간격의 기준은 **팔 길이**입니다. 이 아이는 어깨에서 손끝까지 0.317m 이고
## 어깨 사이가 0.194m 인데, 손 간격이 팔 길이보다 짧으면 등 뒤에서 손을
## 맞잡은 것처럼 보입니다. 0.561m 는 팔 길이의 1.8배, 어깨 폭의 2.9배입니다.
##
## 벌릴수록 뒤로는 덜 갑니다(0.137 -> 0.091). 둘 중에서는 벌어지는 쪽을
## 골랐습니다 - 뒤로 간 것은 옆에서만 보이지만 벌어진 것은 어느 각도에서도
## 보입니다. 이 게임은 위에서 내려다봅니다.
##
## 팔꿈치는 0 - 굽히면(-30) 오히려 앞으로 돌아옵니다(-0.135). "뻗는다" 는
## 말대로 편 채로 두는 쪽이 더 멀리 갑니다.
##
## 재는 방법도 한 번 틀렸습니다. `Skeleton3D.get_bone_global_pose` 는 이 시점에
## 자세 층이 반영되기 전 값이라, 각도를 바꿔도 **여섯 후보가 전부 같은 수**가
## 나왔습니다. 앵커는 최종 자세를 따라가므로 그쪽으로 바꿔서 잡았습니다.
##
## 팔의 Z(34)는 클립이 이미 넣어 둔 "벌림 접기"(make_kids.py --arms)와 같은
## 값입니다. 여기 값은 쉬는 자세(A 포즈) 기준의 절대 자세라, 이걸 빼먹으면
## 고함칠 때마다 팔이 A 포즈로 벌어졌다가 돌아옵니다.
const SHOUT := {
	"Spine": Vector3(16, 0, 0), "Chest": Vector3(11, 0, 0),
	"Neck": Vector3(-21, 0, 0), "Head": Vector3(-17, 0, 0),
	"LeftArm": Vector3(-75, 45, 50), "RightArm": Vector3(-75, -45, -50),
	"LeftForeArm": Vector3(0, 0, 0), "RightForeArm": Vector3(0, 0, 0),
}


## 박치기 예고. 한 손을 앞으로 천천히 뻗습니다.
##
## 예고는 **다음에 올 것과 닮아야** 합니다. 뻗은 손이 가리키는 쪽이 곧 달려올
## 쪽이라, 고리(바닥 표시)를 못 본 사람도 몸만 보고 비킬 수 있습니다.
##
## 한 손만 씁니다. 두 손을 같이 뻗으면 미는 동작(CARRY 와 비슷해집니다)으로
## 보여서, 달려오는 것과 이어지지 않습니다.
const REACH := {
	"Spine": Vector3(-6, 0, 0), "Chest": Vector3(-4, 0, 0),
	"Neck": Vector3(-8, 0, 0), "Head": Vector3(-6, 0, 0),
	"RightArm": Vector3(78, 0, -6), "RightForeArm": Vector3(6, 0, 0),
	"LeftArm": Vector3(-14, 0, 40), "LeftForeArm": Vector3(8, 0, 0),
}

## 박치기 중. 팔을 뒤로 젖히고 머리를 앞으로 수그립니다.
##
## 팔 각도는 주인공의 고함(SHOUT)과 같은 값입니다 - 같은 리그에서 실측으로
## 고른 "뒤로 벌어진 팔" 이고, 여기서도 하는 일이 같습니다(뒤로 보내서 앞으로
## 나가는 힘을 그립니다).
##
## 다른 것은 머리입니다. 고함은 젖히고 이쪽은 **수그립니다** - 그 차이 하나로
## 소리를 내는 것과 몸으로 받는 것이 갈립니다.
const RAM := {
	"Spine": Vector3(24, 0, 0), "Chest": Vector3(16, 0, 0),
	"Neck": Vector3(26, 0, 0), "Head": Vector3(20, 0, 0),
	"LeftArm": Vector3(-75, 45, 50), "RightArm": Vector3(-75, -45, -50),
	"LeftForeArm": Vector3(0, 0, 0), "RightForeArm": Vector3(0, 0, 0),
}

## 베개로 앞을 막고 선 자세. 그 적은 **늘** 이 자세입니다.
##
## 늘 걸어 두는 것이 핵심입니다. 공격할 때만 막는 자세를 하면 "지금은 막고
## 있고 지금은 아니다" 를 매 순간 읽어야 하는데, 이 적의 규칙은 그런 것이
## 아닙니다 - 앞은 언제나 막혀 있습니다. 자세가 규칙을 그대로 말해야 합니다.
##
## 팔은 잡기 자세(CARRY)보다 조금 더 앞으로, 팔꿈치를 접어 베개를 가슴에
## 안습니다. 다리는 건드리지 않습니다 - 막은 채로 걸어와야 합니다.
const GUARD := {
	"Spine": Vector3(8, 0, 0), "Chest": Vector3(5, 0, 0),
	"Neck": Vector3(6, 0, 0), "Head": Vector3(4, 0, 0),
	"LeftArm": Vector3(80, 0, 14), "RightArm": Vector3(80, 0, -14),
	"LeftForeArm": Vector3(38, 0, 0), "RightForeArm": Vector3(38, 0, 0),
}

## 베개를 머리 위로 들어 올린 예고 자세.
##
## 팔 각도는 고함(SHOUT)을 고를 때 이미 재 둔 값을 씁니다. 그 표에서
## 어깨 X = -100 은 손이 가장 높이 오르고(0.817m - 이 아이 키가 0.85m 이니
## 머리 위입니다) **두 손이 0.064m 로 모입니다.** 고함에서는 그 모이는 것이
## 문제라 -75 를 골랐지만, 여기서는 두 손으로 물건 하나를 든 자세라 오히려
## 그 값이 맞습니다.
##
## 허리는 뒤로 젖힙니다. 내리치기 전에 뒤로 가는 것이 있어야 앞으로 나오는
## 힘이 읽힙니다(RAM 의 반대 방향과 같은 이유).
const SLAM_UP := {
	"Spine": Vector3(-16, 0, 0), "Chest": Vector3(-10, 0, 0),
	"Neck": Vector3(-10, 0, 0), "Head": Vector3(-8, 0, 0),
	"LeftArm": Vector3(-100, 0, 34), "RightArm": Vector3(-100, 0, -34),
	"LeftForeArm": Vector3(14, 0, 0), "RightForeArm": Vector3(14, 0, 0),
}

## 내리친 직후. 팔을 앞아래로 뻗고 허리를 접습니다.
##
## 팔은 책을 든 자세(READ)와 같은 74/24 입니다 - 같은 리그에서 "편 팔이
## 앞아래 45도" 로 재서 고른 값이고, 여기서 필요한 것도 그것입니다.
const SLAM_DOWN := {
	"Spine": Vector3(26, 0, 0), "Chest": Vector3(16, 0, 0),
	"Neck": Vector3(20, 0, 0), "Head": Vector3(16, 0, 0),
	"LeftArm": Vector3(74, 0, 24), "RightArm": Vector3(74, 0, -24),
	"LeftForeArm": Vector3(0, 0, 0), "RightForeArm": Vector3(0, 0, 0),
}

## 등을 붙잡혀 못 움직이는 자세.
##
## 맞은 자세(HURT)와 반대로 만들었습니다. 맞을 때는 팔을 모아 **막지만**,
## 붙잡혔을 때는 팔이 앞으로 벌어져 **버둥거려야** 합니다 - 막는 자세로
## 두면 스스로 웅크린 것처럼 보여서, 뒤에 매달린 아이 때문이라는 것이
## 읽히지 않습니다.
##
## 허리를 앞으로 접는 것도 같은 이유입니다. 등에 무게가 걸린 모양입니다.
const BOUND := {
	"Spine": Vector3(20, 0, 0), "Chest": Vector3(12, 0, 0),
	"Neck": Vector3(-14, 0, 0), "Head": Vector3(-10, 0, 0),
	"LeftArm": Vector3(58, 0, 46), "RightArm": Vector3(58, 0, -46),
	"LeftForeArm": Vector3(24, 0, 0), "RightForeArm": Vector3(24, 0, 0),
}


## 주인공이 맞은 순간. 뒤로 밀리며 팔로 막습니다.
##
## 적의 HIT 와 다르게 만들었습니다. 적은 소리에 밀려 팔이 벌어지지만, 맞는
## 쪽이 주인공일 때는 **막는 동작**이 필요합니다 - 아무것도 안 하고 젖혀지기만
## 하면 맞고도 가만히 있는 것으로 보입니다. 팔을 앞으로 모아 얼굴을 가리고,
## 고개를 숙여 어깨를 웅크립니다.
const HURT := {
	"Spine": Vector3(-14, 0, 0), "Chest": Vector3(-10, 0, 0),
	"Neck": Vector3(18, 0, 0), "Head": Vector3(14, 0, 0),
	"LeftArm": Vector3(64, 0, 26), "RightArm": Vector3(64, 0, -26),
	"LeftForeArm": Vector3(52, 0, 0), "RightForeArm": Vector3(52, 0, 0),
}


## 고함에 맞은 순간. 소리에 밀려 뒤로 젖혀집니다.
##
## 뒤로 젖히는 것과 팔을 드는 것을 같이 해야 합니다. 젖히기만 하면 바람에
## 흔들린 것 같고, 팔만 들면 항복하는 것처럼 보입니다.
const HIT := {
	"Spine": Vector3(-22, 0, 0), "Chest": Vector3(-18, 0, 0),
	"Neck": Vector3(-26, 0, 0), "Head": Vector3(-20, 0, 0),
	"LeftArm": Vector3(-34, 0, 28), "RightArm": Vector3(-34, 0, -28),
	"LeftForeArm": Vector3(-30, 0, 0), "RightForeArm": Vector3(-30, 0, 0),
}


## 잡힌 쪽. 등을 잡혀 끌려가는 모양입니다.
##
## 머리와 다리를 앞으로 내밀어 몸을 활처럼 굽힙니다 - 잡힌 부위(등)가 뒤로
## 당겨지고 나머지가 끌려오는 모양이라야 "끌린다" 로 읽힙니다. 꼿꼿이 서서
## 따라오면 같이 걸어가는 것으로 보입니다.
const HELD := {
	"Spine": Vector3(-16, 0, 0), "Chest": Vector3(-12, 0, 0),
	"Neck": Vector3(24, 0, 0), "Head": Vector3(18, 0, 0),
	"LeftUpLeg": Vector3(26, 0, 0), "RightUpLeg": Vector3(26, 0, 0),
	"LeftLeg": Vector3(-20, 0, 0), "RightLeg": Vector3(-20, 0, 0),
}
