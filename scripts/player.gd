class_name Player
extends CharacterBody3D

signal breath_empty

## 조작하는 캐릭터. 이동은 카메라 기준, 조준은 마우스 기준입니다.
## 두 축을 분리해 두면 등 뒤의 적을 보면서 물러설 수 있고, 이것이 트윈스틱
## 계열 액션 로그라이크의 기본 문법입니다.

signal health_changed(hp: float, max_hp: float)
signal died
## 받아 냈습니다. 화면이 한마디 띄우고 소리를 냅니다.
signal parried

const GRAVITY := 22.0

## ── 패링 ──────────────────────────────────────────────────────────
##
## 고함은 **지르는 기술이 아니라 받아 내는 기술**입니다. 맞기 직전에 누르면
## 그 한 대를 받아 내고, 받아 낸 뒤가 이 기술의 본론입니다.
##
## 판정 창은 계통이 정합니다(`RunState.parry_window`, 0.16~0.34초). 계통을
## 파면 세지는 것이 아니라 **쉬워집니다.**

## 받아 낸 순간 세상이 느려지는 배속과, 그 시간(**실제 시간**입니다 - 느린
## 시간으로 재면 배속을 바꿀 때마다 길이가 같이 흔들립니다).
## 막기를 연달아 **두드리지** 못하게 하는 대기. 패링 창은 이 간격으로만
## 다시 열립니다 - 없으면 버튼을 떨듯이 눌러 창을 늘 열어 둘 수 있습니다.
## 누르고 **있는** 것은 이 값과 무관하게 계속 막습니다.
const PARRY_COOLDOWN := 0.50

## ── 누르고 있는 동안의 막기 ────────────────────────────────────────
##
## 막기는 **두 가지**입니다. 누르고 있으면 계속 막고(값을 치릅니다), 오는
## 것에 **맞춰 누르면** 패링이 됩니다(값이 없고 되받아칩니다).
##
## 계속 막는 쪽에 값이 없으면 누르고만 있는 것이 답이 되어, 타이밍을 맞출
## 이유가 사라집니다. 숨으로 값을 매깁니다.

## 한 대 막을 때 드는 숨.
##
## 시간당 줄이는 방식이었는데 뺐습니다 - 막는 동안 **발이 아예 묶이므로**
## 그것으로 이미 값을 치릅니다. 시간까지 재면 손을 얹고 있는 것만으로 숨이
## 마르고, 그러면 「언제 막을까」 가 아니라 「언제 떼야 안 마를까」 가 됩니다.
const BREATH_GUARD_HIT := 20.0
## 받아 낼 때 드는 숨. 막기의 절반입니다 - 맞춰 누른 값입니다.
const BREATH_PARRY := 10.0
## **막아도 새어 들어오는 몫.**
##
## 0 으로 두면 막기가 무적이 되어, 숨이 남는 한 그냥 누르고 서 있는 것이
## 답입니다. 30% 가 들어오면 **버티는 것에도 끝이 있습니다** - 언제 막고
## 언제 비킬지가 매번 다시 정해집니다. 받아 내면(패링) 0 입니다: 맞춰
## 누른 값이 「한 대를 통째로 지우는 것」이라야 맞출 이유가 생깁니다.
const GUARD_LEAK := 0.30
## **앞쪽 이만큼만 막습니다.** 뒤는 그대로 맞습니다 - 등을 조심할 이유가
## 없어지면 막기가 자세가 아니라 스위치가 됩니다(베개 아이와 같은 규칙).
const GUARD_ARC := 180.0
## **비켜서며 다리를 겁니다.**
##
## 예전에는 상대 머리 위로 솟구쳐 밟고 공중재비를 돌았습니다. 한 대 받아
## 낸 값으로는 **너무 큰 동작**이라, 받아 낼 때마다 화면이 통째로 뒤집혔고
## 판이 그때마다 끊겼습니다. 지금은 옆으로 반걸음 비켜서면서 발을 걸어
## 넘어뜨립니다 - 몸은 바닥에 붙어 있고, 끝나면 그 자리에서 이어집니다.
##
## 상대를 돌아 **뒤로 가는 데** 걸리는 시간.
const PARRY_TIME := 0.42
## 그 길의 **몇 %에서 밀까**(0~1). 다 돌아 등을 본 자리에서 밉니다.
const PARRY_TRIP_AT := 0.88
## 걸어 넘어뜨릴 때의 피해 배수와 못 일어나는 시간.
##
## **미는 힘은 밀기와 같은 값을 씁니다**(`SHOVE_KNOCK` + 스킬). 여기에 따로
## 숫자를 적어 두면 밀기를 키워도 발 걸기만 옛 세기로 남아서, 같은 손이
## 하는 두 가지가 다르게 자랍니다.
const PARRY_TRIP_MULT := 1.2
const PARRY_TRIP_STUN := 1.6

## **멀리서 쏜 것을 받아 냈을 때** 쫓아가 걸 수 있는 거리.
##
## 밀기가 닿는 거리와 같습니다 - 「받아 냈으면 밀 수 있다」 가 되려면 두
## 거리가 하나여야 합니다. 이 밖이면 피해만 지우고 끝입니다: 방 저편에서 쏜
## 것을 받아 냈다고 거기까지 날아가면, 받아 내기가 순간이동이 됩니다.
const PARRY_REACH := LUNGE_RANGE
## **때린 자리가 내 코앞이면 날아온 것**입니다.
##
## 맞붙어서 때리는 것은 때린 자리로 **적의 자리**를 넘깁니다(1~2.6m 밖).
## 날아온 것은 **탄이 터진 자리**를 넘기는데 그건 내 몸입니다. 이 거리 하나로
## 둘이 갈립니다.
##
## 처음에는 「때린 자리 근처에 적이 있나」 로 갈랐는데, 가까이서 쏜 아이가
## 그 안에 들어와 **원거리인데 맞붙기로 잡혔습니다.**
const PARRY_HIT_NEAR := 0.9

## **맞은 뒤에도 이만큼은 늦게 눌러도 받아 냅니다**(초).
##
## 창은 누른 뒤 **앞쪽으로만** 열려 있었습니다(0.16~0.34초). 뒤쪽 여유가 0 이라,
## 맞는 순간에 맞춰 누르면 이미 늦습니다 - 손은 「맞는 순간」을 겨누는데 창은
## 그 앞에만 있으니 **일찍 눌러야 하는 기술**이 됩니다. 그러면 배우는 것이
## 「맞는 순간을 보기」 가 아니라 「빨리 누르기」 가 되고, 그건 이 기술이 있는
## 이유가 아닙니다.
##
## 맞고 나서 이 안에 누르면 **그 한 대를 되돌리고** 받아 냅니다. 되돌리는 것이
## 곧 패링이 하는 일이라, 규칙이 하나 늘지 않습니다.
const PARRY_LATE := 0.10
## **거리를 좁히고 나서 비켜섭니다.**
##
## 상대가 이 거리 안이면 「바로 앞」이라 그냥 겁니다. 그보다 멀면 먼저
## 직선으로 달려가 이만큼까지 좁힌 뒤에 비켜서며 겁니다.
##
## 한동안 상대를 중심으로 **반원**을 그리며 들어갔습니다. 멀 때는 그럴듯했는데
## 코앞에서 받아 내도 반 바퀴를 돌아서, 가까울수록 동작이 더 커졌습니다 -
## 거꾸로입니다. 좁히는 일과 거는 일은 **따로**여야 합니다.
const PARRY_CLOSE := 1.05
## 좁히러 달려가는 빠르기(m/s)와 그 시간의 한도.
const PARRY_RUN_SPEED := 9.0
const PARRY_RUN_MAX := 0.34
## 잔상을 떨구는 간격(m). 구르기와 같은 규칙 - **거리마다** 떨굽니다. 시간으로
## 떨구면 멀리서 달려올 때 성기고 코앞에서 걸 때 뭉칩니다.
const PARRY_TRAIL_STEP := 0.22
## 발을 거는 동안 몸을 내리는 깊이(m). 다리를 뻗으면 발이 뜹니다.
const PARRY_CROUCH := 0.14
const ACCEL := 55.0
const FRICTION := 40.0
## 구르기: 4.0m/s 로 0.28초 = **1.12m** (1.76 -> 1.40 -> 1.12, 두 번 0.8배).
##
## 달리기(3.1m/s)의 1.29배입니다. 1.40m 일 때는 한 번 구르면 방 절반을
## 건너서, 굴러 피하기가 **아슬아슬하게 비키는 것**이 아니라 그냥 자리를
## 뜨는 것이 됐습니다. 방을 6~9칸으로 줄인 뒤로는 더 그랬습니다.
const DASH_SPEED := 4.0
const DASH_TIME := 0.28
## 동작 전체 길이. 이동(DASH_TIME)이 끝난 뒤의 남은 구간이 착지·반동·복귀
## 입니다 - 구르는 모습이 보이려면 이 꼬리가 있어야 합니다.
const ROLL_TIME := 0.50
## 한 바퀴가 끝나는 시점(동작 전체 중 비율).
##
## **이동이 끝나는 순간과 같습니다.** 예전에는 0.80 으로 못 박아 둬서 한 바퀴에
## 0.40초가 걸렸는데, 이동은 0.28초에 끝나므로 나머지 0.12초 동안 **멈춘 채로
## 계속 돌았습니다.** 굴러가는 것이 아니라 제자리에서 도는 것으로 보이던
## 이유입니다.
##
## 비율로 적어 두면 구르기 속도나 거리를 바꿔도 회전이 저절로 따라옵니다.
const ROLL_TURN := DASH_TIME / ROLL_TIME
## 마지막에 머리가 진행 방향으로 더 나가는 정도(라디안). 한 바퀴를 넘겨
## 돌았다가 되돌아옵니다.
const ROLL_OVERSHOOT := 0.35
## 잡기/밀치기. 소리 지르기보다 세고 느리고 가까이 붙어야 합니다 - 그래야
## 두 기술이 서로를 대체하지 않습니다.
## 손이 닿는 거리와 각도.
##
## **물건의 몸집을 더해서** 잽니다(_grab_distance). 중심끼리만 재면 큰 상자는
## 눈앞에 있어도 중심이 멀어서 안 잡힙니다 - 발밑에 있는데 안 잡히는 것처럼
## 느껴지던 원인입니다.
##
## 예전에는 2.4m / 160도였습니다. 몸집까지 더해서 재므로 실제로는 방 반대편
## 것도 잡히는 수준이라, 무엇이 잡힐지 눌러 보기 전에는 알 수 없었습니다.
## 좁히는 대신 **잡힐 것을 고리로 미리 보여 줍니다**(_drive_grab_hint) -
## 판정이 좁아도 답답하지 않은 이유가 그것입니다.
## 1.5m / 120도에서 한 번 더 좁혔습니다. 고리가 무엇이 잡힐지 미리 알려
## 주므로, 좁아도 "왜 안 잡히지" 가 되지 않습니다 - 고리가 없으면 안 잡히는
## 것이 눈에 보입니다.
const GRAB_RANGE := 1.25
## 잡기가 닿는 각. 160 -> 120 -> 100 -> **76** 으로 좁혀 왔습니다.
##
## 좁혀도 손해가 없는 이유는 **띠가 거짓말을 안 하기 때문**입니다 - 잡힐
## 것에는 노란 띠가 뜨고, 그 띠는 잡기 판정과 **같은 함수**로 고른 대상에
## 뜹니다. 각이 좁아도 무엇이 잡히는지는 눌러 보기 전에 보입니다.
const GRAB_ARC := deg_to_rad(76.0)
## **록온을 껐을 때**의 잡기 각. 76 -> 150 도.
##
## 록온이 꺼져 있으면 조준은 **가는 쪽**입니다(폰에는 마우스가 없습니다).
## 그래서 옆에 붙은 적을 밀려면 그쪽으로 걸어가면서 눌러야 했는데, 붙어 있는
## 상대일수록 각이 크게 벌어져서 **가까울수록 안 맞는** 거꾸로 된 일이
## 생겼습니다 - 2.6m 밖에서는 38도 안에 들지만 0.6m 앞에서는 조금만 어긋나도
## 벗어납니다.
##
## 넓혀도 손해가 없는 이유는 **고리가 거짓말을 안 하기 때문**입니다. 고리는
## 이 함수가 고른 대상 아래에 깔리므로(`_drive_grab_hint`), 각이 넓어지면
## 고리도 같이 넓어집니다 - 무엇이 밀릴지는 누르기 전에 보입니다.
const GRAB_ARC_FREE := deg_to_rad(150.0)
## 넓힌 각에서 **정면을 얼마나 우대하는가**(m/라디안).
##
## 그냥 넓히기만 하면 "가장 가까운 것" 이 이겨서, 정면 1.2m 를 겨누고 눌렀는데
## 어깨 뒤 0.9m 가 밀립니다. 각을 거리로 환산해 더합니다 - 1.0 이면 60도
## 벌어진 적은 1.05m 더 먼 것으로 칩니다.
const GRAB_ANGLE_COST := 1.0
const SHOVE_MULT := 1.7
## **고함의 피해는 밀기의 절반**입니다. 앞을 통째로 쓸고(132°) 값도 싸므로
## (숨 10), 밀기와 같이 아프면 밀기를 쓸 이유가 없어집니다.
##
## 밀기 배수에 곱해서 뽑습니다 - 밀기를 손보면 고함이 따라옵니다. 여기 숫자를
## 따로 적어 두면 둘이 반드시 갈라집니다.
const SHOUT_MULT := SHOVE_MULT * 0.5
## 달려드는 속도와 시간.
##
## 배율 1.0 = **평소 달리는 속도 그대로**입니다. 예전에는 2.4배(7.4m/s)로
## 튀어 나갔는데, 달려가는 것이 아니라 쏘아지는 것으로 보였고 다리도 그
## 속도를 따라가지 못했습니다.
##
## 속도를 낮추면 같은 거리를 가는 데 더 걸립니다. 시간과 사거리를 함께
## 맞췄습니다 - 2.6m 를 3.1m/s 로 가면 0.84초입니다.
const LUNGE_SPEED := 1.0
const LUNGE_TIME := 0.85
## 달려들기 시작할 수 있는 거리. 이 시간 안에 닿을 수 있는 만큼만 잡습니다 -
## 더 멀리서 시작하면 못 닿고 끝나는 헛손질이 늘어납니다.
const LUNGE_RANGE := 2.6
## 손끝이 몸 밖으로 나가는 여유. 0 으로 두면 살이 정확히 겹쳐야 해서,
## 서로 밀어내는 충돌 때문에 영영 안 닿습니다.
const HAND_REACH := 0.12
## 손을 앞으로 내미는 시점. 닿는 거리에 이만큼을 더한 데서 자세를 바꿉니다.
##
## 0.70m 면 달리는 속도(3.1m/s)로 0.22초 앞입니다 - 뻗는 것이 눈에 보이고,
## 뻗은 채로 달려온 것처럼 보이지도 않는 사이입니다.
const REACH_LEAD := 0.70
## 팔을 다 뻗는 데 걸리는 시간의 하한. 보통은 거리가 정하지만, 상대를 쫓아가는
## 동안에도 이 속도로는 뻗어 나갑니다.
const LUNGE_SWING_TIME := 0.16
## 밀기가 성공했을 때 적이 밀려나는 세기.
## 밀기가 밀어내는 세기(m/s). take_damage 쪽에서 1.5m/s 가 먼저 들어가므로
## 합쳐서 3.0m/s 입니다 - 주인공이 달리는 속도(3.1)와 비슷한 정도이고,
## 느슨한 감속(8m/s^2)에서 0.55m 쯤 밀려납니다. 한 걸음 반입니다.
## 밀기가 밀어내는 속도(m/s). 주인공이 달리는 속도(3.1)와 비슷합니다.
##
## 밀린 뒤에는 8m/s^2 로 잦아들므로 **0.55m** 쯤 밀려납니다 - 한 걸음 반입니다.
## 예전에는 두 곳에서 들어간 값이 합쳐져 18.5m/s(5.7m)였습니다.
## 미는 세기(m/s). 3.0 -> **3.6**(1.2배)입니다.
##
## 던지기와 나란히 놓고 보니 밀기가 너무 얌전했습니다. 던지기는 잡는 값을
## 치르는 만큼 더 가야 하지만, 여섯 배는 "다른 기술" 이지 "큰 형" 이
## 아닙니다 - 밀기를 올리고 던지기를 내려 둘을 나란히 맞췄습니다
## (enemy.gd 의 THROW_PUSH).
const SHOVE_KNOCK := 3.6
const PUSH_TIME := 0.42
## 밀기 대기. **연격(밀기 Lv2)이면 절반**입니다.
##
## 0.95 에서 0.55 로 줄였습니다. 대기가 길면 밀기가 "가끔 쓰는 것" 이 되는데,
## 이 게임의 기본기는 밀기입니다. 막는 일은 숨(8)이 합니다.
const GRAB_COOLDOWN := 0.55
## 고함 대기. 0.55 -> 0.34.
const SHOUT_COOLDOWN := 0.34


func _grab_cooldown() -> float:
	## 밀기 대기. **「밀기」 Lv2(연격)면 절반**입니다 - 연달아 밀 수 있게
	## 하는 것이 그 단계가 파는 물건입니다.
	if state != null and state.has_push_combo():
		return GRAB_COOLDOWN * 0.5
	return GRAB_COOLDOWN
const THROW_MULT := 1.5

const ATTACK_RANGE := 2.7


## 필살기. 규칙은 전부 `scripts/ultimate.gd` 에 있고 여기서는 **몸을 움직이는
## 일**만 합니다 - 판단과 연출을 섞으면 동작을 더할 때마다 두 곳이 함께
## 자랍니다.
var ultimate := Ultimate.new()
## 필살 모드에서 켜지는 파란 기운. 모드가 끝나면 지웁니다.
var _aura: Node3D
## 잔상을 남길 때까지 남은 시간. 모드 동안에는 **모든 움직임**에 남깁니다.
var _aura_trail := 0.0
## 필살 모드에서 이미 들른 적. 구르기를 연달아 누르면 다음 적으로 갑니다.
var _ult_visited: Array = []
signal ultimate_changed(ratio: float, on: bool, note: String)


func note_hit() -> void:
	## **적을 한 대 때렸습니다.** 용기가 여기서만 찹니다.
	##
	## 때리는 자리가 여럿이라(고함·밀기·던지기·부딪힘) 각자 게이지를 올리면
	## 하나를 더할 때마다 빠뜨립니다. 한 군데로 모읍니다.
	var before := ultimate.ratio()
	ultimate.add_hit()
	if ultimate.ratio() != before:
		ultimate_changed.emit(ultimate.ratio(), ultimate.active, "")


func skill_lv(fam: String) -> int:
	## 계통 레벨. **3 부터 이펙트가 붙고 5 부터 강해집니다.**
	##
	## 눈에 보이는 것을 레벨에 매다는 이유: 수치만 오르면 무엇을 골랐는지
	## 화면에 남지 않습니다. 파고 있는 계통이 기술을 볼 때마다 드러나야
	## "이 판은 구르기 판" 이 됩니다.
	return state.family_level(fam) if state != null else 0


## 이펙트의 **세기는 실제로 오른 값에서** 뽑습니다.
##
## 계통 Lv 는 "이 계통을 파고 있다" 까지만 말합니다(3 부터 이펙트가 붙습니다).
## 그 위의 세기 - 잔상 장수와 진하기, 아지랑이 크기, 구슬 개수 - 는 찍은
## 스킬이 실제로 올린 값에서 나옵니다.
##
## 계통 Lv 로 세기까지 정하면 **이펙트가 거짓말을 합니다.** 밀기 계통에는
## (옛 이야기입니다. 그때는 밀기 계통에 「억센 손」·「밀치는 힘」·「긴 팔」
## 셋이 들어 있었고, 긴 팔만 세 번 찍으면 넉백은 그대로인 채 세게 밀리는 그림이
func shout_range() -> float:
	## 고함이 닿는 거리. 스킬로 늘어납니다 - 파문 크기도 이 값에서 나오므로
	## (_show_shout), 늘리면 **보이는 것과 닿는 것이 같이** 커집니다.
	return ATTACK_RANGE + (state.shout_range if state != null else 0.0)
## 록온이 반응하는 거리가 **밀기 사거리보다 얼마나 넓은가**(m).
##
## 닿기 직전에 몸이 돌아가기 시작하라는 값입니다. 예전에는 11m 였는데, 방
## 반대편 적에게도 몸이 돌아가서 **가려는 방향과 보는 방향이 계속
## 어긋났습니다.**
const AUTO_AIM_MARGIN := 1.2


func lock_on_range() -> float:
	## 록온이 반응하는 거리. **밀기(달려들기) 사거리를 따라갑니다.**
	##
	## 3.9m 로 박아 두었던 값입니다. 그때는 고함 사거리(2.7)보다 조금 넓게
	## 잡은 것이었는데, 그 뒤로 고함이 **모은 만큼 1.29~5.7m** 로 변하게
	## 되면서 어느 값과도 안 맞게 됐습니다 - 고함을 판 사람은 겨눌 수 있는
	## 적에게 록온이 안 걸렸습니다.
	##
	## 밀기에 맨 이유: 록온이 실제로 필요한 순간은 **붙어서 미는 순간**입니다.
	## 고함은 부채꼴이 넓어서 대충 그쪽만 보면 맞지만, 밀기는 한 사람을
	## 정확히 겨눠야 하고 등 뒤냐 앞이냐까지 갈립니다.
	##
	## **「긴 팔」은 걷어냈습니다.** 스킬 스무 개를 여섯 계통으로 줄일 때
	## 이미 빠졌는데(`_recompute` 가 안 건드려서 늘 0), 값만 죽은 채 남아
	## 있었습니다 - 더해도 아무 일이 안 일어나는 항이 식에 남아 있으면
	## 다음에 읽는 사람이 "찍으면 늘어나는구나" 로 잘못 압니다.
	##
	## 사거리를 늘리는 것 자체가 별로였습니다: 달려드는 거리가 길어지면 더
	## 멀리서 밀 수 있는 대신 **달려가는 동안 무방비인 시간**이 같이 길어져서,
	## 이득이 거의 없습니다.
	return LUNGE_RANGE + AUTO_AIM_MARGIN
const ATTACK_ARC := deg_to_rad(110.0)
const SWING_TIME := 0.30
const HIT_INVULN := 0.45
## 허리 높이. 구르기 회전축이자 몸통 노드의 기준입니다.
const HIP := 0.55
## 구르는 동안 회전축이 올라가는 높이. 꼭대기에서 HIP 의 1.5배가 됩니다.
##
## 예전에는 반대로 **내려갔습니다**(HIP 의 0.48배까지). 바닥을 스치는 그림을
## 노린 것인데, 회전축이 발치에 붙으니 구르는 것이 아니라 바닥에 누워 비비는
## 것처럼 보였습니다. 축이 올라가야 몸이 바닥에서 떠서 넘어가는 것으로
## 읽힙니다.
const ROLL_LIFT := HIP * 0.5
## 구르고 나온 직후 빨라지는 시간과 배율(「이속」 Lv2).
##
## 0.55초는 한 걸음 반쯤입니다 - 더 길면 그냥 이동 속도가 오른 것이 되고,
## 더 짧으면 손에 안 잡힙니다.
const ROLL_BURST_TIME := 0.55
const ROLL_BURST_MULT := 1.35

## ── 자동차 질주 ──────────────────────────────────────────────────
##
## 타면 **정해진 시간 동안 무적으로 방을 휘젓습니다.** 조종은 못 합니다 -
## 조종되면 그냥 "빨라지고 무적인 상태" 라 다른 기술이 다 쓸모없어집니다.
## 못 모는 대신 아무 대가도 없고(숨도 안 듭니다), 그래서 몰렸을 때 "도망갈까"
## 말고 다른 답이 하나 생깁니다.
const JOY_TIME := 3.4
const JOY_SPEED := 7.2
## 부딪힌 적이 받는 피해 배율과 닿는 거리.
const JOY_DAMAGE := 1.6
const JOY_REACH := 1.15
## 방향을 새로 뽑는 주기. 짧으면 제자리에서 떨고, 길면 벽만 보고 갑니다.
const JOY_TURN_EVERY := 0.62
## 부딪힌 적을 밀어내는 힘.
const JOY_KNOCK := 7.0
## 조작이 방향을 끌어당기는 세기(초당).
##
## 1.1 로 두었더니 **아무 소용이 없었습니다** - 0.62초마다 ±2 라디안씩 제멋대로
## 꺾는 힘이 훨씬 세서, 밀고 있는 쪽의 반대로 가는 일이 잦았습니다. 끌어당기는
## 힘을 3.5 로 올리고, 무엇보다 **꺾는 기준을 밀고 있는 쪽으로** 바꿨습니다.
##
## 그래도 조종은 안 됩니다. 흔들리는 폭이 ±0.9 라디안(±52도)이라 원하는 곳에
## 딱 가지는 못하고, 밀어붙이면 대충 그쪽으로 향합니다 - 모는 것이 아니라
## **떼를 쓰는** 정도입니다.
const JOY_STEER := 3.5
## 클립 재생 배속. test3 의 걷기 사이클은 32프레임/24fps 라 한 걸음에 1.3초로,
## 초당 6.5m 로 달리는 캐릭터에 붙이면 미끄러지듯 보입니다.
## 클립이 **1배속에서 바닥을 미는 속도**(m/s). 재생 속도를 여기에 맞추면
## 발이 미끄러지지 않습니다.
##
## 손으로 정한 값이 아니라 실측입니다(`run.bat --pose=stride`,
## `--pose=striderun`). 발 본에 앵커를 붙여 몸 기준 로컬 좌표에서 뒤로 가는
## 발의 이동을 4초간 더했습니다:
##
##     걷기  1.292초  4초에 2.575m  ->  0.644 m/s
##     달리기 0.958초  4초에 4.372m  ->  1.093 m/s
##
## 골반을 올리고(tools/raise_hips.py) 무릎 방향을 바로잡은 뒤(make_kids.py 의
## fix_knees) 다시 잰 값입니다. **리그나 클립을 손대면 반드시 다시 재야
## 합니다** - 무릎 하나 뒤집었을 뿐인데 보폭이 1.7배가 됐습니다.
##
## 모델을 바꾸거나 클립을 다시 구우면 **이 값도 다시 재야 합니다.** 보폭은
## 다리 길이와 흔드는 각도에서 나오므로 캐릭터마다 다릅니다.
const WALK_GROUND := 0.624
const RUN_GROUND := 1.093
## 이보다 느리면 서 있는 것으로 봅니다. 0 에 가까울 때까지 걷기를 돌리면
## 제자리에서 발만 까딱입니다.
## 뒤로 갈 때의 이동 배율.
const BACK_SPEED := 0.6

const MOVE_ANIM_MIN := 0.35
## 뒷걸음질 클립이 1배속에서 바닥을 미는 속도(m/s). 거꾸로 돌린 값이라
## 앞걸음과 자가 조금 다릅니다 - 재는 방법이 "두 발 중 더 많이 민 쪽" 이어서
## 부호를 뒤집으면 고르는 발이 달라집니다. `--pose=skate --face=180` 으로
## 실측해 맞춥니다.
## 실측: 이 값에서 발/몸 = 1.03~1.05.
const BACK_GROUND := 0.417

## 지금 뒷걸음질 중인가. 문턱 사이에서는 이 값을 그대로 유지합니다.
## 어깨 너머에서 이동 입력을 해석하는 기준 각도. 손을 뗄 때만 갱신합니다.
var _move_yaw := 0.0

var _moving_back := false
## 이번 구르기에서 이미 친 적. 구르기가 시작될 때마다 비웁니다.
var _pierced: Dictionary = {}
## 달려드는 중인 상대와 남은 시간. 손이 닿거나 시간이 다하면 끝납니다.
var _lunge_at: Node3D = null
var _lunge_time := 0.0
## 팔이 얼마나 앞으로 나왔는가. 0 이면 뒤로 젖힌 채, 1 이면 다 뻗은 것입니다.
##
## 예전에는 참/거짓이었습니다. 그래서 닿기 직전에 자세가 통째로 바뀌며 팔이
## 한 프레임에 159도를 건너뛰었습니다 - 뒤로 젖힌 그림과 뻗은 그림 둘뿐이라
## **뻗는 동작 자체가 없었습니다.**
var _lunge_swing := 0.0
## 섞은 결과를 담아 두는 그릇. 매 프레임 새로 만들지 않으려고 재사용합니다.
var _lunge_pose: Dictionary = {}
## 밀친 뒤 뻗은 팔을 잠깐 붙들어 두는 시간. 닿자마자 팔이 풀리면 친 것이
## 아니라 스친 것으로 보입니다.
const SHOVE_HOLD := 0.12
var _shove_hold := 0.0
## 우유를 마시는 데 걸리는 시간. 이 동안은 다른 것을 못 합니다.
##
## 짧으면 집는 것과 구분이 안 되고, 길면 적 앞에서 못 씁니다. 서진의
## 박치기 예고(0.62초)보다 조금 길게 둬서, **눈앞에서 마시면 맞습니다** -
## 언제 마실지가 판단이 되도록.
## 책 한 권을 읽는 데 걸리는 시간. 다 읽으면 기술 고르기가 열립니다.
##
## 마시기(0.85초)보다 깁니다. 회복은 급할 때 쓰는 것이고 독서는 여유가 있을
## 때 하는 것이라, **길이 자체가 "지금 할 일인가" 를 묻습니다.** 이 동안에는
## 고함도 구르기도 못 하므로 적 앞에서 읽으면 그대로 맞습니다.
## 읽기는 네 마디입니다. 한 동작으로 뭉뚱그리면 "책이 손에 생겼다" 로만
## 보입니다 - 다가가 꺼내고, 물러나며 돌고, 펴는 것이 다 보여야 이야기입니다.
##
##   1. 뻗기     책장으로 오른손을 뻗으며 다가갑니다.
##   2. 빼기     덮인 책이 책장에서 손으로 빠져나옵니다.
##   3. 물러나기 오른쪽 뒤로 물러나며 몸을 조금 돌립니다.
##   4. 펴기     왼손을 책 위에 얹어 좌우로 폅니다.
const READ_REACH := 0.50
const READ_PULL := 0.28
const READ_BACK := 0.52
const READ_OPEN := 0.70
const READ_TIME := READ_REACH + READ_PULL + READ_BACK + READ_OPEN
## 물러나며 몸을 트는 각도(라디안). 화면을 정면으로 볼 필요는 없고, 돌아섰다는
## 것만 보이면 됩니다.
const READ_TURN_ANGLE := 1.05
var _read_time := 0.0
## 손에 든 책. 엔진 기본 도형으로 그 자리에서 만듭니다 - 모델을 따로 굽기엔
## 너무 단순하고, 색만 바뀌면 되는 물건입니다.
var _book: Node3D
## 읽는 동안 바라볼 쪽. 자동 조준이 몸을 돌리지 못하게 붙들어 둡니다.
var _read_face := Vector3.ZERO
## 돌기 시작할 때 보고 있던 쪽. 여기서 _read_face 까지 **이어서** 돕니다.
var _read_from_face := Vector3.ZERO
## 책이 빠져나오는 자리(책장의 책 높이).
var _read_shelf_at := Vector3.ZERO
## 펼침 정도를 먹일 책의 두 쪽. [노드, 다 폈을 때의 각도] 입니다.
var _book_halves: Array = []
## 섞은 읽기 자세를 담아 두는 그릇과, 지금 펼쳐진 정도(0~1).
var _read_pose: Dictionary = {}
var _book_open := 0.0
signal read_done

const DRINK_TIME := 0.85
## 마시는 동안 우유갑을 손보다 얼마나 위에 두는가. 손이 닿는 높이와 입
## 높이의 차이입니다.
const DRINK_LIFT := 0.15
var _drink_time := 0.0
## 마시는 도중 두 번째 "꿀꺽" 을 이미 냈는가.
var _gulped := false
## 지금 누르면 잡히는 소품 아래에 깔리는 고리. 하나를 만들어 옮겨 씁니다.
var _grab_hint: MeshInstance3D
var _grab_hint_mat: StandardMaterial3D
var _hint_t := 0.0
## 내 몸 반지름. 손이 닿았는지 볼 때 씁니다.
var _body_radius := 0.42

var state: RunState
var rng: RandomNumberGenerator

var pivot: Node3D
## 절차적 몸통 움직임 전용 노드. 조준(pivot)과 분리해 둬야 둘이 안 싸웁니다.
var body: Node3D
var _anim: AnimationPlayer
var _walk := ""
var _run := ""
var _back := ""
var _idle := ""
var _push_clip := ""
## 걷기 클립이 없는 모델이면 걸음 반동까지 몸통으로 만들어야 합니다.
## 클립이 있으면 반동은 클립이 내므로, 몸통 쪽은 살짝만 거듭니다.
var _procedural := false
var _step_phase := 0.0
var _roll_time := 0.0
var _roll_probe := false
var stride_probe := false
## 들고 있는 것. 소품일 수도 적일 수도 있습니다.
var _held: Node3D = null
## 손을 따라다니는 앵커. 한 번만 만듭니다.
var _left_hand: BoneAttachment3D = null
var _right_hand: BoneAttachment3D = null
var _anchors_done := false
## 숨이 다시 차기까지 남은 뜸.
## 쿨다운을 걸 때의 처음 값. 화면에 "얼마나 남았나" 를 그리려면 남은 시간만
## 으로는 부족합니다 - 전체가 얼마인지 알아야 비율이 나옵니다.
var _attack_cd_max := 0.55
var _dash_cd_max := 1.0
var _grab_cd_max := 1.0
var _breath_pause := 0.0
var _breath_warn := 0.0
## 연타 셈. 마지막으로 쓴 기술, 몇 번째인지, 얼마나 남았는지.
var _repeat_kind := ""
var _repeat_n := 0
var _repeat_t := 0.0
## 대기 중에 눌러 둔 잡기. 풀리면 바로 나갑니다.
var _grab_queued := 0.0
## 마지막으로 스틱(방향키)이 가리킨 쪽과 그 기억이 남아 있는 시간.
var _last_dir := Vector2.ZERO
var _last_dir_time := 0.0
## 던지기 예비동작. 도는 동안에도 물건은 손에 붙어 있습니다.
var _throw_time := 0.0
var _throw_dir := Vector3.FORWARD
var _push_time := 0.0
var _push_hit := false
var _grab_cd := 0.0
var _jiggle: Jiggle
## 클립 위에 구르기·잡기 자세를 겹치는 층.
var _pose: PoseOverride
var _ragdoll: PhysicalBoneSimulator3D
var _last_hit_from := Vector3.ZERO

var aim := Vector3.FORWARD

## 등을 붙잡혀 못 움직이는 동안 남은 시간. 0 이면 자유입니다.
var _bound_time := 0.0
## 붙잡고 있는 아이. 빠져나갈 때 그쪽에도 알려야 둘이 같이 풀립니다.
var _bound_by: Node3D = null
## 버둥거림(버튼 연타)이 화면에 보이도록 남기는 시간.
var _struggle_show := 0.0
var _attack_cd := 0.0
var _swing_time := 0.0

## **실험 중인 베개싸움이 거는 고리 셋.** 평소에는 `null` · `1.0` · 빈 것이라
## 아무 일도 안 합니다 - 어린이집 탐험의 동작은 한 톨도 안 바뀝니다.
##
## 걷어낼 때는 이 셋과 아래 세 자리(공격 입력 · 걸음 배율 · 자세 층)만 지우면
## 됩니다.
var attack_hook: Object = null
var ext_move_scale := 1.0
## 밖에서 걸어 주는 상체 자세. 베개를 휘두를 때 **허리와 골반이 같이 트는**
## 몫이 여기로 들어옵니다(팔은 IK 가 맡으므로 안 들어 있습니다).
var ext_pose: Dictionary = {}
## 지금 눌러 둔 패링 판정 창. 0 보다 크면 오는 한 대를 받아 냅니다.
var _parry_ready := 0.0
## 받아 내고 비켜서는 동안의 남은 시간. 0 보다 크면 조작을 안 받습니다.
var _parry_air := 0.0
## 발 걸기가 이미 들어갔나. 한 번만 들어가야 합니다.
var _parry_hit := false
var _parry_foe: Node3D = null
## 비켜서서 설 자리. 받아 낸 순간 정해 둡니다 - 가는 동안 상대가 밀려나므로,
## 그때 가서 뽑으면 설 자리가 상대를 따라 흔들립니다.
var _parry_to := Vector3.ZERO
## 좁히러 달려가는 시간(0 이면 바로 앞이라 안 달립니다)과 그 끝 자리.
var _parry_run := 0.0
var _parry_run_to := Vector3.ZERO
## 도는 쪽(+1 / -1)과, 잔상을 떨군 뒤 지나온 거리.
var _parry_spin := 1.0
var _parry_trail := 0.0
## 이번 프레임에 가고 싶은 속도. **자리를 직접 옮기지 않습니다** - 옮기면
## 충돌을 아예 안 거쳐서 벽을 뚫고 방 밖으로 나갑니다(실제로 그랬습니다).
var _parry_vel := Vector3.ZERO
## 방금 맞은 한 대. 늦게 눌렀을 때 되돌릴 것들입니다.
var _late_hit := 0.0
var _late_from := Vector3.ZERO
var _late_amount := 0.0
## 뛰어오르기 전 자리. 앞발로 차면 여기보다 조금 **뒤로** 내려섭니다.
var _parry_from := Vector3.ZERO
## 느려진 시간이 끝나는 **실제** 시각(ms).
var _parry_cd := 0.0
## 막는 자세가 남는 시간. 판정 창(0.16~0.34초)보다 조금 길게 둡니다 - 창과
## 똑같이 두면 자세가 들어가기도 전에 풀려서, 눌렀는데 아무 그림도 안 납니다.
var _guard_pose := 0.0
## 막기 버튼을 누르고 있나.
var _guard_held := false
const GUARD_POSE_MIN := 0.30
## 막는 동안 몸을 내리는 깊이(m).
##
## 엉덩이 높이는 `HIP` 로 **고정**입니다. 그래서 무릎만 접으면 발이 바닥에서
## 떠오릅니다(재 봤습니다: 0.03m 에서 0.11m 로). 접은 만큼 몸을 내려야 오른발이
## 바닥에 남습니다 - 구르기가 몸을 띄우는 것(`ROLL_LIFT`)과 같은 자리입니다.
const GUARD_CROUCH := 0.09
## 구르고 나온 직후의 질주가 남은 시간(「이속」 Lv2).
var _roll_burst := 0.0
## 지난 프레임에 구르는 중이었나. 끝나는 **그 프레임**을 잡으려는 값입니다.
var _was_rolling := false
## 자동차를 타고 달리는 동안 남은 시간.
var _joy_time := 0.0
## 지금 타고 있는 자동차.
var _joy_car: Prop = null
## 지금 달려가는 쪽. 벽에 부딪히거나 때가 되면 새로 뽑습니다.
var _joy_dir := Vector3.ZERO
## 다음에 방향을 새로 뽑기까지 남은 시간.
var _joy_turn := 0.0
## 이번 질주에서 이미 친 적. 한 번씩만 칩니다 - 안 그러면 붙어 있는 적을
## 매 프레임 쳐서 즉사시킵니다.
var _joy_hit: Dictionary = {}
## 고함을 모은 정도(0~1). **-1 이면 모으는 중이 아닙니다.**
## 이번에 지른 고함이 얼마나 모은 것인가. 판정과 그림이 같이 씁니다.
var _shout_fired := 1.0
## 모으는 동안 도는 목소리. 손을 떼면 끊습니다.
var _shout_voice: AudioStreamPlayer = null
## 모으는 동안 발밑에 자라는 부채꼴.
var _shout_prev: MeshInstance3D = null
var _shout_prev_mat: StandardMaterial3D = null
## 모으는 동안 입에서 뻗는 소용돌이.
var _shout_vortex: Node3D = null
## 지른 뒤 소용돌이가 스러지는 시간(초).
const VORTEX_FADE := 0.30
## 구가 선 위를 흘러간 정도(0~1). 상태는 **부르는 쪽이** 듭니다.
var _shout_flow := 0.0
## 고함 자세를 붙잡고 있는 시간. 판정(_swing_time, 0.30초)보다 깁니다.
##
## 목소리 클립이 1.05초인데 자세가 0.30초에 풀리면, 아직 지르고 있는데 아이는
## 이미 차렷으로 돌아와 있습니다. 파문을 목소리에 맞춘 것과 같은 이유입니다.
## 목소리 끝까지 끌지는 않았습니다 - 팔을 1초 내내 뒤로 둔 채 뛰면 그건
## 고함이 아니라 달리는 자세가 됩니다.
const SHOUT_POSE_TIME := 0.62
var _shout_hold := 0.0
var _swing_hit := false
var _dash_cd := 0.0
var _dash_time := 0.0
## 구르며 잔상을 떨군 뒤 지나간 거리(m).
var _roll_trail := 0.0
var _dash_dir := Vector3.FORWARD
var _invuln := 0.0
var _dead := false

## 자동 플레이(--bot) 가 켜지면 키보드 대신 이 값들이 들어옵니다.
var bot_active := false
var bot_move := Vector2.ZERO

## 화면 조작(폰)에서 들어오는 값. 키보드 입력과 더해집니다.
var touch_move := Vector2.ZERO
## 록온. 켜면 가장 가까운 적을 겨눕니다. **기본은 끔**입니다.
var auto_aim := false
## 마우스로 겨누는가. **화면 조작(폰)에서는 false** 입니다.
##
## 폰에는 마우스가 없는데 `get_mouse_position()` 은 **마지막으로 닿은 자리**를
## 계속 돌려줍니다. 그래서 록온을 끄면 몸이 조금 전에 누른 버튼 쪽을 향한 채로
## 굳고, 걸어가는 쪽과 보는 쪽이 따로 놉니다 - 게걸음으로 걷는 것처럼
## 보입니다. 그럴 때는 **가는 쪽**이 조준입니다.
var mouse_aim := true


func setup(run_state: RunState, generator: RandomNumberGenerator) -> void:
	state = run_state
	rng = generator
	ultimate.setup(run_state)

	collision_layer = 1 << 1
	# 벽/바닥(1) + 적(1<<2) + 소품(1<<4). 셋 다 몸으로 부딪힙니다.
	collision_mask = 1 | (1 << 2) | (1 << 4)
	floor_snap_length = 0.4

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	var dims: Dictionary = Models.size_of(Models.HERO)
	capsule.radius = float(dims["radius"]) * 0.85
	_body_radius = capsule.radius
	capsule.height = float(dims["height"])
	shape.shape = capsule
	shape.position = Vector3(0, capsule.height * 0.5, 0)
	add_child(shape)

	# 발밑 그림자. 몸통보다 **넓게** 깔아야 보입니다 - 내려다보는 각도라
	# 몸이 그림자를 거의 다 가려서, 좁게 깔면 발끝에 붉은 자국만 남습니다
	# (실제로 시험해 보고 넓혔습니다).
	Models.add_shadow(self, capsule.radius * 1.9)

	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	body = Node3D.new()
	body.name = "Body"
	# 몸을 허리 높이에 두고 모델을 그만큼 내려 답니다. 이렇게 해야 body 를
	# 돌릴 때 **허리를 중심으로** 돕니다. 발을 중심으로 돌면 앞구르기가 아니라
	# 발목을 축으로 한 재주넘기가 됩니다.
	body.position.y = HIP
	pivot.add_child(body)
	var model := Models.spawn(Models.HERO)
	model.position.y = -HIP
	body.add_child(model)
	_anim = Models.find_anim(model)
	_walk = Models.clip(_anim, "Walk")
	_idle = Models.clip(_anim, "Idle")
	_push_clip = Models.clip(_anim, "Push") if _anim != null and _anim.has_animation("Push") else ""
	_run = Models.clip(_anim, "Run") if _anim != null and _anim.has_animation("Run") else ""
	_back = Models.clip(_anim, "Back") if _anim != null and _anim.has_animation("Back") else ""
	if _anim != null and _idle != "":
		_anim.play(_idle)
	# 클립이 없는 모델(예전 도원 리그)이면 걸음 반동까지 몸통으로 만듭니다.
	_procedural = _walk == ""
	_jiggle = Models.add_jiggle(model)
	_pose = Models.add_pose(model)
	_ragdoll = Ragdoll.build(Models.find_skeleton(model))

	add_to_group("player")


# ---------------------------------------------------------------- 루프

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_shove_hold = maxf(0.0, _shove_hold - delta)
	_slip = maxf(0.0, _slip - delta)
	_drive_grab_hint(delta)
	if _read_time > 0.0:
		_read_time -= delta
		_drive_read(delta)
		if _read_time <= 0.0:
			_finish_read()
	if _drink_time > 0.0:
		_drink_time -= delta
		if not _gulped and _drink_time <= DRINK_TIME * 0.45:
			_gulped = true
			_gulp()
		if _drink_time <= 0.0:
			_finish_drink()
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_grab_cd = maxf(0.0, _grab_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	# **놓았으면 되돌립니다.** `_held` 가 그 아이가 아니게 된 순간이 곧
	# 놓은 순간입니다 - 어느 갈래로 놓였든(던졌든 맞았든 죽었든) 여기를
	# 지나갑니다.
	if _pass_with != null and _held != _pass_with:
		if is_instance_valid(_pass_with):
			remove_collision_exception_with(_pass_with)
		_pass_with = null
	_parry_ready = maxf(0.0, _parry_ready - delta)
	_late_hit = maxf(0.0, _late_hit - delta)
	_parry_cd = maxf(0.0, _parry_cd - delta)
	if guarding():
		_guard_pose = maxf(_guard_pose, 0.12)
	_guard_pose = maxf(0.0, _guard_pose - delta)
	# **되돌리는 쪽을 잊으면 웅크린 채로 걸어 다닙니다.** 구르기가 자기
	# 높이를 쓰는 동안에는 건드리지 않습니다.
	if _guard_pose <= 0.0 and _roll_time <= 0.0 and _parry_air <= 0.0 			and body != null and not is_equal_approx(body.position.y, HIP):
		body.position.y = HIP
	# **잔상 열두 장은 층이 시작될 때 미리 짓습니다.**
	#
	# 첫 구르기에서 지으면 그 프레임이 통째로 값입니다(실측 10.3ms). 층
	# 시작은 어차피 한 번 걸리는 자리라 여기 얹는 편이 낫습니다.
	if _ghost_pool.is_empty():
		_build_ghost_pool()
	_tick_parry(delta)
	_drive_ghosts(delta)
	state.elapsed += delta

	if _parry_air > 0.0:
		# **받아 내고 도는 동안의 걸음**입니다. `_tick_parry` 가 정해 둔
		# 속도를 그대로 씁니다 - 자리를 직접 옮기지 않고 속도로 가야
		# `move_and_slide` 가 벽에서 멈춰 줍니다.
		velocity = _parry_vel
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	_update_aim()

	if _joy_time > 0.0:
		# **자동차를 타는 동안에는 다른 것이 아무것도 안 됩니다.** 걷지도,
		# 구르지도, 밀지도 못합니다 - 못 모는 것이 이 물건의 값입니다.
		_drive_joyride(delta)
	elif _bound_time > 0.0:
		# 붙잡혀 있으면 걷지도 구르지도 못합니다. 구르기는 애초에 들어올 수
		# 없지만(_try_dash 가 막습니다), 붙잡히기 직전에 시작한 구르기가
		# 남아 있을 수 있어 여기서도 끊습니다.
		_dash_time = 0.0
		_struggle(delta)
	elif _dash_time > 0.0:
		_dash_time -= delta
		# 구르는 거리는 **속도로** 늘립니다. 시간을 늘리면 무적 시간까지
		# 같이 늘어나서, 거리 강화가 생존 강화가 됩니다.
		# 잔상은 **거리마다** 떨굽니다. 시간으로 떨구면 빨리 구를 때 성기고
		# 느릴 때 뭉칩니다.
		_roll_trail += DASH_SPEED * (1.0 + state.roll_dist) * delta
		if _roll_trail > 0.34:
			_roll_trail = 0.0
			_roll_afterimage()
		var roll_speed := DASH_SPEED * (1.0 + state.roll_dist)
		velocity.x = _dash_dir.x * roll_speed
		velocity.z = _dash_dir.z * roll_speed
	else:
		_ground_move(delta)

	_shout_hold = maxf(0.0, _shout_hold - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_hold_min = maxf(0.0, _hold_min - delta)
	if _roll_time > 0.0 and state.has_roll_damage():
		_roll_pierce_hits()
	# 구르기가 **막 끝난 프레임**을 잡습니다. 끄는 곳(_try_dash)과 켜는 곳을
	# 떨어뜨려 두면, 어느 갈래로 구르기가 끝나든(맞아서·붙잡혀서·층이
	# 바뀌어서) 통과가 남지 않습니다.
	var rolling := _roll_time > 0.0 or _dash_time > 0.0
	if _was_rolling and not rolling:
		collision_mask |= (1 << 2)
		# **「이속」 Lv2**: 구르고 나온 직후 잠깐 빨라집니다. 구르기를 도망이
		# 아니라 **파고드는 수단**으로 만드는 값입니다.
		if state.has_roll_burst():
			_roll_burst = ROLL_BURST_TIME
	_was_rolling = rolling
	_roll_burst = maxf(0.0, _roll_burst - delta)
	if _swing_time > 0.0:
		_swing_time -= delta
		# 휘두르기 시작하고 조금 뒤에 판정합니다. 예고 없이 맞으면 억울합니다.
		if not _swing_hit and _swing_time <= 0.16:
			_swing_hit = true
			_resolve_swing()

	if _lunge_time > 0.0:
		_drive_lunge(delta)

	if _push_time > 0.0:
		_push_time -= delta
		# 달려드는 중이면 **닿는 순간**에 판정합니다(_drive_lunge). 상대가
		# 없을 때만 시간으로 합니다 - 헛손질도 동작 중간에 끝나야 합니다.
		if not _push_hit and _lunge_at == null and _push_time <= PUSH_TIME * 0.55:
			_push_hit = true
			_resolve_grab()

	move_and_slide()
	_unstick(delta)
	_push_what_we_hit()
	if _held != null:
		if not is_instance_valid(_held):
			_held = null
		elif _held is Enemy:
			# 적은 들지 않습니다. **두 손으로 등을 잡아** 앞에 끌고 갑니다.
			#
			# 붙는 자리를 손 위치에서 뽑습니다. 사람 몸 중심에서 잰 고정
			# 거리로 두면 자세가 조금만 바뀌어도 손과 몹 사이가 벌어집니다.
			var radius: float = float(_held.get_meta("body_radius", 0.35))
			# 몸이 보는 쪽으로 반지름만큼 더 나갑니다. aim 을 쓰면 던지려고
			# 도는 동안 몸만 돌고 몹은 조준 방향에 남아 어긋납니다.
			var face: Vector3 = -pivot.global_transform.basis.z
			face.y = 0.0
			_held.hold_at(_hands_point() + face.normalized() * radius,
				global_position, delta)
		elif _held.has_method("carry_to"):
			# 마시는 동안에는 우유갑을 **입 높이로 올려** 붙입니다.
			#
			# 이 아이는 머리가 크고 팔이 짧아서, 팔을 어떻게 접어도 손이
			# 머리뼈보다 0.07m 아래까지밖에 못 올라갑니다(실측). 손에 그대로
			# 붙이면 우유갑이 가슴 앞에 있고, 마시는 것이 아니라 안고 있는
			# 모양이 됩니다. 그 차이만큼 물건만 올립니다.
			var lift := Vector3(0, DRINK_LIFT, 0) if _drink_time > 0.0 else Vector3.ZERO
			_held.carry_to(_hand_point() + lift, delta)
		else:
			_held = null
	if _throw_time > 0.0:
		# 도는 동안에는 조준이 몸을 붙잡지 않습니다. 둘이 싸우면 회전이
		# 중간에서 멈춥니다.
		_drive_throw(delta)
	else:
		_face_aim(delta)
	# 둘 다 돌립니다. 본 클립이 팔다리를, 몸통 노드가 기울기·구르기·외치기를
	# 맡습니다. 층이 달라 서로 싸우지 않습니다.
	_drive_animation()
	_drive_body(delta)
	_drive_shout_charge(delta)
	_drive_pose_layer(delta)
	_drive_breath(delta)
	_drive_ultimate(delta)
	if _grab_queued > 0.0:
		_grab_queued -= delta
		# 기다리는 사이에 무언가를 들었으면 그 누름은 버립니다. 큐는
		# "잡기/밀기가 대기 중이었다" 를 위한 것이지 던지기를 위한 것이
		# 아닙니다 - 되살아나면 집자마자 날아갑니다.
		if _held != null:
			_grab_queued = 0.0
		elif _grab_cd <= 0.0:
			_grab_queued = 0.0
			grab_press()


## 미끄러운 자리에 서 있는 동안 남는 시간. 함정이 매 프레임 채워 줍니다.
var _slip := 0.0


func guard_speed_mult() -> float:
	## 막는 동안의 걸음(배). **아예 멈춥니다.**
	##
	## 느리게만 두면 막은 채로 슬금슬금 다니는 것이 답이 됩니다. 발이 묶여야
	## 「지금 막을 것인가」 가 매번 값을 치르는 선택이 됩니다.
	return 0.0 if guarding() else 1.0


func _accel_now() -> float:
	## 미끄러지는 동안에는 **가는 쪽을 바꾸기 어렵습니다.** 속도를 줄이는 것이
	## 아니라 조종이 늦어지는 것이라, 밟은 채로 방향을 꺾으면 그대로 밀려
	## 나갑니다 - 물에 미끄러지는 감각이 그것입니다.
	return ACCEL * (0.28 if _slip > 0.0 else 1.0)


func _friction_now() -> float:
	return FRICTION * (0.12 if _slip > 0.0 else 1.0)


func slip_on(amount: float) -> void:
	## 우유 웅덩이를 밟았습니다. 함정이 부릅니다.
	_slip = maxf(_slip, 0.12 * amount)


func _ground_move(delta: float) -> void:
	var input := _move_input()
	if input.length() > 0.25:
		# 마지막으로 준 방향을 기억해 둡니다. 던질 때 씁니다.
		_last_dir = input.normalized()
		_last_dir_time = AIM_MEMORY
	else:
		_last_dir_time = maxf(0.0, _last_dir_time - delta)
	var wish := Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	_wish_dir = wish

	var speed := state.move_speed
	# 구르고 나온 직후의 질주(「이속」 Lv2).
	if _roll_burst > 0.0:
		speed *= ROLL_BURST_MULT
	# **막고 있으면 느립니다.** 막은 채로 평소처럼 걸으면 켜 두는 것이
	# 답이 되어, 언제 막을지가 아무것도 정하지 않습니다.
	speed *= guard_speed_mult()
	# 베개싸움이 휘두르는 동안 발을 묶는 자리. 평소에는 1.0 입니다.
	speed *= ext_move_scale
	var target := wish * speed
	# 뒤로 갈 때는 느립니다. 사람이 그렇기도 하고, 무엇보다 **뒤로도 같은
	# 속도로 도망칠 수 있으면 돌아설 이유가 없습니다** - 적에게 등을 보이는
	# 위험을 감수할지가 선택이 되려면 값이 있어야 합니다.
	if _moving_back:
		target *= BACK_SPEED
	if _swing_time > 0.0:
		target *= _swing_move_scale()
	if _throw_time > 0.0:
		# 도는 중에는 거의 제자리입니다. 돌면서 걸어가면 힘이 실리지 않습니다.
		target *= 0.25
	elif _carrying_heavy():
		target *= HEAVY_SPEED_SCALE
	elif _carrying_enemy():
		# 몹을 끌고 있으면 걷기만 됩니다. 또래 하나를 끌면서 뛸 수는 없고,
		# 무엇보다 그래야 "잡는다" 가 값을 치르는 선택이 됩니다 - 더 센
		# 기술을 쓰는 동안 발이 느려지는 것이 그 값입니다.
		target *= CARRY_SPEED_SCALE

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var rate := _accel_now() if wish.length_squared() > 0.01 else _friction_now()
	flat = flat.move_toward(target, rate * delta)
	velocity.x = flat.x
	velocity.z = flat.z


## 끼었다고 보기까지 기다리는 시간(초)과, 빼내는 속도(m/s).
##
## 0.30초는 **벽에 잠깐 붙는 것과 끼는 것을 가르는 값**입니다. 모퉁이를 스치며
## 도는 동안에도 한두 프레임은 못 나아가는데, 그때마다 몸이 옆으로 밀리면
## 걷는 것이 미끄럽게 느껴집니다.
##
## 빼내는 속도는 걷는 속도(3.1)보다 느립니다. 빠르면 끼었다 풀리는 순간
## 튕겨 나가서, 무슨 일이 일어났는지 모르게 됩니다.
const STUCK_TIME := 0.30
const STUCK_PUSH := 1.8
## 끼었을 때 둘러보는 거리(m). 이 안의 소품에서 멀어지는 쪽으로 뺍니다.
const STUCK_LOOK := 2.2

var _stuck_time := 0.0
var _stuck_from := Vector3.ZERO
## 이번 프레임에 **가려던 쪽**(수평, 길이 0~1). 끼임 판단이 이것을 봅니다.
var _wish_dir := Vector3.ZERO


func _unstick(delta: float) -> void:
	## **가려는데 못 가고 있으면 빼냅니다.**
	##
	## 책장·옷장 같은 붙박이는 네모난 충돌체이고 벽에 붙여 놓습니다. 벽과
	## 소품 사이에 좁은 쐐기가 생기면 캡슐이 그 안에 물려서, 어느 쪽으로 밀어도
	## 못 나옵니다 - `move_and_slide` 는 미끄러질 면이 없으면 아무 데도 안
	## 갑니다.
	##
	## **속도가 아니라 실제로 움직인 거리**로 봅니다. 끼었을 때도 가려는
	## 마음은 그대로라, 거리로 봐야 "못 가고 있다" 가 잡힙니다.
	##
	## 가려는 뜻은 **누른 방향**(`_wish_dir`)에서 읽습니다. `velocity` 로 보면
	## 안 됩니다 - `move_and_slide` 가 막힌 방향의 속도를 지우고 돌아오므로,
	## 정작 완전히 막혔을 때 0 이 되어 "가려는 중이 아니다" 로 읽힙니다.
	var moved := global_position.distance_to(_stuck_from)
	_stuck_from = global_position
	var trying := _bound_time <= 0.0 and _joy_time <= 0.0 and not _dead 		and _wish_dir.length_squared() > 0.25
	if not trying or moved > 0.012:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time < STUCK_TIME:
		return
	var away := _unstick_dir()
	if away.length_squared() < 0.0001:
		return
	# `move_and_collide` 로 뺍니다. 자리를 직접 옮기면 벽을 뚫고 나갑니다 -
	# 끼는 자리는 대개 벽 옆이라 그쪽으로 밀어낼 일이 반드시 생깁니다.
	move_and_collide(away * STUCK_PUSH * delta)


func _unstick_dir() -> Vector3:
	## 빠져나갈 쪽. **가장 가까운 소품에서 멀어지되, 가려던 쪽도 섞습니다.**
	##
	## 멀어지기만 하면 뒤로 밀려나기만 하고 제자리로 돌아옵니다. 가려던 쪽을
	## 섞어야 소품을 돌아 나가는 모양이 됩니다.
	var wish := _wish_dir
	if wish.length_squared() > 0.0001:
		wish = wish.normalized()
	var best: Node3D = null
	var closest := STUCK_LOOK
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Node3D
		if not is_instance_valid(prop):
			continue
		var d := prop.global_position.distance_to(global_position)
		if d < closest:
			closest = d
			best = prop
	if best == null:
		# 소품이 없으면 **가려던 쪽의 옆으로** 빠집니다. 벽 모퉁이에 물린
		# 경우라 옆으로 한 뼘만 나가면 미끄러질 면이 생깁니다.
		return Vector3(-wish.z, 0.0, wish.x)
	var away: Vector3 = global_position - best.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		return Vector3(-wish.z, 0.0, wish.x)
	return (away.normalized() * 0.75 + wish * 0.55).normalized()


func _push_what_we_hit() -> void:
	## 부딪힌 것을 밀어내고, 그만큼 내 속도를 깎습니다.
	##
	## CharacterBody3D 는 강체를 자동으로 밀지 않습니다. 그냥 두면 인형이
	## 벽처럼 단단하게 서 있어서, 발에 걸린 장난감이 사람을 막습니다.
	## 부딪힌 쪽에 충격을 주고 내 쪽은 조금 느려지게 해야 "치고 지나간다" 가
	## 됩니다.
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider()
		var away := -hit.get_normal()
		away.y = 0.0
		if away.length_squared() < 0.0001:
			continue
		if other is Prop and (other as Prop).is_fixed():
			# 붙박이는 벽으로 칩니다. 충격을 줘 봐야 안 움직이는데, 속도만
			# 깎으면 "밀고 있는데 안 밀리는" 것으로 느껴집니다 - 벽에 부딪힐
			# 때처럼 그냥 막히는 편이 읽힙니다.
			continue
		if other is RigidBody3D:
			# 무거운 가구는 잘 안 밀립니다(질량으로 알아서 갈립니다).
			other.apply_central_impulse(away.normalized() * 2.6)
			velocity *= 0.88
		elif other is Enemy:
			other.shove(away.normalized() * 2.2)
			velocity *= 0.80

## 고함을 지르는 동안의 이동 속도 배율.
## 맞은 자세를 붙잡는 시간. 무적 시간(HIT_INVULN)보다 짧게 둡니다 - 자세가
## 무적보다 오래 남으면, 이미 다시 움직일 수 있는데 몸은 아직 웅크린 채라
## 조작이 안 먹는 것처럼 느껴집니다.
## 집은 뒤 던지기가 열릴 때까지의 시간.
##
## **0.30 에서 0.06 으로 내렸습니다.** 손에 붙는 것을 보고 나서 던지라는
## 뜻이었는데, 재 보니 **손에 든 뒤로도 0.32초 동안 눌러도 아무 일이 안
## 일어났습니다.** 그 사이에는 화면에도 소리에도 아무것도 없어서, 버튼이
## 씹힌 것으로만 느껴집니다.
##
## 원래 막으려던 것은 **한 번의 누름이 집기와 던지기를 다 하는 것**이었는데,
## 그건 이제 다른 데서 막습니다 - 집는 누름은 집기가 먹고, 던지기는 **다음
## 누름**입니다(큐에도 안 넣습니다, 아래 `grab_press` 참고).
##
## 0 이 아닌 것은 눌림이 한 번 튈 때(하드웨어·터치 반복)를 위한 최소한입니다.
## 0.06 은 네 프레임이라 손으로는 못 느낍니다.
const HOLD_MIN := 0.06
var _hold_min := 0.0

const HURT_POSE_TIME := 0.32
var _hurt_time := 0.0

const SHOUT_MOVE_SCALE := 0.20


func _swing_move_scale() -> float:
	## 외치는 동안 얼마나 느려지는가.
	##
	## 예전에는 휘두르는 0.30초 내내 25% 로 깎았습니다. 재사용 대기가 0.55초라
	## **연타하면 절반 넘게 발이 묶여**, 조작이 끊기는 것처럼 느껴졌습니다.
	##
	## 지금은 **지르는 내내 20%** 입니다. 가장자리만 짧게 이어 붙여 급정거처럼
	## 느껴지지 않게 했습니다 - 0.04초에 걸쳐 눌리고 0.05초에 걸쳐 풀립니다.
	##
	## **모으는 동안에도 같은 값입니다.**
	##
	## 고함이 누르는 만큼 커지는 기술이 되면서, 모으는 시간(최대 0.86초)이
	## 통째로 새로 생겼습니다. 그동안 평소 속도로 걸으면 모으는 일에 값이
	## 없습니다 - 걸어 다니며 모았다가 좋은 자리에서 떼면 그만입니다.
	## 발이 느려져야 **어디서 모을지**가 선택이 됩니다.
	##
	## 완전히 묶지 않고 0.2배를 남긴 이유: 0 이면 모으는 내내 못 움직여서,
	## 예고를 보고 굴러 피하는 것과 겨룰 수가 없습니다. 느리게라도 자리를
	## 옮길 수 있어야 "모으면서 물러난다" 가 가능합니다.
	## 눌리는 구간은 판정 시간(0.30초)까지입니다. 자세를 붙잡는 0.62초나
	## 목소리까지 끌면 재사용 대기(0.34초)보다 길어져, 연타하면 발이 계속
	## 묶입니다 - 예전에 조작이 끊긴다고 하신 그 상태로 돌아갑니다.
	var t := 1.0 - clampf(_swing_time / SWING_TIME, 0.0, 1.0)
	var k := clampf(t / 0.12, 0.0, 1.0) * clampf((1.0 - t) / 0.18, 0.0, 1.0)
	return lerpf(1.0, SHOUT_MOVE_SCALE, k)


func _move_input() -> Vector2:
	# 읽는 동안에는 **조작이 통째로 잠깁니다.** 고함·구르기·잡기는 이미
	# 막혀 있었는데 발만 열려 있어서, 책을 든 채 걸어 다닐 수 있었습니다 -
	# 꺼내고 돌아서는 동작이 그 자리에서 일어나야 이야기로 읽힙니다.
	if _read_time > 0.0:
		return Vector2.ZERO
	if bot_active:
		return bot_move
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	input += touch_move
	input = input.limit_length(1.0)
	# 어깨 너머 화면에서는 **카메라 기준**으로 갑니다.
	#
	# 내려다보는 화면에서는 위 키가 언제나 세계의 같은 쪽을 뜻해도 됩니다 -
	# 카메라가 돌지 않으니까요. 어깨 너머에서는 카메라가 몸을 따라 도는데,
	# 그때도 세계 기준이면 몸을 돌릴 때마다 같은 키가 다른 쪽으로 갑니다.
	#
	# # 그런데 매 프레임 카메라 각도로 돌리면 **제자리를 맴돕니다**
	#
	# 오른쪽을 누른다 -> 카메라 기준 오른쪽으로 간다 -> 몸이 그쪽을 본다 ->
	# 카메라가 따라 돈다 -> 같은 "오른쪽" 이 아까보다 더 오른쪽을 가리킨다.
	# 누르고만 있어도 방향이 계속 돌아가서 빙빙 돕니다. 자기 꼬리를 쫓는
	# 구조입니다.
	#
	# 그래서 기준 각도를 **손을 뗀 순간에만** 새로 잡습니다. 누르고 있는
	# 동안에는 카메라가 어떻게 돌든 가는 방향이 고정이라 똑바로 갑니다.
	# 카메라는 그 사이 천천히 뒤로 돌아옵니다 - 화면은 돌지만 몸은 직진합니다.
	if Game.instance == null or Game.instance.cam_mode != Game.CamMode.SHOULDER:
		return input
	if input.length() < 0.2:
		_move_yaw = Game.instance.cam_yaw()
		return input
	return input.rotated(-_move_yaw)


func _auto_aim() -> bool:
	## 가장 가까운 적을 봅니다. 없으면 가는 쪽을 봅니다.
	##
	## 범위는 **밀기 사거리**를 따라갑니다(`lock_on_range`). 때릴 수 있을 만큼
	## 붙어야 반응하고, 그 전에는 가는 쪽을 봅니다.
	var best: Node3D = null
	var closest := lock_on_range()
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		# 밀려 날아가는 적은 **록온도 안 걸립니다.** 못 미는 상대를 계속
		# 보고 있으면, 다음에 밀 상대에게서 몸이 돌아가 있습니다.
		if not is_instance_valid(e) or not e.is_targetable():
			continue
		var d := e.global_position.distance_to(global_position)
		if d < closest:
			closest = d
			best = e
	if best != null:
		var to: Vector3 = best.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			aim = to.normalized()
			return true
	var moving := Vector3(velocity.x, 0.0, velocity.z)
	if moving.length_squared() > 0.5:
		aim = moving.normalized()
		return true
	return true


func _update_aim() -> void:
	# 책을 읽는 동안에는 조준을 바꾸지 않습니다.
	#
	# 책장을 등지도록 돌려 세워 놓았는데, 마우스나 자동 조준이 매 프레임
	# 덮어써서 몸이 도로 벽을 향했습니다 - 돌아선 이유가 사라집니다.
	if _read_time > 0.0:
		# 여기서는 **아무것도 하지 않습니다.** 조준은 _drive_read 가 마디마다
		# 정합니다 - 예전에는 여기서 최종 목표를 매 프레임 덮어써서, 돌아서는
		# 중간이 통째로 사라지고 한 프레임에 홱 돌았습니다.
		return
	if Game.instance != null and Game.instance.debug_aim != Vector3.ZERO:
		aim = Game.instance.debug_aim
		return
	# 어깨 너머에서는 마우스로 겨누지 않습니다.
	#
	# 마우스 조준은 화면의 한 점을 가슴 높이 평면에 내려서 씁니다. 위에서
	# 내려다볼 때는 정확하지만, 카메라가 거의 수평인 어깨 너머에서는 그 광선이
	# 평면과 거의 나란해서 조금만 움직여도 겨누는 점이 수십 미터씩 튑니다.
	# 대신 **가는 쪽과 가까운 적**이 방향을 정합니다(소울라이크의 방식입니다).
	if Game.instance != null and Game.instance.cam_mode == Game.CamMode.SHOULDER:
		_auto_aim()
		return
	if auto_aim and _auto_aim():
		return
	if not mouse_aim:
		# 마우스가 없습니다. **가는 쪽**을 봅니다.
		#
		# 멈추면 마지막으로 보던 쪽을 그대로 둡니다 - 0 으로 되돌리면 손을
		# 뗄 때마다 몸이 한 방향으로 홱 돌아갑니다.
		var going := Vector3(velocity.x, 0.0, velocity.z)
		if going.length_squared() > 0.25:
			aim = going.normalized()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.001:
		return
	# 가슴 높이 평면과 만나는 점. 바닥(y=0)으로 잡으면 가까이서 조준이 흔들립니다.
	var plane_y := global_position.y + 0.8
	var t := (plane_y - origin.y) / dir.y
	if t <= 0.0:
		return
	var point := origin + dir * t
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() > 0.04:
		aim = to.normalized()


func _face_aim(delta: float) -> void:
	if pivot == null:
		return
	# 노드의 앞은 -Z 입니다. d 를 향하게 하려면 atan2(-d.x, -d.z) 입니다.
	var want := atan2(-aim.x, -aim.z)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, want, 1.0 - exp(-18.0 * delta))


func _facing() -> Vector3:
	## 몸이 보고 있는 쪽(수평). 노드의 앞은 -Z 입니다.
	if pivot == null:
		return -global_transform.basis.z
	var f: Vector3 = -pivot.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


func _drive_animation() -> void:
	## 재생 속도를 **실제 이동 속도에 맞춥니다.** 발이 바닥을 미는 속도와 몸이
	## 나아가는 속도가 같아야 미끄러지지 않습니다.
	##
	## 예전에는 `속도 / 3.0 * 3배` 라는 손으로 맞춘 식이었습니다. 재 보니
	## 걷기 클립은 1배속에서 0.36 m/s 를 밀고 있었는데 몸은 3.1 m/s 로
	## 나가고 있었습니다 - 발이 2.8배 미끄러지고 있었습니다.
	if _anim == null or stride_probe:
		return
	if _push_time > 0.0 and _push_clip != "" and _lunge_at == null:
		# 밀기 클립이 끝날 때까지 건드리지 않습니다.
		#
		# **달려드는 중에는 예외입니다.** 그때는 클립을 틀지 않는데도 여기서
		# 비켜서면 다리가 멈춘 채로 미끄러져 갑니다 - 클립을 안 트는 것만으로는
		# 모자랐습니다(`_push_time` 은 여전히 흐르고 있었습니다).
		return

	# **실제로 움직인 속도**를 씁니다(velocity 가 아니라).
	#
	# velocity 는 "가려는" 속도라 벽에 붙어 밀고 있을 때도 그대로 남습니다.
	# 그걸로 다리를 돌리면 벽 앞에서 제자리걸음이 아니라 **제자리 질주**가
	# 됩니다 - 실측에서 몸이 0.02m 가는 동안 발이 0.91m 를 밀고 있었습니다.
	var speed := Vector3(get_real_velocity().x, 0.0, get_real_velocity().z).length()
	# 구르는 중에도 다리 클립을 **계속 돌립니다.** 자세 층(PoseOverride.ROLL)이
	# 다리를 덮고 있어 화면에는 안 보이지만, 여기서 멈춰 두면 구르기가 끝나는
	# 순간 걷기가 처음부터 다시 시작합니다 - 그 0.15초 동안 몸은 아직 빠르게
	# 나가는데 발은 이제 막 첫 걸음이라 미끄러집니다. 구르기 직후의 스케이팅이
	# 이것이었습니다.
	if speed > MOVE_ANIM_MIN:
		# 가는 쪽과 **보는 쪽**을 비교합니다.
		#
		# 적이 가까우면 몸은 적을 봅니다(자동 조준). 그 상태로 물러나면 몸은
		# 앞을 보는데 발은 뒤로 가야 하는데, 클립을 그대로 돌리면 앞으로 걷는
		# 다리로 뒤로 미끄러집니다 - 문워크입니다.
		#
		# 문턱을 두고 그 사이에서는 **직전 판단을 유지**합니다. 옆으로 걸을
		# 때 0 근처에서 부호가 떨리면 다리가 앞뒤로 발작합니다.
		var along := Vector3(velocity.x, 0.0, velocity.z).normalized().dot(_facing())
		if along < -0.25:
			_moving_back = true
		elif along > 0.25:
			_moving_back = false

		# 뒤로 갈 때는 **보폭이 좁은 전용 클립**을 거꾸로 돌립니다.
		#
		# 처음에는 걷기를 그대로 거꾸로 돌렸는데, 보폭이 앞걸음 그대로라 발이
		# 뒤로 성큼 뻗었습니다. 사람은 뒤로 갈 때 발을 멀리 내밀지 않습니다 -
		# 발밑이 안 보이니 짧게 더듬습니다.
		var use_run := not _moving_back and _run != "" and speed >= RUN_GROUND
		var clip := _walk
		var ground := WALK_GROUND
		if _moving_back and _back != "":
			clip = _back
			ground = BACK_GROUND
		elif use_run:
			clip = _run
			ground = RUN_GROUND
		if clip != "" and _anim.current_animation != clip:
			_anim.play(clip, 0.12)
		# 클램프는 안전장치일 뿐입니다. 여기에 걸리면 그만큼 미끄러집니다 -
		# 걸리지 않도록 달리기 클립의 보폭을 걷기의 두 배로 잡았습니다.
		var rate := clampf(speed / ground, 0.35, 6.0)
		_anim.speed_scale = -rate if _moving_back else rate
	else:
		if _anim.current_animation != _idle and _idle != "":
			_anim.play(_idle, 0.2)
		_anim.speed_scale = 1.0


func _drive_body(delta: float) -> void:
	## 몸통 노드 하나를 기울이고 굴리고 늘여서 만드는 동작 층.
	##
	## 본 클립(걷기·대기)과 **겹쳐서** 돕니다. 클립이 팔다리를 접는 동안 이쪽은
	## 몸 전체의 기울기와 반동을 맡습니다. 구르기와 외치기는 클립으로 만들 수
	## 없어(그런 클립이 없습니다) 전부 여기서 나옵니다.
	##
	## 치비 비례에서는 이 층이 특히 잘 먹힙니다 - 다리가 짧아 보폭이 눈에 잘
	## 안 띄고, 속도감의 대부분은 **기울기와 상하 반동**이 만듭니다.
	if _roll_time > 0.0:
		_pose_roll(delta)
		return

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var top := maxf(1.0, state.move_speed)
	# 걷기와 달리기를 나눕니다. 0 이면 걷기, 1 이면 전력 질주입니다.
	var run := clampf((speed / top - 0.45) / 0.55, 0.0, 1.0)
	var moving := speed > 0.6

	# 걸음 위상. 달릴수록 빨리 감깁니다.
	var step_before := _step_phase
	_step_phase += delta * (2.4 + speed * (1.6 + run * 1.4))
	# 발소리는 **걸음 위상**에서 뽑습니다. 시간으로 재면 빨리 달릴 때 발과
	# 소리가 어긋나고, 애니메이션 배속을 바꾸면 또 어긋납니다. 위상이 반
	# 바퀴 돌 때마다 한 발입니다(한 바퀴에 두 발).
	if speed > MOVE_ANIM_MIN and is_on_floor() 			and int(step_before / PI) != int(_step_phase / PI):
		# 지금 크기의 30%. 소리 크기는 로그라 20*log10(0.3) = -10.5dB 를
		# 더 뺍니다. 발소리는 초당 세 번쯤 나므로, 있는 줄 모를 만큼만
		# 깔려야 걷는 느낌만 남고 시끄럽지 않습니다.
		Sfx.play(Sfx.STEP, -27.5, 0.18)
		# 이동 계통 Lv3 부터 발자국이 빛납니다. 소리를 거의 지운 자리라
		# 눈으로 걸음이 보이는 편이 낫습니다.
		if skill_lv("move") >= 3:
			Fx.ring(get_parent(), global_position, Color(0.7, 1.0, 0.8),
				0.5, 0.26)

	var bob := 0.0
	var lean := Vector2.ZERO      # x=앞뒤(pitch), y=좌우(roll)
	var stretch := 1.0
	# 클립이 걸음 반동을 이미 내고 있으면 몸통 반동을 줄입니다. 둘 다 세게
	# 넣으면 위아래로 두 번 튀어 멀미가 납니다.
	var cycle := 1.0 if _procedural else 0.3
	if moving:
		var amp := clampf(speed / top, 0.0, 1.3)
		# 한 사이클에 두 번 오르내립니다(다리마다 한 번). 달릴 때 더 크게 튑니다.
		bob = absf(sin(_step_phase)) * (0.075 + run * 0.085) * amp * cycle
		lean.y = sin(_step_phase * 0.5) * (0.10 + run * 0.06) * amp * cycle
		# 진행 방향으로 몸을 기울입니다. 조준과 이동이 따로 놀 수 있으니
		# 속도를 몸 기준으로 바꿔서 앞뒤/좌우를 나눕니다.
		var local: Vector3 = pivot.global_transform.basis.inverse() * flat
		# 달릴 때는 앞으로 더 숙입니다 - 속도감의 대부분이 이 각도에서 나옵니다.
		lean.x = clampf(-local.z * (0.022 + run * 0.030), -0.34, 0.34)
		lean.y += clampf(local.x * 0.020, -0.16, 0.16)
		# 뛰어오를 때 살짝 늘어납니다.
		stretch = 1.0 + sin(_step_phase) * 0.045 * run * cycle
	else:
		# 서 있을 때의 숨쉬기.
		bob = sin(_step_phase * 0.8) * 0.012 * cycle
		lean.y = sin(_step_phase * 0.5) * 0.02 * cycle

	if _swing_time > 0.0:
		# 허리 굽힘을 이제 본(PoseOverride.SHOUT)이 나눠 맡습니다. 몸통 노드까지
		# 그대로 두면 둘이 더해져 몸이 반으로 접힙니다.
		lean.x += _shout_pitch() * SHOUT_BODY_MIX
		stretch += _shout_stretch()

	body.position.y = lerpf(body.position.y, HIP + bob, 1.0 - exp(-24.0 * delta))
	body.rotation.z = lerp_angle(body.rotation.z, lean.y, 1.0 - exp(-16.0 * delta))
	body.rotation.x = lerp_angle(body.rotation.x, lean.x, 1.0 - exp(-18.0 * delta))
	var want := Vector3(2.0 - stretch, stretch, 2.0 - stretch)
	body.scale = body.scale.lerp(want, 1.0 - exp(-20.0 * delta))


## 몸통 노드가 맡는 몫. 나머지는 본 자세가 냅니다.
const SHOUT_BODY_MIX := 0.6


func _shout_pitch() -> float:
	## 외치기. 숨을 들이켜며 **뒤로 젖혔다가** 앞으로 내지르고, 다시 섭니다.
	##
	## 되감기(젖히기)가 있어야 내지르는 순간이 커 보입니다. 곧바로 앞으로만
	## 숙이면 그냥 고개를 떨군 것처럼 보입니다.
	##
	## 회복 구간이 중요합니다. 예전에는 동작이 **가장 숙인 자세에서 끝나서**,
	## 끝나는 순간 자세가 튕겨 돌아왔습니다 - 그게 공격이 끊겨 보이는 원인이었습니다.
	## 이제 동작 안에서 거의 제자리까지 돌아온 뒤 끝납니다.
	var t := 1.0 - clampf(_swing_time / SWING_TIME, 0.0, 1.0)
	if t < 0.32:                                    # 들이켜기
		return lerpf(0.0, 0.32, ease(t / 0.32, 0.5))
	if t < 0.60:                                    # 내지르기
		return lerpf(0.32, -0.40, ease((t - 0.32) / 0.28, 3.0))
	return lerpf(-0.40, -0.03, ease((t - 0.60) / 0.40, 0.4))   # 회복


func _shout_stretch() -> float:
	## 웅크렸다가 내지르는 순간 부풀고, 끝에는 제자리로 돌아옵니다.
	var t := 1.0 - clampf(_swing_time / SWING_TIME, 0.0, 1.0)
	if t < 0.32:
		return -0.05 * (t / 0.32)
	return 0.10 * sin((t - 0.32) / 0.68 * PI)


func _drive_ultimate(delta: float) -> void:
	## 시간을 흘리고, 모드가 켜져 있으면 **몸에 그 표시를 붙입니다.**
	var was := ultimate.active
	ultimate.tick(delta)
	if ultimate.active:
		# 모든 움직임에 잔상을 남깁니다. 구르기 잔상과 같은 방법이라
		# (뼈대까지 복제하고 애니메이션을 떼기) 값도 같습니다(1.8ms).
		_aura_trail -= delta
		if _aura_trail <= 0.0:
			_aura_trail = ULT_TRAIL_STEP
			_ultimate_ghost()
	if was and not ultimate.active:
		_end_ultimate("시간 초과")


## 필살 모드에서 잔상을 떨구는 간격. 구르기(0.34m 마다)와 달리 시간으로
## 재는 이유: 모드에서는 서 있기만 해도 기운이 도는 것으로 보여야 합니다.
## 필살기 명령이 한 글자씩 맞을 때 나는 음의 높이. **올라갑니다.**
##
## 0 번째 자리는 안 씁니다(명령이 시작되기 전). 1 = 구르기가 맞음,
## 2 = 밀기가 맞음, 3 = 발동.
const ULT_NOTES := [1.0, 1.0, 1.26, 1.5]
const ULT_TRAIL_STEP := 0.10
## 필살 동작들의 크기. 한곳에 모아 두면 손볼 때 표만 봅니다.
const ULT_DASH_RANGE := 14.0      ## 달려들기가 닿는 거리(m)
const ULT_PUSH_RANGE := 2.4       ## 밀어붙이기가 닿는 거리(m)
const ULT_SHOUT_RADIUS := 7.5     ## 포효의 반지름(m)
const ULT_SHOUT_MULT := 2.4       ## 포효 피해 배율
const ULT_SHOUT_KNOCK := 14.0     ## 포효 넉백
const ULT_PUSH_MULT := 1.8        ## 밀어붙이기 피해 배율


func ultimate_press(key: String) -> bool:
	## 누름 하나를 필살기에 먼저 물어봅니다. **true 면 평소 동작은 하지
	## 않습니다** - 필살기가 그 누름을 가져간 것입니다.
	##
	## 세 기술이 모두 이 함수를 첫 줄에서 부릅니다. 새 동작을 더할 때도
	## 여기만 지나가면 되므로, 기술 쪽 코드는 자라지 않습니다.
	var what := ultimate.feed(key)
	match what:
		"":
			return false
		"opened":
			# **안 삼킵니다.** 소리만 내고 평소 동작을 그대로 하게 false 를
			# 돌려줍니다 - 용기가 찼다는 이유로 구르기나 밀기가 안 나가면,
			# 그건 규칙이 아니라 사람 눈에 고장입니다(ultimate.gd 참고).
			#
			# **한 글자 맞을 때마다 음이 올라갑니다.** 폰에서는 버튼을 훑는
			# 동안 손가락이 화면을 가리므로, 어디까지 갔는지 눈으로는 잘
			# 안 보입니다 - 귀로 알 수 있어야 끝까지 훑습니다.
			Sfx.play_at(Sfx.PICK, ULT_NOTES[mini(ultimate.step_index(),
				ULT_NOTES.size() - 1)], -4.0)
			return false
		"fire":
			_begin_ultimate()
			return true
		"empty":
			_end_ultimate("용기 부족")
			return true
		"over":
			_end_ultimate("")
			return true
		_:
			_ultimate_move(what)
			return true


func _begin_ultimate() -> void:
	## 파란 기운을 두르고 세상을 멈춥니다.
	# 마지막 음. 명령의 두 음보다 한 단 더 높습니다 - 올라가던 것이
	# 도착한 것으로 들립니다.
	Sfx.play_at(Sfx.PICK, ULT_NOTES[ULT_NOTES.size() - 1], 0.0)
	_aura = Fx.aura(get_parent(), self)
	_aura_trail = 0.0
	_ult_visited.clear()
	if Game.instance != null:
		Game.instance.world_frozen = true
	Sfx.play(Sfx.SHOUT, 0.0, 0.0)
	Game.shake(0.5, 0.35)
	Fx.ring(get_parent(), global_position, Fx.RUSH_COLOR, 3.2, 0.5)
	ultimate_changed.emit(ultimate.ratio(), true, "필살")


func _end_ultimate(note: String) -> void:
	if is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	ultimate.stop()
	if Game.instance != null:
		Game.instance.world_frozen = false
	ultimate_changed.emit(ultimate.ratio(), false, note)


func _ultimate_ghost() -> void:
	Fx.body_ghost(get_parent(), body, Fx.RUSH_COLOR, 0.65)


func _ultimate_move(key: String) -> void:
	## **필살 동작.** 여기 갈래 하나가 곧 동작 하나입니다.
	ultimate_changed.emit(ultimate.ratio(), true, ultimate.move_name(key))
	match key:
		"roll":
			_ult_dash()
		"grab":
			_ult_push()
		"shout":
			_ult_shout()


func _nearest_enemy(within: float, skip: Array = []) -> Node3D:
	var best: Node3D = null
	var near := within
	for node in get_tree().get_nodes_in_group("enemies"):
		var foe := node as Node3D
		if not is_instance_valid(foe) or skip.has(foe):
			continue
		var to: Vector3 = foe.global_position - global_position
		to.y = 0.0
		if to.length() < near:
			near = to.length()
			best = foe
	return best


func _ult_dash() -> void:
	## **가장 가까운 적으로 한 번에 갑니다.** 굴러가는 것이 아니라 이미 가
	## 있는 것이라, 거리에 상관없이 한 번입니다.
	##
	## 두 번째부터는 **그 다음으로 가까운 적**입니다. 한 번 들른 적은 건너
	## 뜁니다 - 안 그러면 붙어 있는 그 적에게 계속 다시 붙어서, 연달아
	## 누르는 것이 제자리걸음이 됩니다. 훑고 지나가는 그림이 되어야 합니다.
	var foe := _nearest_enemy(ULT_DASH_RANGE, _ult_visited)
	if foe == null:
		# 다 들렀으면 **한 바퀴 다시 돕니다.** 여기서 모드를 끝내면, 적이
		# 적게 남았을 때 필살기가 도중에 끊깁니다.
		_ult_visited.clear()
		foe = _nearest_enemy(ULT_DASH_RANGE)
	if foe == null:
		_end_ultimate("적이 없다")
		return
	_ult_visited.append(foe)
	var to: Vector3 = foe.global_position - global_position
	to.y = 0.0
	var stop_at: float = float(foe.get_meta("body_radius", 0.35)) + _body_radius + 0.1
	aim = to.normalized()
	# 지나온 길에 잔상을 깔아 **간 것이 아니라 지나간 것**으로 보이게 합니다.
	var steps := clampi(int(to.length() / 0.8), 2, 12)
	for i in range(1, steps):
		Fx.ghost_at(get_parent(), body, global_position + to.normalized() * (to.length() * float(i) / float(steps)),
			Fx.RUSH_COLOR, 0.45 - 0.02 * i)
	global_position = foe.global_position - to.normalized() * stop_at
	velocity = Vector3.ZERO
	Fx.ring(get_parent(), global_position, Fx.RUSH_COLOR, 1.6, 0.3)
	Sfx.play(Sfx.THROW, -2.0, 0.06)


func _ult_push() -> void:
	## **연타로 밀어붙입니다.** 적이 사거리 밖이면 거기서 모드가 끝납니다 -
	## 허공을 계속 밀면 용기만 새고, 끝나는 조건이 하나 있어야 연타에 긴장이
	## 생깁니다.
	var foe := _nearest_enemy(ULT_PUSH_RANGE)
	if foe == null:
		_end_ultimate("놓쳤다")
		return
	var dir: Vector3 = foe.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else aim
	aim = dir
	var roll := state.roll_damage(rng)
	if foe.has_method("knock_back"):
		foe.knock_back(dir * (SHOVE_KNOCK + state.shove_knock) * 1.4)
	if foe.has_method("stagger_for"):
		foe.stagger_for(0.5)
	foe.call("take_damage", float(roll[0]) * ULT_PUSH_MULT, bool(roll[1]),
		Vector3.ZERO, 0.0, global_position)
	_play_push()
	Sfx.play(Sfx.PUSH, 0.0, 0.06)
	Game.shake(0.26, 0.16)


func _ult_shout() -> void:
	## **아주 큰 원만큼** 피해와 넉백. 부채꼴이 아니라 원인 이유: 필살기는
	## 겨누는 기술이 아니라 판을 뒤집는 기술입니다.
	Fx.ring(get_parent(), global_position, Fx.RUSH_COLOR, ULT_SHOUT_RADIUS, 0.55)
	Fx.orbs(get_parent(), global_position + Vector3(0, 0.7, 0), aim,
		ULT_SHOUT_RADIUS, 14, true)
	# **호랑이는 발밑에 깝니다.** 아이 높이에 띄우면 아이를 덮습니다 - 포효는
	# 아이를 가운데 둔 원이라 그 원이 바닥에 그려지는 편이 범위와도 맞습니다.
	Fx.tiger(get_parent(), global_position + Vector3(0, 0.04, 0), aim,
		ULT_SHOUT_RADIUS, true)
	Sfx.play(Sfx.SHOUT, 1.0, 0.0)
	Game.shake(0.6, 0.4)
	for node in get_tree().get_nodes_in_group("enemies"):
		var foe := node as Node3D
		if not is_instance_valid(foe):
			continue
		var to: Vector3 = foe.global_position - global_position
		to.y = 0.0
		if to.length() > ULT_SHOUT_RADIUS:
			continue
		var away := to.normalized() if to.length() > 0.05 else aim
		var roll := state.roll_damage(rng)
		if foe.has_method("knock_back"):
			foe.knock_back(away * ULT_SHOUT_KNOCK)
		if foe.has_method("stagger_for"):
			foe.stagger_for(1.2)
		foe.call("take_damage", float(roll[0]) * ULT_SHOUT_MULT, bool(roll[1]),
			Vector3.ZERO, 0.0, global_position)


func _out_of_breath() -> void:
	## 숨이 모자라 못 썼습니다. 아무 일도 안 일어나면 버튼이 고장 난 줄
	## 압니다 - 어디를 보라고 한 번 알려 줍니다.
	##
	## 뜸을 둡니다. 버튼을 누르고 있으면 매 프레임 알림이 쏟아집니다.
	if _breath_warn > 0.0:
		return
	_breath_warn = 0.7
	breath_empty.emit()
	# **머리 위에 띄웁니다.** 화면 위 알림은 손이 보고 있는 자리가 아닙니다 -
	# 급해서 누르는 순간이라 눈은 몸에 붙어 있습니다.
	Fx.popup_text(get_parent(), global_position + Vector3(0, 1.5, 0),
		"숨 차", Color(0.95, 0.55, 0.45))


func _drive_breath(delta: float) -> void:
	_breath_warn = maxf(0.0, _breath_warn - delta)
	_repeat_t = maxf(0.0, _repeat_t - delta)
	if _repeat_t <= 0.0:
		_repeat_n = 0
	if _carrying_enemy() or _carrying_prop():
		# 들고 있는 동안에는 계속 샙니다. 오래 들고 있을수록 던질 여유가
		# 줄어들므로, 집었으면 쓰라는 압력이 생깁니다.
		#
		# 가구는 세 배로 닳습니다. 들 수는 있지만 들고 돌아다닐 수는 없다는
		# 뜻이고, 그것이 "무겁다" 를 규칙으로 표현하는 방법입니다.
		var drain := BREATH_HEAVY_DRAIN if _carrying_heavy() else BREATH_CARRY_DRAIN
		_spend_breath(drain * delta, false)
		if state.breath <= 0.0 and _carrying_prop():
			# 숨이 다 빠지면 놓칩니다.
			(_held as Prop).drop()
			_held = null
			_out_of_breath()
		return
	_breath_pause = maxf(0.0, _breath_pause - delta)
	if _breath_pause <= 0.0:
		var regen := BREATH_REGEN + state.breath_regen
		# **「이속」 Lv3 은 걸으면 숨이 두 배로 찹니다.**
		#
		# 가만히 서서 차는 것보다 움직이며 차는 편이 낫게 만드는 값입니다 -
		# 숨을 기다리는 동안 화면 구석에 서 있는 것이 최선이면, 기다리는
		# 시간이 곧 아무것도 안 하는 시간이 됩니다.
		if state.has_walk_regen() and Vector2(velocity.x, velocity.z).length() > 0.6:
			regen *= 2.0
		state.breath = minf(state.max_breath, state.breath + regen * delta)


func breath_cost(kind: String, base: float) -> float:
	## 지금 그 기술을 쓰면 드는 숨. 세지는 않고 **묻기만** 합니다.
	##
	## 값을 미리 알아야 "쓸 수 있나" 를 올바른 값으로 물을 수 있습니다. 검사는
	## 처음 값으로 하고 소모만 올리면, 숨이 모자란 채로 기술이 나가서 다음
	## 한 번이 통째로 막힙니다.
	if kind != _repeat_kind or _repeat_t <= 0.0:
		return base
	# "고른 숨"(스킬)이 **더 드는 몫만** 깎습니다. 처음 값은 그대로입니다 -
	# 연타를 싸게 하는 스킬이지 기술을 싸게 하는 스킬이 아닙니다.
	var step := REPEAT_STEP * (1.0 - state.repeat_relief)
	var mult := 1.0 + step * float(mini(_repeat_n, REPEAT_CAP))
	# **못 쓰는 기술이 되지는 않게** 합니다. 숨이 가득해도 못 쓰는 값이면
	# 비싸진 것이 아니라 없어진 것입니다.
	return minf(base * mult, state.max_breath * 0.95)


func _note_repeat(kind: String) -> void:
	## 기술을 쓴 것을 셈에 적습니다. 실제로 나간 뒤에 부릅니다.
	if kind == _repeat_kind and _repeat_t > 0.0:
		_repeat_n += 1
	else:
		_repeat_kind = kind
		_repeat_n = 1
	_repeat_t = REPEAT_WINDOW
	if _repeat_n > 2:
		# 세 번째부터는 화면에 알립니다. 숨 막대만으로는 "왜 이렇게 빨리
		# 닳지" 가 안 읽힙니다.
		Fx.popup_text(get_parent(), global_position + Vector3(0, 1.75, 0),
			"헉헉", Color(1.0, 0.85, 0.55))


func _has_breath(cost: float) -> bool:
	return state.breath >= cost


func _spend_breath(amount: float, pause: bool = true) -> void:
	state.breath = maxf(0.0, state.breath - amount)
	if pause:
		_breath_pause = BREATH_PAUSE


func _drive_pose_layer(delta: float) -> void:
	## 구르기 말고는 여기서 자세 층을 정합니다. 구르기는 자기 곡선으로 직접
	## 정하므로 건드리지 않습니다.
	##
	## 되돌리는 쪽을 잊으면 자세가 켜진 채로 남습니다 - 구르기가 끝난 뒤에도
	## 15% 쯤 접힌 채로 걸어 다니게 됩니다.
	if _pose == null or _roll_time > 0.0:
		return
	var want := 0.0
	if _lunge_time > 0.0 and _lunge_at != null:
		# 달려드는 자세가 맞은 자세 다음입니다. 달려가다 맞으면 그쪽이
		# 먼저 보여야 합니다.
		#
		# 달려가는 동안은 팔을 뒤로(RAM), 닿을수록 앞으로(LUNGE). 뒤로 젖힌
		# 팔이 앞으로 나오는 그 전환이 곧 "지금 친다" 입니다 - 그래서 전환
		# 자체가 보여야 합니다. 둘 사이를 섞어서 **뻗는 도중**을 만듭니다.
		#
		# 제곱해서 뒤로 갑니다(가속). 등속으로 뻗으면 미는 것이 아니라 팔을
		# 들어 올리는 것으로 보입니다 - 실제로 미는 팔은 늦게 출발해서 닿는
		# 순간에 가장 빠릅니다.
		_pose.pose = PoseOverride.mix_into(_lunge_pose,
			PoseOverride.RAM, PoseOverride.LUNGE, _lunge_swing * _lunge_swing)
		want = 1.0
	if _shove_hold > 0.0:
		# 밀친 직후. 뻗은 팔을 그대로 조금 더 둡니다.
		_pose.pose = PoseOverride.LUNGE
		want = 1.0
	if _bound_time > 0.0:
		# 붙잡힌 자세가 맞은 자세보다 앞입니다. 붙잡히는 순간 피해가 함께
		# 들어와서(_cling_grab) 둘이 같이 켜지는데, 그때 보여야 하는 것은
		# **왜 못 움직이는지**입니다.
		_pose.pose = PoseOverride.BOUND
		want = 1.0
	elif _hurt_time > 0.0:
		# 맞은 자세가 가장 앞입니다. 맞는 순간 하던 것이 무엇이든, 몸은
		# 그쪽을 먼저 따라야 "맞았다" 로 읽힙니다.
		_pose.pose = PoseOverride.HURT
		want = 1.0
	elif _lunge_time > 0.0 and _lunge_at != null:
		pass          # 위에서 이미 정했습니다
	elif not ext_pose.is_empty():
		# **베개싸움이 거는 자리.** 맞은 자세보다는 뒤, 나머지보다는 앞입니다 -
		# 휘두르는 도중에 막기나 고함의 자세가 끼면 몸과 베개가 따로 놉니다.
		_pose.pose = ext_pose
		want = 1.0
	elif _parry_air > 0.0:
		# **받아 내는 동안이 가장 앞입니다.** 그 사이에 다른 자세가 끼면
		# 발을 거는 그림이 통째로 안 보입니다.
		#
		# 몸을 내립니다. 엉덩이 높이가 고정이라 다리를 뻗으면 발이 뜨는데
		# (재 봤습니다: 0.18m), 발이 뜬 채로는 「걸었다」 가 아니라 발길질로
		# 보입니다.
		if body != null:
			body.position.y = HIP - PARRY_CROUCH
		_pose.pose = PoseOverride.TRIP
		want = 1.0
	elif _guard_pose > 0.0:
		# **웅크린 만큼 몸을 내립니다.** 엉덩이 높이가 고정이라 무릎만 접으면
		# 발이 바닥에서 떠오릅니다(재 봤습니다: 0.03 -> 0.11m).
		if body != null:
			var deep := clampf(_guard_pose / GUARD_POSE_MIN, 0.0, 1.0)
			body.position.y = HIP - GUARD_CROUCH * deep
		# **막는 자세가 고함보다 앞입니다.** 둘은 서로 다른 버튼이 됐지만,
		# 고함을 지른 직후에 막기를 누르면 `_shout_hold` 가 아직 남아 있어서
		# 팔이 뒤로 젖혀진 채로 막게 됩니다 - 지금 무엇을 하고 있는지는
		# **마지막에 누른 것**이 말해야 합니다.
		_pose.pose = PoseOverride.BLOCK
		want = 1.0
	elif _shout_hold > 0.0:
		# **모으기 시작하는 순간부터** 팔이 뒤로 갑니다.
		#
		# 예전에는 `_shout_hold` 하나만 봤는데, 그 값은 **떼는 순간**에
		# 걸립니다(`_try_attack`). 그래서 누르는 동안 내내 평소 자세로 서
		# 있다가 다 끝나고 나서야 팔이 뒤로 갔습니다 - 모으는 그림이 통째로
		# 빠져서, 화면에서는 소리와 부채꼴만 자라고 몸은 가만히 있었습니다.
		#
		# 지른 뒤 팔이 뒤에 남습니다(`_shout_hold`).
		#
		# 고함이 잡기보다 먼저입니다. 몹을 끌고 있으면 애초에 고함을 못 지르고
		# (_begin_shout), 소품을 들고 있을 때는 두 팔이 어디로 갈지 하나로
		# 정해져야 팔이 두 곳을 동시에 가리키지 않습니다.
		_pose.pose = PoseOverride.SHOUT
		want = 1.0
	elif _read_time > 0.0:
		# 꺼낼 때는 한 손을 뻗고(REACH), 돌 때는 안고(CARRY), 펼 때 읽습니다.
		match read_phase():
			0:
				_pose.pose = PoseOverride.READ_REACH_POSE
			1, 2:
				_pose.pose = PoseOverride.READ_HOLD
			_:
				# 한 손으로 든 자세에서 두 손 자세로 **섞어** 갑니다. 왼손이
				# 책 위로 올라오고, 벌어지는 만큼 책도 펼쳐집니다.
				_pose.pose = PoseOverride.mix_into(_read_pose,
					PoseOverride.READ_HOLD, PoseOverride.READ, _book_open)
		want = 1.0
	elif _drink_time > 0.0:
		# 마시는 자세가 잡은 자세보다 앞입니다. 우유갑도 손에 들려 있어서
		# 잡은 자세 조건에 걸리는데, 그러면 마시는 내내 그냥 들고만 있습니다.
		_pose.pose = PoseOverride.DRINK
		want = 1.0
	elif _carrying_enemy() and (_pose.weight < 0.05 or _pose.pose == PoseOverride.CARRY):
		_pose.pose = PoseOverride.CARRY
		want = 1.0
	# 맞은 자세만 훨씬 빨리 들어갑니다. 0.32초 만에 끝나는 동작이라 보통
	# 속도(16)로 섞으면 가장 웅크린 모양이 나오기 전에 풀려 버립니다.
	var rate := 45.0 if (_hurt_time > 0.0 or not ext_pose.is_empty()) else 16.0
	_pose.weight = lerpf(_pose.weight, want, 1.0 - exp(-rate * delta))


func _pose_roll(delta: float) -> void:
	## 앞구르기. 구르는 방향을 보고, 허리를 축으로 한 바퀴 돕니다.
	##
	## body 가 허리 높이에 있어서 회전 중심이 허리입니다(setup 참고). 발을
	## 축으로 돌면 구르기가 아니라 장대 넘어가듯 보입니다.
	_roll_time = maxf(0.0, _roll_time - delta)
	var t := 1.0 - clampf(_roll_time / ROLL_TIME, 0.0, 1.0)

	# 구르는 쪽을 봅니다. 굴러가면서 다른 데를 보고 있으면 이상합니다.
	var want_yaw := atan2(-_dash_dir.x, -_dash_dir.z)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, want_yaw, 1.0 - exp(-26.0 * delta))

	# 앞구르기. 머리가 진행 방향으로 먼저 숙여집니다.
	#
	# 부호는 눈으로 고르지 말고 재세요(--pose=roll --trace-at=1). 위에서
	# 내려다보는 카메라에서는 앞뒤가 거의 구분되지 않습니다. 머리 본의
	# 진행방향 거리가 **먼저 +로** 가야 앞구르기입니다.
	#
	# 마지막 두 마디는 반동입니다. 한 바퀴에서 딱 멈추면 브레이크를 밟은 것
	# 처럼 보입니다. 조금 더 돌아 머리가 다리보다 앞으로 나갔다가 중립으로
	# 되돌아오면, 구르던 기세가 남아 있는 것으로 읽힙니다.
	if t < ROLL_TURN:
		body.rotation.x = -(TAU + ROLL_OVERSHOOT) * ease(t / ROLL_TURN, 0.75)
	else:
		var back := (t - ROLL_TURN) / (1.0 - ROLL_TURN)
		body.rotation.x = lerpf(-(TAU + ROLL_OVERSHOOT), -TAU, ease(back, 0.45))
	body.rotation.z = lerp_angle(body.rotation.z, 0.0, 1.0 - exp(-20.0 * delta))
	# 몸을 웅크렸다 폅니다. 짧게 구르면 회전만으로는 "돈다" 로 보이고
	# "구른다" 로 안 보여서, 웅크림이 회전만큼 중요합니다.
	#
	# 한 바퀴가 끝나는 지점(TURN)에 맞춰 다 펴집니다. 반동 구간은 선 자세로
	# 남겨야 머리가 앞으로 나가는 것이 보입니다.
	var curl := clampf(t / ROLL_TURN, 0.0, 1.0)
	var tuck := 1.0 - sin(curl * PI) * 0.30
	body.scale = Vector3(tuck, tuck, tuck)
	# 몸 자체도 ㄷ 자로 접습니다. 크기만 줄이면 작아진 채로 **일자로** 도는
	# 것이라, 막대가 굴러가는 것으로 보입니다. 접힌 모양이 회전보다 먼저
	# 읽히므로 이쪽이 더 중요합니다.
	#
	# 접히고 펴지는 타이밍을 회전과 같은 곡선(sin)에 맞춥니다 - 웅크림이
	# 가장 깊은 순간이 바닥을 지나는 순간입니다.
	if _pose != null:
		_pose.pose = PoseOverride.ROLL
		_pose.weight = sin(curl * PI) * 0.85 + minf(curl, 1.0) * 0.15
	# 회전축이 떠올랐다 내려옵니다. 한 바퀴의 한가운데에서 가장 높습니다.
	body.position.y = HIP + sin(curl * PI) * ROLL_LIFT

	if _roll_probe:
		# 머리가 진행 방향으로 가면 앞구르기, 반대면 뒤구르기입니다.
		var skel := Models.find_skeleton(body)
		if skel != null:
			var head := skel.find_bone("Head")
			if head >= 0:
				var world: Vector3 = (skel.global_transform * skel.get_bone_global_pose(head)).origin
				var off := world - global_position
				print("[roll] t=%.2f  머리높이=%.2f  진행방향거리=%+.2f" % [
					t, off.y, off.dot(_dash_dir)])


# ---------------------------------------------------------------- 행동

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event.is_action_pressed("attack"):
		# 이 액션 이름은 그대로 두었습니다(좌클릭 / J). **하는 일이
		# 막기로 바뀐 것**이라, 액션 이름까지 고치면 키 설정이 통째로
		# 어긋납니다.
		parry_press()
	elif event.is_action_released("attack"):
		parry_release()
	elif event.is_action_pressed("dash"):
		_try_dash()
	elif event.is_action_pressed("grab") and attack_hook != null:
		# 베개싸움에서는 이 버튼이 **휘두르기**입니다. 잡기·던지기·고함이
		# 아니라 하나뿐이라, 갈래를 여기서 끊습니다.
		attack_hook.call("swing")
	elif event.is_action_pressed("grab"):
		grab_press()
	elif event.is_action_released("grab"):
		grab_release()


func attack() -> void:
	## **막기입니다.** 예전에는 이 자리가 고함이었는데, 고함이 공격 버튼으로
	## 넘어가면서 이 버튼이 비었습니다.
	parry_press()


func parry_release() -> void:
	## 손을 뗐습니다. 자세는 조금 더 남습니다 - 그 프레임에 뚝 끊기면 막다가
	## 사라진 것이 아니라 자세가 튄 것으로 보입니다.
	_guard_held = false


func guarding() -> bool:
	## 지금 막고 있나. 숨이 다하면 못 막습니다 - **버티는 데도 값이 듭니다.**
	##
	## 「0 보다 크다」로는 모자랍니다. 숨은 늘 조금씩 차오르므로, 바닥난
	## 뒤에도 한 톨 남은 것으로 계속 막힙니다(실측: 숨을 0 으로 두고 네
	## 프레임 뒤에 맞았더니 1.6 이 차 있어서 그대로 막았습니다). **한 대
	## 값만큼**은 있어야 합니다.
	return (_guard_held and not _dead and _parry_air <= 0.0
		and state.breath >= BREATH_GUARD_HIT)


func parry_press() -> void:
	## 판정 창을 엽니다. 이 안에 맞으면 그 한 대를 받아 냅니다.
	##
	## **공격은 안 나갑니다.** 순수한 방어입니다 - 누르면 뭐라도 나가는
	## 기술이면 계속 누르는 것이 답이 되어, 타이밍을 맞출 이유가 없습니다.
	if _dead or _parry_air > 0.0:
		return
	if _joy_time > 0.0 or _bound_time > 0.0 or _read_time > 0.0:
		return
	_guard_held = true
	_guard_pose = maxf(_guard_pose, GUARD_POSE_MIN)
	# **방금 맞았으면 그 한 대를 되돌립니다.** 창을 새로 열기 전입니다 -
	# 열고 나면 이 누름이 「앞으로의 한 대」 를 기다리는 것이 되어, 방금
	# 맞은 것은 영영 못 되돌립니다.
	if _parry_cd <= 0.0 and _try_late_parry():
		_parry_cd = PARRY_COOLDOWN
		return
	# **패링 창은 누른 그 순간에만** 열립니다. 누르고 있는 동안 계속 열려
	# 있으면 막기와 패링이 같은 것이 되어, 맞추는 일이 없어집니다.
	if _parry_cd > 0.0:
		return
	_parry_cd = PARRY_COOLDOWN
	_parry_ready = state.parry_window
	# **연 것은 자세가 말합니다.**
	#
	# 발밑에 고리를 띄워 봤는데, 막기는 **누르고 있는 기술**이라 그 고리가
	# 누를 때마다 발밑에서 커졌다 사라집니다 - 자주 나오는 표시가 매번 눈을
	# 끌면 그게 곧 잡음입니다. 몸이 이미 웅크리고 두 팔을 올리므로(BLOCK),
	# 표시는 그것으로 충분합니다. 귀로만 한 번 알립니다.
	Sfx.play_at(Sfx.PICK, 0.8, -8.0)


func shout_press() -> void:
	_begin_shout()


func shout_release() -> void:
	## 뗄 때는 아무 일도 없습니다. 신호는 그대로 두는데, 터치 버튼과 확인용
	## 배치가 여전히 짝으로 부르기 때문입니다.
	pass


## 고함을 모으는 것에 대하여.
##
## 누르는 동안 부채꼴이 **길이와 넓이 둘 다** 커집니다. 살짝 눌렀다 떼면 최소
## 범위이고 소리도 거기서 끊깁니다 - 소리가 온전히 다 나는 동안 누르고 있어야
## 최대입니다. 귀와 눈이 같은 것을 말하므로 언제까지 눌러야 하는지를 따로
## 배울 필요가 없습니다.
##
## **숨도 모은 만큼 듭니다.** 처음에는 값을 안 받았는데, 시작을 점만 하게
## 줄이면서 바꿨습니다 - 거의 안 닿는 고함에 온 숨을 내면 살짝 누르는 일이
## 그냥 낭비가 되고, 그러면 "짧게 지를 수도 있다" 는 선택이 사라집니다.
## 최소에서 30%, 최대에서 100% 입니다.
## 다 모으는 데 걸리는 시간(초).
##
## **0.86 에서 0.60 으로 줄였습니다.** 0.86 은 목소리가 살아 있는 길이에
## 맞춘 값이었는데, 손으로 쥐고 있기에는 깁니다 - 최대로 지르려면 매번 거의
## 1초를 서 있어야 하고, 그동안 발이 0.2배로 묶입니다.
##
## **소리는 그대로 끝까지 납니다.** 다 모여 저절로 나갈 때는 목소리를 끊지
## 않습니다(`_release_shout`) - 남은 0.45초가 지르고 난 여운이 됩니다.
## 끊으면 최대로 질렀는데 소리가 제일 짧아지는, 거꾸로 된 일이 생깁니다.
##
## 살짝 눌렀다 뗄 때만 거기서 끊깁니다. 그건 "덜 모았다" 가 귀에 남아야 해서
## 그렇습니다.
## **0.86 → 0.60 → 0.50.** 손으로 쥐고 있기에는 그만큼도 깁니다 - 최대로
## 지르려면 매번 서 있어야 하고 그동안 발이 0.2배로 묶입니다. 목소리(1.05초)의
## 절반이 채 안 되므로 남은 절반은 지르고 난 여운이 됩니다.
const SHOUT_CHARGE_TIME := 0.50
## 살짝 눌렀을 때의 몫. 0 이면 스쳐 누른 것이 헛손질이 되어, 눌렀는데 아무 일도
## 안 일어난 것처럼 보입니다.
## **끝까지 모았다**고 보는 값. 모으는 정도는 0~1 인데, 마지막 프레임에
## 0.9999 같은 값으로 끝나는 일이 있어서 1.0 으로 견주면 놓칩니다.
const SHOUT_FULL := 0.995
const SHOUT_CHARGE_MIN := 0.05
## 최소일 때와 최대일 때의 사거리 배수.
##
## **0.55 에서 0.14 로 내렸습니다.** 시작이 이미 절반이면 모으는 일이 "조금 더
## 넓어진다" 밖에 안 됩니다 - 거의 발밑의 점에서 자라야 커지는 것이 보입니다.
const SHOUT_REACH_MIN := 0.14
## 최소일 때와 최대일 때의 각도(도). 시작을 좁혀야 부채꼴이 **벌어지는** 것이
## 보입니다.
const SHOUT_ARC_MIN := 30.0
const SHOUT_ARC_MAX := 132.0
## 입의 높이(m). 소용돌이의 꼭짓점이 여기서 시작합니다.
##
## 키가 1.25m 이고 머리뼈가 키의 81% 쯤이라(베개를 놓을 때 재 둔 값) 입은
## 0.92 근처입니다.
const MOUTH_HEIGHT := 0.92


func shout_arc(charge: float) -> float:
	## 그때의 부채꼴 각도. **판정과 그림이 같은 함수를 씁니다.**
	return lerpf(SHOUT_ARC_MIN, SHOUT_ARC_MAX, clampf(charge, 0.0, 1.0))


func shout_reach(charge: float) -> float:
	## 그때의 사거리.
	return shout_range() * lerpf(SHOUT_REACH_MIN, 1.0, clampf(charge, 0.0, 1.0))


func _roll_afterimage() -> void:
	## 구르는 동안 남는 **파란 잔상**. 구르기 계통 Lv3 부터 붙습니다.
	##
	## 지나간 프레임의 **몸 모양 그대로**를 떨굽니다. 그러려면 그 순간의 자세가
	## 굳어 있어야 하는데, 스킨 메시는 뼈대를 따라 그려지므로 메시만 복제하면
	## 살아 있는 뼈대를 따라와 제자리에 겹칩니다. 그래서 **뼈대까지 통째로**
	## 복제하고 애니메이션을 떼어 그 자세에서 멈춰 세웁니다.
	##
	## 값이 싸지 않으므로(뼈 38개짜리 subtree 복제) 구르는 0.28초 동안 넷까지만
	## 떨굽니다. 그보다 촘촘해도 눈에는 같습니다.
	# **문턱은 Lv3 입니다.** 잔상은 「기존 5레벨 이펙트」였고, 계통을 끝까지
	# 판 자리의 상입니다. 상한이 3 이 되면서 2 로 내려 둔 적이 있는데, 그러면
	# 적을 통과하기만 하는 Lv2 가 눈에는 Lv3 과 같아 보입니다.
	var lv := skill_lv("roll")
	if lv < 3:
		return
	# 밝은 잔상은 **뚫는 몸**입니다(구르며 피해, Lv3).
	_afterimage(state.roll_pierce > 0.0)


## 달려드는 동안 잔상을 떨구는 간격(m). 구르기(0.34m)보다 성깁니다 - 달려드는
## 속도가 구르기보다 느려서, 같은 간격이면 잔상이 뭉쳐 한 덩어리로 보입니다.
const LUNGE_TRAIL_STEP := 0.42

## 달려들며 잔상을 떨군 뒤 지나간 거리(m).
var _lunge_trail := 0.0


func _lunge_afterimage(delta: float) -> void:
	## **밀기 계통 Lv3 부터** 달려드는 동안에도 파란 잔상이 남습니다.
	##
	## 밀기 Lv3 은 이미 밀리는 적 쪽에 잔상을 붙이는데(`_shove_one`), 그건
	## **맞은 뒤**의 그림입니다. 달려가는 사이는 여전히 평소와 같아서, 계통을
	## 끝까지 판 것이 **기술이 나가기 전까지는 화면에 안 보였습니다.**
	##
	## 구르기와 같은 방법입니다 - 거리마다 떨굽니다. 시간으로 떨구면 멀리서
	## 달려들 때 성기고 코앞에서 걸 때 뭉칩니다.
	if skill_lv("push") < 3:
		return
	_lunge_trail += Vector2(velocity.x, velocity.z).length() * delta
	if _lunge_trail < LUNGE_TRAIL_STEP:
		return
	_lunge_trail = 0.0
	# 밝은 잔상은 **피해까지 오른 밀기**입니다(Lv3 의 +60%). 구르기 잔상이
	# 「뚫는 몸」을 밝게 쓰는 것과 같은 규칙 - 밝으면 아픕니다.
	_afterimage(state.shove_damage >= 0.5)


## 잔상 한 장을 만드는 시간을 마디마디 모읍니다(`--pose=pushcost`).
static var ghost_n := 0
static var ghost_dup := 0
static var ghost_strip := 0
static var ghost_mat := 0
static var ghost_add := 0
static var ghost_tail := 0


## **잔상을 미리 만들어 두고 돌려 씁니다.**
##
## 예전에는 한 장마다 몸을 복제해서 붙이고, 0.3초 뒤에 버렸습니다. 데스크톱
## 에서는 0.89ms 라 괜찮아 보였는데 **폰에서는 한 장에 40~50ms** 였습니다
## (기록에서 스크립트 92~108ms 인 프레임에 「잔상」 표시가 줄줄이 붙었습니다).
## 리그가 달린 몸을 복제하고 버리는 일은 폰에서 그만큼 비쌉니다.
##
## 만들지도 버리지도 않습니다. 판을 시작할 때 열두 장을 만들어 두고, 쓸 때는
## **뼈 자세만 베껴** 옵니다(62개 대입). 다 쓰면 감췄다가 다시 씁니다.
const GHOST_POOL := 12
var _ghost_pool: Array[Node3D] = []
var _ghost_mat: Array[StandardMaterial3D] = []
## 각 장이 언제까지 보이나(0 이면 비어 있음)와 그 장의 총 수명.
var _ghost_left: PackedFloat32Array = PackedFloat32Array()
var _ghost_life: PackedFloat32Array = PackedFloat32Array()
## 다음에 꺼내 볼 자리. 빈 것이 없으면 **가장 오래된 것**을 뺏습니다 -
## 그러지 않으면 빨리 움직일 때 잔상이 뚝 끊깁니다.
var _ghost_next := 0


func _build_ghost_pool() -> void:
	## 열두 장을 한 번에 만들어 둡니다. **판을 시작할 때** 부릅니다 - 첫
	## 구르기에서 만들면 그 프레임이 통째로 값입니다.
	if not _ghost_pool.is_empty() or body == null:
		return
	_ghost_left.resize(GHOST_POOL)
	_ghost_life.resize(GHOST_POOL)
	for i in GHOST_POOL:
		var g := body.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		if g == null:
			return
		# 애니메이션과 자세 층을 떼어냅니다. **`queue_free()` 로는 안
		# 됩니다** - 그건 프레임 끝에 도는데 그 전에 `add_child` 가 돌아
		# 층들이 트리에 들어가고, 물리뼈 층이 뼈를 못 찾는다며 오류를 뼈
		# 수만큼 냅니다. 오류 한 줄마다 백트레이스가 붙어 그것만으로 한
		# 장에 100ms 였습니다.
		for node in _all_nodes(g):
			if is_instance_valid(node) and (node is AnimationPlayer
					or node is SkeletonModifier3D):
				if node.get_parent() != null:
					node.get_parent().remove_child(node)
				node.free()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for node in _all_nodes(g):
			if node is MeshInstance3D:
				var mi := node as MeshInstance3D
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# 카툰 외곽선이 잔상마다 검은 테두리를 두르면 그림자 떼가
				# 됩니다.
				mi.set_meta("flat", true)
		g.visible = false
		get_parent().add_child(g)
		_ghost_pool.append(g)
		_ghost_mat.append(mat)


func _afterimage(strong: bool) -> void:
	## 지금 자세 그대로의 **파란 잔상** 한 장. 미리 만들어 둔 것을 씁니다.
	if body == null:
		return
	var _t0 := Time.get_ticks_usec()
	_build_ghost_pool()
	if _ghost_pool.is_empty():
		return
	# 빈 자리를 찾습니다. 없으면 가장 오래된 것을 뺏습니다.
	var slot := -1
	for i in GHOST_POOL:
		var k := (_ghost_next + i) % GHOST_POOL
		if _ghost_left[k] <= 0.0:
			slot = k
			break
	if slot < 0:
		slot = _ghost_next
	_ghost_next = (slot + 1) % GHOST_POOL
	var g: Node3D = _ghost_pool[slot]
	if not is_instance_valid(g):
		return
	var _t1 := Time.get_ticks_usec()
	# **뼈 자세만 베낍니다.** 복제하지 않습니다.
	var src := Models.find_skeleton(body)
	var dst := Models.find_skeleton(g)
	if src != null and dst != null:
		for b in mini(src.get_bone_count(), dst.get_bone_count()):
			dst.set_bone_pose_position(b, src.get_bone_pose_position(b))
			dst.set_bone_pose_rotation(b, src.get_bone_pose_rotation(b))
			dst.set_bone_pose_scale(b, src.get_bone_pose_scale(b))
	var _t2 := Time.get_ticks_usec()
	var tone := Color(0.28, 0.60, 1.0) if not strong else Color(0.40, 0.80, 1.0)
	var a0 := 0.45 if not strong else 0.65
	_ghost_mat[slot].albedo_color = Color(tone.r, tone.g, tone.b, a0)
	var _t3 := Time.get_ticks_usec()
	g.global_transform = body.global_transform
	g.visible = true
	var _t4 := Time.get_ticks_usec()
	_ghost_life[slot] = 0.30 if not strong else 0.45
	_ghost_left[slot] = _ghost_life[slot]
	# **잔상도 표시를 답니다.** 구르기·밀기 누름과는 다른 자리입니다 - 누른
	# 프레임이 아니라 **가는 동안** 몇 장씩 떨어지므로, 누름 표시만 보면
	# "구르기 옆에서 끊긴다" 까지만 알고 그게 누름인지 잔상인지 모릅니다.
	Trace.mark("잔상")
	var _t5 := Time.get_ticks_usec()
	ghost_n += 1
	ghost_dup += _t1 - _t0
	ghost_strip += _t2 - _t1
	ghost_mat += _t3 - _t2
	ghost_add += _t4 - _t3
	ghost_tail += _t5 - _t4


func _drive_ghosts(delta: float) -> void:
	## 떠 있는 잔상을 흐리게 하고, 다 되면 감춥니다.
	##
	## **트윈을 안 씁니다.** 장마다 트윈을 만들면 그것도 만들고 버리는
	## 값이고, 열두 장이면 열두 개가 매 프레임 돕니다. 숫자 하나씩 줄이는
	## 편이 쌉니다.
	for i in _ghost_left.size():
		if _ghost_left[i] <= 0.0:
			continue
		_ghost_left[i] -= delta
		var g: Node3D = _ghost_pool[i]
		if _ghost_left[i] <= 0.0:
			if is_instance_valid(g):
				g.visible = false
			continue
		var k := clampf(_ghost_left[i] / maxf(_ghost_life[i], 0.0001), 0.0, 1.0)
		# 처음 진하기는 수명이 말해 줍니다(0.45 짜리는 0.30초, 밝은 것은
		# 0.45초) - 장마다 따로 들고 있을 값이 아닙니다.
		var full := 0.45 if _ghost_life[i] < 0.40 else 0.65
		var c: Color = _ghost_mat[i].albedo_color
		c.a = full * k
		_ghost_mat[i].albedo_color = c


func _all_nodes(root: Node) -> Array:
	## 하위 전부. 잔상에서 떼어낼 것과 색을 입힐 것을 찾는 데 씁니다.
	var out: Array = [root]
	var stack: Array = [root]
	while not stack.is_empty():
		for c in (stack.pop_back() as Node).get_children():
			out.append(c)
			stack.append(c)
	return out


func dash() -> void:
	_try_dash()


func _take_prop(prop: Node3D, grab_cost: float) -> void:
	## 손 닿는 데 있는 소품을 집거나 마십니다.
	##
	## 소품은 **그 자리에서** 집습니다. 물건은 등 뒤랄 것이 없으니 달려들
	## 이유도 없고, 발밑의 인형을 집으려고 몸이 튀어 나가면 그게 더
	## 이상합니다.
	if prop.is_drink():
		_begin_drink(prop)
		return
	_spend_breath(grab_cost)
	_note_repeat("grab")
	_grab_cd = _grab_cooldown() * 0.15
	_grab_cd_max = maxf(_grab_cd, 0.001)
	_hold_min = HOLD_MIN
	_push_time = PUSH_TIME
	_push_hit = true          # 소품을 집을 때는 밀기 판정을 하지 않습니다
	_play_push()
	Sfx.play(Sfx.GRAB, -3.0, 0.08)
	_take(prop)


func grab_press() -> void:
	## 한 번 누르면 잡고, **들고 있을 때 다시 누르면 던집니다.**
	##
	## 예전에는 누르고 있는 동안 들고, 떼면 던졌습니다. 폰에서 그게 잘 안
	## 됩니다 - 던지려면 한 엄지로 버튼을 누른 채 다른 엄지로 방향을 주고
	## 버튼만 떼야 하는데, 스틱을 먼저 놓는 일이 잦아 그냥 발밑에 떨어집니다.
	## 누르는 동작 하나로 통일하면 그 순서가 사라집니다.
	##
	## 잡을 것이 없으면 밀기입니다. 상황이 이미 하나로 정해져 있으므로 버튼을
	## 나누지 않습니다 - 엄지가 갈 곳만 늘어납니다.
	if _parry_air > 0.0:
		# **받아 내고 도는 동안에는 아무것도 안 받습니다.**
		return
	if _mash():
		return
	if ultimate_press("grab"):
		return
	if _joy_time > 0.0 or _dash_time > 0.0 or _dead or _throw_time > 0.0 or _drink_time > 0.0 or _read_time > 0.0:
		return
	if _held != null:
		if not is_instance_valid(_held):
			_held = null
			return
		# **집은 직후에는 던지지 않습니다.** 기억해 두지도 않습니다.
		#
		# 예전에는 이 자리에서 대기(_grab_cd) 검사에 걸려 누름이 큐에 들어갔고,
		# 대기가 풀리는 0.14초 뒤에 그 누름이 **던지기로 되살아났습니다.**
		# 짧게 한 번 눌렀을 뿐인데 집자마자 날아가는 것이 그래서였습니다.
		#
		# 큐가 필요한 것은 "잡기/밀기가 대기 중이라 아무 일도 안 일어난" 경우
		# 뿐입니다. 던지기는 이미 손에 든 것이 눈에 보이므로, 안 되면 다시
		# 누르면 됩니다 - 기억해 뒀다가 나중에 던지면 오히려 놀랍니다.
		if _hold_min > 0.0:
			return
		_throw_held()
		return
	if _grab_cd > 0.0:
		# 대기 중에 누른 것은 버리지 않고 기억해 뒀다가 풀리는 순간 씁니다.
		# 버리면 "분명히 눌렀는데 아무 일도 안 일어났다" 가 됩니다.
		_grab_queued = 0.25
		return

	# **상호작용이 먼저입니다.**
	#
	# 상인·책장 앞에서는 잡기가 아니라 말 걸기가 되어야 합니다. 소품 잡기보다
	# 앞에 두는 이유: 책장 옆에 인형이 굴러다니면 책 대신 인형이 잡힙니다.
	# 상호작용할 것이 없으면 false 라 하던 대로 이어집니다.
	if Game.instance != null and Game.instance.try_interact():
		return

	# **손 닿는 소품도 「상호작용」입니다.** 고함보다 앞에 둡니다 - 발밑에
	# 인형이 굴러다니는데 제자리에서 누르면 고함이 나가면, 인형을 집으려고
	# 인형 쪽으로 방향을 눌러야 합니다.
	#
	# 숨 검사도 여기서 합니다(소품 집기는 밀기와 같은 값입니다). 아래 고함
	# 갈래보다 앞이지만, **소품이 손 닿는 데 있을 때만** 지나갑니다.
	var near_prop := _nearest_prop()
	if near_prop != null and _grab_distance(near_prop) <= GRAB_RANGE:
		var prop_cost := breath_cost("grab", BREATH_GRAB)
		if not _has_breath(prop_cost):
			_out_of_breath()
			return
		_take_prop(near_prop, prop_cost)
		return

	# **제자리에서 누르면 고함입니다. 단, 상호작용이 먼저입니다.**
	#
	# 밀기와 고함을 한 버튼에 묶었습니다. 둘은 사거리가 2.6 대 2.7 로 거의
	# 같아서 **상황만으로는 못 가릅니다** - 같은 자리에서 둘 다 쓸 수 있으니
	# 사람이 골라야 하는데, 숨겨 놓고 알아서 고르면 눌러 보기 전에는 무엇이
	# 나올지 모릅니다. 그건 규칙이 아니라 운입니다. 이미 주고 있는 **이동
	# 입력**으로 가릅니다 - 밀기는 **가는** 기술이고 고함은 **여기를 쓰는**
	# 기술입니다.
	#
	# **이 갈래를 함수 맨 앞에 뒀던 것이 잘못이었습니다.** 그러면 책장 앞에
	# 가만히 서서 눌러도 고함이 나가고, 책을 꺼내려면 **책장 쪽으로 방향을
	# 누른 채** 눌러야 했습니다 - 말이 안 됩니다. 상호작용은 「여기 있는
	# 것에 손을 대는 일」이라 제자리에서 누르는 것이 바로 그 뜻입니다.
	#
	# 그래서 순서가 이렇습니다:
	#
	#   ① 손에 든 것이 있으면      던지기 (방향과 무관)
	#   ② 상인·책장·풀장이 있으면  말 걸기·읽기·물물교환
	#   ③ 소품이 손 닿는 데 있으면 집기·마시기
	#   ④ 방향이 없으면            **고함**
	#   ⑤ 방향이 있으면            밀기(달려들기)
	#
	# 숨 검사(밀기 30)보다도 앞입니다. 뒤에 두면 숨이 20 남았을 때 고함(10)을
	# 지를 수 있는데도 「숨 차」 가 뜹니다.
	if _held == null and _move_input().length_squared() < 0.04:
		_begin_shout()
		return

	# 밀기와 잡기는 **같은 버튼에서 나오는 한 가지 동작**이라 셈도 하나로
	# 봅니다. 나눠 세면 밀고 잡고를 번갈아 눌러 벌금을 피할 수 있는데, 손이
	# 하는 일은 그대로라 규칙이 말장난이 됩니다.
	var grab_cost := breath_cost("grab", BREATH_GRAB)
	if not _has_breath(grab_cost):
		_out_of_breath()
		return

	# 적에게는 **손을 뻗고 달려듭니다.**
	#
	# 예전에는 누르는 순간 그 자리에서 판정했습니다. 사거리 안이면 잡히고
	# 아니면 헛손질이라, 무엇이 일어날지가 눌러 봐야만 알 수 있었습니다.
	# 지금은 달려가는 동안 화면에 보이고, **손이 닿는 순간** 앞이냐 뒤냐로
	# 밀기와 잡기가 갈립니다 - 판정이 눈에 보이는 자리에서 일어납니다.
	var foe := _lunge_target()
	_spend_breath(grab_cost)
	_note_repeat("grab")
	_push_time = PUSH_TIME
	_push_hit = false
	# **달려들 때는 밀기 클립을 틀지 않습니다.**
	#
	# 그 클립이 도는 동안에는 `_drive_animation` 이 통째로 비켜서므로
	# (팔 동작이 걷기에 덮이면 안 되니까), 다리도 같이 멈춥니다 - 손만 뻗은
	# 채 미끄러져 갑니다. 팔은 자세 층(PoseOverride.LUNGE)이 이미 맡고 있어서
	# 클립이 없어도 됩니다. 클립을 빼면 다리는 걷기/달리기가 그대로 돕니다.
	if foe == null:
		_play_push()
	if foe != null:
		_lunge_at = foe
		_lunge_time = LUNGE_TIME
		_lunge_swing = 0.0
		# **달려드는 것도 한 번 쓴 것입니다.** 대기를 온전히 겁니다.
		#
		# 예전에는 여기서 0.15배(0.14초)만 걸었습니다. 손에 든 것을 던질 때
		# 버튼이 즉시 먹어야 해서 둔 값인데, 던지기는 이 검사보다 **앞에서**
		# 갈라지므로(`_held != null`) 대기와 상관이 없습니다. 남은 것은
		# "범위 안에 적이 있으면 0.14초마다 밀 수 있다" 뿐이었습니다 -
		# 달려드는 0.85초 동안 다시 눌러 달려들기가 처음부터 되살아나고,
		# 손이 닿아 밀친 자리(`_land_lunge`)에서는 대기를 걸지도 않아서
		# 적 앞에서는 밀기가 사실상 대기 없는 기술이었습니다.
		#
		# 실측(테스트 방에서 매 프레임 누름, 3초): 적 있음 20회 / 없음 4회.
		_grab_cd = _grab_cooldown()
		_grab_cd_max = maxf(_grab_cd, 0.001)
	else:
		# 아무도 없으면 제자리에서 한 번 밀칩니다. 헛손질도 동작은 나가야
		# 버튼이 먹은 것으로 느껴집니다.
		_grab_cd = _grab_cooldown()
		_grab_cd_max = maxf(_grab_cd, 0.001)
		Sfx.play(Sfx.PUSH, -1.0, 0.06)


func grab_release() -> void:
	## 이제 아무 일도 하지 않습니다.
	##
	## 지우지 않고 남겨 둡니다 - 키보드·터치·봇이 모두 뗄 때 이걸 부르는데,
	## 지우면 세 곳을 같이 고쳐야 하고 하나라도 빠뜨리면 조용히 죽습니다.
	pass


func _throw_held() -> void:
	## 들고 있는 것을 던집니다. 방향은 지금 주고 있는 쪽, 없으면 조금 전에
	## 가리킨 쪽, 그것도 없으면 보고 있는 쪽입니다.
	##
	## 방향이 없다고 발밑에 내려놓지 않습니다. 누름 한 번으로 던지는 방식에서는
	## "던지려고 눌렀는데 놓였다" 가 실수로만 느껴집니다 - 벽에 던지더라도
	## 던지는 쪽이 낫습니다.
	var input := _move_input()
	if input.length() < 0.25 and _last_dir_time > 0.0:
		input = _last_dir
	var dir := aim
	if input.length() >= 0.25:
		dir = Vector3(input.x, 0.0, input.y).normalized()

	# 바로 놓지 않습니다. **돌려서** 던집니다 - 뒤로 조금 느리게 감았다가,
	# 가속하며 던질 방향으로 더 돕니다. 던지는 힘이 어디서 나오는지가 보여야
	# 날아가는 거리가 납득됩니다.
	_grab_cd = _grab_cooldown() * 0.15
	_grab_cd_max = maxf(_grab_cd, 0.001)
	_hold_min = HOLD_MIN
	_throw_dir = _throw_direction(dir)
	_throw_time = THROW_WINDUP


func _hands_point() -> Vector3:
	## 두 손의 가운데. 몹이 붙어야 할 자리입니다.
	##
	## 잡기 자세(PoseOverride.CARRY)가 두 팔을 앞으로 모으므로, 그 손들의
	## 가운데가 곧 붙는 자리입니다. 자세와 위치를 따로 손으로 정하면 반드시
	## 어긋나므로 **자세가 만든 손 위치를 읽어서** 씁니다.
	_ensure_anchors()
	if _left_hand != null and _right_hand != null:
		return (_left_hand.global_position + _right_hand.global_position) * 0.5
	return global_position + aim * 0.45 + Vector3(0, 0.62, 0)


func _ensure_anchors() -> void:
	if _anchors_done:
		return
	_anchors_done = true
	_left_hand = Models.add_anchor(body, "LeftHand")
	_right_hand = Models.add_anchor(body, "RightHand")


func _hand_point() -> Vector3:
	## 오른손의 위치. 소품은 여기에 붙습니다.
	##
	## 머리 위에 얹으면 밀기 동작에서 팔은 뻗는데 물건은 정수리에 붙어 있어
	## 두 동작이 따로 놉니다. 본을 못 찾으면 몸 앞 허리 높이로 돌아갑니다 -
	## 모델을 바꿨을 때 물건이 사라지는 것보다는 낫습니다.
	_ensure_anchors()
	if _right_hand != null:
		return _right_hand.global_position
	return global_position + aim * 0.40 + Vector3(0, 0.62, 0)


func _drive_throw(delta: float) -> void:
	## 던지기 예비동작. 뒤로 반 바퀴 감았다가 가속하며 앞으로 반 바퀴.
	##
	## 한 방향으로 계속 돕니다(해머던지기와 같습니다). 뒤로 갔다가 앞으로
	## 되돌아오면 감은 것이 풀리는 것으로 보여서 힘이 실리지 않습니다.
	_throw_time = maxf(0.0, _throw_time - delta)
	var t := 1.0 - clampf(_throw_time / THROW_WINDUP, 0.0, 1.0)

	# 앞 구간은 뒤로 느리게 감고(15도), 뒤 구간은 가속하며 앞으로 돕니다(30도).
	#
	# 뒤 구간의 계수(0.667, 0.333)는 이어지는 각속도를 맞춘 값입니다. 그냥
	# u^2 로 두면 앞 구간 끝에서 속도가 0 으로 뚝 떨어졌다 다시 붙습니다.
	var offset := 0.0
	if t < THROW_WIND_PART:
		offset = -THROW_WIND_BACK * (t / THROW_WIND_PART)
	else:
		var u := (t - THROW_WIND_PART) / (1.0 - THROW_WIND_PART)
		offset = -THROW_WIND_BACK + THROW_SWING * (0.667 * u + 0.333 * u * u)
	if _roll_probe:
		print("[throw] t=%.2f 각도=%+.0f도" % [t, rad_to_deg(offset)])
	# **던질 방향을 기준으로** 앞뒤로 흔듭니다. 각도가 작아졌으므로 지금 보는
	# 각도에서 시작할 이유가 없습니다 - 오히려 던질 쪽을 보고 감아야 어느
	# 쪽으로 던지는지가 처음부터 보입니다.
	var target_yaw := atan2(-_throw_dir.x, -_throw_dir.z)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw + offset,
		1.0 - exp(-30.0 * delta))

	if _throw_time > 0.0:
		return

	# 다 돌았습니다. 놓습니다.
	var thrown := _held
	_held = null
	if not is_instance_valid(thrown):
		return
	_push_time = PUSH_TIME
	_push_hit = true          # 던지기는 밀기 판정을 따로 하지 않습니다
	_play_push()
	# 놓는 순간 손 위치에 딱 붙입니다. 들고 있는 동안에는 조금 늦게 따라오게
	# 해 두어서(손맛), 도는 도중에 놓으면 물건이 아직 뒤쪽에 남아 있습니다 -
	# 그 자리에서 날아가면 엉뚱한 쪽에서 나온 것으로 보입니다.
	# **소품만** 손 위치로 옮깁니다.
	#
	# 적은 들지 않고 **바닥에 끌고** 다니므로(hold_at 이 발 높이로 내립니다),
	# 손 높이로 올려 놓고 놓으면 0.67m 를 떨어집니다 - 밀려나는 그림에 뜬금없는
	# 낙하가 섞입니다. 있던 자리에서 그대로 밀려나야 합니다.
	if thrown is Prop:
		(thrown as Node3D).global_position = _hand_point()
	# **놓는 순간**입니다. 예비동작이 시작될 때 내면 아직 손에 있는데
	# 날아가는 소리가 먼저 납니다.
	#
	# **미는 소리**입니다(`THROW` 의 휙 소리가 아니라). 던지기는 밀기의
	# 연장이고 - 이펙트도 밀기 계통에서 뽑습니다 - 휙 소리는 0.34초짜리
	# 바람이라 몸이 돌아가는 큰 동작 끝에서 아무 일도 안 일어난 것처럼
	# 들렸습니다. 같은 손이 하는 일이면 같은 소리가 나야 합니다.
	Sfx.play(Sfx.PUSH, -1.0, 0.06)
	if thrown is Prop:
		thrown.throw(_throw_dir, state.damage * THROW_MULT)
	elif thrown is Enemy:
		# **던지기는 밀기의 연장입니다.**
		#
		# 잡아서 앞으로 보내는 것이라 손이 하는 일이 밀기와 같습니다. 그래서
		# 미는 힘을 키우는 스킬(억센 손·밀치는 힘)이 여기에도 그대로 붙습니다.
		# 따로 두면 밀기 계통을 파는 동안 잡기가 점점 쓸모없어집니다 - 같은
		# 버튼으로 나오는 두 기술인데 하나만 자라는 셈입니다.
		# 미는 세기를 **한 번만** 넘깁니다. 예전에는 `throw_knock` 에도 넣고
		# 배수(reach)에도 넣어서 스킬이 두 번 곱해졌습니다.
		thrown.throw_knock = SHOVE_KNOCK + state.shove_knock
		thrown.launch(_throw_dir, 1.0, state.damage * 0.8 * (1.0 + state.shove_damage))
	Fx.ring(get_parent(), global_position + _throw_dir,
		Color(1.0, 0.85, 0.5, 0.35), 1.1, 0.28)


func _throw_direction(wish: Vector3) -> Vector3:
	## 겨눈 쪽에 **화면 안의** 적이 있으면 그 적에게 던집니다.
	##
	## 화면 밖은 세지 않습니다. 안 보이는 적에게 물건이 빨려 들어가면 내가
	## 던진 것이 아니라 게임이 던진 것이 됩니다. 반대로 보이는 적을 겨눴는데
	## 옆으로 스치면 조준이 고장 난 것으로 느껴집니다 - 그래서 붙일 때는
	## **끝까지** 붙입니다.
	var best: Node3D = null
	var best_score := cos(THROW_SNAP_ARC)
	var cam: Camera3D = Game.instance.camera if Game.instance != null else null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if not is_instance_valid(enemy) or enemy == _held:
			continue
		var head: Vector3 = enemy.global_position + Vector3(0, 0.6, 0)
		if cam != null and not cam.is_position_in_frustum(head):
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.4:
			continue
		var score := to.normalized().dot(wish)
		if score > best_score:
			best_score = score
			best = enemy
	if best == null:
		return wish
	var to_enemy: Vector3 = best.global_position - global_position
	to_enemy.y = 0.0
	return to_enemy.normalized()


## 몹을 끌 때의 이동 배율. 달리기 문턱(최고 속도의 45%) 아래로 확실히
## 떨어지는 값이라, 끌고 가는 동안에는 걷기 동작만 나옵니다.
## 기술이 쓰는 숨. 100 이 가득입니다.
##
## 숨이 100 이므로 **한 번에 몇 번 쓸 수 있나**가 곧 이 값입니다.
##
##   고함 28   세 번 지르면 바닥
##   구르기 20  다섯 번 - 연달아 굴러 피할 수 있어야 합니다
##   밀기 8    열 번 이상. 기본기라 세면 안 됩니다
##
## 재사용 대기는 짧게 두고 **여기서 막습니다.** 대기로 막으면 기다리는 것이
## 답이 되지만, 숨으로 막으면 섞어 쓰는 것이 답이 됩니다.
## **처음 값**입니다(스테미나 계통을 안 찍은 상태). 숨이 100 이므로 곧
## "몇 번 쓸 수 있나" 로 읽힙니다 - 구르기 두 번 반, 밀기 세 번입니다.
##
## 28 / 20 / 8 이었습니다. 밀기가 너무 싸서 **밀기만 계속 누르는 것**이 늘
## 답이었고, 셋 중 무엇을 쓸지가 선택이 안 됐습니다.
const BREATH_SHOUT := 10.0
const BREATH_ROLL := 40.0
const BREATH_GRAB := 30.0
## 잡고 있는 동안 새는 양(초당). 0.1초에 0.5 씩 = 초당 5.
const BREATH_CARRY_DRAIN := 5.0
## 무거운 가구를 들고 있을 때. 세 배로 닳습니다 - 6.7초면 숨이 바닥납니다.
const BREATH_HEAVY_DRAIN := 15.0
## 무거운 가구를 든 채로 걷는 속도. 몹을 끌 때(0.42)보다도 느립니다.
const HEAVY_SPEED_SCALE := 0.28
## 방향 기억이 남는 시간.
##
## 던지려면 방향을 준 채로 잡기 버튼을 떼야 하는데, 엄지 두 개가 서로 다른
## 일을 하고 있어서 **스틱을 먼저 놓는 일이 잦습니다.** 그러면 방향이
## 없다고 판단해 그 자리에 툭 내려놓습니다 - 던진 줄 알았는데 안 던져지는
## 것으로 느껴집니다. 조금 전에 가리킨 쪽을 기억해 두면 그 어긋남이
## 사라집니다.
const AIM_MEMORY := 0.6
## 화면 안의 적에게 붙여 주는 각도.
##
## 이 안에 적이 있으면 **그쪽으로 정확히** 날아갑니다. 예전에는 35도 안에서
## 65%만 당겨 줬는데, 그러면 적을 겨눴는데도 옆으로 스치는 일이 남습니다 -
## 반쯤 도와주는 것이 도와주지 않는 것보다 나쁩니다.
const THROW_SNAP_ARC := deg_to_rad(45.0)
## 차오르는 속도(초당)와, 쓰고 나서 차기 시작할 때까지의 뜸.
##
## 뜸이 없으면 고함 직후에도 조금씩 차올라서 "바닥났다" 는 순간이 안
## 생깁니다. 60/초면 가득 차는 데 1.7초, 잡기 한 번 몫(10)은 0.17초입니다.
##
## 숨이 100 이 되면서 24 로 내렸습니다. 가득 차는 데 4.2초 - 구르기(20)
## 한 번 몫이 0.83초입니다. 60 을 그대로 두면 100 짜리 게이지가 1.7초에
## 가득 차서, 값을 100 으로 되돌린 이유가 사라집니다.
##
## 「스테미나」 계통이 여기에 더합니다(Lv3 이면 64/초).
const BREATH_REGEN := 24.0
const BREATH_PAUSE := 0.3

## 같은 기술을 잇달아 쓸 때 숨이 더 드는 비율.
##
## # 왜 필요한가
##
## 기술마다 값이 달라도 **연타는 언제나 최선**이었습니다. 숨이 차오르는 대로
## 같은 버튼을 계속 누르면 되니까, "지금 무엇을 쓸까" 가 "지금 쓸 수 있나" 로
## 줄어듭니다. 특히 밀기는 10 밖에 안 들어서 사실상 무한이었습니다.
##
## 한 번 더 쓸 때마다 **처음 값의 절반씩** 더 듭니다. 두 번째는 1.5배,
## 세 번째는 2배, 네 번째부터는 2.5배로 멈춥니다. 그 위로 계속 올리면 어느
## 순간부터 못 쓰는 기술이 되는데, 그건 비싸진 것이 아니라 사라진 것입니다.
##
## **다른 기술로 바꾸면 그 자리에서 처음 값으로 돌아옵니다.** 이 규칙이 하는
## 말은 "쉬어라" 가 아니라 **"섞어 써라"** 입니다 - 밀고 지르고 구르면 값이
## 안 오르고, 같은 것만 반복하면 오릅니다.
const REPEAT_STEP := 0.5
const REPEAT_CAP := 3
## 이 시간 안에 같은 기술을 또 쓰면 연타로 봅니다. 숨이 다시 차는 데 걸리는
## 시간(80 을 쓰면 1.6초)과 비슷하게 잡아, 기다렸다 쓰면 값이 안 오릅니다.
const REPEAT_WINDOW := 1.7

const CARRY_SPEED_SCALE := 0.42
## 던지기 예비동작 길이.
##
## 한 바퀴를 돌리다가 45도만 돌리는 것으로 바꿨습니다. 한 바퀴는 도는 동안
## 물건이 몸 반대편까지 휘돌아 가서, **오른쪽으로 던졌는데 왼쪽에서 날아가는
## 것처럼** 보였습니다. 각도가 작으면 그 착시가 사라집니다.
const THROW_WINDUP := 0.22
## 그중 앞 구간(뒤로 감기)이 차지하는 비율. 나머지가 던지는 구간입니다.
const THROW_WIND_PART := 0.45
## 뒤로 감는 각도와, 이어서 앞으로 도는 각도.
##
## 앞으로 30도를 도는데 그중 15도는 감은 것을 푸는 데 쓰이므로, 던지는 방향을
## 15도 지나쳐 멈춥니다 - 그 15도가 던지고 난 뒤의 여운입니다.
const THROW_WIND_BACK := deg_to_rad(15.0)
const THROW_SWING := deg_to_rad(30.0)

## 등 뒤로 인정하는 범위. 0.25 면 옆에서 조금 앞까지, 뒤쪽 약 209도입니다.
##
## 처음에는 -0.35(뒤쪽 110도)로 좁게 뒀는데, 적이 늘 이쪽을 보고 도니 정확히
## 뒤통수에 서는 순간이 오지 않아 **사실상 잡을 수가 없었습니다.** 옆에서도
## 잡히게 열어 두고 정면만 확실히 막습니다 - 판단은 "정면으로 달려들지 말 것"
## 하나로 남기고 그 이상은 요구하지 않습니다.
const BEHIND_DOT := 0.25


## 잡은 적이 대신 맞을 때의 배율. 1.0 이면 받은 만큼 그대로 넘깁니다.
##
## 1.0 을 넘기지 않는 이유: 방패로 쓰는 것만으로 적이 빨리 죽으면, 잡고 서서
## 맞아 주는 것이 가장 좋은 공격이 됩니다. 막아 주는 값은 **피해를 안 받는
## 것**이지 상대가 더 아픈 것이 아닙니다.
const SHIELD_MULT := 1.0
## 앞으로 인정하는 각도. 1.0 이 정면, 0 이면 옆까지입니다.
const SHIELD_DOT := 0.15


func _shield_blocks(from: Vector3) -> bool:
	## 잡은 적이 이 공격을 대신 맞는가.
	if not _carrying_enemy():
		return false
	if from == Vector3.ZERO:
		return false          # 어디서 왔는지 모르면 막지 않습니다
	var to := from - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	return to.normalized().dot(_facing()) >= SHIELD_DOT


func _shield_take(amount: float, from: Vector3) -> void:
	## 잡힌 적이 대신 맞습니다.
	var shield := _held as Enemy
	if shield == null:
		return
	var dir := (shield.global_position - from)
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else _facing()
	Fx.popup_text(get_parent(), global_position + Vector3(0, 1.6, 0),
		"막았다", Color(0.7, 0.9, 1.0))
	Game.shake(0.18, 0.14)
	# 잡힌 채로는 밀려나면 안 됩니다(손에서 빠집니다). 경직만 줍니다.
	shield.take_damage(amount * SHIELD_MULT, false, Vector3.ZERO, 0.0)
	if not is_instance_valid(shield) or shield.hp <= 0.0:
		# 다 버티고 죽었습니다. 손이 비었으니 자세도 풀립니다.
		_held = null


func _carrying_enemy() -> bool:
	## `is_instance_valid` 를 **먼저** 봅니다. `is` 는 해제된 인스턴스에 대고
	## 쓰면 그 자리에서 오류라, and 의 오른쪽에 두면 이미 늦습니다. 들고 있던
	## 적이 죽으면(다른 적의 돌진, 폭죽) 정확히 그 상황이 됩니다.
	return is_instance_valid(_held) and _held is Enemy


func _carrying_prop() -> bool:
	return is_instance_valid(_held) and _held is Prop


func _carrying_heavy() -> bool:
	return _carrying_prop() and (_held as Prop).is_heavy()


func behind_of(enemy: Enemy) -> bool:
	## 봇이 "돌아 들어갔는지" 를 물어볼 수 있게 열어 둡니다.
	return _behind(enemy)


func _behind(enemy: Enemy) -> bool:
	## 적의 등 뒤에 서 있는가.
	##
	## 앞에서는 잡지 못하고 밀기가 나갑니다. 잡기가 더 센 기술이므로 아무 데서나
	## 되면 밀기를 쓸 이유가 없어집니다. **뒤로 돌아 들어가는 수고**를 값으로
	## 치르게 하면 둘이 다른 상황의 답이 됩니다.
	var to_me: Vector3 = global_position - enemy.global_position
	to_me.y = 0.0
	if to_me.length() < 0.05:
		return true
	return enemy.facing().dot(to_me.normalized()) < BEHIND_DOT


func _grab_distance(node: Node3D) -> float:
	## 표면까지의 거리. 물건 반지름을 빼서 **몸집이 큰 것도 닿으면 잡히게**
	## 합니다.
	var to: Vector3 = node.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > 0.25 and to.normalized().dot(aim) < cos(GRAB_ARC * 0.5):
		return INF
	var bulk := 0.0
	if node is Prop:
		bulk = (node as Prop).throw_size() * 0.5
	else:
		bulk = float(node.get_meta("body_radius", 0.3))
	return maxf(0.0, d - bulk)


func _take(target: Node3D) -> void:
	if target is Prop:
		if target.grab(self):
			_held = target
	elif target is Enemy:
		target.hold(self)
		_held = target
		_hold_pass(target, true)
	if _held != null:
		Fx.popup_text(get_parent(), global_position + Vector3(0, 1.5, 0),
			"잡았다", Color(1.0, 0.85, 0.5))


## 지금 서로 통과하기로 해 둔 아이. **되돌리는 곳을 한 군데로** 두려고
## 들고 있습니다 - `_held` 를 지우는 곳이 여덟 군데라, 거기마다 되돌리면
## 반드시 한 곳을 빠뜨립니다(그러면 놓은 뒤에도 영영 통과합니다).
var _pass_with: Node3D = null


func _hold_pass(who: Node3D, on: bool) -> void:
	## **잡은 그 아이하고만 서로 통과합니다.**
	##
	## 잡힌 아이는 매 프레임 손 자리로 끌려옵니다(`Enemy.hold_at`). 그런데
	## 주인공의 충돌 마스크에 적 층이 들어 있어서, 끌려온 몸이 주인공과
	## 겹치면 물리가 그 겹침을 **밀어내며 풉니다** - 매 프레임 밀리니 속도가
	## 쌓이고, 크고 무거운 아이(베개)일수록 겹침이 깊어 더 세게 튕깁니다.
	## 그렇게 빨라진 몸은 벽도 지나갑니다.
	##
	## 층을 통째로 끄면 안 됩니다 - 잡은 동안에도 **다른 적**과는 부딪혀야
	## 합니다. 그 하나만 예외로 뺍니다.
	if not is_instance_valid(who) or not (who is CollisionObject3D):
		return
	if on:
		_pass_with = who
		add_collision_exception_with(who)
	else:
		_pass_with = null
		remove_collision_exception_with(who)


func _begin_drink(prop: Prop) -> void:
	## 우유를 두 손에 쥐고 마시기 시작합니다.
	##
	## 회복은 **다 마신 뒤에** 옵니다. 누르는 순간 차오르면 동작이 장식이
	## 되고, 적 앞에서 눌러 놓고 도망가도 이득입니다. 0.85초를 버텨야
	## 받는 것이라야 "지금 마셔도 되나" 가 판단이 됩니다.
	_spend_breath(BREATH_GRAB)
	_grab_cd = _grab_cooldown() * 0.15
	_grab_cd_max = maxf(_grab_cd, 0.001)
	_drink_time = DRINK_TIME
	_gulped = false
	if prop.grab(self):
		_held = prop
	Sfx.play(Sfx.GRAB, -3.0, 0.08)
	_gulp()


func _drive_read(delta: float) -> void:
	## 읽기 네 마디를 굴립니다. 남은 시간에서 지금이 어느 마디인지 뽑습니다 -
	## 마디마다 타이머를 따로 두면 넷이 어긋납니다.
	##
	## 발도 여기서 옮깁니다. 조작이 잠겨 있어(_move_input 이 0 을 돌려 줍니다)
	## 걷기로는 못 움직이는데, 다가가고 물러나는 것이 이 동작의 절반입니다.
	var done := READ_TIME - _read_time
	var open := 0.0
	var move := Vector3.ZERO
	# 몸의 오른쪽. 앞을 -Z 로 보는 규약에서 오른쪽은 이렇게 나옵니다.
	var right := Vector3(-_read_from_face.z, 0.0, _read_from_face.x)
	var yaw0 := atan2(-_read_from_face.x, -_read_from_face.z)

	if done < READ_REACH:
		# 1. 뻗기. 책장 쪽으로 천천히 다가갑니다. 책은 아직 책장 안입니다.
		aim = _read_from_face
		move = _read_from_face * 0.85
		if _book != null:
			_book.visible = false
	elif done < READ_REACH + READ_PULL:
		# 2. 빼기. **덮인 채** 책장에서 손으로 끌려 나옵니다.
		var u := clampf((done - READ_REACH) / READ_PULL, 0.0, 1.0)
		aim = _read_from_face
		if _book != null:
			_book.visible = true
			_book.global_position = _read_shelf_at.lerp(_book_point(0.0), u * u)
			_book.global_rotation = Vector3(0.0, _facing_yaw(), 0.0)
	elif done < READ_REACH + READ_PULL + READ_BACK:
		# 3. 물러나기. 오른쪽 뒤로 물러나며 몸이 조금 돌아갑니다.
		#
		# **중간이 보여야 합니다** - 각도를 한 번에 바꾸면 순간이동이고,
		# 이어서 돌리면 방향키로 돌린 것처럼 보입니다. 화면을 정면으로 볼
		# 필요는 없습니다. 돌아섰다는 것만 보이면 됩니다.
		var u := clampf((done - READ_REACH - READ_PULL) / READ_BACK, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		aim = _yaw_dir(yaw0 + READ_TURN_ANGLE * e)
		move = (right * 0.9 - _read_from_face * 0.8) * (1.0 - e * 0.6)
		if _book != null:
			_book.global_position = _book_point(0.0)
			_book.global_rotation = Vector3(0.0, _facing_yaw(), 0.0)
	else:
		# 4. 펴기. 왼손이 책 위로 올라오면서 좌우로 펼쳐집니다.
		var u := clampf(
			(done - READ_REACH - READ_PULL - READ_BACK) / READ_OPEN, 0.0, 1.0)
		open = clampf(u / 0.55, 0.0, 1.0)
		open = open * open * (3.0 - 2.0 * open)
		aim = _yaw_dir(yaw0 + READ_TURN_ANGLE)
		if _book != null:
			_book.global_position = _book_point(open)
			_book.global_rotation = Vector3(0.0, _facing_yaw(), 0.0)

	velocity.x = move.x
	velocity.z = move.z
	_book_open = open
	_shape_book(open)


func _yaw_dir(yaw: float) -> Vector3:
	## 각도를 보는 방향으로. 앞은 -Z 입니다.
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func read_phase() -> int:
	## 0 뻗기 / 1 빼기 / 2 물러나기 / 3 펴기. 자세를 고를 때 씁니다.
	var done := READ_TIME - _read_time
	if done < READ_REACH:
		return 0
	if done < READ_REACH + READ_PULL:
		return 1
	if done < READ_REACH + READ_PULL + READ_BACK:
		return 2
	return 3


func begin_read(cover: Color, face: Vector3 = Vector3.ZERO) -> void:
	## 책장에서 책을 한 권 꺼내 읽기 시작합니다.
	##
	## `face` 는 **책장을 등진 쪽**입니다. 책을 꺼내고 돌아서서 읽습니다 -
	## 벽을 마주 본 채 읽으면 큰 머리에 가려 책이 한 픽셀도 안 보입니다.
	## 사람도 책을 꺼내면 돌아서서 봅니다.
	# 지금 보고 있는 쪽이 곧 책장 쪽입니다(그 앞에 서서 눌렀으니).
	_read_from_face = _facing()
	# 돌아설 곳은 **화면 쪽**입니다. 카메라에서 뽑으므로 두 시점 모두에서
	# 맞습니다 - 세계 좌표로 적어 두면 어깨 너머에서 엉뚱한 데를 봅니다.
	_read_face = face
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		# 카메라의 **위치**가 아니라 **보는 축**에서 뽑습니다.
		#
		# 위치로 재면 카메라가 따라오는 중일 때 엉뚱한 쪽이 나옵니다 - 몸이
		# 순간이동하거나 빠르게 움직인 직후에는 카메라가 아직 뒤에 있어서,
		# "화면 쪽" 이 옆이나 뒤가 됩니다. 보는 축은 그때도 그대로입니다.
		# basis.z 는 화면에서 **바라보는 사람 쪽**을 가리킵니다.
		var toward: Vector3 = cam.global_transform.basis.z
		toward.y = 0.0
		if toward.length_squared() > 0.01:
			_read_face = toward.normalized()
	if _read_face.length_squared() > 0.001:
		_read_face.y = 0.0
		_read_face = _read_face.normalized()
	# 책이 빠져나올 자리. 몸 앞 책장의 책 높이입니다.
	_read_shelf_at = global_position + _read_from_face * 0.55 + Vector3(0, 0.62, 0)
	_read_time = READ_TIME
	# **읽는 동안은 안 맞습니다.**
	#
	# 다 읽으면 스킬 고르기 창이 열리고 그때는 게임이 멈춥니다(실측: 창이 뜬
	# 다음 프레임이 아예 안 옵니다). 그런데 **창이 뜨기 전 이 동작**은 그대로
	# 돌아서, 책을 꺼내 돌아서서 펴는 사이에 얻어맞았습니다 - 손에는 "고르는
	# 중에 맞았다" 로 느껴집니다.
	#
	# 여기서 멈출 수는 없습니다. 멈추면 이 동작 자체가 안 돌아 책을 영영 못
	# 펴고, 창도 안 열립니다. 그래서 **동작이 도는 동안 안전하게** 둡니다.
	_invuln = maxf(_invuln, READ_TIME)
	_book = _make_book(cover)
	get_parent().add_child(_book)
	_book.global_position = _read_shelf_at
	_book.visible = false
	Sfx.play(Sfx.PAGE, -6.0, 0.10)


func is_reading() -> bool:
	return _read_time > 0.0


func _finish_read() -> void:
	_read_time = 0.0
	if is_instance_valid(_book):
		_book.queue_free()
	_book = null
	_book_halves.clear()
	read_done.emit()


func _book_point(open: float = 1.0) -> Vector3:
	## 책이 놓이는 자리. 손 위치에서 **앞·위로 조금 더** 내밉니다.
	##
	## 손에 딱 붙이면 내려다보는 화면에서 몸과 머리에 가려 안 보입니다 -
	## 우유갑을 입 높이로 올린 것과 같은 이유입니다. 펼친 면이 카메라를
	## 향해야 책으로 읽힙니다.
	var face := -pivot.global_transform.basis.z if pivot != null else Vector3.FORWARD
	face.y = 0.0
	# 덮인 책은 **오른손에만** 들려 있습니다. 펴지면서 두 손 가운데로 옮겨
	# 옵니다 - 왼손이 올라와 같이 받치는 것이 그 움직임입니다.
	var at: Vector3 = _hand_point().lerp(_hands_point(), open)
	return at + face.normalized() * 0.06 + Vector3(0, 0.07, 0)


func _facing_yaw() -> float:
	return pivot.global_rotation.y if pivot != null else 0.0


## 반쪽 하나의 기본 폭(m). 실제 폭은 손 간격에 맞춰 매 프레임 늘립니다.
const BOOK_HALF := 0.15


func _make_book(cover: Color) -> Node3D:
	## 펼친 책. 표지 두 쪽을 **좌우로** 벌리고 그 위에 흰 종이를 얹습니다.
	##
	## 책등은 몸의 앞뒤 축을 따라 눕습니다. 예전에는 반대로 만들어 책이
	## 앞뒤로 펴졌는데, 내려다보는 화면에서는 그게 **위아래로 펴지는** 것으로
	## 보입니다 - 책을 눕혀 놓고 위아래로 접었다 폈다 하는 모양이었습니다.
	##
	## 네 개의 상자면 충분합니다 - 손에 들린 30cm 짜리 물건이라, 그보다
	## 자세히 만들어도 보이지 않습니다.
	var root := Node3D.new()
	root.name = "Book"
	_book_halves.clear()
	for side in [-1.0, 1.0]:
		var cover_mi := MeshInstance3D.new()
		var cover_mesh := BoxMesh.new()
		cover_mesh.size = Vector3(BOOK_HALF, 0.014, 0.19)
		cover_mi.mesh = cover_mesh
		var cover_mat := StandardMaterial3D.new()
		cover_mat.albedo_color = cover
		cover_mat.roughness = 0.8
		cover_mi.material_override = cover_mat
		root.add_child(cover_mi)
		_book_halves.append([cover_mi, side, 0.0])

		var page_mi := MeshInstance3D.new()
		var page_mesh := BoxMesh.new()
		page_mesh.size = Vector3(BOOK_HALF * 0.92, 0.012, 0.174)
		page_mi.mesh = page_mesh
		var page_mat := StandardMaterial3D.new()
		page_mat.albedo_color = Color(0.98, 0.97, 0.92)
		page_mat.roughness = 0.9
		page_mi.material_override = page_mat
		root.add_child(page_mi)
		_book_halves.append([page_mi, side, 0.014])
	return root


func _shape_book(open: float) -> void:
	## 책의 두 쪽을 **손 간격에 맞춰** 놓습니다.
	##
	## 폭을 손에서 뽑는 이유: 자세가 펴지면서 손이 벌어지는데, 책 폭을 상수로
	## 두면 손이 책 밖으로 나갑니다. 손 사이를 재서 그만큼 채우면 **책이 손을
	## 벌린 것**처럼 보입니다 - 실제로 펼친 책을 들면 그렇게 됩니다.
	if _book_halves.is_empty():
		return
	_ensure_anchors()
	var spread := 2.0 * BOOK_HALF
	if _left_hand != null and _right_hand != null:
		spread = _left_hand.global_position.distance_to(_right_hand.global_position)
	# 덮였을 때는 손 간격과 무관합니다(한 손에 들려 있으니). 펴지면서 두 손
	# 사이를 채우는 폭으로 옮겨 갑니다.
	var half_w: float = lerpf(BOOK_HALF, maxf(spread * 0.5, 0.05), open)
	for entry in _book_halves:
		var node: Node3D = entry[0]
		if not is_instance_valid(node):
			continue
		var side: float = float(entry[1])
		var lift: float = float(entry[2])
		# 반쪽은 책등에서 손까지를 채웁니다. 가운데가 그 절반 자리입니다.
		node.scale.x = half_w / BOOK_HALF
		# **덮였을 때는 두 쪽이 포개집니다**(x = 0). 펴지면서 좌우로
		# 벌어집니다 - 예전에는 접힌 상태에서도 나란히 놓여 있어서, 처음부터
		# 펴진 책을 들고 나오는 것으로 보였습니다.
		node.position = Vector3(side * half_w * 0.5 * open, lift, 0.0)
		# 바깥쪽 모서리가 위로 들립니다. 덮으면 0(평평), 펴면 V.
		node.rotation.z = side * 0.30 * open


func _gulp() -> void:
	## 마시는 소리를 글자로 냅니다. 0.85초 동안 화면에 아무 말이 없으면
	## 회복이 **일어났는지도** 모른 채 지나갑니다 - 소리는 폰에서 꺼 두는
	## 사람이 많아서 글자가 마지막 신호입니다.
	Fx.popup_text(get_parent(), global_position + Vector3(0, 1.45, 0),
		"꿀꺽꿀꺽", Color(1.0, 1.0, 0.92))


func _finish_drink() -> void:
	## 다 마셨습니다. 우유갑은 사라지고 체력이 찹니다.
	_drink_time = 0.0
	var amount := 0.0
	var drink := _held as Prop
	_held = null
	if is_instance_valid(drink):
		amount = drink.heal_amount()
		drink.queue_free()
	if amount <= 0.0:
		return
	state.heal(amount)
	Fx.popup_text(get_parent(), global_position + Vector3(0, 1.5, 0),
		"+%d" % int(amount), Color(0.6, 1.0, 0.7))


func _play_push() -> void:
	if _anim == null or _push_clip == "":
		return
	_anim.play(_push_clip)
	# 클립은 0.83초짜리인데 기술은 0.42초입니다. 배속을 맞춰 둘이 같이 끝나게 합니다.
	_anim.speed_scale = (20.0 / 24.0) / PUSH_TIME


func _lunge_target() -> Node3D:
	## 보고 있는 쪽의 가장 가까운 적. 등 뒤는 세지 않습니다 - 뒤로 달려드는
	## 것은 조작이 아니라 사고입니다.
	# **록온이 꺼져 있으면 넓게 봅니다.** 그때는 조준이 가는 쪽이라, 좁은 각을
	# 그대로 두면 옆에 붙은 적을 밀려고 매번 몸을 돌려 세워야 합니다.
	var arc := GRAB_ARC if auto_aim else GRAB_ARC_FREE
	var half := cos(arc * 0.5)
	var best: Node3D = null
	# **닿는지(사거리·각)와 고르는 것(점수)은 다른 일입니다.** 점수를 사거리로
	# 막아 두면 2.4m 40도처럼 **닿는데 점수만 넘는** 적이 조용히 빠집니다.
	var best_score := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not is_instance_valid(enemy) or enemy.held_by != null:
			continue
		# **밀려 날아가는 중이면 못 겁니다.** 붙잡아 두는 밀기를 막습니다.
		if not enemy.is_targetable():
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d >= LUNGE_RANGE:
			continue
		var dot := 1.0 if d <= 0.2 else to.normalized().dot(aim)
		if dot < half:
			continue
		# **거리에 각을 얹어 고릅니다.** 순전히 가까운 것으로 고르면 넓힌
		# 각에서 어깨 뒤가 이깁니다 - 겨눈 쪽이 아닌 것이 밀리면, 넓힌 것이
		# 도움이 아니라 딴 데를 치는 일이 됩니다.
		var score := d + acos(clampf(dot, -1.0, 1.0)) * GRAB_ANGLE_COST
		if score >= best_score:
			continue
		best_score = score
		best = enemy
	return best


func _drive_lunge(delta: float) -> void:
	## 손을 뻗은 채 상대에게 달려갑니다. 닿으면 그 자리에서 판정합니다.
	_lunge_time = maxf(0.0, _lunge_time - delta)
	if _lunge_at == null or not is_instance_valid(_lunge_at):
		_lunge_at = null
		_lunge_time = 0.0
		_lunge_trail = 0.0
		return
	_lunge_afterimage(delta)
	var to: Vector3 = _lunge_at.global_position - global_position
	to.y = 0.0
	# **손이 실제로 닿는 거리**입니다.
	#
	# 예전에는 `사거리 x 0.55 + 적 반지름` 이라 **1.54m** 였습니다. 그런데 두
	# 몸을 합쳐도 0.42m(실측: 내 0.20 + 적 0.22)뿐입니다 - 몸 세 개가 들어갈
	# 거리에서 넉백이 터졌습니다. 손은 허공을 지나는데 적이 날아갔습니다.
	#
	# 두 반지름을 더한 값이 살이 맞닿는 거리이고, 거기에 손끝 여유를 조금
	# 얹습니다. 서로 밀어내는 충돌 때문에 그보다 가까워지지도 않으므로,
	# 이 값이면 붙는 순간에 터집니다.
	var reach: float = _body_radius 		+ float(_lunge_at.get_meta("body_radius", 0.4)) + HAND_REACH
	if to.length() <= reach:
		_land_lunge(_lunge_at)
		return
	if _lunge_time <= 0.0:
		# 못 닿았습니다. 헛손질로 끝냅니다.
		_lunge_at = null
		return
	# 얼마나 뻗을지를 **남은 거리에서** 뽑습니다.
	#
	# 달려가는 동안에는 팔을 **뒤로** 젖힙니다(서진의 박치기와 같은 자세).
	# 앞으로 뻗은 채 달려오면 그 자세가 너무 오래 남아, 손이 닿는 순간이
	# 특별해 보이지 않습니다. 마지막에 뻗어야 그 순간이 동작의 정점이 됩니다.
	#
	# 시간이 아니라 거리로 재는 이유: 그래야 **닿는 순간에 정확히 다 뻗습니다.**
	# 시간으로 하면 상대가 다가오거나 멀어질 때 뻗기가 먼저 끝나거나 덜 뻗은
	# 채로 닿습니다.
	var near := clampf(1.0 - (to.length() - reach) / REACH_LEAD, 0.0, 1.0)
	# 한 번 나가기 시작한 팔은 되돌아오지 않습니다. 상대가 물러나면 거리가
	# 도로 멀어지는데, 그때마다 팔이 오갔다면 뻗다 마는 것으로 보입니다.
	# 대신 최소 속도를 둬서, 상대를 쫓아가는 동안에도 뻗기는 끝납니다.
	if _lunge_swing > 0.0:
		near = maxf(near, _lunge_swing + delta / LUNGE_SWING_TIME)
	_lunge_swing = clampf(maxf(_lunge_swing, near), 0.0, 1.0)

	# 상대 쪽으로 밀어 줍니다. 조준도 같이 붙들어 두어야 달려가다 몸이
	# 돌아가지 않습니다.
	var dir := to.normalized()
	aim = dir
	velocity.x = dir.x * state.move_speed * LUNGE_SPEED
	velocity.z = dir.z * state.move_speed * LUNGE_SPEED


func _land_lunge(enemy: Node3D) -> void:
	## **손이 닿았습니다.** 여기서 밀기와 잡기가 갈립니다.
	##
	## 등 뒤면 잡고, 앞이면 밉니다. 규칙은 예전과 같지만 판정하는 자리가
	## 다릅니다 - 누르는 순간이 아니라 **닿는 순간**이라, 달려가는 사이에
	## 적이 돌면 결과도 바뀝니다. 눈에 보이는 것과 일어나는 일이 같아집니다.
	Trace.mark("밀기")
	_lunge_at = null
	_lunge_time = 0.0
	_push_hit = true
	velocity.x *= 0.2
	velocity.z *= 0.2
	var foe := enemy as Enemy
	if foe != null and foe.is_liftable() and _behind(foe):
		_hold_min = HOLD_MIN
		Sfx.play(Sfx.GRAB, -3.0, 0.08)
		_take(foe)
		return
	_shove_one(enemy)


func _shove_one(enemy: Node3D) -> void:
	## 밀기 성공. 피해와 함께 **살짝 밀려납니다.**
	##
	## 하얀 상자가 튀어 나오는 이펙트는 여기서만 냅니다. 예전에는 버튼을
	## 누르기만 하면 나와서, 헛손질과 성공이 화면에서 같아 보였습니다.
	var dir: Vector3 = enemy.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else aim
	var roll := state.roll_damage(rng)
	var shove_mult := SHOVE_MULT * (1.0 + state.shove_damage)
	# 방향은 **길이 1 로** 넘깁니다.
	#
	# 예전에는 2.4 를 곱해 넘겼는데, 받는 쪽이 거기에 다시 5 를 곱해서
	# 12m/s 가 됐습니다. 아래의 knock_back(6.5)까지 더하면 18.5m/s - 감속
	# 30 으로도 5.7m 를 날아갔습니다. 아이가 아이를 미는 힘이 아닙니다.
	# 미는 힘은 **한 군데서만** 넣습니다(아래 knock_back).
	#
	# take_damage 도 방향을 받으면 속도를 더하는데, knock_back 이 가던 속도를
	# 끊고 시작하므로 여기서 넣은 몫은 그대로 지워집니다 - 두 곳에서 넣으면
	# 합이 얼마인지 아무도 모르게 됩니다.
	if _guarded(enemy):
		# 막혔습니다. 미는 힘이 도로 나에게 옵니다 - 아무 일도 안 일어나면
		# 밀기가 안 닿은 것인지 막힌 것인지 손으로 구분되지 않습니다.
		enemy.call("take_damage", 0.0, false, Vector3.ZERO, 0.0, global_position)
		velocity -= dir * 3.0
		return
	# **미는 것이 먼저, 피해가 나중입니다.**
	#
	# 순서가 반대면 마지막 한 대로 죽인 적이 **제자리에서 사라집니다** -
	# 죽는 순간 밀림이 아직 안 걸려 있어서, 적은 쪽(enemy.gd 의 `_die`)이
	# "밀리는 중이면 멈춘 뒤에" 를 판단할 근거가 없습니다. 밀어 두고 때리면
	# 죽어도 끝까지 밀려간 뒤에 쓰러집니다.
	if enemy.has_method("knock_back"):
		# **「밀기」 Lv3 이면 연쇄가 두 번 남습니다** - 밀린 적1 에 부딪힌
		# 적2 가 밀리고, 그 적2 에 부딪힌 적3 까지입니다. 셋에서 끊는 이유는
		# 끝이 없으면 밀기 한 번이 방 하나를 정리해서, 다른 기술을 쓸 이유가
		# 사라지기 때문입니다.
		enemy.knock_back(dir * (SHOVE_KNOCK + state.shove_knock),
			2 if state.has_push_chain() else 0)
	if enemy.has_method("stagger_for"):
		enemy.stagger_for(0.45)
	enemy.call("take_damage", float(roll[0]) * shove_mult, bool(roll[1]),
		Vector3.ZERO, 0.0, global_position)
	note_hit()
	Fx.burst(get_parent(), enemy.global_position + Vector3(0, 0.7, 0),
		Color(1.0, 0.8, 0.5), 12, 3.6)
	# 밀기 계통 Lv3 부터 **미는 힘이 보입니다.**
	#
	# 예전에는 맞은 자리에 고리 하나였습니다. 고리는 "퍼졌다" 는 되지만
	# "이쪽으로 세게 밀었다" 가 안 됩니다 - 방향이 없는 그림이라, 미는 기술을
	# 파고 있다는 것이 화면에 안 남았습니다.
	#
	# 실루엣 뒤로 파란 직선을 깔고(만화가 속도를 그리는 방법), 팔에만 잔상을
	# 남깁니다. 색은 구르기 잔상과 같은 파랑입니다 - 같은 힘에서 나온 것으로
	# 읽히게.
	# **이펙트는 계통 Lv3 에서만** 붙습니다(옛 5레벨 이펙트).
	#
	# 세기는 레벨이 아니라 **실제로 오른 값**에서 뽑습니다 - 레벨로 세면
	# 이펙트가 수치와 따로 놀아 거짓말을 합니다.
	# **밀기 Lv3 의 표시는 잔상 하나뿐입니다.**
	#
	# 두 가지를 걷어냈습니다.
	#
	#   밀린 적의 보라 잔상   밀려나는 몸이 이미 크게 움직이는 그림이라,
	#                        자국까지 겹치면 무엇이 몸이고 무엇이 자국인지
	#                        흐려집니다. 색도 다른 데 안 쓰던 것이라 튀었습니다.
	#   아이 뒤의 아지랑이     같은 순간에 셋(잔상·아지랑이·밀린 몸)이 겹쳐
	#                        화면이 어수선했습니다.
	#
	# 남은 것은 **달려드는 동안의 파란 잔상**(`_lunge_afterimage`)입니다.
	# 그건 기술이 나가기 **전**에 보이므로 밀리는 그림과 안 겹칩니다.
	Sfx.play(Sfx.PUSH, -1.0, 0.06)
	Game.shake(0.28, 0.18)
	_shove_hold = SHOVE_HOLD


func _resolve_grab() -> void:
	## 달려들 상대가 없었을 때의 밀기 판정.
	##
	## **한 명만** 칩니다. 예전에는 사거리 안의 모두를 쳤는데, 적이 둘 있으면
	## 한 번 눌렀는데 둘이 같이 날아가서 기술이 두 번 나간 것처럼 보였습니다.
	## 달려드는 쪽이 한 명을 고르는 기술이 됐으므로, 이쪽도 한 명입니다.
	if _held != null:
		return
	var foe := _lunge_target()
	if foe != null:
		_shove_one(foe)


func _drive_grab_hint(delta: float) -> void:
	## **지금 누르면 저것이 잡힌다**를 미리 보여 줍니다.
	##
	## 판정을 좁히면 헛손질이 늘어납니다 - 좁히면서 헛손질을 안 늘리려면
	## 범위가 눈에 보여야 합니다. 그래서 고리는 잡기 판정과 **같은 함수**로
	## 고른 대상 아래에 깔립니다. 다른 식으로 계산하면 고리가 떠 있는데
	## 안 잡히는 순간이 생기고, 그러면 고리가 거짓말이 됩니다.
	##
	## 눌러도 아무 일이 없는 상황(손이 차 있음, 대기 중, 숨 부족)에서는
	## 띄우지 않습니다. 신호는 "된다" 일 때만 켜져야 신호입니다.
	_hint_t += delta
	var target: Prop = null
	if _held == null and _drink_time <= 0.0 and _grab_cd <= 0.0 			and not _dead and _throw_time <= 0.0 and _has_breath(BREATH_GRAB):
		var near := _nearest_prop()
		if near != null and _grab_distance(near) <= GRAB_RANGE:
			target = near
	if target == null:
		if _grab_hint != null:
			_grab_hint.visible = false
		return

	_ensure_grab_hint()
	_grab_hint.visible = true
	# 물건 몸집에 맞춥니다. 큰 상자에 작은 고리가 뜨면 무엇을 가리키는지
	# 알 수 없습니다.
	var r: float = maxf(target.throw_size() * 0.75, 0.34)
	var beat := sin(_hint_t * 5.0)
	_grab_hint.global_position = Vector3(
		target.global_position.x, 0.05, target.global_position.z)
	# 세로로 눌러 **바닥에 그린 띠**로 보이게 합니다. 안 누르면 도넛이
	# 하나 놓여 있는 것으로 보입니다.
	var w := r * (1.0 + beat * 0.05)
	_grab_hint.scale = Vector3(w, 0.22, w)
	_grab_hint_mat.albedo_color.a = 0.5 + beat * 0.16


func _ensure_grab_hint() -> void:
	if _grab_hint != null:
		return
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 20
	_grab_hint_mat = StandardMaterial3D.new()
	_grab_hint_mat.albedo_color = Color(1.0, 0.86, 0.45, 0.55)
	_grab_hint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grab_hint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grab_hint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_grab_hint_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grab_hint = MeshInstance3D.new()
	_grab_hint.mesh = mesh
	_grab_hint.material_override = _grab_hint_mat
	_grab_hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 카툰 옵션이 고리에 검은 테두리를 두르지 않게 합니다.
	_grab_hint.set_meta("flat", true)
	get_parent().add_child(_grab_hint)


func _nearest_prop() -> Prop:
	var best: Prop = null
	var closest := GRAB_RANGE
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if not is_instance_valid(prop) or prop.held_by != null:
			continue
		# 붙박이는 후보에 넣지 않습니다. 넣어 두면 풀장 옆에서 누를 때마다
		# 그것이 가장 가까운 소품으로 뽑혀, 적에게 달려들어야 할 잡기가
		# 아무 일도 안 하는 것이 됩니다.
		if prop.is_fixed():
			continue
		var to := prop.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > closest:
			continue
		if d > 0.2 and to.normalized().dot(aim) < cos(GRAB_ARC * 0.5):
			continue
		closest = d
		best = prop
	return best


func _begin_shout() -> bool:
	## 누르는 순간 **그대로 지릅니다.** 늘 최대 범위입니다.
	##
	## 한동안 **누르는 만큼 커지는** 기술이었습니다(0.5초 모으기). 값을 여럿
	## 매달아 놨었는데 - 모은 만큼 범위, 모은 만큼 숨, Lv3 은 끝까지 모아야
	## 피해 - 손에는 결국 "매번 0.5초를 서 있어야 한다" 로만 남았습니다.
	## 그동안 발이 0.2배로 묶이므로 급할 때 못 쓰는 기술이 되고, 그러면 판을
	## 정리하는 기술이라는 자리와도 어긋납니다.
	##
	## 지금은 **누르면 나갑니다.** 값은 숨 10 하나입니다.
	if _parry_air > 0.0:
		return false
	if _mash():
		return false
	if ultimate_press("shout"):
		return false
	if _joy_time > 0.0 or _attack_cd > 0.0 or _dash_time > 0.0 			or _carrying_enemy() or _throw_time > 0.0 or _drink_time > 0.0 or _read_time > 0.0:
		return false
	# **숨은 여기서 확인만** 하고 뺏지 않습니다. 모으다 그만두는 일이 값을
	# 치르는 일이 되면, 잘못 눌렀을 때 손해가 두 번입니다.
	# 살짝 지르는 것도 못 할 만큼 숨이 없을 때만 막습니다. 실제로 빼는 것은
	# 지를 때이고, 그때 **모은 만큼** 냅니다.
	# 확인은 **가장 비싼 쪽**(덜 지른 값)으로 합니다. 싼 쪽으로 물으면 모으다
	# 그만뒀을 때 낼 수 없는 값이 나옵니다.
	if not _has_breath(breath_cost("shout", BREATH_SHOUT)):
		_out_of_breath()
		return false
	# **늘 최대**입니다. 그림과 판정이 같은 값을 쓰므로 여기 한 줄이 둘 다
	# 정합니다(`shout_reach` / `shout_arc`).
	_shout_fired = 1.0
	_shout_voice = Sfx.play_loose(Sfx.SHOUT, 0.0)
	# 범위를 **그 자리에 그렸다가** 스러지게 합니다.
	Trace.mark("고함")
	_shout_show = SHOUT_SHOW
	_shout_preview()
	_try_attack()
	return true


## 지른 범위가 화면에 남아 있는 시간(초). 그 뒤 0.30초에 걸쳐 스러집니다.
##
## 짧게 둡니다 - 길면 이미 끝난 판정이 계속 떠 있어서, 그 안에 서 있으면
## 아직 아픈 것으로 읽힙니다.
const SHOUT_SHOW := 0.12
var _shout_show := 0.0


func _drive_shout_charge(delta: float) -> void:
	## 지른 뒤 범위가 잠깐 남습니다. 선분이 지글거리도록 매 프레임 다시
	## 그립니다(보일링) - 한 장으로 세워 두면 붙여 놓은 그림이 됩니다.
	if _shout_show <= 0.0:
		return
	_shout_show -= delta
	if _shout_show <= 0.0:
		_clear_shout_preview()
	else:
		_shout_preview()
	return
## (안 씀) 모으던 시절, 부채꼴 안의 적을 매 프레임 굳히던 값. 지금은 지르는
## 순간 `_resolve_swing` 이 `Enemy.SHOUT_STAGGER` 로 한 번 겁니다.
##
## 매 프레임 새로 걸므로 **머무는 동안 계속 굳어 있습니다.** 값이 짧아야
## 부채꼴 밖으로 나간 순간 곧바로 풀립니다 - 길게 걸면 스쳐 지나간 적이
## 한참 뒤까지 굳어 있어서, 굳힌 것이 내가 한 일로 안 읽힙니다.
const SHOUT_CHARGE_STAGGER := 0.12
func _shout_preview() -> void:
	## 모으는 동안 **자라는 부채꼴**을 발밑에 그립니다.
	##
	## 지를 때 칠하는 것과 같은 함수로 만듭니다(`Fx.fan_mesh`) - 미리 보는
	## 것과 실제로 닿는 것이 다르면 그림이 거짓말입니다.
	# **늘 최대**입니다. 모으기가 없어졌으므로 그림도 한 크기뿐입니다.
	var charge := 1.0
	if _shout_prev == null:
		_shout_prev_mat = Fx.fan_material()
		_shout_prev = MeshInstance3D.new()
		_shout_prev.material_override = _shout_prev_mat
		_shout_prev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shout_prev.set_meta("flat", true)
		get_parent().add_child(_shout_prev)
	# 자라는 것을 보여 주는 것이 일이라 메시를 매번 새로 만듭니다. 부채꼴은
	# 삼각형 스무 장이라 값이 없습니다(0.0x ms).
	_shout_prev.mesh = Fx.fan_mesh(shout_reach(charge) + 0.4, shout_arc(charge))
	_shout_prev.global_position = global_position + Vector3(0, 0.05, 0)
	_shout_prev.rotation.y = atan2(-aim.x, -aim.z)

	# **고함 효과선.** 입에서 앞으로 뻗는 **흰 선분 다발**입니다.
	#
	# 선분은 규칙적이지 않습니다 - 길이·굵기·간격이 제각각이고 중간에서
	# 시작하는 것도 섞입니다. 자를 대고 그은 것처럼 균일하면 효과가 죽습니다.
	# 패턴 셋을 미리 만들어 두고 **통째로 갈아 끼워** 지글거리게 합니다(보일링).
	#
	# 소용돌이(원뿔 + 나선 셰이더)를 걷어낸 자리입니다. 모양은 그럴듯했지만
	# **덩어리**라 그 뒤의 적이 가려졌습니다 - 굴러 피할 자리를 보려고 켜 둔
	# 그림이 그 자리를 덮는 셈이었습니다.
	#
	# **판정과 같은 값**을 넘깁니다(`shout_reach`, `shout_arc`). 부채꼴이
	# 자라면 선분도 정확히 그만큼 길고 넓어집니다.
	if _shout_vortex == null or not is_instance_valid(_shout_vortex):
		_shout_vortex = Fx.make_shout_rays(get_parent())
		_shout_flow = 0.0
	_shout_flow += get_physics_process_delta_time()
	Fx.drive_shout_rays(_shout_vortex,
		global_position + Vector3(0, MOUTH_HEIGHT, 0),
		aim, shout_reach(charge) + 0.4, MOUTH_HEIGHT, shout_arc(charge),
		# 모을수록 조금 진해집니다. **시작부터 진합니다** - 아래 참고.
		0.85 + 0.15 * charge, _shout_flow)
	# **누르는 순간부터 보여야 합니다.**
	#
	# 시작 진하기가 0.16 이었습니다. 부채꼴도 소용돌이도 누르는 첫 프레임부터
	# 있었는데(실측: 모은 0.20 에 부채꼴·소용돌이 둘 다 true), 그때는 사거리도
	# 최소(×0.14)라 **작고 옅은 것이 겹쳐** 폰에서는 아무것도 없는 것으로
	# 보였습니다 - 손에는 "지를 때만 뭔가 나온다" 로 느껴집니다.
	#
	# 크기는 안 건드립니다. 작게 시작하는 것은 정한 규칙이고, 크기를 올리면
	# 살짝 지르는 것과 끝까지 모으는 것의 차이가 없어집니다. **진하기만**
	# 올립니다 - 모으는 정도는 크기가 이미 말하고 있습니다.
	_shout_prev_mat.albedo_color = Color(1.0, 0.84, 0.45, 0.34).lerp(
		Color(1.0, 0.72, 0.32, 0.46), charge)


func _clear_shout_preview() -> void:
	## **범위 표시와 효과선을 같은 시간에 지웁니다.**
	##
	## 둘 다 그 자리에 두고 0.30초에 걸쳐 스러집니다. 지르는 순간 한꺼번에
	## 지우면 소리는 이어지는데 그림만 뚝 끊깁니다.
	##
	## 예전에는 **범위 표시만 곧바로 지우고** 효과선만 스러지게 했습니다.
	## 그래서 부채꼴이 먼저 사라지고 흰 선만 0.30초 더 떠 있었습니다 - 어디까지
	## 닿았는지는 이미 없는데 소리는 아직 나가는 중인 그림이 됩니다.
	if _shout_prev != null and is_instance_valid(_shout_prev):
		var fan := _shout_prev
		var fan_mat := _shout_prev_mat
		if fan_mat != null:
			var a0: float = fan_mat.albedo_color.a
			var tw0 := fan.create_tween()
			tw0.tween_method(func(f: float) -> void:
				fan_mat.albedo_color.a = a0 * f,
				1.0, 0.0, VORTEX_FADE)
			tw0.tween_callback(fan.queue_free)
		else:
			fan.queue_free()
	_shout_prev = null
	_shout_prev_mat = null
	if _shout_vortex != null and is_instance_valid(_shout_vortex):
		var gone := _shout_vortex
		var tw := gone.create_tween()
		tw.tween_method(func(f: float) -> void:
			for mi in Fx.all_shout_lines(gone):
				var m := mi.material_override as StandardMaterial3D
				if m != null:
					m.albedo_color.a = f,
			1.0, 0.0, VORTEX_FADE)
		tw.tween_callback(gone.queue_free)
	_shout_vortex = null
func _try_attack() -> void:
	if _mash():
		return
	if ultimate_press("shout"):
		return
	# 끌고 있으면 고함도 못 지릅니다. 두 손이 이미 차 있습니다 - 자세가
	# 서로 덮어써서 팔이 두 곳을 동시에 가리키게 됩니다.
	if _joy_time > 0.0 or _attack_cd > 0.0 or _dash_time > 0.0 or _carrying_enemy() or _throw_time > 0.0 or _drink_time > 0.0 or _read_time > 0.0:
		return
	# **모은 만큼 냅니다.** 살짝 지른 것은 30%, 끝까지 모은 것은 100% 입니다.
	# **모을수록 쌉니다**(BREATH_SHOUT 40 -> BREATH_SHOUT_FULL 30).
	var shout_cost := breath_cost("shout", BREATH_SHOUT)
	if not _has_breath(shout_cost):
		_out_of_breath()
		return
	_spend_breath(shout_cost)
	_note_repeat("shout")
	_attack_cd = SHOUT_COOLDOWN
	_attack_cd_max = _attack_cd
	_swing_time = SWING_TIME
	_shout_hold = SHOUT_POSE_TIME
	_swing_hit = false
	_show_swing()
	# 고함 계통 Lv3 부터 **파란 구슬**이 함께 퍼집니다(Lv5 는 더 크게).
	# 파문(고리)은 사거리를 가르치는 그림이라 그대로 두고, 그 위에 얹습니다.
	# 구슬 개수는 **굳히는 힘**(「쩌렁쩌렁」 0.5초마다 셋)에서 뽑습니다.
	# 사거리는 이미 `shout_range()` 가 그림 크기를 정하므로 여기서 안 셉니다 -
	# 「멀리 가는 소리」를 찍으면 구슬이 그만큼 멀리 퍼집니다.
	# **소용돌이.** 고함이 만드는 기운입니다 - 계통 Lv 과 상관없이 늘 뜹니다.
	#
	# 파란 구슬을 걷어낸 자리입니다. 구슬은 "퍼졌다" 는 됐지만 **소리가 밀어
	# 낸다**는 그림이 아니었습니다. 나선으로 감겨 빨려 드는 모양이 지르는
	# 행위와 더 가깝고, 무엇보다 모은 만큼 커지는 것과 잘 붙습니다.
	#
	var slv := skill_lv("shout")
	if slv >= 3 and _shout_fired >= SHOUT_FULL:
		# **Lv5 는 호랑이입니다.** 구슬은 "퍼졌다" 까지이고, 계통을 끝까지 판
		# 자리에는 그만한 그림이 있어야 합니다.
		Fx.tiger(get_parent(), global_position + Vector3(0, 0.35, 0), aim,
			shout_reach(_shout_fired))
	elif slv >= 2:
		# Lv2 는 맞은 자리에서 구슬이 한 번 더 터집니다. 소용돌이는 이미
		# 모으는 동안 내내 떠 있으므로, 여기서는 **맞았다**만 보태면 됩니다.
		Fx.orbs(get_parent(), global_position + Vector3(0, 0.7, 0), aim,
			shout_reach(_shout_fired), 5 + slv * 3, slv >= 3)


## 자동차를 탄 동안 **허리 아래를 지웁니다.**
##
## 앉는 자세가 없어서 다리가 자동차 지붕을 뚫고 나왔습니다. 자세로는 못
## 풉니다 - 어떻게 접어도 발끝이 어딘가로 삐져나오고, 무릎을 굽히면 이번에는
## 무릎이 나옵니다. **높이로 지우면** 자세와 상관이 없습니다.
const RIDE_FADE_TOP := 0.62
const RIDE_FADE_SPAN := 0.30

## 지우기 전의 재질. 내릴 때 그대로 되돌립니다.
var _ride_mats: Array = []


func _fade_lower_body(on: bool) -> void:
	## 몸의 재질을 **면마다** 갈아 끼웁니다.
	##
	## `material_override` 가 아니라 면별(`surface_override`)인 이유: 덮어쓰기는
	## 메시의 모든 면에 같은 재질을 씌워서, 면마다 다른 그림을 쓰는 모델이면
	## 통째로 한 색이 됩니다.
	if not on:
		for e in _ride_mats:
			var mi := e[0] as MeshInstance3D
			if is_instance_valid(mi):
				mi.set_surface_override_material(int(e[1]), e[2])
		_ride_mats.clear()
		return
	if not _ride_mats.is_empty() or body == null:
		return
	var shader := load("res://assets/shaders/body_fade.gdshader") as Shader
	if shader == null:
		return
	for node in _all_nodes(body):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			var m := ShaderMaterial.new()
			m.shader = shader
			if src != null:
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				m.set_shader_parameter("albedo", src.albedo_color)
			m.set_shader_parameter("fade_span", RIDE_FADE_SPAN)
			_ride_mats.append([mi, i, mi.get_surface_override_material(i)])
			mi.set_surface_override_material(i, m)


func _drive_ride_fade() -> void:
	## 지우는 높이는 **세계 좌표**라 매 프레임 몸을 따라 옮깁니다.
	for e in _ride_mats:
		var mi := e[0] as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		var m := mi.get_surface_override_material(int(e[1])) as ShaderMaterial
		if m != null:
			m.set_shader_parameter("waist_y", global_position.y + RIDE_FADE_TOP)


func begin_joyride(car: Prop) -> bool:
	## 자동차에 올라탑니다. 이미 타고 있거나 다른 일을 하는 중이면 안 탑니다.
	if _joy_time > 0.0 or _bound_time > 0.0 or _read_time > 0.0:
		return false
	if car == null or not is_instance_valid(car) or car.spent:
		return false
	if _held != null:
		# 두 손이 차 있으면 못 탑니다. 들고 있던 것은 놓습니다.
		if _held is Prop:
			(_held as Prop).drop()
		_held = null
	Trace.mark("자동차")
	_joy_car = car
	_joy_time = JOY_TIME
	_joy_hit.clear()
	# **허리 아래를 지웁니다.** 앉는 자세가 없어서 다리가 지붕을 뚫습니다.
	_fade_lower_body(true)
	# 처음 방향은 **보고 있는 쪽**입니다. 아무 데로나 튀어 나가면 탄 것이
	# 아니라 사고를 당한 것으로 보입니다.
	_joy_dir = aim if aim.length_squared() > 0.01 else Vector3.FORWARD
	_joy_turn = JOY_TURN_EVERY
	# **타는 동안 차를 물리에서 통째로 뺍니다.**
	#
	# `freeze` 만으로는 부족했습니다 - 얼린 차는 움직이지 않는 벽이 되는데,
	# 그 벽을 매 프레임 발밑으로 옮기니 물리가 몸을 밖으로 밀어냈습니다.
	# 빠져나갈 곳이 위뿐이라 **하늘로 날아갔습니다.** 층을 0 으로 두면
	# 아무와도 안 부딪히므로 밀려날 일이 없습니다.
	car.freeze = true
	car.set_solid(false)
	car.held_by = self
	Sfx.play(Sfx.THROW, -2.0, 0.05)
	return true


func _drive_joyride(delta: float) -> void:
	## 무적으로 방을 휘젓습니다. **조종은 안 됩니다** - 방향은 스스로 바뀌고,
	## 벽에 닿으면 튕겨 나옵니다.
	_joy_time -= delta
	_invuln = maxf(_invuln, 0.12)
	_joy_turn -= delta
	var wish := _move_input()
	var steering := wish.length_squared() > 0.04
	if _joy_turn <= 0.0:
		_joy_turn = JOY_TURN_EVERY
		if steering:
			# **밀고 있으면 그쪽을 중심으로** 흔들립니다. 가던 쪽에서 아무렇게나
			# 꺾으면 조작이 아무리 세도 0.62초마다 무위로 돌아갑니다 - 실제로
			# 재 보니 밀고 있는 쪽의 반대로 가고 있었습니다.
			var base := Vector3(wish.x, 0.0, wish.y).normalized()
			_joy_dir = base.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
		else:
			# 손을 놓고 있으면 제멋대로. 완전히 무작위로 뽑으면 제자리에서
			# 갈팡질팡하고, 조금만 꺾으면 직선으로만 갑니다.
			_joy_dir = _joy_dir.rotated(Vector3.UP, rng.randf_range(-2.0, 2.0)).normalized()
	# **조작이 조금은 먹습니다.**
	#
	# 처음에는 아예 안 먹게 뒀습니다 - 조종되면 그냥 "빨라지고 무적인 상태" 라
	# 다른 기술이 다 쓸모없어지니까요. 그런데 아무것도 안 먹으면 타는 순간부터
	# 3.4초 동안 **화면을 구경하는 시간**이 됩니다.
	#
	# 가려는 쪽으로 조금씩 끌어당깁니다. 스스로 꺾는 힘이 훨씬 세서 원하는
	# 곳에 딱 가지는 못하지만, 밀어붙이면 대충 그쪽으로 향합니다 - 모는 것이
	# 아니라 **떼를 쓰는** 정도입니다.
	if steering:
		var want := Vector3(wish.x, 0.0, wish.y).normalized()
		_joy_dir = _joy_dir.lerp(want, minf(1.0, JOY_STEER * delta)).normalized()
	# 벽에 닿았으면 튕깁니다. 벽을 밀고 있으면 제자리에서 부르릉거립니다.
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		if n.length_squared() > 0.0001:
			_joy_dir = _joy_dir.bounce(n.normalized()).normalized()
	velocity.x = _joy_dir.x * JOY_SPEED
	velocity.z = _joy_dir.z * JOY_SPEED
	# **위로는 안 갑니다.** 무엇에 걸려 튀어 오르더라도 그 자리에서 눌러
	# 둡니다 - 자동차는 바닥을 달리는 물건입니다.
	velocity.y = minf(velocity.y, 0.0)
	aim = _joy_dir
	_joyride_hits()
	# 차가 발밑을 따라옵니다.
	if is_instance_valid(_joy_car):
		_joy_car.global_position = global_position + Vector3(0, 0.12, 0)
		_joy_car.rotation.y = atan2(-_joy_dir.x, -_joy_dir.z)
	_drive_ride_fade()
	if _joy_time <= 0.0:
		_end_joyride()


func _joyride_hits() -> void:
	## 지나가며 치는 적. 한 번의 질주에서 같은 적은 **한 번만** 칩니다.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if not is_instance_valid(enemy) or _joy_hit.has(enemy.get_instance_id()):
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() > JOY_REACH + float(enemy.get_meta("body_radius", 0.4)):
			continue
		_joy_hit[enemy.get_instance_id()] = true
		var roll := state.roll_damage(rng)
		enemy.call("take_damage", float(roll[0]) * JOY_DAMAGE, bool(roll[1]),
			Vector3.ZERO, 0.5, global_position)
		if enemy.has_method("knock_back"):
			var away: Vector3 = to.normalized() if to.length() > 0.05 else _joy_dir
			enemy.knock_back(away * JOY_KNOCK)
		note_hit()
		Game.shake(0.18, 0.12)
		Fx.burst(get_parent(), enemy.global_position + Vector3(0, 0.6, 0),
			Color(1.0, 0.9, 0.6), 10, 3.6)


func _end_joyride() -> void:
	_joy_time = 0.0
	_fade_lower_body(false)
	if is_instance_valid(_joy_car):
		# 내린 자리에 세워 둡니다. 다시 탈 수 있어야 이 물건이 방의 자원으로
		# 남습니다 - 한 번 쓰고 사라지면 그냥 이벤트입니다.
		_joy_car.held_by = null
		_joy_car.freeze = false
		_joy_car.set_solid(true)
		# **한 번 타면 끝입니다.** 다시 탈 수 있으면 방 하나가 무한한 무적
		# 시간이 됩니다 - 내렸다 다시 타면 되니까요.
		_joy_car.mark_spent()
		_joy_car.global_position = global_position + aim * -1.1 + Vector3(0, 0.3, 0)
	_joy_car = null
	velocity.x *= 0.3
	velocity.z *= 0.3


func _try_dash() -> void:
	if _parry_air > 0.0:
		return
	if _mash():
		return
	# **필살기가 먼저 봅니다.** 명령을 받는 중이거나 모드 안이면 이 누름은
	# 그쪽이 가져갑니다(ultimate_press 참고).
	if ultimate_press("roll"):
		return
	# 끌고 있으면 못 구릅니다. 사람을 잡은 채로 앞구르기를 하면 잡은 손이
	# 어디로 가야 할지 정할 수가 없습니다.
	if _joy_time > 0.0 or _dash_cd > 0.0 or _carrying_enemy() or _throw_time > 0.0 or _read_time > 0.0:
		return
	# **베개싸움: 휘두르는 도중에는 못 구릅니다.** 되돌릴 수 없다는 것이 그
	# 판의 규칙인데, 구르기로 후딜을 지울 수 있으면 규칙이 없어집니다.
	# 고리가 안 걸려 있으면(탐험) 이 줄은 없는 것과 같습니다.
	if attack_hook != null and bool(attack_hook.call("busy")):
		return
	var roll_cost := breath_cost("roll", BREATH_ROLL) * state.roll_cost_mult()
	if not _has_breath(roll_cost):
		_out_of_breath()
		return
	_spend_breath(roll_cost)
	_note_repeat("roll")
	var input := _move_input()
	var dir := Vector3(input.x, 0.0, input.y)
	# 입력이 없으면 보고 있는 쪽으로 구릅니다. 제자리 구르기는 쓸모가 없습니다.
	_dash_dir = dir.normalized() if dir.length_squared() > 0.01 else aim
	_dash_time = DASH_TIME
	Trace.mark("구르기")
	_roll_time = ROLL_TIME
	_pierced.clear()
	# **대기는 거의 없습니다.** 연달아 구르는 것을 막는 것은 숨이지 시계가
	# 아닙니다 - 시계로 막으면 굴러 피해야 하는 순간에 "아직 안 됨" 이 되고,
	# 그건 실력이 아니라 운입니다.
	_dash_cd = state.dash_cooldown
	_dash_cd_max = maxf(_dash_cd, 0.001)
	# 구르는 **동작 내내** 무적입니다. 예전에는 이동이 끝나는 순간(0.28초)
	# 까지만이라, 아직 굴러가는 그림인데 맞았습니다 - 눈에 보이는 것과 판정이
	# 어긋나면 억울하게 느껴집니다.
	_invuln = maxf(_invuln, ROLL_TIME)
	# **「구르기」 Lv2 는 적을 통과합니다.**
	#
	# 무적만으로는 부족합니다 - 안 아픈데 몸이 걸려서, 적 무리 한가운데로
	# 굴러 들어가면 그 안에 끼입니다. 피하는 기술이 갇히는 기술이 됩니다.
	# 적 층(1<<2)만 뺍니다. 벽은 그대로 막아야 방 밖으로 나갑니다.
	if state.has_roll_ghost():
		collision_mask &= ~(1 << 2)
	_swing_time = 0.0
	if _jiggle != null:
		_jiggle.kick(_dash_dir * 26.0)
	# 작고 흐릿하게. 알파를 낮춘 이유는 이 고리가 **가산 합성**이라 알파를
	# 안 내리면 밝은 파란 원반처럼 화면을 덮기 때문입니다. 구르는 몸을
	# 가리면 안 됩니다 - 지금은 발밑에 잠깐 번지는 정도입니다.
	Fx.ring(get_parent(), global_position, Color(0.5, 0.75, 1.0, 0.28), 0.85, 0.26)


## 구르며 뚫을 때의 피해 배율과 닿는 거리.
##
## 고함보다 약하게 둡니다(0.6배). 구르기는 이미 무적이라, 피해까지 세면
## "굴러다니기만 하면 되는" 판이 됩니다.
const PIERCE_MULT := 0.6
const PIERCE_REACH := 1.0


func _roll_pierce_hits() -> void:
	## 한 번 구르는 동안 같은 적은 **한 번만** 칩니다. 안 그러면 붙어 있는
	## 적에게 매 프레임 들어가 즉사시킵니다.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if not is_instance_valid(enemy) or _pierced.has(enemy.get_instance_id()):
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() > PIERCE_REACH + float(enemy.get_meta("body_radius", 0.4)):
			continue
		_pierced[enemy.get_instance_id()] = true
		var roll := state.roll_damage(rng)
		var dir := _dash_dir if _dash_dir.length_squared() > 0.01 else aim
		enemy.call("take_damage",
			float(roll[0]) * PIERCE_MULT * state.roll_pierce, bool(roll[1]), dir,
			0.0, global_position)
		note_hit()
		Fx.burst(get_parent(), enemy.global_position + Vector3(0, 0.6, 0),
			Color(0.8, 0.95, 1.0), 8, 3.0)


func _guarded(enemy: Node3D) -> bool:
	## 앞을 막는 적(베개)이 **지금 내 자리에서 오는 것**을 막는지.
	##
	## 피해는 받는 쪽(`Enemy.take_damage`)이 알아서 걸러내지만, 경직·넉백·
	## 흡혈은 때리는 쪽에서 따로 넣습니다. 그쪽을 안 물어보면 "피해는 0 인데
	## 경직은 걸리는" 상태가 되어, 막힌 채로 계속 밀기만 해도 적이 굳습니다 -
	## 그러면 뒤로 돌아갈 이유가 없어집니다.
	return enemy.has_method("guard_blocks") and enemy.call("guard_blocks", global_position)


func _resolve_swing() -> void:
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if not is_instance_valid(enemy):
			continue
		var to := enemy.global_position - global_position
		to.y = 0.0
		# **모은 만큼**입니다. 그림(`Fx.shout_fan`)과 같은 함수를 쓰므로,
		# 눈에 보인 부채꼴이 곧 닿는 범위입니다.
		var reach: float = shout_reach(_shout_fired) 			+ float(enemy.get_meta("body_radius", 0.4))
		if to.length() > reach:
			continue
		if to.normalized().dot(aim) < cos(deg_to_rad(shout_arc(_shout_fired)) * 0.5):
			continue
		# **고함은 「고함」 Lv3 전까지 아프지 않습니다.**
		#
		# 범위가 넓고 굳히기까지 하는데 피해까지 있으면 다른 기술을 쓸 이유가
		# 없어집니다 - 실제로 그렇게 굴러가고 있었습니다. 지금 이 기술이 파는
		# 것은 **판을 정리하는 것**이고, 정리한 뒤 때리는 일은 밀기가 합니다.
		# **고함은 처음부터 아픕니다. 밀기의 절반입니다.**
		#
		# 한동안 Lv3 전까지 피해가 0 이었습니다. 「범위와 경직만으로 판을
		# 정리하는 기술」이라는 뜻이었는데, 손에는 **안 아픈 버튼**으로만
		# 남았습니다 - 눌러도 적이 그대로 서 있으면 무엇을 한 것인지 알 수
		# 없습니다.
		#
		# 절반인 이유: 고함은 앞을 통째로 쓸고(132°) 값도 쌉니다(숨 10).
		# 밀기와 같이 아프면 밀기를 쓸 이유가 없어집니다.
		var roll: Array = state.roll_damage(rng)
		roll[0] = float(roll[0]) * SHOUT_MULT
		if state.family_level("shout") >= 3:
			# 계통을 끝까지 판 고함은 맞은 자리에서 한 번 더 터집니다.
			Fx.orbs(get_parent(), enemy.global_position + Vector3(0, 0.5, 0),
				aim, 1.2, 5, true)
		var blocked := _guarded(enemy)
		enemy.call("take_damage", float(roll[0]), bool(roll[1]), aim,
			Enemy.SHOUT_STAGGER, global_position)
		if blocked:
			continue
		# **밀지도, 끊지도 않습니다.**
		#
		# 밀어내던 것을 끊는 것으로 바꿨다가, 그것도 뺐습니다. 고함의 값은
		# 이제 **누르는 순간**에 있습니다 - 맞는 타이밍에 맞춰 누르면 패링이
		# 되고(`_try_parry`), 그 뒤가 이 기술의 본론입니다. 지르는 것만으로
		# 적의 동작이 지워지면, 타이밍을 맞출 이유가 사라집니다.
		hit_any = true
		note_hit()
	if hit_any:
		Game.shake(0.16, 0.10)


func _show_swing() -> void:
	## 외침. 소리는 안 나지만 **보이게** 만듭니다.
	##
	## 무기가 없는 아이라 공격은 소리 지르기입니다. 그래서 칼 궤적 대신 앞으로
	## 퍼져 나가는 파문을 그립니다. 판정 범위(정면 부채꼴)와 같은 방향·거리라
	## 눈으로 사거리를 배울 수 있습니다.
	##
	## 파문을 셋으로 나눠 시차를 두는 이유: 하나면 그냥 원이 커지는 것으로
	## 보이지만, 여럿이 이어 나가면 소리가 퍼지는 것으로 읽힙니다.
	## 시차를 두고 셋을 내보냅니다. 뒤엣것일수록 늦게, 조금 더 앞에서, 조금 더
	## 작게 나가서 셋이 앞으로 벌어지는 깔때기를 그립니다. 크기까지 같으면
	## 겹쳐서 하나로 보입니다(실제로 그렇게 나왔습니다).
	##
	## 시차는 **목소리 길이에 맞춥니다**. 셋을 앞쪽에 몰아 내보내면 목소리가
	## 아직 한창일 때 화면에는 아무것도 남지 않습니다(RING_GAP 주석 참고).
	# **닿는 범위를 그대로 칠합니다.** 사거리와 각도를 판정에서 받아 오므로
	# (`shout_range()`, `ATTACK_ARC`), 수치를 바꾸면 그림도 같이 바뀝니다.
	Fx.shout_fan(get_parent(), global_position, aim,
		shout_reach(_shout_fired) + 0.4, shout_arc(_shout_fired))

	# 목소리. vtos 프로젝트에서 자른 클립(a1)입니다.
	#
	# 음높이를 매번 조금씩 흔듭니다. 같은 파일이 그대로 반복되면 세 번째부터
	# 기계음으로 들립니다.
	# **목소리는 여기서 안 냅니다.** 누르는 순간(`_begin_shout`)에 시작해서
	# 떼는 순간 끊깁니다 - 모은 만큼만 들리는 것이 이 기술의 규칙입니다.

	# 외치는 순간 발밑에서 먼지가 한 번 튑니다.
	#
	# 화면 흔들기는 여기서 하지 않습니다. 맞혔을 때만 흔들어야(_resolve_swing)
	# 흔들림이 "맞았다" 는 신호로 남습니다. 헛쳐도 흔들면 그냥 잡음입니다.
	Fx.burst(get_parent(), global_position + Vector3(0, 0.15, 0),
		Color(1.0, 0.86, 0.55), 5, 2.0)


## 파문의 크기는 **소리가 닿는 원**에서 끌어옵니다. 가장 큰 고리의 지름이
## 사거리(ATTACK_RANGE)와 같아지고, 다 퍼졌을 때 고리의 앞쪽 가장자리가 마침
## 판정 끝에 놓입니다. 그래서 눈에 보이는 원 하나가 곧 사거리 눈금입니다.
const RING_SPAN := 0.5

## 파문의 시간표는 **목소리 클립에서 끌어옵니다**. shout_a1.wav 는 1.05초이고,
## 0.05~0.90초 내내 최대치 근처로 울리다가 끝에서야 잦아듭니다(50ms 창 RMS 실측:
## 0.30~0.45초가 최대, 0.95초에 -20dB). 여기에 맞추지 않으면 목소리가 한창일 때
## 화면에는 이미 아무것도 없습니다 - 실제로 그렇게 어긋나 있었습니다.
##
## - 첫 고리가 가장 커지는 때(GROW_TIME)를 소리가 가장 큰 구간에 둡니다.
## - 마지막 고리가 사라지는 때(GAP*2 + GROW + FADE = 0.94초)를 소리가 잦아드는
##   0.95초에 맞춥니다.
##
## 재사용 대기(0.55초)보다 길어서 연타하면 두 번째 고함의 고리와 겹칩니다.
## 그래도 맞습니다 - 목소리도 그만큼 겹쳐서 나기 때문입니다.
const GROW_TIME := 0.32
const FADE_TIME := 0.30
const RING_GAP := 0.16

## 시작이자 사라질 때의 크기. 0 에서 시작하면 첫 프레임에 점으로 찍히고,
## 0 으로 끝나면 마지막에 무엇이 줄어들었는지 보이지 않습니다.
const RING_SEED := 0.18

## 파문 메시는 늘 같은 모양입니다. 공격마다 새로 만들면 그때마다 정점을 다시
## 올려서 프레임이 한 번 튑니다(실측: 6.9ms -> 13.6ms). 한 번 만들어 돌려씁니다.
static var _shared_ring: TorusMesh = null


static func _ring_mesh() -> TorusMesh:
	if _shared_ring == null:
		var m := TorusMesh.new()
		# 얇은 고리. 두꺼우면 파문이 아니라 원반으로 보입니다.
		m.inner_radius = 0.93
		m.outer_radius = 1.0
		m.rings = 24
		m.ring_segments = 6
		_shared_ring = m
	return _shared_ring


func _shout_ring(at: Vector3, peak: float, alpha: float) -> void:
	## 정면으로 나아가는 파문 하나. 소리 원 크기까지 커졌다가 다시 작아집니다.
	if not is_instance_valid(self) or get_parent() == null:
		return
	var mesh := _ring_mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.6, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 방향은 부모가, 크기는 자식이 맡습니다. 한 노드에서 basis 와 scale 을 같이
	# 건드리면 둘이 서로를 다시 계산하면서 고리가 납작한 막대로 눌립니다
	# (실제로 그렇게 나왔습니다).
	var holder := Node3D.new()
	holder.position = at
	holder.basis = Basis.looking_at(aim, Vector3.UP)
	get_parent().add_child(holder)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# 고리를 세웁니다. 기본 토러스는 눕혀져 있어 그대로 두면 바닥 물결이 됩니다.
	mi.rotation.x = PI * 0.5
	mi.scale = Vector3.ONE * RING_SEED
	holder.add_child(mi)

	# 고함 계통 Lv 이 오르면 파문이 굵고 밝아집니다. Lv5 부터는 터질 때
	# 한 겹이 더 나갑니다 - 같은 기술인데 화면이 달라지는 것이 강화입니다.
	var slv := skill_lv("shout")
	var far := shout_range() * RING_SPAN * peak
	# 나아가는 거리는 셋 다 같습니다. 크기에 따라 다르게 보내면 작은 뒷고리가
	# 더 멀리 가서 앞고리를 따라잡고, 셋이 한자리에 겹쳐 하나로 보입니다
	# (실제로 그렇게 나왔습니다). 같은 거리를 가야 처음의 시차가 간격으로 남습니다.
	var travel := shout_range() * RING_SPAN
	var tween := holder.create_tween()
	tween.set_parallel(true)
	# 크기는 균일하게 키웁니다. 축마다 다르게 늘리면 원이 타원으로 무너집니다.
	tween.tween_property(mi, "scale", Vector3.ONE * far, GROW_TIME) 		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "position", at + aim * travel, GROW_TIME) 		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# 퍼지는 동안에는 살짝만 옅어집니다. 여기서 0 까지 빼 버리면 가장 커진
	# 순간에 이미 안 보이고, 그대로 사라져 뚝 끊긴 것으로 느껴집니다.
	tween.tween_property(mat, "albedo_color:a", alpha * 0.7, GROW_TIME)
	# 되돌아오는 꼬리. 커진 만큼 다시 작아져야 "울렸다 잦아들었다" 로 읽힙니다.
	tween.chain().tween_property(mi, "scale", Vector3.ONE * RING_SEED, FADE_TIME) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "albedo_color:a", 0.0, FADE_TIME)
	tween.chain().tween_callback(holder.queue_free)


# ---------------------------------------------------------------- 피해

func skill_charge(kind: String) -> float:
	## 그 기술이 얼마나 준비됐는지. 0 = 방금 썼음, 1 = 지금 쓸 수 있음.
	##
	## **숨은 여기서 안 봅니다.** 쿨다운은 기다리면 차고 숨이 모자란 것은
	## 기다려도 안 되는(다른 기술을 써야 하는) 다른 상태라, 화면에서도 다르게
	## 보여야 합니다 - 하나로 합치면 왜 못 쓰는지가 안 읽힙니다.
	match kind:
		"shout":
			return 1.0 - clampf(_attack_cd / maxf(_attack_cd_max, 0.001), 0.0, 1.0)
		"roll":
			return 1.0 - clampf(_dash_cd / maxf(_dash_cd_max, 0.001), 0.0, 1.0)
		"grab":
			return 1.0 - clampf(_grab_cd / maxf(_grab_cd_max, 0.001), 0.0, 1.0)
	return 1.0


func skill_winded(kind: String) -> bool:
	## 숨이 모자라 못 쓰는 상태인지. **연타로 오른 값**까지 반영합니다 -
	## 세 번째 밀기가 25 를 요구하는데 화면에는 10 짜리로 보이면, 왜 안
	## 나가는지 알 수 없습니다.
	match kind:
		"shout":
			return not _has_breath(breath_cost("shout", BREATH_SHOUT))
		"roll":
			return not _has_breath(breath_cost("roll", BREATH_ROLL))
		"grab":
			return not _has_breath(breath_cost("grab", BREATH_GRAB))
	return false


func is_bound() -> bool:
	return _bound_time > 0.0


func bind_by(who: Node3D, seconds: float) -> bool:
	## 등을 붙잡힙니다. 잡을 수 있었으면 true.
	##
	## **구르는 중에는 안 잡힙니다.** 구르기는 "맞을 수 없는 상태" 이고
	## (projectile.gd 의 통과 판정과 같은 규칙), 붙잡히는 것은 맞는 것보다
	## 오래 아픈 일이라 여기만 예외로 두면 구르기의 뜻이 흔들립니다.
	##
	## **한 번에 하나만** 붙습니다. 둘이 겹치면 시계가 두 개 돌아서, 먼저
	## 붙은 쪽이 떨어질 때 아직 붙어 있는 쪽까지 같이 풀립니다.
	if _dead or is_invulnerable() or _bound_time > 0.0 or _read_time > 0.0:
		return false
	_bound_time = seconds
	_bound_by = who
	# 들고 있던 것은 놓칩니다. 붙잡힌 채로 물건을 계속 쥐고 있으면, 붙잡힌
	# 시간이 아무것도 잃지 않는 시간이 됩니다.
	if is_instance_valid(_held):
		if _held is Enemy:
			(_held as Enemy).release_pose()
			(_held as Enemy).held_by = null
		elif _held.has_method("drop"):
			_held.call("drop")
	_held = null
	velocity.x = 0.0
	velocity.z = 0.0
	return true


func unbind_from(who: Node3D) -> void:
	## 붙잡고 있던 쪽이 먼저 떨어졌을 때. 잡고 있는 아이가 맞았거나 죽었거나.
	if _bound_by != who:
		return
	_bound_time = 0.0
	_bound_by = null


func _break_free() -> void:
	## 스스로 빠져나갑니다.
	_bound_time = 0.0
	if is_instance_valid(_bound_by) and _bound_by.has_method("release_cling"):
		_bound_by.release_cling()
	_bound_by = null
	Sfx.play(Sfx.PUSH, -8.0, 0.14)
	Fx.burst(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(1.0, 0.95, 0.7), 12, 3.6)


func _struggle(delta: float) -> void:
	## 붙잡혀 있는 동안. 발이 묶이고, 버튼을 두드리면 빨리 풀립니다.
	##
	## 시간만으로 풀리게 두면 붙잡힌 1.5초가 **아무것도 아닌 시간**이 됩니다 -
	## 손을 놓고 기다리는 것이 최선인 구간은 게임이 잠깐 멈춘 것과 같습니다.
	## 두드려서 줄일 수 있으면 그 시간에도 할 일이 있고, 얼마나 급한지에 따라
	## 두드리는 세기가 달라집니다.
	_bound_time -= delta
	_struggle_show = maxf(0.0, _struggle_show - delta)
	# 몸부림. 제자리에서 조금씩 흔들립니다.
	velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
	if not is_instance_valid(_bound_by):
		# 잡고 있던 아이가 사라졌습니다(죽었거나 던져졌거나).
		_bound_time = 0.0
		_bound_by = null
		return
	if _bound_time <= 0.0:
		_break_free()


## 버튼 한 번에 줄어드는 시간. 세 번쯤 두드리면 절반이 됩니다.
const STRUGGLE_STEP := 0.26


func _mash() -> bool:
	## 붙잡혀 있을 때 눌린 버튼은 **전부 버둥거림**이 됩니다.
	##
	## 어떤 버튼인지 가리지 않습니다. 붙잡힌 사람이 "무엇을 눌러야 하지" 를
	## 고민하게 만들 이유가 없고, 폰에서는 누를 수 있는 버튼이 몇 개 안 됩니다.
	if _bound_time <= 0.0:
		return false
	_bound_time = maxf(0.0, _bound_time - STRUGGLE_STEP)
	_struggle_show = 0.18
	Fx.burst(get_parent(), global_position + Vector3(0, 1.2, 0),
		Color(1.0, 0.9, 0.6), 5, 2.2)
	if _bound_time <= 0.0:
		_break_free()
	return true


func is_invulnerable() -> bool:
	return _invuln > 0.0 or _dead


func _guard_takes(from: Vector3) -> bool:
	## 누르고 있는 막기가 이 한 대를 **깎는가**(다 지우지는 못합니다).
	##
	## **앞쪽 130도만** 막습니다. 뒤까지 막으면 등을 조심할 이유가 없어지고,
	## 그러면 막기가 자세가 아니라 스위치가 됩니다(베개 아이와 같은 규칙).
	if not guarding():
		return false
	var to := from - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	if to.normalized().dot(aim) < cos(deg_to_rad(GUARD_ARC) * 0.5):
		return false
	# 막을 때마다 숨을 한 번 더 씁니다. 계속 막고만 있으면 숨이 먼저 다합니다.
	state.breath = maxf(0.0, state.breath - BREATH_GUARD_HIT)
	_invuln = maxf(_invuln, 0.10)
	_guard_pose = maxf(_guard_pose, GUARD_POSE_MIN)
	# 막은 자리에서 조각이 튑니다. **고리는 안 씁니다** - 고리는 이 게임에서
	# 「퍼지는 것」의 모양이라, 받아 낸 자리에 쓰면 무언가 나간 것으로
	# 보입니다.
	Sfx.play(Sfx.PUSH, -8.0, 0.06)
	Game.shake(0.12, 0.08)
	Fx.burst(get_parent(), global_position + to.normalized() * 0.45
		+ Vector3(0, 0.7, 0), Color(0.82, 0.90, 1.0), 7, 2.4)
	return true


func _try_parry(from: Vector3) -> bool:
	## **맞기 직전에 막기를 눌러 뒀나.** 눌러 뒀으면 그 한 대를 받아 냅니다.
	if _parry_ready <= 0.0 or _dead or _parry_air > 0.0:
		return false
	return _do_parry(from)


func _try_late_parry() -> bool:
	## **맞고 나서 눌렀나.** 0.10초 안이면 그 한 대를 되돌리고 받아 냅니다.
	##
	## 되돌리는 것이 곧 패링이 하는 일이라, 규칙이 하나 늘지 않습니다 -
	## 「받아 내면 그 한 대는 없던 일」 이 앞에서든 뒤에서든 같습니다.
	if _late_hit <= 0.0 or _dead or _parry_air > 0.0:
		return false
	var from := _late_from
	var back := _late_amount
	_late_hit = 0.0
	if not _do_parry(from):
		return false
	# **되돌립니다.** 맞은 값만 돌려주고, 넉백은 `_begin_parry` 가 속도를
	# 0 으로 만들면서 저절로 지워집니다.
	state.hp = minf(state.max_hp, state.hp + back)
	health_changed.emit(state.hp, state.max_hp)
	return true


func _do_parry(from: Vector3) -> bool:
	## 받아 낼 상대를 찾아 넘깁니다. 앞에서 눌렀든 뒤에서 눌렀든 여기로
	## 모입니다 - 갈래를 둘로 두면 한쪽만 고치게 됩니다.
	# **때린 쪽을 찾습니다.** `from` 은 때린 자리라 그 근처의 적이 임자입니다 -
	# 가장 가까운 적을 그냥 집으면, 뒤에서 온 것을 받아 내고 엉뚱한 아이에게
	# 발을 겁니다.
	if from.distance_to(global_position) > PARRY_HIT_NEAR:
		# **맞붙어서 맞았습니다.** 때린 자리가 곧 적의 자리입니다.
		var foe: Node3D = null
		var near := 3.2
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Node3D
			if not is_instance_valid(e):
				continue
			var d: float = e.global_position.distance_to(from)
			if d < near:
				near = d
				foe = e
		if foe != null:
			_begin_parry(foe, false)
			return true
	# **날아온 것을 받아 냈습니다.**
	#
	# 쏜 쪽을 찾아 **밀기가 닿는 거리 안이면** 반원을 그리며 다가가 겁니다.
	var shooter := _nearest_enemy(PARRY_REACH
		+ 0.6)          # 몸 반지름 몫
	if shooter != null:
		_begin_parry(shooter, true)
		return true
	# 닿지 않는 데서 쏜 것입니다. **피해만 지우고 끝입니다** - 방 저편까지
	# 날아가면 받아 내기가 순간이동이 됩니다.
	_parry_ignore()
	return true


func _parry_ignore() -> void:
	## 받아 내기는 됐지만 **되받아칠 상대가 없습니다.** 날아온 것을 쳐낸
	## 것까지만입니다.
	_parry_ready = 0.0
	_guard_held = false
	state.breath = maxf(0.0, state.breath - BREATH_PARRY)
	_invuln = maxf(_invuln, 0.25)
	_guard_pose = maxf(_guard_pose, GUARD_POSE_MIN)
	Sfx.play(Sfx.GRAB, -4.0, 0.0)
	Sfx.play_at(Sfx.PICK, 1.4, -5.0)
	Game.shake(0.14, 0.10)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.9, 0),
		Color(1.0, 0.95, 0.8), 8, 2.6)
	parried.emit()


func _begin_parry(foe: Node3D, _unused: bool = false) -> void:
	## 받아 냈습니다. **거리를 좁히고, 비켜서면서 발을 걸어 넘어뜨립니다.**
	##
	## 좁히는 마디는 **멀 때만** 돕니다. 바로 앞이면 그냥 겁니다 - 코앞에서도
	## 달려가는 시늉을 하면 그게 더 큰 동작입니다.
	##
	## 후속 누름이 없습니다. 받아 내면 이 한 동작이 끝까지 돕니다 - 받아 낸
	## 그 순간에 무엇을 눌러야 하는지 배울 자리가 없으면 손이 굳습니다.
	_parry_ready = 0.0
	_parry_foe = foe
	_parry_from = global_position
	_parry_hit = false
	# 받아 낸 한 대는 **없던 일이 됩니다.** 안 지우면 끝나는 순간 그 공격이
	# 마저 들어옵니다.
	if foe.has_method("interrupt"):
		foe.call("interrupt", 0.9)
	# 돌고 있던 것들을 다 접습니다.
	_dash_time = 0.0
	_roll_time = 0.0
	_push_time = 0.0
	_lunge_time = 0.0
	_lunge_at = null
	_swing_time = 0.0
	_guard_held = false
	# **값은 숨 10 입니다.** 막기(20)의 절반 - 맞춰 누른 값입니다.
	state.breath = maxf(0.0, state.breath - BREATH_PARRY)

	var dir: Vector3 = foe.global_position - _parry_from
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.0001 else aim
	aim = dir
	# **어느 쪽으로 비킬까.** 손이 방향을 주고 있으면 그쪽, 아니면 왼쪽입니다.
	# 벽에 밀어붙여 놓고 늘 같은 쪽으로 비키면 벽에 낀 채로 서 있게 됩니다.
	var side := Vector3(-dir.z, 0.0, dir.x)
	var wish := _wish_dir
	if wish.length_squared() > 0.04 and wish.dot(side) < 0.0:
		side = -side
	# **먼저 거리를 좁힙니다.** 바로 앞(1.05m)이면 안 달립니다.
	var gap: float = _parry_from.distance_to(foe.global_position) - PARRY_CLOSE
	_parry_run = clampf(gap / PARRY_RUN_SPEED, 0.0, PARRY_RUN_MAX) if gap > 0.05 else 0.0
	_parry_run_to = _parry_from + dir * maxf(gap, 0.0)
	_parry_run_to.y = _parry_from.y
	# **돌아서 등 뒤에 섭니다.** 좁힌 자리의 정반대편입니다 - 반 바퀴를
	# 돌므로 끝 자리는 곡선을 그리는 식과 어긋날 수가 없습니다.
	_parry_spin = 1.0 if side.dot(Vector3(-dir.z, 0.0, dir.x)) >= 0.0 else -1.0
	_parry_to = foe.global_position + dir * PARRY_CLOSE
	_parry_to.y = _parry_from.y
	_parry_trail = 0.0
	_parry_air = _parry_run + PARRY_TIME
	_invuln = maxf(_invuln, _parry_air + 0.2)

	Sfx.play(Sfx.GRAB, -2.0, 0.0)
	Sfx.play_at(Sfx.PICK, 1.4, -3.0)
	Game.shake(0.18, 0.12)
	Fx.burst(get_parent(), _parry_from + Vector3(0, 0.5, 0),
		Color(1.0, 0.95, 0.8), 8, 2.6)
	parried.emit()


func _tick_parry(delta: float) -> void:
	## 비켜서며 발을 거는 한 동작을 굴립니다.
	##
	## **세상을 늦추지 않습니다.** 받아 낼 때마다 0.34배로 0.42초를 늦춰
	## 봤는데, 동작이 작아지고 나니 그 늦춤이 동작보다 크게 느껴졌습니다 -
	## 손에 붙는 기술일수록 자주 나오고, 자주 나오는 것이 매번 판을 끊으면
	## 그건 상이 아니라 방해입니다.
	if _parry_air <= 0.0:
		return
	_parry_air -= delta
	# **두 마디입니다.** 먼저 직선으로 좁히고(멀 때만), 그 다음 비켜서며
	# 겁니다. 바닥에 붙어 갑니다 - 조금이라도 뜨면 다시 큰 동작이 됩니다.
	var pos: Vector3
	var k := 0.0
	if _parry_air > PARRY_TIME:
		# ① 좁히는 마디.
		var kr := 1.0 - clampf((_parry_air - PARRY_TIME) / maxf(_parry_run, 0.0001),
			0.0, 1.0)
		pos = _parry_from.lerp(_parry_run_to, kr)
	else:
		# ② **상대를 돌아 등 뒤로 가는 마디.**
		k = 1.0 - clampf(_parry_air / PARRY_TIME, 0.0, 1.0)
		pos = _orbit_point(k * k * (3.0 - 2.0 * k))
	pos.y = global_position.y
	# **가는 내내 잔상을 떨굽니다.** 거리마다입니다(구르기와 같은 규칙) -
	# 좁히는 마디에서는 촘촘하고, 도는 짧은 궤도에서는 두어 장입니다.
	_parry_trail += pos.distance_to(global_position)
	if _parry_trail >= PARRY_TRAIL_STEP:
		_parry_trail = 0.0
		_afterimage(false)
	# **자리를 직접 옮기지 않습니다.** 옮기면 충돌을 안 거쳐서 벽을 뚫고
	# 방 밖으로 나갑니다 - 받아 내고 나면 벽 뒤에 서 있었습니다. 가고 싶은
	# 만큼을 속도로 바꿔 두면 `move_and_slide` 가 벽에서 멈춰 줍니다.
	var step := pos - global_position
	step.y = 0.0
	_parry_vel = step / maxf(delta, 0.0001)
	# **지나가면서** 겁니다. 다 비켜선 뒤에 걸면 두 동작으로 보입니다.
	if not _parry_hit and _parry_air <= PARRY_TIME and k >= PARRY_TRIP_AT:
		_parry_trip()
	# 넘어뜨린 쪽을 계속 봅니다.
	if is_instance_valid(_parry_foe):
		var to: Vector3 = _parry_foe.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			aim = to.normalized()
	if _parry_air <= 0.0:
		_end_parry()


func _orbit_point(t: float) -> Vector3:
	## **상대를 중심으로 반 바퀴 돌아 등 뒤로** 갑니다.
	##
	## 좁히는 마디가 이미 거리를 1.05m 로 맞춰 놨으므로, 여기서는 반지름이
	## 거의 그대로인 짧은 궤도입니다 - 멀리서부터 돌던 시절처럼 크게 휘지
	## 않습니다.
	##
	## 상대가 안 보이면(죽었거나) 그냥 끝 자리로 갑니다.
	if not is_instance_valid(_parry_foe):
		return _parry_run_to.lerp(_parry_to, t)
	var c: Vector3 = _parry_foe.global_position
	c.y = _parry_run_to.y
	var v0: Vector3 = _parry_run_to - c
	v0.y = 0.0
	var r := maxf(v0.length(), 0.05)
	var a := atan2(v0.z, v0.x) + PI * _parry_spin * t
	return c + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _parry_trip() -> void:
	## **발을 걸어 넘어뜨립니다.** 한 번만 들어갑니다.
	##
	## 미는 힘이 작습니다 - 넘어뜨리는 것이지 날려 보내는 것이 아닙니다.
	## 대신 **못 일어나는 시간**이 깁니다(1.6초). 그 사이가 잡거나 미는
	## 자리입니다.
	_parry_hit = true
	var foe := _parry_foe
	if not is_instance_valid(foe):
		return
	var roll := state.roll_damage(rng)
	foe.call("take_damage", float(roll[0]) * PARRY_TRIP_MULT, bool(roll[1]),
		global_position, PARRY_TRIP_STUN, global_position)
	# **등 뒤에서 앞으로 밉니다.** 내가 선 자리에서 상대 쪽입니다 - 돌아서
	# 뒤를 잡았으니 미는 쪽도 그 등이 향한 앞이어야 합니다.
	var go: Vector3 = foe.global_position - global_position
	go.y = 0.0
	go = go.normalized() if go.length_squared() > 0.0001 else aim
	# **미는 세기는 밀기와 같은 값**입니다. 여기에 숫자를 따로 적어 두면
	# 밀기를 키워도 발 걸기만 옛 세기로 남습니다.
	if foe.has_method("knock_back"):
		foe.call("knock_back", go * (SHOVE_KNOCK + state.shove_knock))
	Sfx.play(Sfx.PUSH, -3.0, 0.0)
	Game.shake(0.24, 0.14)
	Fx.burst(get_parent(), foe.global_position + Vector3(0, 0.25, 0),
		Color(0.90, 0.85, 0.72), 9, 2.6)
	note_hit()


func _end_parry() -> void:
	## 비켜선 자리에 섭니다.
	_parry_air = 0.0
	_parry_foe = null
	# **마지막에 자리를 맞추지 않습니다.** 맞추면 벽에 막혀 멈춰 선 몸이
	# 끝나는 순간 벽 너머로 순간이동합니다 - 막힌 것이 헛일이 됩니다.
	_parry_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	if pivot != null:
		pivot.rotation.x = 0.0


## **마지막으로 나를 아프게 한 것.** 죽음 화면이 씁니다.
##
## 지금 결말 화면은 처치·사탕·시간만 보여 줍니다 - 잘한 판과 못한 판이 같은
## 숫자로 끝나고, **다음 판에 무엇을 고칠지**가 안 남습니다. 무엇에게 졌는지
## 한 줄이 있으면 그 한 줄이 다음 판의 목표가 됩니다.
var last_hit_by := ""


func take_damage(amount: float, from: Vector3 = Vector3.ZERO,
		knock: float = 5.0, source: String = "") -> void:
	## `knock` 은 밀려나는 세기입니다. 기본값은 예전 그대로라, 값을 안 주는
	## 기존 호출들(할퀴기·가시·호통)은 하던 대로 밀립니다. 박치기만 두 배
	## 넘게 줘서 **부딪혀 튕겨나가는 것**이 다른 피격과 구분됩니다.
	if is_invulnerable():
		return
	# **막혀서 30% 만 들어온 것도 셉니다.** 마지막 한 대가 무엇이었나가
	# 궁금한 것이지, 온전히 맞았는지가 궁금한 것이 아닙니다.
	if source != "":
		last_hit_by = source
	# **맞기 직전에 고함을 눌러 뒀나.** 눌러 뒀으면 이 한 대는 없던 일이
	# 되고, 대신 받아 냅니다 - 무적(`is_invulnerable`)보다 뒤에 둡니다.
	# 구르는 중이면 이미 안 맞으므로 패링이 될 일도 없습니다.
	if _try_parry(from):
		return
	# **누르고 있으면 막습니다.** 앞쪽에서 오는 것만이고, **다 막지는
	# 못합니다** - 30% 는 새어 들어옵니다.
	#
	# 패링보다 뒤입니다 - 맞춰 누른 사람은 되받아쳐야지 그냥 막고 마는 것이
	# 아닙니다.
	if _guard_takes(from):
		amount *= GUARD_LEAK
	# 맞으면 연속이 끊깁니다. 게이지는 두 됩니다(ultimate.gd 참고).
	ultimate.broke()
	# **잡은 적이 앞을 막습니다.**
	#
	# 잡기는 숨을 계속 쓰고 발이 느려지는데 얻는 것이 "던질 수 있다" 뿐이라,
	# 들고 있는 동안이 순수한 손해였습니다. 앞에서 오는 것을 잡힌 쪽이 대신
	# 맞으면, 들고 다니는 시간 자체가 값을 합니다 - 적 하나를 방패로 쓰면서
	# 그 적을 깎는 셈이라 이득이 두 겹입니다.
	#
	# **앞에서 오는 것만** 막습니다. 잡힌 적은 몸 앞에 있으므로, 뒤에서 오는
	# 것까지 막으면 물건이 아니라 결계가 됩니다 - 등 뒤를 조심할 이유가
	# 사라지면 잡고 서 있는 것이 답이 되어 버립니다.
	if _shield_blocks(from):
		_shield_take(amount, from)
		return
	# **방금 맞은 한 대를 기억해 둡니다.** 곧바로 막기를 누르면 되돌립니다.
	_late_hit = PARRY_LATE
	_late_from = from
	_late_amount = amount
	state.hp -= amount
	_invuln = HIT_INVULN
	Sfx.play(Sfx.HURT, -3.0, 0.10)
	health_changed.emit(state.hp, state.max_hp)

	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.7, 0), amount,
		false, Fx.HURT_COLOR)
	Fx.flash(pivot, Fx.HURT_COLOR, 0.14)
	Fx.punch(pivot, 0.18)
	if _jiggle != null and from != Vector3.ZERO:
		_jiggle.kick((global_position - from).normalized() * 34.0)
	Game.shake(0.35, 0.22)

	_last_hit_from = from
	_hurt_time = HURT_POSE_TIME
	if from != Vector3.ZERO:
		var push := (global_position - from)
		push.y = 0.0
		if push.length_squared() > 0.001:
			velocity += push.normalized() * knock

	if state.hp <= 0.0:
		# **「체력」 Lv3 은 한 판에 한 번 버팁니다.**
		#
		# 완전 회복이 아니라 절반입니다 - 다 채워 주면 죽을 자리에서 죽지
		# 않는 것이 아니라 판이 하나 더 생기는 것이 되고, 그러면 계통 하나가
		# 다른 다섯보다 압도적으로 좋아집니다. 절반은 "한 번 더 실수하면
		# 끝" 이라는 자리에 세워 줍니다.
		if state.has_revive():
			state.revive_used = true
			state.hp = state.max_hp * 0.5
			_invuln = maxf(_invuln, 1.4)
			health_changed.emit(state.hp, state.max_hp)
			Game.shake(0.5, 0.34)
			Fx.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
				Color(1.0, 0.9, 0.5), 26, 4.2)
			if Game.instance != null:
				Game.instance.ui.toast("버텼다!", UiTheme.ACCENT)
			return
		state.hp = 0.0
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	if _anim != null:
		_anim.pause()
	var tween := pivot.create_tween()
	tween.tween_property(pivot, "rotation:x", -PI * 0.5, 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Fx.ring(get_parent(), global_position, Fx.HURT_COLOR, 3.0, 0.6)
	died.emit()
