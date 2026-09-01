class_name RunState
extends RefCounted

## 한 번의 도전(run) 동안만 사는 수치들. 죽으면 통째로 버려집니다.
## 로그라이크의 성장은 전부 여기 모여 있고, 축복과 상점은 이 값만 건드립니다.

var floor_num := 1

## 층 이름. **숫자가 아니라 반 이름**입니다.
##
## "지하 3층" 은 어디에나 있는 던전이고, "햇님반" 은 어린이집입니다 - 적이
## 전부 또래이고 상인도 또래인 판에서 층까지 어린이집의 말이어야 한 이야기가
## 됩니다. 마지막은 **원장실**입니다: 어린이집에서 아이가 불려 가는 곳이고,
## 선생님(관문)이 거기 있는 것이 설명 없이 읽힙니다.
const FLOOR_NAMES := ["씨앗반", "나무반", "햇님반", "달님반", "원장실"]


static func floor_name(n: int) -> String:
	## 범위를 벗어나면 숫자로 돌아갑니다 - 이름을 다 못 붙인 층이 생겨도
	## 화면이 비지 않게.
	if n >= 1 and n <= FLOOR_NAMES.size():
		return FLOOR_NAMES[n - 1]
	return "지하 %d층" % n
var gold := 0

var max_hp := 100.0
var hp := 100.0
var damage := 20.0
## 0.8배로 낮춘 값(예전 6.5). 축복과 상점의 증가폭도 같은 비율로 줄여
## 성장 곡선의 모양은 그대로 뒀습니다.
## 두 번에 걸쳐 낮췄습니다: 6.5 -> 5.2(0.8배) -> 3.1(다시 0.6배).
## 축복과 상점의 증가폭도 같은 비율로 줄여 성장 곡선의 모양은 유지했습니다.
var move_speed := 3.1
var crit_chance := 0.05
var crit_mult := 2.0
## 구르기 재사용 대기. **거의 없습니다**(1.1 -> 0.22).
##
## 연달아 구르는 것을 막는 것은 숨(20)이지 시계가 아닙니다. 시계로 막으면
## 피해야 하는 순간에 "아직 안 됨" 이 되는데, 그건 실력이 아니라 운입니다.
var dash_cooldown := 0.22

## 성격을 바꾸는 축복들. 0 이면 없는 것이고, 값이 들어가면 그 규칙이 켜집니다.
##
## 켜짐/꺼짐(bool)이 아니라 수치로 둔 이유: 같은 축복을 두 번 뽑았을 때
## 쌓이게 하려는 것입니다. bool 이면 두 번째는 아무 일도 안 일어나고,
## 그때가 하필 셋 다 마음에 안 드는 판입니다.
var shout_knock := 0.0      # 고함이 밀어내는 힘
var roll_pierce := 0.0      # 구르며 뚫고 지나가는 피해 배율

## 기술별 강화. 상수로 박혀 있던 것들을 여기서 더해 씁니다 - 값을 한곳에
## 모아 두면 어떤 스킬이 무엇을 건드리는지 표만 봐도 압니다.
var shout_range := 0.0      # 고함 사거리 +m
var shove_knock := 0.0      # 밀기 넉백 +
var shove_damage := 0.0     # 밀기 피해 배율 +
var roll_dist := 0.0        # 구르기 거리 배율 +
var breath_regen := 0.0     # 숨 회복 +/초
## 연타 벌금을 깎는 비율(0~0.8). 같은 기술을 잇달아 쓸 때 더 드는 숨이
## 그만큼 줄어듭니다. 없애지는 못합니다 - 0 이 되면 연타가 다시 최선이 되고,
## 그러면 이 규칙을 넣은 이유가 사라집니다.
var repeat_relief := 0.0

## 물물교환에서 산 몫. **레벨 표와 따로 듭니다.**
##
## `_recompute` 가 max_hp·move_speed·breath_regen 을 표에서 새로 쓰기 때문에,
## 여기 안 모아 두면 산 것이 다음 축복 한 번에 사라집니다.
var bought_hp := 0.0
var bought_speed := 0.0
var bought_regen := 0.0

## 기술 계통별 레벨. **여섯 계통, 각 3 레벨이 끝입니다.**
##
## 예전에는 스킬이 스무 개였고 계통 레벨은 그것들을 몇 번 골랐는지의 합이라,
## "밀기를 팠다" 와 "무엇이 세졌다" 가 따로 놀았습니다 - 같은 밀기 Lv3 인데
## 넉백만 셋 찍은 판과 사거리만 셋 찍은 판이 완전히 다른 게임이었습니다.
##
## 지금은 **계통이 곧 스킬**입니다. 고르면 그 계통이 한 단계 오르고, 그
## 단계에 무엇이 붙는지는 아래 표 하나에 다 적혀 있습니다. 고르는 화면에서
## "다음 단계에 무엇이 생기는지" 를 그대로 보여 줄 수 있습니다.
var skill_lv: Dictionary = {
	"push": 0, "shout": 0, "roll": 0, "hp": 0, "move": 0, "breath": 0,
}
## **레벨은 `skill_lv` 한 곳에만 있습니다.**
##
## 예전에는 `boon_lv`(스킬별)와 `skill_lv`(계통별)가 따로 있었고, 계통이 곧
## 스킬이 되면서 둘이 같은 값이 됐습니다. 그런데 `level_of` 는 앞의 것을,
## `family_level` 은 뒤의 것을 읽고 있어서 **한쪽만 고치면 조용히 갈라졌습니다** -
## 실제로 확인용 배치에서 고함 Lv1 인데 피해가 들어가는 것으로 잡혔습니다.
## 둘을 하나로 합쳤습니다.

## 계통마다 3 단계가 끝입니다.
const MAX_LV := 3

## 「굳센 몸」 Lv3 의 버티기를 이미 썼는가. 한 판에 한 번뿐입니다.
var revive_used := false

## 계통 이름. 화면에 그대로 씁니다.
const FAMILY_NAME := {
	"push": "밀기", "shout": "고함", "roll": "구르기",
	"hp": "체력", "move": "이속", "breath": "스테미나",
}

## 숨. 기술을 쓰는 밑천입니다.
##
## 재사용 대기만 있을 때는 모든 기술을 늘 쓸 수 있어서, 무엇을 쓸지가
## "지금 뭐가 준비됐나" 로만 정해졌습니다. 하나의 게이지를 나눠 쓰면
## **무엇을 포기할지**가 매번 생깁니다.
##
## **100 입니다.** 시험 삼아 500 으로 벌려 둔 적이 있는데, 그러면 무엇을 써도
## 게이지가 안 줄어서 이 자원이 아무것도 정하지 않게 됩니다. 100 이면 기술
## 값(고함 40/30 · 구르기 40 · 밀기 30)이 곧 "몇 번 쓸 수 있나" 로 읽힙니다.
##
## 재사용 대기는 짧게 두고 **숨이 대신 막습니다**(player.gd). 대기로 막으면
## 기다리는 것이 답이지만, 숨으로 막으면 **섞어 쓰는 것**이 답입니다.
var breath := 100.0
var max_breath := 100.0

## 용기. **필살기 게이지**입니다(`scripts/ultimate.gd`).
##
## 숨과 다른 자원인 이유: 숨은 기술을 쓸 때마다 줄고 가만있으면 차는
## **평상시의 밑천**이고, 용기는 **잘 싸울수록만** 차는 상입니다. 하나로 합치면
## 필살기가 "오래 쉬면 나오는 것" 이 되어, 몰아치는 것과 이어지지 않습니다.
var courage := 0.0


var kills := 0
var elapsed := 0.0


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func roll_damage(rng: RandomNumberGenerator) -> Array:
	## [피해량, 치명타 여부]
	if rng.randf() < crit_chance:
		return [damage * crit_mult, true]
	return [damage, false]


# ---------------------------------------------------------------- 축복

## 층을 정리할 때마다 셋 중 하나를 고릅니다. **고르는 것은 계통입니다** -
## 이름이 여섯 개뿐이라 "이번 판은 무엇을 파고 있나" 를 화면 없이도 압니다.
##
## 단계마다 무엇이 붙는지는 여기 한 곳에만 적습니다. 코드 여기저기서 레벨을
## 보고 갈라지면, 표를 고쳐도 실제 동작이 안 따라오는 일이 반드시 생깁니다 -
## 아래 `_recompute` 가 이 표를 읽어 수치를 다시 계산하고, 규칙(연격·통과
## 같은 것)은 `has_*` 함수 하나씩으로만 물어봅니다.
const BOONS := [
	{"id": "push", "family": "push", "group": "push", "name": "밀기", "icon": "✋",
		"steps": [
			"넉백 2배",
			"넉백 3배 · 연격(대기 절반)",
			"넉백 4.5배 · 피해 +60% · 밀림 연쇄",
		]},
	{"id": "shout", "family": "shout", "group": "shout", "name": "고함", "icon": "◎",
		"steps": [
			"범위 +1.0m",
			"범위 +2.0m · 밀어냄",
			"범위 +3.0m · 피해 발생 · 호랑이",
		]},
	{"id": "roll", "family": "roll", "group": "roll", "name": "구르기", "icon": "◐",
		"steps": [
			"거리 +30%",
			"거리 +60% · 적을 통과",
			"거리 +90% · 구르며 피해 · 숨 40% 절약",
		]},
	{"id": "hp", "family": "hp", "group": "hp", "name": "체력", "icon": "■",
		"steps": [
			"최대 체력 +40",
			"최대 체력 +80 · 층마다 완전 회복",
			"최대 체력 +120 · 쓰러질 때 한 번 버팀",
		]},
	{"id": "move", "family": "move", "group": "move", "name": "이속", "icon": "▲",
		"steps": [
			"이동 속도 +15%",
			"이동 속도 +29% · 구른 직후 잠깐 질주",
			"이동 속도 +44% · 걸으면 숨이 두 배로 참",
		]},
	{"id": "breath", "family": "breath", "group": "breath", "name": "스테미나", "icon": "≈",
		"steps": [
			"최대 숨 +30 · 회복 +12/초",
			"최대 숨 +60 · 회복 +24/초",
			"최대 숨 +100 · 회복 +40/초 · 연타 벌금 절반",
		]},
]


func offer_boons(rng: RandomNumberGenerator) -> Array:
	## **아직 3 이 안 된 계통** 중에서 셋을 뽑습니다.
	##
	## 다 찍은 계통을 다시 내밀면 고를 것이 없는 선택지가 되고, 여섯 중 셋이
	## 이미 찼을 때는 화면이 통째로 그렇게 됩니다.
	var pool: Array = []
	for b in BOONS:
		if int(skill_lv.get(String(b["id"]), 0)) < MAX_LV:
			pool.append(b)
	pool.shuffle()
	var picked: Array = []
	for b in pool:
		# **다음 단계의 설명**을 실어 보냅니다. 지금 상태가 아니라 고르면
		# 무엇이 생기는지를 봐야 고를 수 있습니다.
		var copy: Dictionary = b.duplicate(true)
		var lv := int(skill_lv.get(String(b["id"]), 0))
		copy["desc"] = String(b["steps"][mini(lv, MAX_LV - 1)])
		picked.append(copy)
		if picked.size() == 3:
			break
	return picked


func apply_boon(id: String) -> void:
	## 계통 하나를 한 단계 올립니다. **Lv 도 여기서 오릅니다** - 두 곳에서
	## 세면 언젠가 어긋납니다.
	if not skill_lv.has(id):
		return
	var lv := mini(MAX_LV, int(skill_lv[id]) + 1)
	skill_lv[id] = lv
	_recompute()
	if id == "hp":
		# 늘어난 만큼 그 자리에서 채워 줍니다. 안 채우면 "최대 체력이 늘었다"
		# 가 지금 이 순간에는 아무 일도 아닌 것이 됩니다.
		heal(40.0)
	elif id == "breath":
		breath = max_breath


func _recompute() -> void:
	## 레벨 표에서 수치를 **다시 계산합니다.** 더하는 것이 아니라 매번 새로
	## 씁니다 - 더하면 이 함수를 두 번 부른 날 값이 두 배가 됩니다.
	var lp := level_of("push")
	var ls := level_of("shout")
	var lr := level_of("roll")
	var lh := level_of("hp")
	var lm := level_of("move")
	var lb := level_of("breath")

	# 밀기. 기본 넉백은 player.gd 의 SHOVE_KNOCK(3.6)이고, 여기 값은 **더하는
	# 몫**입니다. 배수로 적으면 기본값을 고칠 때 이 표가 조용히 어긋납니다.
	shove_knock = [0.0, 3.6, 7.2, 12.6][lp]
	shove_damage = [0.0, 0.0, 0.0, 0.60][lp]

	# 고함. 사거리만 오릅니다 - **피해는 Lv3 에서 처음 생깁니다**(has_shout_damage).
	shout_range = [0.0, 1.0, 2.0, 3.0][ls]
	shout_knock = [0.0, 0.0, 9.0, 12.0][ls]

	# 구르기.
	# 단계마다 10% 포인트씩 낮췄습니다(옛 30/60/90). 기본 거리도 같이 줄여서
	# (player.gd 의 DASH_SPEED), 다 찍어도 방을 가로지르지는 못합니다.
	roll_dist = [0.0, 0.20, 0.50, 0.80][lr]
	roll_pierce = 1.0 if lr >= 3 else 0.0

	max_hp = 100.0 + 40.0 * lh + bought_hp
	move_speed = 3.1 * [1.0, 1.15, 1.29, 1.44][lm] + bought_speed
	max_breath = 100.0 + [0.0, 30.0, 60.0, 100.0][lb]
	breath_regen = [0.0, 12.0, 24.0, 40.0][lb] + bought_regen
	repeat_relief = 0.5 if lb >= 3 else 0.0
	hp = minf(hp, max_hp)
	breath = minf(breath, max_breath)


# ── 단계로 갈리는 **규칙**들 ────────────────────────────────────────
#
# 수치가 아니라 있고 없고가 갈리는 것들입니다. 부르는 쪽에서 레벨 숫자를
# 직접 보지 않게 하려고 함수로 둡니다 - 숫자를 흩뿌리면 표를 고쳐도 한두
# 군데가 안 따라옵니다.

func has_push_combo() -> bool:
	## 밀기 Lv2. 대기가 절반이 되어 연달아 밀 수 있습니다.
	return level_of("push") >= 2


func has_push_chain() -> bool:
	## 밀기 Lv3. 밀린 적에 부딪힌 적도 밀립니다(다시 그 적에 부딪힌 적도).
	return level_of("push") >= 3


func has_shout_damage() -> bool:
	## 고함 Lv3. **그 전까지 고함은 피해가 0 입니다** - 범위와 경직만으로
	## 판을 정리하는 기술이라, 피해까지 있으면 다른 기술을 쓸 이유가 없습니다.
	return level_of("shout") >= 3


func has_roll_ghost() -> bool:
	## 구르기 Lv2. 구르는 동안 적을 통과합니다.
	return level_of("roll") >= 2


func has_roll_damage() -> bool:
	## 구르기 Lv3. 지나간 적이 아픕니다.
	return level_of("roll") >= 3


func roll_cost_mult() -> float:
	## 구르기 Lv3 은 숨을 40% 덜 씁니다.
	return 0.6 if level_of("roll") >= 3 else 1.0


func has_floor_heal() -> bool:
	## 체력 Lv2. 층을 넘을 때마다 가득 찹니다.
	return level_of("hp") >= 2


func has_revive() -> bool:
	## 체력 Lv3. 한 판에 한 번, 쓰러지지 않고 일어납니다.
	return level_of("hp") >= 3 and not revive_used


func has_roll_burst() -> bool:
	## 이속 Lv2. 구르기가 끝난 뒤 잠깐 빨라집니다.
	return level_of("move") >= 2


func has_walk_regen() -> bool:
	## 이속 Lv3. 걷는 동안 숨이 두 배로 찹니다.
	return level_of("move") >= 3


func family_of(id: String) -> String:
	for b in BOONS:
		if String(b["id"]) == id:
			return String(b.get("family", ""))
	return ""


func level_of(id: String) -> int:
	return int(skill_lv.get(id, 0))


func family_level(fam: String) -> int:
	## 계통 Lv(0~3). 수치도 이펙트도 전부 이 값 하나에서 나옵니다.
	return int(skill_lv.get(fam, 0))


func apply_family(fam: String, _rng: RandomNumberGenerator) -> String:
	## 그 계통을 **한 단계 올립니다.** 무엇이 붙었는지를 돌려줍니다.
	##
	## 계통이 곧 스킬이라 고를 것이 없습니다 - 예전에는 계통 안에서 덜 찍은
	## 스킬을 골라야 했는데, 그 갈래가 통째로 사라졌습니다.
	if not skill_lv.has(fam):
		return ""
	if level_of(fam) >= MAX_LV:
		return "%s 이미 Lv%d" % [FAMILY_NAME.get(fam, fam), MAX_LV]
	apply_boon(fam)
	var lv := level_of(fam)
	for b in BOONS:
		if String(b["id"]) == fam:
			return "%s Lv%d - %s" % [FAMILY_NAME.get(fam, fam), lv,
				String(b["steps"][lv - 1])]
	return String(FAMILY_NAME.get(fam, fam))


func skill_summary() -> Array:
	## HUD 에 쓸 "계통 Lv" 목록. 아직 안 찍은 계통은 빼고 보여 줍니다.
	var out: Array = []
	for fam in ["push", "shout", "roll", "hp", "move", "breath"]:
		var lv := family_level(fam)
		if lv > 0:
			out.append("%s Lv%d" % [FAMILY_NAME.get(fam, fam), lv])
	return out


# ---------------------------------------------------------------- 상점

## 가격은 층이 오를수록 비싸집니다. 초반에 다 사 버리면 후반에 살 게 없어집니다.
func shop_stock(rng: RandomNumberGenerator) -> Array:
	## 물물교환 재고 셋. **또래가 가진 것들**입니다 - 숫돌이나 가죽 손잡이는
	## 어린이집에 없습니다.
	##
	## 값은 층이 오를수록 비싸집니다. 초반에 다 바꿔 버리면 후반에 바꿀 것이
	## 없어집니다.
	var scale := 1.0 + (floor_num - 1) * 0.22
	var catalog := [
		{"id": "heal", "name": "딸기 우유", "desc": "체력 60 회복",
			"price": int(22 * scale), "icon": "♨"},
		{"id": "power", "name": "단단한 주먹밥", "desc": "공격력 +6",
			"price": int(42 * scale), "icon": "†"},
		{"id": "vigor", "name": "두꺼운 조끼", "desc": "최대 체력 +25",
			"price": int(40 * scale), "icon": "▣"},
		{"id": "swift", "name": "새 운동화", "desc": "이동 속도 +0.29",
			"price": int(38 * scale), "icon": "▼"},
		{"id": "keen", "name": "돋보기", "desc": "치명타 확률 +8%",
			"price": int(46 * scale), "icon": "◈"},
		{"id": "breath", "name": "박하 사탕", "desc": "숨 회복 +8/초",
			"price": int(44 * scale), "icon": "≈"},
	]
	catalog.shuffle()
	var stock := catalog.slice(0, 3)
	# 회복은 항상 하나 놓습니다. 바꿀 것이 공격력뿐이면 이 자리가 함정이
	# 됩니다 - 물놀이터가 바로 옆에 있어 사탕을 쓸 곳이 이미 둘입니다.
	var has_heal := false
	for item in stock:
		if item["id"] == "heal":
			has_heal = true
	if not has_heal:
		for c in catalog:
			if c["id"] == "heal":
				stock[2] = c
				break
	return stock


func buy(item: Dictionary) -> bool:
	if gold < int(item["price"]):
		return false
	gold -= int(item["price"])
	match String(item["id"]):
		"heal": heal(60.0)
		"power": damage += 6.0
		"vigor":
			bought_hp += 25.0
			_recompute()
			heal(25.0)
		"swift":
			bought_speed += 0.29
			_recompute()
		"keen": crit_chance = minf(0.75, crit_chance + 0.08)
		"breath":
			bought_regen += 8.0
			_recompute()
	return true
