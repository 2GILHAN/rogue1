class_name Ultimate
extends RefCounted

## 필살기 — 게이지(용기) · 발동 명령 · 필살 모드의 동작 표를 한곳에 모읍니다.
##
## # 왜 파일 하나에 모으는가
##
## 나중에 파생 동작을 더 붙일 자리라, **더할 곳이 한 군데여야** 합니다.
## 동작 하나를 더한다는 것은 여기 `MOVES` 에 줄 하나를 더하고 `player.gd` 의
## `_ultimate_move` 에 그 이름의 갈래를 하나 더 여는 일입니다 - 게이지·명령·
## 시간 제한은 손댈 필요가 없습니다.
##
## 이 클래스는 **판단만** 합니다. 실제로 몸을 움직이고 이펙트를 내는 것은
## `player.gd` 입니다 - 판단과 연출을 섞으면 동작을 더할 때마다 두 곳이
## 함께 자라고, 그러면 규칙이 어디 있는지 아무도 모르게 됩니다.
##
## # 흐름
##
##   쌓기   적을 때릴 때마다 `add_hit()`. 맞으면 `broke()` 로 연속이 끊깁니다.
##   발동   가득 찬 상태에서 `feed()` 에 구르기 → 밀기 → 고함이 짧은 사이에
##          들어오면 필살 모드가 켜집니다.
##   모드   그 뒤의 누름은 전부 필살 동작이 됩니다. 누를 때마다 용기를 쓰고,
##          `IDLE_LIMIT` 안에 다음 누름이 없으면 풀립니다.

## 용기 게이지의 최대치. 아래 `MOVES` 의 값들이 이 값을 기준으로 정해집니다 -
## 가득 차면 구르기 두 번 + 고함 한 번 정도가 나갑니다.
const MAX := 100.0

## 한 대 때릴 때마다 차는 양과, 연속으로 이어질 때의 덤.
##
## 연속에 덤을 주는 이유: 한 대씩 꾸준히 때려도 결국 차기만 하면 "언젠가는
## 쌓이는 것" 이라 게이지를 볼 이유가 없습니다. 끊기지 않고 몰아칠 때 눈에
## 띄게 빨리 차야 **지금 이 순간의 목표**가 됩니다.
const GAIN := 5.0
const COMBO_STEP := 1.2
const COMBO_MAX := 4

## 연속이 끊기는 시간. 이 안에 다음 타격이 없으면 연속수가 0 으로 돌아갑니다.
const COMBO_HOLD := 2.6

## **계통 하나를 끝까지(Lv3) 팠을 때만 찹니다.**
##
## 필살기는 판을 어느 정도 판 사람에게 열리는 문입니다. 처음부터 차면 그냥
## 또 하나의 기술이고, 스킬을 고르는 일과도 이어지지 않습니다.
##
## **5 로 박혀 있었습니다.** 계통 상한이 3 이 되면서 이 조건이 영영 안
## 맞아서, 게이지도 명령도 통째로 죽어 있었습니다 - 계통을 끝까지 판 보상이
## 아무것도 없던 이유입니다.
const NEED_FAMILY_LV := 3

## 발동 명령. 이 차례대로 눌러야 합니다.
##
## 구르기로 시작하는 이유: 구르기는 무적이라 아무 때나 눌러도 손해가 아닙니다.
## 잘못 눌러 죽는 일이 없어야 사람이 명령을 시도해 봅니다.
const COMMAND: Array[String] = ["roll", "grab", "shout"]
## 명령의 다음 글자까지 허용하는 시간. 폰에서 버튼 위를 훑는 속도가 이만합니다.
const COMMAND_WINDOW := 0.55

## 필살 모드에서 다음 누름까지 기다리는 시간. 지나면 풀립니다.
const IDLE_LIMIT := 1.6

## 필살 동작 표. **여기에 줄을 더하는 것이 곧 동작을 더하는 일입니다.**
##
## `cost` 는 용기, `name` 은 화면에 뜨는 이름입니다. `keep` 은 그 동작을 쓴
## 뒤에도 모드가 이어지는지 - 지금은 전부 이어지지만, 마무리 기술을 넣을
## 자리를 미리 열어 둡니다.
const MOVES := {
	"roll": {"cost": 18.0, "name": "달려들기", "keep": true},
	"grab": {"cost": 12.0, "name": "밀어붙이기", "keep": true},
	"shout": {"cost": 34.0, "name": "포효", "keep": true},
}

## 지금 모드가 켜져 있나.
var active := false
## 모드에서 다음 누름까지 남은 시간.
var idle_left := 0.0
## 발동 명령이 지금 몇 글자까지 맞았나, 다음 글자까지 남은 시간.
var _step := 0
var _step_left := 0.0
## 연속 타격 수와, 끊기기까지 남은 시간.
var combo := 0
var _combo_left := 0.0

var _state: RunState


func setup(state: RunState) -> void:
	_state = state


func step_index() -> int:
	## 명령이 지금 몇 글자까지 맞았나(0 = 안 받는 중). 소리의 음높이를 이
	## 값으로 올립니다 - 화면을 안 봐도 **어디까지 갔는지** 귀로 압니다.
	return _step


func ready_to_fire() -> bool:
	## 게이지가 가득 찼나. 명령을 받아 줄지의 조건입니다.
	return _state != null and _state.courage >= MAX


func ratio() -> float:
	if _state == null:
		return 0.0
	return clampf(_state.courage / MAX, 0.0, 1.0)


func unlocked() -> bool:
	## 게이지가 차기 시작하는 조건. 화면에 게이지를 보일지도 이걸로 정합니다 -
	## 아직 못 쓰는 게이지가 늘 떠 있으면 무엇을 보라는 표시인지 모릅니다.
	if _state == null:
		return false
	# 여섯 계통 전부를 봅니다. `"passive"` 라는 계통은 개편에서 사라졌고,
	# 체력·스테미나를 끝까지 판 판만 문이 안 열릴 이유가 없습니다.
	for fam in RunState.FAMILY_NAME.keys():
		if _state.family_level(fam) >= NEED_FAMILY_LV:
			return true
	return false


func tick(delta: float) -> void:
	## 시간을 흘립니다. 모드가 풀렸으면 true 를 돌려주는 대신, 부르는 쪽이
	## `active` 를 보고 정리하도록 둡니다 - 상태는 한 군데(여기)에만 둡니다.
	if _step_left > 0.0:
		_step_left -= delta
		if _step_left <= 0.0:
			_step = 0
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			combo = 0
	if not active:
		return
	idle_left -= delta
	if idle_left <= 0.0:
		active = false


func add_hit() -> void:
	## 적을 한 대 때렸습니다. **연속일수록 많이 찹니다.**
	if _state == null or active or not unlocked():
		return
	combo = mini(combo + 1, COMBO_MAX)
	_combo_left = COMBO_HOLD
	_state.courage = minf(MAX, _state.courage + GAIN * pow(COMBO_STEP, combo - 1))


func broke() -> void:
	## 맞았습니다. **연속만 끊고 게이지는 두 됩니다.**
	##
	## 깎으면 한 대 맞을 때마다 여태 쌓은 것이 사라지는데, 그러면 필살기가
	## "안 맞는 사람만 쓰는 것" 이 되어 정작 몰릴 때 못 씁니다.
	combo = 0
	_combo_left = 0.0


func feed(key: String) -> String:
	## 누름 하나를 넣습니다. 돌려주는 값이 곧 **부르는 쪽이 할 일**입니다.
	##
	##   ""          평소대로 하세요(이 누름은 필살기와 무관합니다)
	##   "opened"    명령이 한 글자 나아갔습니다. 평소 동작도 **하세요**
	##   "fire"      필살 모드가 켜졌습니다
	##   "roll"/...  필살 동작 이름. 그 동작을 하세요
	##   "empty"     용기가 모자랍니다. 모드가 풀립니다
	##   "over"      모드가 그 누름으로 끝났습니다
	if _state == null:
		return ""
	if active:
		return _spend(key)
	if not ready_to_fire():
		_step = 0
		return ""
	# 명령을 받는 중입니다.
	if key != COMMAND[_step]:
		# 첫 글자면 거기서 다시 시작합니다 - 헛디뎠다고 처음부터 다시
		# 누르게 하면, 빠르게 훑는 손에서는 영영 안 맞습니다.
		_step = 1 if key == COMMAND[0] else 0
		_step_left = COMMAND_WINDOW if _step > 0 else 0.0
		return "opened" if _step > 0 else ""
	_step += 1
	_step_left = COMMAND_WINDOW
	if _step < COMMAND.size():
		# **마지막 글자 전까지는 아무것도 안 삼킵니다.**
		#
		# 예전에는 명령을 받는 동안 누름을 전부 삼켰습니다. 이유는 "명령을
		# 넣는 사이에 몸이 딴 데 가 있으면 안 된다" 였는데, 값이 너무
		# 컸습니다 - **게이지가 찼다는 이유로 구르기와 밀기가 안 나갑니다.**
		# 구르고 바로 미는 것은 평범한 연결기라, 용기가 차 있는 동안에는
		# 싸움이 통째로 어긋납니다(관문 앞 체력 6 에서 이걸 만났습니다).
		#
		# 사람은 게이지가 찬 것과 기술이 안 나가는 것을 **잇지 못합니다.**
		# 규칙이 아니라 고장으로 보입니다.
		#
		# 이제 잃는 누름은 **마지막 고함 하나**뿐이고, 그것도 잃는 것이
		# 아니라 더 센 것으로 바뀌는 것입니다. 앞의 둘은 평소대로 나갑니다 -
		# 구르는 동안에는 밀기가 원래 안 나가므로(`_dash_time` 이 막습니다)
		# 몸이 딴 데 가는 일도 실제로는 안 생깁니다.
		return "opened"
	_step = 0
	active = true
	idle_left = IDLE_LIMIT
	return "fire"


func _spend(key: String) -> String:
	## 모드 안에서의 누름. 값을 치르고 동작 이름을 돌려줍니다.
	if not MOVES.has(key):
		return ""
	var cost: float = float(MOVES[key]["cost"])
	if _state.courage < cost:
		active = false
		return "empty"
	_state.courage -= cost
	idle_left = IDLE_LIMIT
	if not bool(MOVES[key].get("keep", true)):
		active = false
		return "over"
	return key


func stop() -> void:
	## 밖에서 모드를 끝냅니다(적이 사거리 밖이라는 등).
	active = false
	idle_left = 0.0


func move_name(key: String) -> String:
	return String(MOVES.get(key, {}).get("name", key))
