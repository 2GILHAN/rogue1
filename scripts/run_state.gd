class_name RunState
extends RefCounted

## 한 번의 도전(run) 동안만 사는 수치들. 죽으면 통째로 버려집니다.
## 로그라이크의 성장은 전부 여기 모여 있고, 축복과 상점은 이 값만 건드립니다.

var floor_num := 1
var gold := 0

var max_hp := 100.0
var hp := 100.0
var damage := 20.0
## 0.8배로 낮춘 값(예전 6.5). 축복과 상점의 증가폭도 같은 비율로 줄여
## 성장 곡선의 모양은 그대로 뒀습니다.
## 두 번에 걸쳐 낮췄습니다: 6.5 -> 5.2(0.8배) -> 3.1(다시 0.6배).
## 축복과 상점의 증가폭도 같은 비율로 줄여 성장 곡선의 모양은 유지했습니다.
var move_speed := 3.1
var attack_rate := 1.0      # 배수. 1.4 면 초당 공격 횟수가 1.4배
var crit_chance := 0.05
var crit_mult := 2.0
var lifesteal := 0.0        # 준 피해의 비율만큼 회복
var dash_cooldown := 1.1

## 성격을 바꾸는 축복들. 0 이면 없는 것이고, 값이 들어가면 그 규칙이 켜집니다.
##
## 켜짐/꺼짐(bool)이 아니라 수치로 둔 이유: 같은 축복을 두 번 뽑았을 때
## 쌓이게 하려는 것입니다. bool 이면 두 번째는 아무 일도 안 일어나고,
## 그때가 하필 셋 다 마음에 안 드는 판입니다.
var shout_knock := 0.0      # 고함이 밀어내는 힘
var prop_blast := 0.0       # 던진 소품이 터지는 세기(1 = 한 번 뽑음)
var roll_pierce := 0.0      # 구르며 뚫고 지나가는 피해 배율
var slam_stun := 0.0        # 던진 적이 주변을 굳히는 시간(초)

## 기술별 강화. 상수로 박혀 있던 것들을 여기서 더해 씁니다 - 값을 한곳에
## 모아 두면 어떤 스킬이 무엇을 건드리는지 표만 봐도 압니다.
var shout_range := 0.0      # 고함 사거리 +m
var shout_stun := 0.0       # 고함 경직 +초
var shove_knock := 0.0      # 밀기 넉백 +
var shove_damage := 0.0     # 밀기 피해 배율 +
var lunge_range := 0.0      # 달려드는 거리 +m
var roll_dist := 0.0        # 구르기 거리 배율 +
var breath_regen := 0.0     # 숨 회복 +/초
## 연타 벌금을 깎는 비율(0~0.8). 같은 기술을 잇달아 쓸 때 더 드는 숨이
## 그만큼 줄어듭니다. 없애지는 못합니다 - 0 이 되면 연타가 다시 최선이 되고,
## 그러면 이 규칙을 넣은 이유가 사라집니다.
var repeat_relief := 0.0

## 기술 계통별 레벨. 같은 계통의 스킬을 몇 번 골랐는지의 합입니다.
##
## 이펙트가 **붙느냐 마느냐**만 이 값으로 정합니다(3 부터). 스킬 하나하나로
## 세면 종류가 많아 좀처럼 3 이 안 되는데, 계통으로 모으면 "고함을 파고
## 있다" 는 선택이 화면에 드러납니다.
##
## **세기는 이 값으로 정하지 않습니다.** 잔상 장수·아지랑이 크기·구슬 개수는
## 실제로 오른 값(`shove_knock`, `shout_stun` ...)에서 뽑습니다 - 계통 Lv 로
## 세기까지 정하면 「긴 팔」만 세 번 찍어도 세게 밀리는 그림이 떠서 이펙트가
## 거짓말을 합니다(player.gd 의 `_picks`).
var skill_lv: Dictionary = {"push": 0, "shout": 0, "roll": 0, "move": 0, "passive": 0}
## 스킬별로 몇 번 골랐는지. 고르는 화면에 Lv 로 보여 줍니다.
var boon_lv: Dictionary = {}

## 계통 이름. 화면에 그대로 씁니다.
const FAMILY_NAME := {
	"push": "밀기", "shout": "고함", "roll": "구르기",
	"move": "이동", "passive": "몸",
}

## 숨. 기술을 쓰는 밑천입니다.
##
## 재사용 대기만 있을 때는 모든 기술을 늘 쓸 수 있어서, 무엇을 쓸지가
## "지금 뭐가 준비됐나" 로만 정해졌습니다. 하나의 게이지를 나눠 쓰면
## **무엇을 포기할지**가 매번 생깁니다.
##
## 값의 비율이 곧 설계입니다 - 고함 한 번이면 숨이 거의 바닥나고, 잡기는
## 열 번을 할 수 있습니다. 고함 맞은 적이 1초 굳으므로(enemy.gd),
## "고함으로 굳히고 → 돌아 들어가 잡는다" 가 자연스럽게 이어집니다.
## 시험 중이라 넉넉하게 잡아 둡니다. 기술 값(고함 80 / 구르기 60 / 잡기 10)은
## 그대로이므로, 나중에 100 으로 되돌리면 원래 설계대로 돌아옵니다.
var breath := 500.0
var max_breath := 500.0

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

## 층을 정리할 때마다 셋 중 하나를 고릅니다. 고르는 행위 자체가 재미이므로
## 선택지는 서로 다른 플레이 방향을 가리켜야 합니다. 그래서 같은 계열
## (예: 피해량)이 한 번에 둘 나오지 않도록 group 으로 묶어 뽑습니다.
## 스킬. `family` 가 계통이고 `group` 은 **한 번에 같이 나오지 않게** 묶는
## 값입니다(offer_boons). 둘을 나눈 이유: 계통이 같아도 성격이 다르면 나란히
## 나오는 편이 낫습니다 - "고함을 넓힐까 세게 할까" 는 좋은 선택입니다.
##
## 고를 때마다 Lv 가 오르고, **계통 Lv 3 부터 이펙트가 붙습니다.** 세기는
## 계통 Lv 이 아니라 **그 스킬이 올린 값**을 따릅니다(고함 Lv5 의 호랑이만
## 계통 Lv 로 갈립니다 - 그것은 세기가 아니라 등급이라서).
const BOONS := [
	# ── 밀기 ────────────────────────────────────────────────────────────
	{"id": "shove_power", "family": "push", "group": "offense", "name": "억센 손",
		"desc": "밀기 피해 +40%", "icon": "✋"},
	{"id": "shove_knock", "family": "push", "group": "trick", "name": "밀치는 힘",
		"desc": "밀기 넉백 +0.7", "icon": "≫"},
	{"id": "lunge_reach", "family": "push", "group": "mobility", "name": "긴 팔",
		"desc": "달려드는 거리 +0.6m", "icon": "→"},

	# ── 고함 ────────────────────────────────────────────────────────────
	{"id": "shout_power", "family": "shout", "group": "offense", "name": "우렁찬 목",
		"desc": "공격력 +7", "icon": "◆"},
	{"id": "shout_range", "family": "shout", "group": "mobility", "name": "멀리 가는 소리",
		"desc": "고함 사거리 +0.5m", "icon": "◎"},
	{"id": "gale", "family": "shout", "group": "trick", "name": "돌풍",
		"desc": "고함이 적을 밀어냅니다", "icon": "≋"},
	{"id": "shout_stun", "family": "shout", "group": "defense", "name": "쩌렁쩌렁",
		"desc": "고함 경직 +0.5초", "icon": "✺"},

	# ── 구르기 ──────────────────────────────────────────────────────────
	{"id": "dash", "family": "roll", "group": "mobility", "name": "그림자 걸음",
		"desc": "구르기 재사용 -25%", "icon": "◇"},
	{"id": "pierce", "family": "roll", "group": "trick", "name": "구르는 돌",
		"desc": "구르며 뚫고 지나갑니다", "icon": "◐"},
	{"id": "roll_far", "family": "roll", "group": "offense", "name": "먼 구르기",
		"desc": "구르는 거리 +25%", "icon": "➤"},

	# ── 이동 ────────────────────────────────────────────────────────────
	{"id": "swift", "family": "move", "group": "mobility", "name": "재빠른 발",
		"desc": "이동 속도 +0.38", "icon": "▲"},
	{"id": "breath", "family": "move", "group": "defense", "name": "긴 숨",
		"desc": "숨 회복 +20/초", "icon": "≈"},
	{"id": "steady", "family": "move", "group": "trick", "name": "고른 숨",
		"desc": "같은 기술 연타로 드는 추가 숨 -40%", "icon": "∿"},

	# ── 몸(패시브) ──────────────────────────────────────────────────────
	{"id": "vigor", "family": "passive", "group": "defense", "name": "굳은 심지",
		"desc": "최대 체력 +30, 그만큼 회복", "icon": "■"},
	{"id": "keen", "family": "passive", "group": "offense", "name": "날 선 눈",
		"desc": "치명타 확률 +10%", "icon": "◉"},
	{"id": "brutal", "family": "passive", "group": "offense", "name": "잔혹",
		"desc": "치명타 배율 +0.6", "icon": "★"},
	{"id": "vampire", "family": "passive", "group": "defense", "name": "피의 대가",
		"desc": "흡혈 +6%", "icon": "●"},
	{"id": "flurry", "family": "passive", "group": "offense", "name": "연격",
		"desc": "공격 속도 +18%", "icon": "✦"},
	{"id": "greed", "family": "passive", "group": "fortune", "name": "탐욕",
		"desc": "즉시 금화 +45", "icon": "◆"},
	{"id": "bomb", "family": "passive", "group": "trick", "name": "폭죽 놀이",
		"desc": "던진 소품이 터집니다", "icon": "✸"},
	{"id": "slam", "family": "passive", "group": "trick", "name": "메다꽂기",
		"desc": "던진 적이 주변을 굳힙니다", "icon": "✖"},
]


func offer_boons(rng: RandomNumberGenerator) -> Array:
	var pool := BOONS.duplicate()
	pool.shuffle()
	var picked: Array = []
	var used_groups := {}
	for b in pool:
		if used_groups.has(b["group"]):
			continue
		used_groups[b["group"]] = true
		picked.append(b)
		if picked.size() == 3:
			break
	# 계열이 모자라면 남은 것으로 채웁니다.
	for b in pool:
		if picked.size() == 3:
			break
		if not picked.has(b):
			picked.append(b)
	return picked


func apply_boon(id: String) -> void:
	## 고른 스킬 하나를 몸에 새깁니다. **Lv 도 여기서 오릅니다** - 두 곳에서
	## 세면 언젠가 어긋납니다.
	boon_lv[id] = int(boon_lv.get(id, 0)) + 1
	var fam := family_of(id)
	if fam != "":
		skill_lv[fam] = int(skill_lv.get(fam, 0)) + 1

	match id:
		# 밀기
		"shove_power": shove_damage += 0.40
		# 한 단계당 +0.7 입니다(예전 0.5). 기본이 3.6 이라 한 번 찍으면
		# 4.3, 다섯 번이면 7.1 - 밀리는 거리로는 0.8m 에서 3.2m 로
		# **네 배**가 됩니다. 계통을 파는 보람이 거리로 보여야 합니다.
		"shove_knock": shove_knock += 0.7
		"lunge_reach": lunge_range += 0.6
		# 고함
		"shout_power": damage += 7.0
		"shout_range": shout_range += 0.5
		"gale": shout_knock += 9.0
		"shout_stun": shout_stun += 0.5
		# 구르기
		"dash": dash_cooldown = maxf(0.35, dash_cooldown * 0.75)
		"pierce": roll_pierce += 1.0
		"roll_far": roll_dist += 0.25
		# 이동
		"swift": move_speed += 0.38
		"breath": breath_regen += 20.0
		# 0.8 에서 멈춥니다. 다 없애면 연타가 다시 최선이 됩니다.
		"steady": repeat_relief = minf(0.8, repeat_relief + 0.40)
		# 몸
		"vigor":
			max_hp += 30.0
			heal(30.0)
		"keen": crit_chance = minf(0.75, crit_chance + 0.10)
		"brutal": crit_mult += 0.6
		"vampire": lifesteal = minf(0.5, lifesteal + 0.06)
		"flurry": attack_rate += 0.18
		"greed": gold += 45
		"bomb": prop_blast += 1.0
		"slam": slam_stun += 1.2


func family_of(id: String) -> String:
	for b in BOONS:
		if String(b["id"]) == id:
			return String(b.get("family", ""))
	return ""


func level_of(id: String) -> int:
	return int(boon_lv.get(id, 0))


func family_level(fam: String) -> int:
	## 계통 Lv. 이펙트가 이 값으로 갈립니다(3 이상 붙고, 5 이상 강해집니다).
	return int(skill_lv.get(fam, 0))


func apply_family(fam: String, rng: RandomNumberGenerator) -> String:
	## 그 계통의 스킬을 **하나 골라 바로 겁니다.** 이름을 돌려줍니다.
	##
	## 실험용입니다(테스트 방). 보통 판에서는 세 장 중에 고르는 것이 곧
	## 게임이지만, 효과를 보려는 자리에서는 그 셋을 뽑는 일 자체가 방해입니다 -
	## 계통 Lv 3 과 5 에서 이펙트가 갈리므로 그 값까지 빨리 올려야 합니다.
	##
	## 같은 계통 안에서는 아직 덜 찍은 것을 먼저 고릅니다. 무작위로 뽑으면
	## 한 스킬만 계속 올라가서, 계통 안의 다른 것을 볼 수 없습니다.
	var pool: Array = []
	for boon in BOONS:
		if String(boon.get("family", "")) == fam:
			pool.append(boon)
	if pool.is_empty():
		return ""
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return level_of(String(a["id"])) < level_of(String(b["id"])))
	var lowest := level_of(String(pool[0]["id"]))
	var tied: Array = []
	for boon in pool:
		if level_of(String(boon["id"])) == lowest:
			tied.append(boon)
	var pick: Dictionary = tied[rng.randi_range(0, tied.size() - 1)]
	apply_boon(String(pick["id"]))
	return String(pick["name"])


func skill_summary() -> Array:
	## HUD 에 쓸 "계통 Lv" 목록. 아직 안 찍은 계통은 빼고 보여 줍니다.
	var out: Array = []
	for fam in ["push", "shout", "roll", "move", "passive"]:
		var lv := family_level(fam)
		if lv > 0:
			out.append("%s Lv%d" % [FAMILY_NAME.get(fam, fam), lv])
	return out


# ---------------------------------------------------------------- 상점

## 가격은 층이 오를수록 비싸집니다. 초반에 다 사 버리면 후반에 살 게 없어집니다.
func shop_stock(rng: RandomNumberGenerator) -> Array:
	var scale := 1.0 + (floor_num - 1) * 0.22
	var catalog := [
		{"id": "heal", "name": "따뜻한 스튜", "desc": "체력 60 회복",
			"price": int(28 * scale), "icon": "♨"},
		{"id": "power", "name": "숫돌", "desc": "공격력 +6",
			"price": int(52 * scale), "icon": "†"},
		{"id": "vigor", "name": "두꺼운 조끼", "desc": "최대 체력 +25",
			"price": int(48 * scale), "icon": "▣"},
		{"id": "swift", "name": "가벼운 부츠", "desc": "이동 속도 +0.29",
			"price": int(45 * scale), "icon": "▼"},
		{"id": "keen", "name": "매의 깃", "desc": "치명타 확률 +8%",
			"price": int(58 * scale), "icon": "◈"},
		{"id": "flurry", "name": "가죽 손잡이", "desc": "공격 속도 +12%",
			"price": int(55 * scale), "icon": "○"},
	]
	catalog.shuffle()
	var stock := catalog.slice(0, 3)
	# 회복약은 항상 하나 놓습니다. 살 것이 공격력뿐이면 상점이 함정이 됩니다.
	var has_heal := false
	for s in stock:
		if s["id"] == "heal":
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
			max_hp += 25.0
			heal(25.0)
		"swift": move_speed += 0.29
		"keen": crit_chance = minf(0.75, crit_chance + 0.08)
		"flurry": attack_rate += 0.12
	return true
