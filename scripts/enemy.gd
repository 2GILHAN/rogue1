class_name Enemy
extends CharacterBody3D

## 적. 나머지 변화는 행동에서 만듭니다.
##
## **이름은 하는 일에서 옵니다.** 화면에 뜨는 이름은 「적N_기술」이고
## (`Enemy.LABEL`), 코드의 열쇠(`grunt`)와 파일 이름(`foe_charger.glb`)도 같은
## 말을 씁니다 - 예전에는 사람 이름과 색 이름이 섞여 있어서, 무엇을 하는
## 적인지 알려면 코드를 열어 봐야 했습니다.
##
##   grunt   기본. 달려와서 때립니다.
##   brute   느리고 단단하며, 가끔 돌진합니다. 큰 색으로 구분됩니다.
##   spitter 거리를 벌리고 가시를 뱉습니다. 접근을 강요합니다.
##
## 셋을 섞으면 한 방에서 "누구부터 처리할지" 라는 판단이 생깁니다. 그 판단이
## 없으면 적이 몇이든 같은 싸움입니다.

signal died(enemy: Enemy)

const GRAVITY := 22.0
## 던져질 때 띄우는 세로 속도. 여기서 체공 시간(2 × 6.9 ÷ 22 = 0.63초)이
## 나오고, 그 시간이 수평 속도를 정합니다.
const THROW_LIFT := 6.9
## 몸을 돌리는 **각속도 상한**(라디안/초). 지수 추종이 아니라 상한입니다.
##
## 지수로 따라오면(1 - exp(-k*dt)) 각도 차이가 클수록 빨리 돌기 때문에,
## 주위를 아무리 돌아도 일정한 각도만 벌어진 채 얼굴이 계속 따라옵니다.
## 실제로 재 보니 걸어서 도는 내내 **0.88**(정면이 1.0)에서 더 벌어지지
## 않아서, 등 뒤를 잡는 것이 원리적으로 불가능했습니다.
##
## 상한을 두면 이야기가 달라집니다. 가까이 붙을수록 같은 속도로 돌아도
## 각속도가 커지므로(w = v/r), 바짝 붙어 돌면 상한을 넘어서 등이 열립니다.
## 구르기(8m/s)로 스쳐 지나가면 훨씬 크게 열립니다.
##
## 1.3 rad/s = 초당 75도. 등 뒤에서 정면까지 돌아오는 데 2.4초입니다.
const TURN_SPEED := 1.3
const SEPARATION := 1.5
## 걷기 클립이 **1배속에서 바닥을 미는 속도**(m/s). 재생 속도를 여기에 맞추면
## 발이 미끄러지지 않습니다. 손으로 정한 값이 아니라 실측입니다
## (`run.bat --pose=stridefoe --foe=<종류>`).
##
## 캐릭터마다 다릅니다 - 다리 길이와 흔드는 각도에서 나오기 때문입니다.
## 모델을 바꾸거나 클립을 다시 구우면 여기도 다시 재야 합니다.
const WALK_GROUND := {
	Models.FOE_CHARGER: 1.141,
	Models.FOE_THROWER: 0.994,
	Models.FOE_BLOCKER: 0.531,
	Models.FOE_SHOUTER: 0.613,
	Models.FOE_CLINGER: 0.555,
	Models.BOSS_TEACHER: 1.304,
}
## 표에 없는 모델이 오면 쓰는 값. 값이 없다고 다리를 멈추는 것보다는
## 서진 것으로라도 도는 편이 낫습니다.
const WALK_GROUND_FALLBACK := 1.100
## 적 이동 속도는 늘 주인공과 같은 비율로 움직입니다(0.8배 뒤 다시 0.6배).
## 한쪽만 느려지면 쫓기는 긴장이나 도망칠 여유 중 하나가 사라집니다.

## **화면에 뜨는 이름.** 번호는 처음 만나는 순서입니다(층이 오르며 하나씩).
const LABEL := {
	"grunt": "적1_박치기",
	"screamer": "적2_고함",
	"spitter": "적3_던지기",
	"brute": "적4_돌진",
	"clinger": "적5_매달리기",
	"pillow": "적6_막기",
	"teacher": "보스_선생님",
}


static func label_of(k: String) -> String:
	return String(LABEL.get(k, k))


const KINDS := {
	# 서진은 **박치기**를 합니다. 손을 한 번 뻗어 겨눈 뒤, 그 방향으로 곧장
	# 달려와 부딪힙니다. `range` 는 때리는 거리가 아니라 **달려들기 시작하는
	# 거리**입니다 - 멀리서 겨누고 오므로 옆으로 비킬 시간이 있습니다.
	#
	# 예고가 길고(0.62초) 방향이 고정되므로 정답은 **옆으로 비키기**입니다.
	# 뒤로 물러나는 것은 답이 아닙니다 - 돌진이 물러나는 것보다 빠릅니다.
	"grunt": {
		"model": Models.FOE_CHARGER,
		"hp": 42.0, "damage": 11.0, "speed": 1.73, "scale": 1.0,
		"range": 4.6, "windup": 0.62, "cooldown": 2.4, "gold": 7,
		"aggro": 17.0,
		"attack": "charge", "charge_dist": 5.0, "charge_speed": 8.0,
		"knock": 11.0,
	},
	# 큰 아이는 **쫓아오는 돌진**입니다.
	#
	# 소품을 집어 던지던 기술이었는데, 던질 소품을 배치에서 뺀 뒤로는 던질
	# 것이 없어서 주우러 걸어 다니기만 했습니다 - 기술이 남아 있는데 아무
	# 일도 안 일어나는 상태였습니다.
	#
	# 서진과 같은 돌진이지만 **길이 굳지 않습니다.** 서진은 예고에서 방향을
	# 못 박고 그대로 달리므로 옆으로 반 발만 빠지면 지나갑니다. 큰 아이는
	# **닿기 0.3초 전까지 길을 고쳐 가며** 따라옵니다 - 일찍 피하면 따라오고,
	# 끝까지 붙어 있다가 마지막 0.3초에 빠져야 지나갑니다. 같은 돌진인데
	# 피하는 **시점**이 달라서 둘이 서로 다른 문제가 됩니다.
	#
	# 0.5 였다가 0.3 으로 좁혔습니다. 0.5초면 6.4m/s 로 **3.2m 앞**에서 길이
	# 굳는데, 그 거리에서는 옆으로 한 걸음만 옮겨도 지나가서 "쫓아온다" 가
	# 헐거웠습니다. 0.3 이면 1.9m - 눈으로 보고 몸을 빼야 하는 거리입니다.
	#
	# 느리고(6.4) 길게(9.0m = 1.41초) 달립니다. 빠르면 마지막 0.5초가 너무
	# 짧아 반응이 아니라 운이 됩니다.
	"brute": {
		"model": Models.FOE_CHARGER,
		"heavy": true,
		"hp": 120.0, "damage": 16.0, "speed": 1.30, "scale": 1.45,
		"range": 7.5, "windup": 0.75, "cooldown": 2.8, "gold": 20,
		"aggro": 15.0,
		"attack": "charge", "charge_dist": 9.0, "charge_speed": 6.4,
		# 닿기 이만큼 전에 길이 굳습니다(초). 0 이면 서진처럼 처음부터 굳습니다.
		"charge_track": 0.3,
		# 길을 고치는 빠르기(도/초). 즉시 꺾이면 피할 방법이 없고, 너무
		# 느리면 따라오는 것으로 안 읽힙니다.
		"charge_turn": 150.0,
	},
	"spitter": {
		# 원거리 적만 다른 메시를 씁니다. 크기와 색조로도 구분되지만, 가장
		# 먼저 알아봐야 하는 적이라 **실루엣**까지 다르게 둡니다.
		"model": Models.FOE_THROWER,
		"hp": 30.0, "damage": 8.0, "speed": 1.54, "scale": 0.9,
		"range": 9.0, "windup": 0.6, "cooldown": 1.9, "gold": 12,
		"aggro": 20.0, "attack": "spit",
	},
	# 선생님. 층마다 최대 한 명 나오는 관문입니다(game.gd 의 _spawn_enemies).
	#
	# 주인공의 공격이 소리 지르기라, 선생님은 **더 큰 소리로 되받습니다.**
	# 앞으로 넓게 퍼지는 호통이라 옆으로 피해야 하고, 그래서 다른 적들과
	# 대처법이 겹치지 않습니다. 예고가 길어(0.9초) 반응할 수 있습니다.
	# 고함치는 아기. **주인공과 같은 기술을 쓰는 또래**입니다.
	#
	# 선생님도 호통을 치지만 그쪽은 층마다 한 명뿐인 관문이라, 옆으로 피하는
	# 법을 배울 기회가 층당 한 번밖에 없었습니다. 같은 규칙을 작게 만들어
	# 여럿 두면 그 배움이 자주 쓰입니다 - 사거리(3.6m)와 각도(66도)가 선생님의
	# 절반 남짓이라 실수해도 덜 아프고, 대신 예고가 짧습니다(0.55초).
	#
	# 아프기보다 **밀어냅니다**(knock 9). 뒤로 날아가 다른 적 쪽으로 몰리는
	# 것이 이 적의 위협입니다.
	"screamer": {
		"model": Models.FOE_SHOUTER,
		# **주인공보다 약간 작습니다**(발~머리뼈 0.87 대 0.924, 6% 아래).
		#
		# 배율을 층에 안 맡깁니다(`base_scale` = `scale`). 다른 종류는 1층에
		# 1.0 으로 서서 층이 깊어지며 제 크기가 드러나는데, 이 아이는 그러면
		# **1층에서 주인공보다 큽니다** - GIRL 모델이 정규화 뒤에도 0.954 라
		# 주인공(0.924)을 넘습니다.
		"hp": 34.0, "damage": 7.0, "speed": 1.60,
		"scale": 0.91, "base_scale": 0.91,
		"range": 2.6, "windup": 0.55, "cooldown": 2.2, "gold": 10,
		"aggro": 18.0,
		"attack": "shout", "arc": 56.0, "knock": 9.0,
	},
	# 붙잡는 아기. 달려와 **등에 매달려** 잠시 못 움직이게 합니다.
	#
	# 혼자서는 거의 아프지 않습니다(피해 4). 위험한 것은 붙잡힌 1.5초 동안
	# **다른 적의 공격을 그대로 받는다**는 것입니다 - 이 적은 스스로 이기는
	# 적이 아니라 다른 적을 이기게 해 주는 적입니다. 그래서 우선순위가 생깁니다.
	#
	# 반드시 **뒤에서** 잡습니다(_pursue_cling 이 등 뒤로 돌아 들어갑니다).
	# 앞에서도 잡히면 정면으로 달려오는 것을 막을 방법이 없어 그냥 붙잡히는
	# 시간이 되지만, 뒤로 돌아오는 동안은 볼 수 있고 돌아서면 막힙니다.
	#
	# 체력이 낮아(26) 한 번에 정리됩니다. 붙잡는 적이 질기면 붙잡힌 동안
	# 아무것도 못 하는 시간이 계속 이어집니다.
	"clinger": {
		"model": Models.FOE_CLINGER,
		# 고함 아기와 **같은 크기**입니다(주인공보다 6% 아래). 같은 이유로
		# 층에 안 맡깁니다 - BOY 모델도 정규화 뒤 0.954 입니다.
		"hp": 40.0, "damage": 4.0, "speed": 2.05,
		"scale": 0.91, "base_scale": 0.91,
		"range": 1.4, "windup": 0.32, "cooldown": 2.4, "gold": 11,
		"aggro": 19.0,
		"attack": "cling", "bind": 1.5, "knock": 3.0,
	},
	# 베개 아기. **앞에서 오는 공격이 통하지 않습니다.**
	#
	# 이 게임의 공격은 셋 다 앞으로 나갑니다(고함은 부채꼴, 밀기는 달려들기,
	# 구르기는 지나가기). 그래서 "정면이 막혀 있다" 는 한 가지 규칙만으로
	# 세 기술 모두에 같은 질문이 생깁니다 - **어떻게 뒤로 돌아갈 것인가**.
	#
	# 답은 이미 손에 있습니다. 예고 중과 휘청일 때는 몸이 돌지 않으므로
	# (_physics_process 의 회전 규칙), 예고를 보고 구르면 등이 열립니다.
	#
	# 함정은 막지 못합니다 - 압정은 발밑에서 올라오고 베개는 앞을 가립니다.
	# 막을 수 없는 길을 하나 남겨 둬야 "이 적은 어떻게 하지" 의 답이 하나로
	# 굳지 않습니다.
	"pillow": {
		"model": Models.FOE_BLOCKER,
		"hp": 78.0, "damage": 14.0, "speed": 1.24, "scale": 1.15,
		"range": 2.1, "windup": 0.7, "cooldown": 2.5, "gold": 18,
		"aggro": 16.0,
		# 막는 각을 150 에서 **100** 으로 좁혔습니다. 150 은 양옆 75도까지라,
		# 눈으로는 분명히 옆에서 때렸는데 막히는 일이 잦았습니다 - 베개는
		# 몸 앞에 있는 물건이지 어깨까지 두른 방패가 아닙니다.
		"attack": "slam", "guard_arc": 100.0, "knock": 8.0,
	},
	"teacher": {
		"model": Models.BOSS_TEACHER,
		"heavy": true,
		"hp": 260.0, "damage": 22.0, "speed": 1.39, "scale": 1.0,
		"range": 6.5, "windup": 0.9, "cooldown": 2.6, "gold": 55,
		"aggro": 22.0,
		"attack": "shout", "arc": 78.0,
	},
}

var kind := "grunt"
var stats := {}
var max_hp := 42.0
var hp := 42.0
var damage := 9.0
var speed := 3.6
var gold := 7

var dungeon: Dungeon
var target: Node3D

var _pivot: Node3D
## 충돌 캡슐 높이. 던질 때의 크기 기준입니다.
var _capsule_height := 1.25
var _flinch_time := 0.0
## 잡혀 끌려갈 때의 자세(pose_override.gd).
var _pose: PoseOverride
var _anim: AnimationPlayer
var stride_probe := false
var _walk := ""
## 이 모델의 걷기 클립이 1배속에서 미는 거리(m/s)와, 지금 몸집 배율.
var _walk_ground := 0.320
var _scale_now := 1.0
## 지금 물러나는 중인가.
var _moving_back := false
var _idle := ""

var _aggro := false
var _windup := -1.0
## 맨손 공격을 예고한 방향. **예고가 시작될 때 굳고 끝까지 안 돕니다.**
var _melee_dir := Vector3.FORWARD
var _cooldown := 0.0
var _repath := 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_i := 0
var _charge := 0.0
var _charge_dir := Vector3.ZERO
## 이번 돌진에서 이미 부딪혔는가. 한 번 달릴 때 한 번만 맞습니다.
var _charge_hit := false
## 지금 들고 있는 소품(던지는 적).
var _carry: Prop = null
var _stagger := 0.0
## 호통을 시작한 순간의 방향. 예고 중에 이 방향이 따라오면 피할 수가 없습니다.
var _shout_dir := Vector3.FORWARD
## 맨손 공격의 판정 범위를 칠하는 바닥 판.
var _melee_fan: MeshInstance3D = null
var _melee_fan_mat: StandardMaterial3D = null
var _melee_flash := 0.0
## 돌진이 지나갈 길을 칠하는 바닥 띠.
var _lane: MeshInstance3D = null
var _lane_mat: StandardMaterial3D = null
var _lane_flash := 0.0
## 내려치기가 닿을 **채워진 원**. 예고 동안 커집니다 - 베개를 드는 동작과
## 원이 자라는 것이 같은 시간을 씁니다.
var _disc: MeshInstance3D = null
var _disc_mat: StandardMaterial3D = null
## 호통의 판정 범위를 칠하는 바닥 판. 그 공격을 쓰는 적만 만듭니다.
var _shout_fan: MeshInstance3D = null
var _shout_fan_mat: StandardMaterial3D = null
## 때린 직후 빨갛게 남는 시간.
var _fan_flash := 0.0

## 등에 매달려 있는 동안 남은 시간. 0 보다 크면 붙잡고 있는 중입니다.
##
## 주인공 쪽에도 같은 시계가 돕니다(player.gd 의 _bound_time). 둘을 따로 두는
## 이유는 **먼저 끝나는 쪽이 있기 때문**입니다 - 버둥거려 빠져나가면 주인공
## 쪽이 먼저 0 이 되고, 매달린 아이가 맞아 떨어지면 이쪽이 먼저 0 이 됩니다.
## 어느 쪽이 끝나든 상대에게 알려서 둘을 같이 풉니다.
var _cling := 0.0
## 붙잡으러 파고드는 동안 남은 시간. 이 시간이 도는 중에는 되돌아가지 않습니다.
var _cling_rush := 0.0
## 매달린 순간의 **붙은 자리**(주인공 기준 수평 오프셋). 매달려 있는 동안
## 이 값을 그대로 지킵니다.
var _cling_offset := Vector3.ZERO
## 내리치는 방향. 예고 때 고정합니다(호통과 같은 이유).
var _slam_dir := Vector3.FORWARD
## 내리친 직후의 자세가 남아 있는 시간.
var _slam_time := 0.0
## 앞을 막는 베개. 그 종류만 들고 있습니다.
var _pillow: Node3D = null
## 베개의 충돌체. 몸통이 돌면 이 자리도 따라 돌려 줍니다.
var _pillow_shape: CollisionShape3D = null
## 들려 있는 동안은 스스로 움직이지 않습니다.
var held_by: Node3D = null
var _thrown := 0.0
var _dead := false

var _bar_fill: MeshInstance3D
var _bar_root: Node3D
var _bar_mat: StandardMaterial3D


## 적 하나의 기본 배수. **수를 줄인 만큼 곱합니다.**
##
## 한 층의 적이 절반 가까이 줄었으므로(game.gd 의 `_spawn_enemies`), 같은
## 배수로 곱해 층 전체의 무게를 비슷하게 맞춥니다. 줄이기만 하면 층이
## 텅 비고, 세게만 하면 처음부터 못 지나갑니다.
const FOE_POWER := 1.45


func setup(enemy_kind: String, floor_num: int, level: Dungeon, player: Node3D) -> void:
	kind = enemy_kind
	stats = KINDS.get(kind, KINDS["grunt"])
	dungeon = level
	target = player

	# 층당 강화. **수가 줄어든 만큼 한 마리가 세집니다.**
	#
	# 다섯 층이 끝이라(Game.FINAL_FLOOR) 예전 곡선으로는 마지막 층에서도
	# 1.9 배밖에 안 올랐습니다 - 깊이 갈수록 어려워지는 느낌이 나오지 않고,
	# 층마다 하나씩 찍는 스킬 쪽이 훨씬 빨리 세집니다.
	#
	# 한 마리가 세지면 **한 마리를 어떻게 처리할지**가 생깁니다. 여럿이면
	# 밀기 한 번에 무리가 정리되는 것이 늘 답이었습니다.
	var f := float(floor_num - 1)
	# **아프기는 한 곳에서 정합니다.** 종류마다 표의 값을 고치면 균형을 다시
	# 잡을 때마다 일곱 줄을 손대야 하고, 그러다 하나를 빼먹으면 그 적만
	# 예전 세기로 남습니다.
	max_hp = float(stats["hp"]) * FOE_POWER * (1.0 + f * 0.42)
	hp = max_hp
	damage = float(stats["damage"]) * FOE_POWER * DAMAGE_SCALE * (1.0 + f * 0.26)
	speed = float(stats["speed"]) * (1.0 + f * 0.03)
	gold = int(round(float(stats["gold"]) * (1.0 + f * 0.18)))

	collision_layer = 1 << 2
	# 벽/바닥(1) + 주인공(1<<1) + 소품(1<<4). 적끼리는 부딪히지 않습니다 -
	# 복도에서 서로 막혀 길이 잠깁니다. 그쪽은 _avoid_crowd 가 부드럽게
	# 벌려 놓습니다.
	collision_mask = 1 | (1 << 1) | (1 << 4)
	floor_snap_length = 0.4

	var body_scale := _body_scale(floor_num)
	_scale_now = body_scale
	var model_path: String = stats.get("model", Models.FOE_CHARGER)
	var body: Dictionary = Models.size_of(model_path)
	var radius: float = float(body["radius"]) * 0.8 * body_scale
	var height: float = float(body["height"]) * body_scale
	set_meta("body_radius", radius)
	Models.add_shadow(self, radius * 1.9)
	_capsule_height = height
	set_meta("body_height", height)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape.shape = capsule
	shape.position = Vector3(0, height * 0.5, 0)
	add_child(shape)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	var model := Models.spawn(model_path, body_scale)
	_pivot.add_child(model)
	# **색조를 덧씌우지 않습니다.**
	#
	# 예전에는 종류마다 다른 색을 몸에 곱했습니다(붉은 서진, 초록 블랙…).
	# 메시가 둘뿐이라 그것 말고 구분할 방법이 없었기 때문입니다. 지금은
	# 종류마다 제 모델이 있어서 그 이유가 사라졌고, 남은 것은 **원래 옷 색이
	# 아닌 아이**뿐입니다 - 그림을 공들여 만들어 놓고 그 위에 물감을 붓는
	# 셈이었습니다.
	#
	# 큰 아이(brute)는 여전히 서진과 같은 메시입니다. 그쪽은 크기(1.45배)와
	# 하는 일(소품을 들고 옵니다)로 구분됩니다.
	Models.add_jiggle(model)      # 치맛단과 머리카락이 따라 흔들립니다
	_pose = Models.add_pose(model)   # 잡혔을 때 몸을 굽히는 층
	_anim = Models.find_anim(model)
	_walk = Models.clip(_anim, "Walk")
	_walk_ground = float(WALK_GROUND.get(model_path, WALK_GROUND_FALLBACK))
	_idle = Models.clip(_anim, "Idle")
	if _anim != null and _idle != "":
		_anim.play(_idle)

	if float(stats.get("guard_arc", 0.0)) > 0.0:
		_build_pillow(height, radius)

	_build_bar(height + 0.35)
	add_to_group("enemies")


func _build_pillow(height: float, radius: float) -> void:
	## 앞을 막는 베개. **엔진 기본 도형**으로 만듭니다.
	##
	## 이 적의 규칙("앞이 막혀 있다")은 눈에 보여야 합니다. 색조만 다르면
	## 왜 안 아픈지 알 수 없고, 그러면 규칙이 아니라 버그로 읽힙니다.
	##
	## `_pivot` 에 붙입니다 - 몸이 도는 대로 같이 돌아야 막는 쪽과 보이는 쪽이
	## 어긋나지 않습니다. 판정은 `facing()` 을 쓰므로 둘이 같은 값에서 나옵니다.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.70, 0.46, 0.20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 1.0)
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_pillow = Node3D.new()
	_pillow.name = "Pillow"
	_pillow.add_child(mi)
	_pivot.add_child(_pillow)
	_pillow.position = _pillow_rest(height, radius)

	# **베개에도 몸이 있습니다.**
	#
	# 그림만 있을 때는 주인공이 베개를 그냥 통과했습니다. 앞이 막혀 있다는
	# 규칙을 눈으로는 보여 주면서 몸으로는 안 막으니, 밀고 들어가 등 뒤로
	# 빠져나가는 것이 정답이 돼 버립니다 - 돌아 들어가라고 만든 적인데
	# **뚫고 들어가는** 것이 더 빨랐습니다.
	#
	# 충돌체는 `_pivot` 이 아니라 **몸(자기 자신)** 에 답니다. 물리 형상은
	# 물리 몸체의 바로 아래 자식일 때만 세어지는데, 이 적은 자기 노드를
	# 돌리지 않고 몸통만 돌리므로(walk 보폭을 잴 때 걸렸던 그 사정) 여기
	# 달고 자리를 매 프레임 맞춰 줍니다(_drive_pillow).
	var box := BoxShape3D.new()
	box.size = Vector3(0.70, 0.46, 0.24)
	_pillow_shape = CollisionShape3D.new()
	_pillow_shape.name = "PillowShape"
	_pillow_shape.shape = box
	add_child(_pillow_shape)


func _pillow_rest(height: float, radius: float) -> Vector3:
	## 베개가 쉬는 자리. **머리 아래, 몸보다 한참 앞**입니다.
	##
	## 처음에는 가슴 높이(키의 0.60)에 몸 바로 앞(반지름+0.22)으로 뒀습니다.
	## 화면에서 베개가 **거의 안 보였습니다** - 이 아이는 머리가 커서, 내려다
	## 보는 63도 카메라에서 머리가 그 자리를 덮습니다.
	##
	## 뼈를 재서 다시 잡았습니다(--pose=guard 가 찍어 줍니다). 키 1.25 기준:
	##
	##     Head 1.015   Neck 0.951   Chest 0.714   Spine 0.465   Hips 0.299
	##
	## 머리뼈가 키의 81% 에 있고 머리통 반지름이 0.25 쯤이라 아래 끝이 0.765
	## 입니다. 베개 위 끝(자리 + 0.23)이 그보다 낮아야 안 가립니다 - 키의
	## 0.44(0.55)면 위 끝이 0.78 로 머리 바로 아래에 놓입니다.
	##
	## 앞으로도 더 내밉니다. 위에서 내려다보면 높이 차이보다 **앞뒤 거리**가
	## 가림을 결정합니다.
	return Vector3(0, height * 0.44, -(radius + 0.34))


func _body_scale(floor_num: int) -> float:
	## 층이 깊어질수록 커집니다. 다만 **1층에서는 주인공과 같은 크기**입니다.
	##
	## 종류별 크기 차이(돌진형 1.45배 등)를 처음부터 주면 1층부터 나보다 큰
	## 적을 만나게 됩니다. 그래서 종류 차이는 층이 깊어지며 서서히 드러나고,
	## 그 위에 완만한 성장이 얹힙니다.
	##
	## 선생님은 여기서 1.0 입니다 - 그쪽 크기는 모델 자체가 1.65m 라서 나오는
	## 것이고, 어른이라는 정체성이라 줄이지 않습니다.
	var f := float(floor_num - 1)
	var kind_scale := float(stats.get("scale", 1.0))
	# **1층에서의 크기.** 적지 않으면 1.0(주인공과 같게)입니다.
	#
	# 두 아기(고함·붙잡기)만 여기에 값을 답니다. 1.0 으로 두면 1층에서
	# **주인공보다 큽니다** - GIRL/BOY 모델이 1.25m 로 정규화된 뒤에도
	# 발~머리뼈가 0.954 라 주인공(0.924)을 넘습니다. 정규화는 머리 장식까지
	# 세는 겉보기 기준이라, 몸의 크기와 늘 같지는 않습니다.
	var base := float(stats.get("base_scale", 1.0))
	# 종류 차이는 6층에서 온전히 드러납니다.
	#
	# **층이 오른다고 커지지는 않습니다.** 예전에는 층당 3%씩(8층까지 최대
	# 24%) 키웠는데, 깊이 들어갈수록 같은 종류가 조금씩 부풀어 "이 아이가
	# 원래 이만한가" 를 알 수 없게 됐습니다. 어려워지는 것은 체력·피해·수가
	# 맡고, 크기는 **종류를 알아보는 표시**로만 씁니다.
	return lerpf(base, kind_scale, clampf(f / 5.0, 0.0, 1.0))


func _build_bar(y: float) -> void:
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, y, 0)
	add_child(_bar_root)

	var width := 0.9
	var back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(width + 0.06, 0.16)
	back.mesh = back_mesh
	back.material_override = _bar_material(Color(0.06, 0.05, 0.05, 0.85), 2)
	_bar_root.add_child(back)

	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(width, 0.11)
	fill_mesh.center_offset = Vector3(width * 0.5, 0, 0.01)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.mesh = fill_mesh
	# **뒷판보다 나중에 그립니다**(3 > 2). 아래 주석을 보세요.
	_bar_mat = _bar_material(Color(0.90, 0.30, 0.26, 0.95), 3)
	_bar_fill.material_override = _bar_mat
	_bar_fill.position = Vector3(-width * 0.5, 0, 0.01)
	_bar_root.add_child(_bar_fill)
	_bar_root.visible = false


func _bar_material(color: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# **빌보드가 `scale` 을 버립니다.**
	#
	# 빌보드는 모델 행렬의 회전을 카메라 것으로 바꿔치는데, `keep_scale` 이
	# 꺼져 있으면 그때 **크기까지 같이 지웁니다.** 그래서 체력이 줄어도
	# `_bar_fill.scale.x` 가 화면에 안 나타나고, 색만 바뀌었습니다 - 바가
	# 있는데 줄지 않으니 무엇을 보라는 표시인지 알 수 없습니다.
	mat.billboard_keep_scale = true
	mat.no_depth_test = true
	# **뒷판과 채움에 같은 값을 주면 안 됩니다.**
	#
	# `no_depth_test` 라 깊이가 순서를 안 정해 줍니다. 그러면 남는 기준은
	# 이 값뿐인데, 둘이 같으면 카메라가 도는 대로 순서가 뒤집혀서 **검은
	# 뒷판이 채움을 덮습니다** - 화면에는 색이 사라진 검은 토막이 떴다가
	# 다시 돌아오는 것으로 보입니다(박치기 아기에서 처음 봤습니다).
	#
	# 채움이 뒷판보다 커야 합니다(뒷판 2, 채움 3).
	mat.render_priority = priority
	return mat


# ---------------------------------------------------------------- 루프

func is_targetable() -> bool:
	## **겨눌 수 있는 상대인가.** 록온과 밀기가 같은 답을 봐야 "보고 있는데
	## 안 밀린다" 가 안 생깁니다.
	##
	## 밀려 날아가는 동안(`_knock`)과 던져져 날아가는 동안(`_thrown`)은
	## 못 겁니다. 그때도 겨눠지면 밀어 놓고 곧바로 다시 밀어 계속 띄워 둘 수
	## 있어서, 밀기가 "한 번 세게" 가 아니라 "붙잡아 두는 것" 이 됩니다.
	return not _dead and held_by == null and _knock <= 0.0 and _thrown <= 0.0


func is_liftable() -> bool:
	## 큰 적(돌진형·선생님)은 아이 힘으로 들리지 않습니다. 그쪽은 밀기만
	## 됩니다 - 관문이 들려서 던져지면 관문이 아닙니다.
	return not bool(stats.get("heavy", false)) and not _dead


func hold(by: Node3D) -> void:
	# 붙잡은 아이를 되잡을 수 있습니다. 그때는 매달린 쪽이 먼저 풀립니다.
	release_cling()
	_drop_carry()
	held_by = by
	_windup = -1.0
	velocity = Vector3.ZERO
	_bar_root.visible = true
	# 잡히는 순간 자리가 바뀌지 않습니다. 등을 잡아 끄는 것이지 들어
	# 올리는 것이 아닙니다 - 아이가 또래를 번쩍 드는 그림은 어색합니다.


func hold_at(point: Vector3, holder: Vector3, delta: float) -> void:
	## 잡힌 채 **잡은 사람의 두 손에 붙어** 끌려옵니다.
	##
	## 들어 올리지는 않습니다. 아이가 또래를 번쩍 드는 그림은 어색하고,
	## 무엇보다 잡는 순간 상대가 머리 위로 순간이동하면 잡았다는 느낌이 나지
	## 않습니다. 그래서 **높이는 그대로 두고** 수평 위치만 손으로 당깁니다.
	##
	## 처음에는 목줄처럼 느슨하게 두고 멀어질 때만 당겼는데, 그러면 손과 몹
	## 사이가 늘 벌어져 잡고 있는 것으로 안 보였습니다. 손이 곧 붙는 자리라
	## 지금은 매 프레임 그리로 당깁니다 - 다만 즉시가 아니라 따라붙게 해서
	## 잡는 순간이 순간이동으로 보이지 않게 합니다.
	var want := point
	want.y = global_position.y
	var next := global_position.lerp(want, 1.0 - exp(-18.0 * delta))
	# 높이는 **잡은 사람의 발 높이로 내립니다.**
	#
	# 잡힌 동안에는 이 함수가 위치를 통째로 정하므로 중력이 돌지 않습니다
	# (_physics_process 가 held_by 에서 먼저 빠져나갑니다). 그래서 공중에 뜬
	# 적을 잡으면 그 높이로 굳어, 수평으로만 손에 끌려오면서 **머리 위에 떠
	# 있는** 모양이 됐습니다 - 밀쳐서 뜬 적을 곧바로 잡으면 그렇게 됩니다.
	#
	# 수평보다 느리게(18 대 9) 내려옵니다. 같은 속도로 당기면 뚝 떨어지는
	# 것으로 보입니다.
	next.y = lerpf(global_position.y, holder.y, 1.0 - exp(-9.0 * delta))
	global_position = next
	# 등을 잡혔으니 잡은 쪽에 등을 보입니다. 방향은 _face 와 같은 규약으로
	# **pivot** 에 씁니다 - 몸통(self)을 돌리면 pivot 의 각도와 겹쳐 두 번
	# 돌아가고, 놓은 뒤에도 그 각도가 남습니다.
	var away: Vector3 = global_position - holder
	away.y = 0.0
	if away.length() > 0.05 and _pivot != null:
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y,
			atan2(-away.x, -away.z), 1.0 - exp(-12.0 * delta))
	_struggle(delta)


func _flinch() -> void:
	## 고함에 맞은 순간의 들썩임.
	##
	## 색만 번쩍이면 "무언가 닿았다" 까지만 전해집니다. 몸이 뒤로 젖혀지고
	## 한 번 들썩여야 **밀렸다**가 됩니다 - 그 1초가 잡으러 들어가라는
	## 신호이므로, 눈에 확실히 보여야 합니다.
	if _pose != null:
		_pose.pose = PoseOverride.HIT
		_pose.weight = 1.0
		_flinch_time = FLINCH_TIME
	if _pivot == null:
		return
	# 살짝 떠올랐다 내려앉습니다. 발이 바닥에서 떨어지는 순간이 있어야
	# 들썩인 것으로 읽힙니다.
	var tw := _pivot.create_tween()
	tw.tween_property(_pivot, "position:y", 0.18, 0.08) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pivot, "position:y", 0.0, 0.16) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _drive_flinch(delta: float) -> void:
	if _flinch_time <= 0.0:
		return
	_flinch_time = maxf(0.0, _flinch_time - delta)
	if _pose != null:
		# 젖혔다가 풀립니다. 끝에서 뚝 끊지 않고 스르르 돌아옵니다.
		_pose.weight = clampf(_flinch_time / FLINCH_TIME, 0.0, 1.0)


func _struggle(delta: float) -> void:
	## 발버둥. 몸을 활처럼 굽힌 채 좌우로 조금씩 흔듭니다.
	##
	## 굽히는 것과 흔드는 것을 같이 해야 합니다. 굽히기만 하면 굳은 인형이
	## 끌려오는 것이고, 흔들기만 하면 멀쩡히 선 채로 몸을 터는 것으로
	## 보입니다.
	var t := float(Time.get_ticks_msec()) * 0.001
	if _pivot != null:
		# 좌우로 조금씩. 크게 흔들면 잡은 손에서 빠져나온 것처럼 보입니다.
		_pivot.rotation.z = sin(t * 7.3) * 0.13
		_pivot.rotation.y = sin(t * 5.1) * 0.16
	if _pose == null:
		return
	# 팔은 좌우가 엇갈리게 휘젓습니다. 같이 움직이면 체조처럼 보입니다.
	#
	# Z 로 팔을 내려 접는 것을 빠뜨리면 안 됩니다. 자세 층은 클립의 팔을
	# **통째로 덮어쓰므로**, 걷기 클립에 구워 둔 팔 내림(-38도)이 사라져
	# 팔을 T 자로 벌린 채 허우적거립니다(실제로 그랬습니다).
	var flail := sin(t * 9.0) * 30.0
	var arms := PoseOverride.HELD.duplicate()
	arms["LeftArm"] = Vector3(24.0 + flail, 0, 52)
	arms["RightArm"] = Vector3(24.0 - flail, 0, -52)
	arms["LeftForeArm"] = Vector3(26.0 - flail * 0.5, 0, 0)
	arms["RightForeArm"] = Vector3(26.0 + flail * 0.5, 0, 0)
	_pose.pose = arms
	_pose.weight = minf(_pose.weight + delta * 5.0, 1.0)


func release_pose() -> void:
	## 놓이면 자세를 풉니다. 잊으면 던져진 뒤에도 몸이 굽은 채로 굳습니다.
	if _pose != null:
		_pose.weight = 0.0
	if _pivot != null:
		_pivot.rotation.z = 0.0
		_pivot.rotation.y = 0.0


## 던질 때 미는 힘이 밀기의 몇 배인가.
##
## 던지기는 **밀기의 큰 형**입니다. 잡아서 앞으로 보내는 것이라 하는 일이
## 같고, 값을 치른 만큼(잡는 동안 숨이 새고 발이 느려집니다) 더 멀리 갑니다.
## 던질 때 미는 힘이 밀기의 몇 배인가.
##
## 2.2 에서 **0.70** 으로 내렸습니다. 같은 속도로 밀어도 던져진 몸은 더
## 멀리 갑니다 - 밀린 적은 살아서 버티고 0.45초 뒤부터 세게 멈추지만,
## 던져진 몸은 0.7초 동안 느슨하게 미끄러지기 때문입니다. 그래서 배수를
## 1.0 이 아니라 0.70 으로 잡아야 둘이 나란해집니다(재서 골랐습니다). 밀기(3.6)와 나란히 놓고 보니 던지기가
## 여섯 배를 날아가서, 같은 손에서 나온 두 기술이 아니라 아예 다른 기술로
## 보였습니다. 지금은 둘이 비슷하게 밀리고, 던지기가 더 나은 점은 거리가
## 아니라 **잡고 있는 동안 방패가 된다는 것과 메다꽂기**입니다.
## 적이 아프게 하는 정도를 통째로 올리고 내리는 값.
##
## 1.5 로 올렸습니다. 그 전에는 다섯 층을 거의 안 맞고 내려갈 수 있어서,
## 막기·구르기·패링을 만들어 두고도 **쓸 이유가 없었습니다** - 규칙이 있는데
## 손이 안 쓰면 없는 것과 같습니다.
const DAMAGE_SCALE := 1.5

const THROW_PUSH := 1.11
## 던져져 밀리는 동안의 감속. 밀기(8)보다 조금 더 걸립니다.
const THROW_BRAKE := 9.0


func launch(direction: Vector3, speed: float, damage: float) -> void:
	## 던져집니다. **바닥으로 밀려납니다** - 뜨지 않습니다.
	##
	## # 포물선을 걷어냈습니다
	##
	## 예전에는 위로 6.9 로 띄워 던졌습니다. 던지는 그림으로는 그럴듯했지만
	## 두 가지가 나빴습니다. 아이가 아이를 **머리 위로 넘기는** 것이 되어
	## 이 게임의 다른 어떤 동작과도 안 맞았고, 뜬 동안에는 어디에 떨어질지
	## 예측이 안 돼서 "던졌더니 저기까지 날아갔다" 가 됐습니다.
	##
	## 지금은 밀기와 **같은 방식**입니다 - 바닥을 따라 미끄러지다 멈춥니다.
	## 다른 것은 세기뿐이고(2.2배), 그래서 두 기술이 한 줄기로 읽힙니다.
	release_cling()
	held_by = null
	release_pose()
	_thrown = 0.7
	_crash_used = false
	if _pivot != null:
		_pivot.rotation.z = 0.0
	var flat := direction
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 0.0001 else facing()
	# 미는 세기는 **한 군데서만** 옵니다(throw_knock). 던진 쪽이 자기 밀기
	# 세기를 넣어 주므로, 밀기 스킬이 여기에도 그대로 붙습니다.
	velocity = flat * (throw_knock * THROW_PUSH * speed)
	velocity.y = 0.0
	# 던지기도 **같은 빠르기 한도**를 씁니다. 밀기와 던지기가 한 줄기라고
	# 적어 놓고 빠르기만 따로 두면, 던진 것만 방 끝까지 날아갑니다.
	_cap_knock()
	_knock = 0.6
	# **던진 사람 쪽으로 몸을 돌립니다.** 밀기와 같은 규칙입니다(knock_back
	# 참고) - 던지기는 밀기의 큰 형이니 밀려나는 모양도 같아야 합니다.
	# 이걸 빼먹으면 던져진 적만 옆을 본 채 미끄러집니다.
	_knock_face = -flat
	take_damage(damage, false, Vector3.ZERO)


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target):
		return
	if held_by != null:
		# **붙잡혀 있으면 아무것도 안 합니다. 다만 예고는 지워야 합니다.**
		#
		# 여기서 그냥 돌아가면 바닥에 칠해 둔 예고가 그 자리에 그대로
		# 남습니다 - 잡아 놓고도 이미 없어진 공격의 위험 구역을 피해 다니게
		# 됩니다(아래 `_hide_warnings` 를 부르는 자리는 여기보다 뒤라 영영
		# 안 지나갑니다).
		_hide_warnings()
		return
	# **책을 읽는 동안에는 멈춥니다.**
	#
	# 읽는 1.6초 동안 주인공은 고함도 구르기도 못 합니다. 그 사이에 맞으면
	# 책장은 "읽으면 손해" 인 물건이 되고, 그러면 아무도 안 읽습니다.
	# 시간이 멈춘 것처럼 두는 편이 읽는 장면과도 어울립니다.
	if is_instance_valid(target) and target.has_method("is_reading") 			and target.is_reading():
		return
	# **고르기·상점 화면이 떠 있으면 멈춥니다.**
	#
	# 그 화면들은 `get_tree().paused` 로도 멈추는데, 화면이 뜨는 **그 프레임**
	# 에는 한 틈이 있습니다 - 책 읽기가 끝나는 순간(주인공의 물리 처리)에
	# 화면이 열리는데, 그보다 뒤에 처리되는 적은 "읽는 중" 도 아니고 아직
	# 멈추지도 않은 상태로 한 번 움직입니다. 실제로 **책을 읽고 고르기도 전에
	# 맞는** 일이 있었습니다.
	if Game.instance != null and (Game.instance.phase != Game.Phase.PLAYING
			or Game.instance.world_frozen):
		return
	# **밀림은 여기서 줄입니다. 어느 갈래로 가든 지나가는 자리입니다.**
	#
	# 예전에는 `_settle` 안에서만 줄였는데, `_settle` 은 깨어 있지 않거나
	# 휘청이는 동안에만 불립니다. 밀기는 밀림 0.45초와 휘청임 0.45초를 같이
	# 거는데 휘청임이 **한 프레임 먼저** 0 이 되므로, 그 프레임에 `_settle`
	# 이 건너뛰어지고 밀림이 0.28 쯤에서 **영영 멈춥니다.**
	#
	# 그러면 `_die` 가 "밀리는 중이니 멈춘 뒤에 쓰러지자" 로 계속 미룹니다 -
	# 체력이 -101 이 되도록 안 죽는 적이 그것이었습니다(실측). 고함으로만
	# 죽던 이유도 같습니다: 고함은 휘청임을 1초 걸어서, 그 1초 동안 `_settle`
	# 이 돌며 멈춘 밀림을 마저 빼 줍니다.
	_tick_knock(delta)
	# 등에 매달려 있는 동안은 스스로 걷지도 공격하지도 않습니다. 붙어 있는
	# 것이 곧 공격이라, 여기서 다른 일을 하면 두 가지가 겹칩니다.
	if _cling > 0.0:
		_drive_cling(delta)
		return
	_drive_flinch(delta)

	_cooldown = maxf(0.0, _cooldown - delta)
	_slip = maxf(0.0, _slip - delta)
	_stagger = maxf(0.0, _stagger - delta)
	_repath -= delta

	if _thrown > 0.0:
		# 날아가는 동안은 스스로 못 움직입니다. 지나가며 다른 적을 칩니다.
		#
		# **이 검사가 아래 접지 처리보다 먼저 와야 합니다.** 던져진 첫
		# 프레임에는 아직 바닥에 서 있는 상태라, 접지 처리가 위로 주는
		# 속도를 그대로 지웁니다. 그래서 한동안 적이 뜨지 않고 바닥을
		# 미끄러지기만 했습니다.
		_thrown -= delta
		# 바닥을 따라 미끄러집니다. 발이 땅에 안 닿아 있으면(계단·소품 위)
		# 그때만 중력을 씁니다.
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = minf(velocity.y, 0.0)
		var slide := Vector3(velocity.x, 0.0, velocity.z).move_toward(
			Vector3.ZERO, THROW_BRAKE * delta)
		velocity.x = slide.x
		velocity.z = slide.z
		# 속도는 **미끄러지기 전에** 적어 둡니다(_crash_pre 참고).
		var pre_throw := _crash_pre()
		move_and_slide()
		_hit_others_while_flying()
		_crash_check(pre_throw)
		# **멈추면 끝입니다.** 예전에는 바닥에 닿는 순간으로 봤는데, 이제는
		# 처음부터 바닥에 있으므로 그 조건이 없습니다.
		if _thrown <= 0.0 or slide.length() < 0.6:
			_thrown = 0.0
			_stagger = maxf(_stagger, 0.6)
			Fx.burst(get_parent(), global_position, Color(1.0, 0.8, 0.5), 8, 3.0)
			if _die_when_landed:
				_die_when_landed = false
				_die()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	if not _aggro:
		# 보이고 가까울 때만 깨어납니다. 층 전체가 한꺼번에 몰려오면
		# 방을 하나씩 정리하는 리듬이 사라집니다.
		if dist < float(stats["aggro"]) and dungeon.has_line_of_sight(global_position, target.global_position):
			wake()
		else:
			_settle(delta)
			move_and_slide()
			return

	# **몸을 돌리는 것은 쫓아갈 때뿐입니다.**
	#
	# 예고 중에는 공격 방향이 이미 고정돼 있고(예고 시작 시점의 방향으로
	# 나갑니다), 돌진 중에도 가는 방향이 정해져 있습니다. 그런데도 몸이
	# 계속 따라 돌면 두 가지가 나빠집니다 - 실제로는 저쪽으로 칠 건데 몸은
	# 이쪽을 보고 있으니 **거짓 정보**가 되고, 등 뒤가 영영 열리지 않아
	# 잡기가 성립하지 않습니다.
	#
	# 맞고 휘청일 때(stagger)도 마찬가지입니다. 맞은 직후에 상대를 정확히
	# 따라보는 것은 맞은 티가 나지 않습니다.
	if _windup >= 0.0:
		_tick_windup(delta, to_target, dist)
	elif _charge > 0.0:
		_charge -= delta
		# **큰 아이는 달리면서도 길을 고칩니다**(닿기 0.5초 전까지).
		# 고치는 동안에는 바닥의 띠도 같이 돌아야 그림이 거짓말을 안 합니다.
		if _track_charge_dir(delta):
			_aim_charge_lane()
		# 달리는 동안에도 같은 방향을 봅니다. 부딪히거나 벽에 밀려 몸이
		# 돌아가면, 가는 쪽과 보는 쪽이 다시 어긋납니다.
		_face(_charge_dir, delta, TURN_SPEED * 3.0)
		var rush: float = float(stats.get("charge_speed", 6.0))
		velocity.x = _charge_dir.x * rush
		velocity.z = _charge_dir.z * rush
	elif _stagger > 0.0:
		_settle(delta)
	else:
		_pursue(delta, to_target, dist)
		_face(to_target, delta)

	if _knock > 0.0 and _knock_face.length_squared() > 0.001:
		# 밀리는 0.45초 안에 다 돌도록 빠르게 돌립니다(180도에 0.17초).
		# 한 프레임에 홱 돌리면 순간이동으로 보입니다.
		_face(_knock_face, delta, TURN_SPEED * 14.0)
	_avoid_crowd(delta)
	var pre := _crash_pre()
	move_and_slide()
	if _charge > 0.0:
		_charge_contact(dist)
	_crash_check(pre)
	_push_what_we_hit()
	_drive_attack_pose(delta)
	# **붙잡혀 있는 동안에는 예고를 안 그립니다.**
	#
	# 잡힌 아이는 아무것도 못 합니다(`hold` 이 `_windup` 을 지웁니다). 그런데
	# 바닥에 칠해 둔 예고는 그 자리에 남아서, 이미 없어진 공격의 위험 구역이
	# 계속 떠 있었습니다 - 잡아 놓고도 그 자리를 피해 다니게 됩니다.
	#
	# **넷을 다 끕니다.** 부채꼴 둘(맨손·호통)만 끄고 띠와 원을 놓치면, 잡은
	# 아이가 박치기나 베개면 그 자리가 그대로 남습니다.
	if held_by != null:
		_hide_warnings()
	else:
		_drive_shout_fan(delta)
		_drive_melee_fan(delta)
		_drive_charge_lane(delta)
		_drive_slam_disc(delta)
	_drive_animation()


func _tick_knock(delta: float) -> void:
	## 밀려나는 시간을 줄이고, 다 밀렸으면 미뤄 둔 죽음을 치릅니다.
	if _knock > 0.0:
		_knock = maxf(0.0, _knock - delta)
	if not _die_when_landed:
		return
	_die_wait -= delta
	if (_knock <= 0.0 and _thrown <= 0.0) or _die_wait <= 0.0:
		_die_when_landed = false
		_die()


func _settle(delta: float) -> void:
	## 밀려나는 동안에는 **천천히 멈춥니다**(30 -> 8 m/s^2).
	##
	## 예전에는 어떤 경우든 30 으로 세웠습니다. 그 감속으로 눈에 보이는 거리를
	## 만들려면 처음 속도가 아주 커야 하는데(0.7m 를 가려면 6.5m/s - 주인공이
	## 달리는 속도의 두 배), 그래서 밀린 것이 아니라 **쏘아진 것**으로
	## 보였습니다. 감속을 낮추면 느린 속도로도 같은 거리가 나옵니다.
	# 밀림을 줄이는 것은 `_tick_knock` 이 맡습니다 - 여기서 줄이면 이 함수가
	# 안 불리는 갈래에서 시간이 멈춥니다.
	var brake := 8.0 if _knock > 0.0 else 30.0
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, brake * delta)
	velocity.x = flat.x
	velocity.z = flat.z


func _pursue(delta: float, to_target: Vector3, dist: float) -> void:
	var visible_now := dungeon.has_line_of_sight(global_position, target.global_position)
	var want := Vector3.ZERO

	if kind == "spitter":
		# 사거리 안쪽 끝까지만 붙고, 너무 가까우면 물러섭니다.
		if visible_now and dist < float(stats["range"]) * 0.55:
			want = -to_target.normalized()
		elif visible_now and dist <= float(stats["range"]):
			want = Vector3.ZERO
			if _cooldown <= 0.0:
				_begin_attack()
				return
		else:
			want = _follow_path(delta)
	elif stats.get("attack", "melee") == "toss":
		want = _pursue_toss(delta, to_target, dist, visible_now)
		if want == Vector3.INF:
			return
	elif stats.get("attack", "melee") == "cling":
		want = _pursue_cling(delta, to_target, dist, visible_now)
		if want == Vector3.INF:
			return
	elif stats.get("attack", "melee") == "charge":
		# 박치기는 **멀리서** 시작합니다. 보이고 사거리 안이면 겨눕니다.
		if visible_now and dist <= float(stats["range"]) and _cooldown <= 0.0:
			_begin_attack()
			return
		# 대기 중에도 물러나지 않고 계속 따라옵니다. 사거리가 6m 를 넘어서,
		# 다른 적처럼 물러나게 두면 방 반대편까지 밀려나 영영 안 붙습니다.
		want = _follow_path(delta)
	else:
		if visible_now and dist <= float(stats["range"]):
			if _cooldown <= 0.0:
				_begin_attack()
				return
			# 재사용 대기 중에는 조금 물러났다 다시 붙습니다(맞물림 방지).
			want = -to_target.normalized() * 0.5
		else:
			want = _follow_path(delta)

	var target_vel := want * speed
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target_vel, 26.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z


func _follow_path(delta: float) -> Vector3:
	if _repath <= 0.0:
		_repath = randf_range(0.30, 0.5)
		_path = dungeon.path_between(global_position, target.global_position)
		_path_i = 0
	while _path_i < _path.size():
		var wp := _path[_path_i]
		var d := Vector2(wp.x - global_position.x, wp.z - global_position.z)
		if d.length() < 0.7:
			_path_i += 1
			continue
		return Vector3(d.x, 0.0, d.y).normalized()
	# 길을 못 찾으면 직진이라도 합니다. 벽에 붙어 미끄러지며 돌아갑니다.
	var direct := target.global_position - global_position
	direct.y = 0.0
	return direct.normalized() if direct.length_squared() > 0.01 else Vector3.ZERO


func _avoid_crowd(delta: float) -> void:
	## 서로 겹쳐 서면 한 덩어리처럼 보이고 개별 조준이 불가능해집니다.
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as Node3D
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l > 0.01 and l < SEPARATION:
			push += d.normalized() * (1.0 - l / SEPARATION)
	if push.length_squared() > 0.0001:
		velocity.x += push.x * 9.0 * delta
		velocity.z += push.z * 9.0 * delta


func throw_size() -> float:
	## 던지기에서 쓰는 크기. 충돌 캡슐의 높이입니다 - 아이는 1.25m 언저리,
	## 선생님은 1.65m 이고, 층이 올라 몸집이 커지면 그대로 반영됩니다.
	return maxf(_capsule_height, 0.3)


func throw_distance() -> float:
	## 소품과 **같은 곡선**을 씁니다. 1층 아이(1.25m)가 곡선의 기준점이라
	## 정확히 2.5m, 즉 제 키의 두 배를 날아갑니다.
	return minf(Prop.THROW_REF_DIST
		* pow(Prop.THROW_REF_SIZE / throw_size(), Prop.THROW_SIZE_POWER),
		Prop.THROW_MAX_DIST)


func look_away_from(point: Vector3) -> void:
	## 그 자리에 등을 보이게 세웁니다. 잡기가 등 뒤에서만 되므로, 확인용
	## 배치(--pose=drag)에서 그 상황을 만들 때 씁니다.
	var away: Vector3 = global_position - point
	away.y = 0.0
	if away.length() > 0.05 and _pivot != null:
		_pivot.rotation.y = atan2(-away.x, -away.z)


func facing() -> Vector3:
	## 지금 보고 있는 방향(수평). 잡기가 등 뒤에서만 되도록 판정할 때 씁니다.
	if _pivot == null:
		return -global_transform.basis.z
	var f: Vector3 = -_pivot.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


func _face(to_target: Vector3, delta: float, turn: float = -1.0) -> void:
	if _pivot == null or to_target.length_squared() < 0.01:
		return
	var want := atan2(-to_target.x, -to_target.z)
	var diff := wrapf(want - _pivot.rotation.y, -PI, PI)
	var step := (TURN_SPEED if turn <= 0.0 else turn) * delta
	_pivot.rotation.y += clampf(diff, -step, step)


func _drive_animation() -> void:
	if _anim == null or stride_probe:
		return
	# 실제로 움직인 속도. velocity 는 벽에 밀고 있을 때도 남아 있어서,
	# 그걸로 돌리면 벽 앞에서 제자리 질주가 됩니다(player.gd 와 같은 이유).
	var s := Vector3(get_real_velocity().x, 0.0, get_real_velocity().z).length()
	if s > 0.35:
		if _anim.current_animation != _walk and _walk != "":
			_anim.play(_walk, 0.15)
		# 재생 속도를 **실제 이동 속도에 맞춥니다.** 발이 바닥을 미는 속도와
		# 몸이 나아가는 속도가 같아야 미끄러지지 않습니다. 몸집이 커지면
		# (층이 오를수록) 보폭도 같이 커지므로 그만큼 나눠 줍니다.
		# 위쪽 한계는 안전장치입니다. 여기에 걸리면 그만큼 미끄러집니다.
		#
		# 이 값들을 한 번 크게 틀렸습니다. 보폭을 **적의 루트 기준**으로 쟀는데
		# 적은 자기 노드를 돌리지 않고 몸통(_pivot)만 돌립니다 - 옆으로 걸어갈
		# 때 앞뒤 성분이 사라져 보폭이 5배 작게 나왔고, 그만큼 다리가 빨리
		# 돌아 미끄러졌습니다(실측 발/몸 = 2.1~4.3). 몸통 기준으로 다시 재서
		# 배속이 7 -> 1.5 로 내려왔습니다.
		var rate := clampf(s / (_walk_ground * maxf(_scale_now, 0.2)), 0.35, 7.0)
		# 물러날 때는 거꾸로 돌립니다. 원거리 적은 가까워지면 뒤로 빠지고
		# 근접 적도 재사용 대기 중에 물러나므로, 그대로 두면 이쪽을 본 채
		# 앞으로 걷는 다리로 뒤로 미끄러집니다(player.gd 와 같은 이유).
		var along := Vector3(velocity.x, 0.0, velocity.z).normalized().dot(facing())
		if along < -0.25:
			_moving_back = true
		elif along > 0.25:
			_moving_back = false
		_anim.speed_scale = -rate if _moving_back else rate
	else:
		if _anim.current_animation != _idle and _idle != "":
			_anim.play(_idle, 0.2)
		_anim.speed_scale = 1.0


# ---------------------------------------------------------------- 공격

func wake() -> void:
	if _aggro:
		return
	_aggro = true
	_bar_root.visible = true
	Fx.popup_text(get_parent(), global_position + Vector3(0, 1.6, 0), "!",
		Color(1.0, 0.5, 0.4))


func _begin_attack() -> void:
	_windup = float(stats["windup"])
	# 예고에 소리를 답니다. 화면 밖에서 시작한 돌진도 귀로 먼저 옵니다.
	Sfx.play(Sfx.WARN, -12.0, 0.10)
	velocity.x = 0.0
	velocity.z = 0.0
	# 예고. 공격 전에 반드시 보이는 신호가 있어야 피할 수 있습니다.
	#
	# 몸을 번쩍이는 것은 "시작했다"만 알리고 짧게 끝냅니다. 예고 내내 켜 두면
	# 캐릭터가 흰 덩어리가 되어 무엇이 오는지 오히려 안 보입니다. 남은 시간은
	# 바닥에서 퍼지는 고리가 알려 줍니다 - 다 퍼지면 맞습니다.
	Fx.flash(_pivot, Color(1.0, 0.85, 0.4), 0.20, 0.5)

	var mode: String = stats.get("attack", "melee")
	if mode == "shout":
		# 호통은 **방향이 있는** 공격이라, 둥근 고리로는 어디로 피해야 할지
		# 알 수 없습니다. 시작 방향을 고정해 두고 그쪽으로 고리를 늘어놓아
		# 위험 구역을 그립니다. 고정하는 것이 핵심입니다 - 예고 내내 방향이
		# 따라오면 옆으로 굴러도 소용이 없습니다.
		var to: Vector3 = (target.global_position - global_position) if is_instance_valid(target) else -_pivot.global_transform.basis.z
		to.y = 0.0
		if to.length_squared() > 0.001:
			_shout_dir = to.normalized()
		_show_shout_fan()
		return

	if mode == "cling":
		# 붙잡기는 예고가 짧습니다(0.32초). **오는 길이 예고**입니다 - 등
		# 뒤로 빙 돌아 들어오는 동안 내내 보입니다.
		#
		# 발밑 고리를 뺐습니다. 예고는 **닿는 자리를 칠하는 것**인데, 발밑
		# 고리는 닿는 자리가 아니라 "얘가 뭘 한다" 만 말합니다 - 그건 몸이
		# 이미 하고 있습니다. 게다가 빈 고리는 가운데가 안전해 보입니다.
		return

	if mode == "slam":
		# 내리칠 **자리를 칠합니다.** 베개가 내려앉을 바닥이 그대로 원입니다.
		#
		# 고리(테두리)였습니다. 테두리는 "이 선 위가 위험" 처럼 읽혀서 가운데가
		# 안전해 보이는데, 내려치기는 **가운데가 가장 위험합니다.** 칠하면 그
		# 오해가 없습니다(박치기의 띠·고함의 부채꼴과 같은 규칙).
		#
		# 방향은 여기서 고정되므로, 예고를 보고 옆으로 굴러 나가면 빗나갑니다.
		var to3: Vector3 = (target.global_position - global_position) if is_instance_valid(target) else -_pivot.global_transform.basis.z
		to3.y = 0.0
		if to3.length_squared() > 0.001:
			_slam_dir = to3.normalized()
		_show_slam_disc()
		return

	if mode == "toss":
		# 던지는 것은 **날아오는 물건 자체가 예고**입니다. 발밑 고리는
		# 닿는 자리가 아니라서 뺐습니다(위 붙잡기와 같은 이유) - 몸이 팔을
		# 드는 것과 번쩍임으로 충분합니다.
		return

	if mode == "charge":
		# 달려올 **길**을 두꺼운 선 하나로 칠합니다.
		#
		# 예전에는 고리 넷을 앞으로 늘어놓았습니다. "이 선 위에 서 있지 말라"
		# 는 뜻은 맞았지만 **넷이 각자 커졌다 사라져서 화면이 어수선했고**,
		# 고리 사이의 빈 곳이 안전해 보였습니다 - 실제로는 그 사이도 전부
		# 지나갑니다. 칠한 띠 하나면 그 오해가 없습니다.
		#
		# 방향은 여기서 고정되고, 예고 중에는 몸도 돌지 않습니다
		# (_physics_process 의 회전 규칙). 따라오면 비켜도 소용이 없습니다.
		var to2: Vector3 = (target.global_position - global_position) if is_instance_valid(target) else -_pivot.global_transform.basis.z
		to2.y = 0.0
		if to2.length_squared() > 0.001:
			_charge_dir = to2.normalized()
		_show_charge_lane()
		return

	if mode == "spit":
		# 뱉는 것도 날아오는 것이 곧 예고입니다. 발밑 고리는 뺐습니다.
		return

	# ── 맨손 공격. **방향을 고정하고 그 부채꼴을 칠합니다.** ──────────
	#
	# 예전에는 예고가 끝나는 순간 **거리만** 봤습니다. 그래서 옆으로 굴러
	# 나가도 가까이만 있으면 맞았고, 굴러 피한다는 것이 사실은 "멀리 도망친다"
	# 뿐이었습니다 - 아슬아슬하게 스치는 맛이 나올 자리가 없었습니다.
	#
	# 방향을 예고 시작에 굳히고, 끝날 때 **그 부채꼴 안에 있는지**를 봅니다.
	# 옆으로 반 발만 굴러 나가도 빗나갑니다. 예고 내내 따라오면 그 선택이
	# 아무 의미가 없으므로, 고정하는 것이 핵심입니다(호통·돌진과 같은 규칙).
	var to4: Vector3 = (target.global_position - global_position) if is_instance_valid(target) else -_pivot.global_transform.basis.z
	to4.y = 0.0
	if to4.length_squared() > 0.001:
		_melee_dir = to4.normalized()
	_show_melee_fan()


func _tick_windup(delta: float, to_target: Vector3, dist: float) -> void:
	if stats.get("attack", "melee") == "cling":
		# 붙잡기 예고 중에는 **계속 따라붙습니다.**
		#
		# 다른 공격은 예고 동안 멈춰 서는 것이 규칙입니다(멈춰야 예고가
		# 읽힙니다). 붙잡기만 예외인 이유는 손이 닿아야 성립하기 때문입니다 -
		# 0.32초를 서 있으면 주인공은 그 사이 1m 를 달아나고, 사거리 1.4m 로
		# 시작한 손이 끝날 때는 2.4m 밖에 있습니다. 실제로 그래서 봇 소크에서
		# **한 번도 안 잡혔습니다**(대기만 돌고 붙잡힘은 0건).
		#
		# 예고가 안 보이는 것은 아닙니다. 이 적의 예고는 멈춰 선 몸이 아니라
		# **달려오는 몸**입니다(_pursue_cling 참고).
		var flat := to_target
		flat.y = 0.0
		if flat.length() > float(stats["range"]) * 0.5 and flat.length_squared() > 0.0001:
			var v := flat.normalized() * speed * 1.5
			velocity.x = v.x
			velocity.z = v.z
		else:
			_settle(delta)
		_face(to_target, delta, TURN_SPEED * 2.0)
	else:
		_settle(delta)
	if stats.get("attack", "melee") == "charge":
		# **고정한 방향으로 몸을 맞춥니다.**
		#
		# 예고 중에 안 도는 규칙은 "쫓아가느라 계속 따라 도는 것" 을 막으려는
		# 것이지, 이미 정해진 쪽을 보지 말라는 뜻이 아닙니다. 방향을 고정한
		# 순간의 몸 각도는 조금 전 상대를 쫓던 각도라 어긋나 있어서, 옆을 본
		# 채로 앞으로 달려가는 일이 생겼습니다.
		#
		# 예고(0.62초) 안에 다 돌도록 평소보다 빠르게 돌립니다. 이건 거짓말이
		# 아닙니다 - 돌아가는 쪽이 곧 달려올 쪽입니다.
		#
		# **큰 아이는 예고 중에도 길을 고칩니다**(`charge_track`). 예고에서만
		# 굳히고 달릴 때 따라오면, 그려 놓은 띠가 곧바로 거짓말이 됩니다 -
		# 고치는 동안에는 띠도 같이 돌아야 합니다.
		if _track_charge_dir(delta):
			_show_charge_lane()
		_face(_charge_dir, delta, TURN_SPEED * 2.2)
	_windup -= delta
	if _windup > 0.0:
		return
	_windup = -1.0
	_cooldown = float(stats["cooldown"])
	var mode: String = stats.get("attack", "melee")
	if mode == "spit":
		_spit(to_target)
	elif mode == "toss":
		_toss(to_target)
	elif mode == "charge":
		# 방향은 예고 때 고정한 그대로입니다. 여기서 다시 겨누면 예고가
		# 거짓말이 됩니다.
		_lane_flash = FAN_FLASH
		_begin_charge(_charge_dir)
	elif mode == "shout":
		_shout(to_target, dist)
	elif mode == "cling":
		_cling_grab(dist)
	elif mode == "slam":
		_slam_hit()
	else:
		# **예고한 부채꼴 안에 있어야 맞습니다.**
		#
		# 거리만 보던 것을 방향까지 보게 바꿨습니다. 예전에는 옆으로 굴러
		# 나가도 가까이만 있으면 맞아서, 구르기가 "아슬아슬하게 피하는 것" 이
		# 아니라 "멀리 도망치는 것" 뿐이었습니다. 이제 반 발만 옆으로 빠져도
		# 빗나갑니다 - 칠해 둔 부채꼴이 그대로 답입니다.
		_melee_flash = FAN_FLASH
		if _melee_in_fan(dist):
			_strike()
		Fx.burst(get_parent(), global_position + to_target.normalized() * 1.2
			+ Vector3(0, 0.7, 0), Color(1.0, 0.6, 0.35), 8, 3.0)


func _shout(to_target: Vector3, dist: float) -> void:
	## 호통. 고정된 방향으로 넓은 부채꼴을 때립니다.
	##
	## 주인공의 공격도 소리 지르기입니다. 선생님은 같은 것을 **더 크게** 합니다 -
	## 사거리가 두 배가 넘고(6.5m) 각도도 넓지만(78도), 그만큼 예고가 깁니다.
	## 뒤로 물러나기보다 **옆으로 빠지는** 것이 정답이 되도록 만든 값입니다.
	var half := deg_to_rad(float(stats.get("arc", 78.0))) * 0.5
	var reach: float = float(stats["range"]) + 0.5
	if is_instance_valid(target) and dist <= reach:
		var to := to_target
		to.y = 0.0
		if to.length_squared() > 0.001 and to.normalized().dot(_shout_dir) >= cos(half):
			# 고함치는 아기는 아프기보다 **밀어냅니다**(knock 9). 선생님은
			# 값을 안 주므로 기본값(5)으로 하던 대로 갑니다.
			target.call("take_damage", damage, global_position,
				float(stats.get("knock", 5.0)))

	# 맞는 순간 **같은 판이 빨갛게** 번쩍입니다. 예고가 노랗다가 붉어지고,
	# 때리는 순간 새빨개졌다 사라지는 한 줄기입니다 - 같은 그림이 색만
	# 바뀌므로 "저 색이 저기까지" 를 한 번 배우면 계속 씁니다.
	_fan_flash = FAN_FLASH
	Fx.burst(get_parent(), global_position + _shout_dir * 1.0 + Vector3(0, 1.2, 0),
		Color(1.0, 0.8, 0.4), 12, 4.0)
	Game.shake(0.30, 0.20)


## 때린 뒤 빨간 판이 남는 시간.
const FAN_FLASH := 0.26

## 공격 예고의 색. **넷이 여기 하나를 봅니다** — 부채꼴(맨손)·부채꼴(호통)·
## 띠(돌진)·원(내려치기).
##
## 색이 갈리면 **같은 뜻인데 다른 것으로 읽힙니다.** 베개 아이의 원만 파랬던
## 적이 있는데, 다른 예고가 전부 노랑→빨강으로 차오르는 판에서 그 하나만
## 파랗게 뜨니 "이건 공격이 아닌가" 로 보였습니다. 예고는 **어느 적이 하든
## 같은 신호**여야 합니다.
##
## 규약: 옅은 노랑에서 시작해 예고가 도는 동안 붉어지고 진해집니다 — 다
## 차오르면 맞습니다. 때리는 순간 새빨개졌다 사라집니다.
const WARN_EARLY := Color(1.0, 0.84, 0.38, 0.13)   ## 예고가 시작될 때
const WARN_LATE := Color(1.0, 0.32, 0.19, 0.43)    ## 예고가 다 찼을 때
const WARN_HIT := Color(1.0, 0.14, 0.10, 0.58)     ## 때리는 순간
## 따라오는 돌진은 달리는 내내 길을 보여 줍니다. 그동안은 「다 찬 예고」와
## 「때리는 순간」 사이에 둡니다 - 이미 오고 있다는 뜻입니다.
const WARN_TRACK := Color(1.0, 0.22, 0.14, 0.52)


## 맨손 공격이 닿는 각도. 호통(78도)보다 좁습니다 - 팔로 치는 것이라
## 넓으면 옆으로 굴러 나가도 안 빠집니다.
const MELEE_ARC := 96.0


func charge_width() -> float:
	## 돌진이 **실제로 맞는 폭**(m).
	##
	## `_charge_contact` 가 쓰는 거리와 같은 값에서 뽑습니다 - 내 반지름 +
	## 주인공 반지름 + 손끝 여유의 두 배입니다. 그림에 폭을 따로 적어 두면
	## 몸이 커졌을 때 선만 옛 굵기로 남습니다.
	var mine: float = float(get_meta("body_radius", 0.35))
	var theirs := 0.30
	if is_instance_valid(target):
		theirs = float(target.get("_body_radius"))
	return (mine + theirs + 0.12) * 2.0


func _track_charge_dir(delta: float) -> bool:
	## **닿기 `charge_track` 초 전까지 길을 고칩니다.** 고쳤으면 true.
	##
	## 서진(`charge_track` 없음)은 여기서 곧바로 false 라 예고에서 굳힌 방향
	## 그대로 달립니다. 큰 아이만 따라옵니다.
	##
	## 왜 "남은 시간" 으로 끊는가: 거리로 끊으면 빠른 돌진일수록 굳는 순간이
	## 이르게 와서, 같은 0.5초를 주려면 적마다 거리를 따로 적어야 합니다.
	## 남은 시간으로 적으면 속도를 고쳐도 **피할 틈은 그대로**입니다.
	var lead: float = float(stats.get("charge_track", 0.0))
	if lead <= 0.0 or not is_instance_valid(target):
		return false
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	# **다가가는 속도로 남은 시간을 셉니다.** 돌진 속도만 쓰면 주인공이
	# 마주 달려올 때 실제로 닿는 시간이 더 짧아, 굳는 순간이 늦어집니다.
	var rush: float = float(stats.get("charge_speed", 6.0))
	if to.length() / maxf(rush, 0.01) <= lead:
		return false
	# 즉시 꺾지 않고 **돌리는 빠르기로** 따라갑니다. 순간이동하듯 꺾이면
	# 피하는 일이 불가능해지고, 그림(길 띠)도 한 프레임에 홱 돌아갑니다.
	var turn := deg_to_rad(float(stats.get("charge_turn", 150.0))) * delta
	if _charge_dir.length_squared() < 0.0001:
		_charge_dir = to.normalized()
		return true
	var want := to.normalized()
	var ang := _charge_dir.signed_angle_to(want, Vector3.UP)
	_charge_dir = _charge_dir.rotated(Vector3.UP, clampf(ang, -turn, turn)).normalized()
	return true


func _aim_charge_lane() -> void:
	## 길 띠의 **방향만** 고칩니다.
	##
	## `_show_charge_lane` 을 다시 부르지 않는 이유: 그쪽은 번쩍임
	## (`_lane_flash`)을 0 으로 되돌립니다. 달리는 중에 부르면 달리기 시작할
	## 때의 새빨간 한 줄기가 첫 프레임에 지워집니다.
	if _lane == null:
		return
	_lane.rotation.y = atan2(-_charge_dir.x, -_charge_dir.z)


func _exit_tree() -> void:
	## 예고 원반은 세계에 달아 두었으므로 **직접 치웁니다.** 적과 함께
	## 사라지지 않으면 층을 넘길 때마다 한 장씩 쌓입니다.
	if is_instance_valid(_disc):
		_disc.queue_free()
		_disc = null


func _slam_center(reach: float) -> Vector3:
	## 베개가 내려앉는 자리. 예고와 판정이 **같은 함수**를 봅니다 - 둘을
	## 따로 적으면 반드시 어긋납니다(돌진에서 2.85m 를 그리고 4.9m 를 달린
	## 적이 있습니다).
	return global_position + _slam_dir * (reach * 0.55)


func _slam_radius(reach: float) -> float:
	return reach * 0.5


func _hide_warnings() -> void:
	## 바닥에 칠해 둔 예고 넷을 한꺼번에 끕니다. 붙잡혔을 때와 끊겼을 때가
	## 같은 자리를 봅니다 - 하나라도 빠지면 없는 공격의 예고가 남습니다.
	if _lane != null:
		_lane.visible = false
	_lane_flash = 0.0
	if _disc != null:
		_disc.visible = false
	if _melee_fan != null:
		_melee_fan.visible = false
	_melee_flash = 0.0
	if _shout_fan != null:
		_shout_fan.visible = false
	_fan_flash = 0.0


func _show_slam_disc() -> void:
	## 내리칠 자리를 **채워진 원**으로 칠합니다. 예고 동안 커집니다.
	if _disc == null:
		_disc_mat = Fx.fan_material()
		_disc = MeshInstance3D.new()
		_disc.name = "SlamDisc"
		_disc.material_override = _disc_mat
		_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disc.set_meta("flat", true)
		# **적 노드가 아니라 세계에 답니다.** 원이 놓이는 자리는 적의 발밑이
		# 아니라 베개가 내려앉을 앞쪽이고, 예고 중에 적이 조금 움직여도
		# 그 자리는 굳어 있어야 합니다.
		get_parent().add_child(_disc)
	var reach: float = float(stats["range"]) + 0.4
	# 360 도 부채꼴이 곧 원입니다. 새 규약을 만들 이유가 없습니다.
	_disc.mesh = Fx.fan_mesh(_slam_radius(reach), 360.0, 28)
	_disc.global_position = _slam_center(reach) + Vector3(0, 0.045, 0)
	_disc.scale = Vector3(0.25, 1.0, 0.25)
	_disc.visible = true


func _drive_slam_disc(delta: float) -> void:
	## 예고가 도는 동안 **원이 자랍니다.** 베개를 드는 동작과 같은 시간을
	## 쓰므로, 다 자라면 맞습니다 - 남은 시간을 눈으로 셀 수 있습니다.
	if _disc == null or _disc_mat == null:
		return
	var slam: bool = stats.get("attack", "melee") == "slam"
	if _windup >= 0.0 and slam and not _dead:
		var total := maxf(float(stats["windup"]), 0.001)
		var k := clampf(1.0 - _windup / total, 0.0, 1.0)
		var g := lerpf(0.25, 1.0, k)
		_disc.scale = Vector3(g, 1.0, g)
		_disc_mat.albedo_color = WARN_EARLY.lerp(WARN_LATE, k)
		_disc.visible = true
		return
	# 예고가 끝나면 한 박자에 사라집니다. 남겨 두면 이미 맞은 자리가 아직
	# 위험한 것으로 보입니다.
	if _disc.visible:
		var a := _disc_mat.albedo_color
		a.a = maxf(0.0, a.a - delta * 3.4)
		_disc_mat.albedo_color = a
		if a.a <= 0.001:
			_disc.visible = false


func _show_charge_lane() -> void:
	## 돌진이 지나갈 길을 바닥에 칠합니다. **길이와 폭이 판정 그대로**입니다.
	if _lane == null:
		_lane_mat = Fx.fan_material()
		_lane = MeshInstance3D.new()
		_lane.name = "ChargeLane"
		_lane.material_override = _lane_mat
		_lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lane.set_meta("flat", true)
		_lane.position = Vector3(0, 0.04, 0)
		# `_pivot` 이 아니라 적 노드에 답니다 - 몸통은 도는데 예고 방향은
		# 굳어 있어야 합니다(호통·맨손 부채꼴과 같은 사정).
		add_child(_lane)
	_lane.mesh = Fx.lane_mesh(float(stats["charge_dist"]), charge_width())
	_lane.rotation.y = atan2(-_charge_dir.x, -_charge_dir.z)
	_lane.visible = true
	_lane_flash = 0.0


func _drive_charge_lane(delta: float) -> void:
	## 예고 동안 붉어지고, 달리기 시작하는 순간 새빨개졌다 사라집니다.
	if _lane == null or _lane_mat == null:
		return
	if _lane_flash > 0.0:
		_lane_flash -= delta
	# **쫓아오는 돌진은 달리는 내내 길을 보여 줍니다.**
	#
	# 굳어 있는 돌진(서진)은 달리기 시작하는 순간 한 번 새빨개졌다 사라지면
	# 됩니다 - 그 뒤로는 길이 안 바뀌니 몸이 곧 예고입니다. 큰 아이는 달리는
	# 동안 길이 계속 돌아가므로, 띠를 끄면 **어디로 오는지 볼 방법이 사라집니다.**
	if _charge > 0.0 and float(stats.get("charge_track", 0.0)) > 0.0 and not _dead:
		_lane_mat.albedo_color = WARN_TRACK
		_lane.visible = true
		return
	if _lane_flash > 0.0:
		var k := clampf(_lane_flash / FAN_FLASH, 0.0, 1.0)
		_lane_mat.albedo_color = Color(WARN_HIT.r, WARN_HIT.g, WARN_HIT.b, WARN_HIT.a * k)
		_lane.visible = true
		return
	if _windup >= 0.0 and stats.get("attack", "melee") == "charge" and not _dead:
		var total := maxf(float(stats["windup"]), 0.001)
		var t := clampf(1.0 - _windup / total, 0.0, 1.0)
		_lane_mat.albedo_color = WARN_EARLY.lerp(WARN_LATE, t)
		_lane.visible = true
		return
	_lane.visible = false


func _show_melee_fan() -> void:
	## 맨손 공격의 판정 범위를 바닥에 칠합니다. **판정과 같은 값**입니다 -
	## `_melee_hits` 가 이 사거리와 각도를 그대로 다시 씁니다.
	if _melee_fan == null:
		_melee_fan_mat = Fx.fan_material()
		_melee_fan = MeshInstance3D.new()
		_melee_fan.name = "MeleeFan"
		_melee_fan.mesh = Fx.fan_mesh(float(stats["range"]) + 0.4, MELEE_ARC)
		_melee_fan.material_override = _melee_fan_mat
		_melee_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_melee_fan.set_meta("flat", true)
		_melee_fan.position = Vector3(0, 0.04, 0)
		# `_pivot` 이 아니라 적 노드에 답니다 - 몸통은 계속 도는데 예고
		# 방향은 굳어 있어야 합니다(호통 부채꼴과 같은 사정).
		add_child(_melee_fan)
	_melee_fan.rotation.y = atan2(-_melee_dir.x, -_melee_dir.z)
	_melee_fan.visible = true
	_melee_flash = 0.0


func _drive_melee_fan(delta: float) -> void:
	## 호통 부채꼴과 같은 규칙입니다 - 예고 동안 붉어지고, 때리는 순간
	## 새빨개졌다 사라집니다.
	if _melee_fan == null or _melee_fan_mat == null:
		return
	if _melee_flash > 0.0:
		_melee_flash -= delta
		var k := clampf(_melee_flash / FAN_FLASH, 0.0, 1.0)
		_melee_fan_mat.albedo_color = Color(WARN_HIT.r, WARN_HIT.g, WARN_HIT.b, WARN_HIT.a * k)
		_melee_fan.visible = _melee_flash > 0.0
		return
	if _windup >= 0.0 and stats.get("attack", "melee") == "melee" and not _dead:
		var total := maxf(float(stats["windup"]), 0.001)
		var t := clampf(1.0 - _windup / total, 0.0, 1.0)
		_melee_fan_mat.albedo_color = WARN_EARLY.lerp(WARN_LATE, t)
		_melee_fan.visible = true
		return
	_melee_fan.visible = false


func _show_shout_fan() -> void:
	## 호통의 판정 범위를 바닥에 칠합니다. **판정과 같은 값**으로 만듭니다 -
	## 사거리와 각도를 그대로 쓰므로, 수치를 바꾸면 그림도 같이 바뀝니다.
	##
	## `_pivot` 이 아니라 적 노드에 답니다. 적은 자기 노드를 돌리지 않고
	## 몸통만 돌리므로(walk 보폭을 잴 때 한 번 걸렸던 것과 같은 사정),
	## 여기에 달아야 예고 방향을 고정한 채로 몸만 따로 돌 수 있습니다.
	if _shout_fan == null:
		var reach: float = float(stats["range"]) + 0.5
		_shout_fan_mat = Fx.fan_material()
		_shout_fan = MeshInstance3D.new()
		_shout_fan.name = "ShoutFan"
		_shout_fan.mesh = Fx.fan_mesh(reach, float(stats.get("arc", 78.0)))
		_shout_fan.material_override = _shout_fan_mat
		_shout_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 카툰 외곽선이 바닥 판을 검은 테두리로 두르면 판이 아니라 구멍이
		# 됩니다.
		_shout_fan.set_meta("flat", true)
		# 바닥보다 조금 띄웁니다. 딱 붙이면 바닥과 다투어 지지직거립니다.
		_shout_fan.position = Vector3(0, 0.04, 0)
		add_child(_shout_fan)
	_shout_fan.rotation.y = atan2(-_shout_dir.x, -_shout_dir.z)
	_shout_fan.visible = true
	_fan_flash = 0.0


func _drive_shout_fan(delta: float) -> void:
	## 예고 동안 **점점 붉어지고**, 때리는 순간 새빨개졌다 사라집니다.
	if _shout_fan == null or _shout_fan_mat == null:
		return
	if _fan_flash > 0.0:
		_fan_flash -= delta
		var k := clampf(_fan_flash / FAN_FLASH, 0.0, 1.0)
		_shout_fan_mat.albedo_color = Color(WARN_HIT.r, WARN_HIT.g, WARN_HIT.b, WARN_HIT.a * k)
		_shout_fan.visible = _fan_flash > 0.0
		return
	if _windup >= 0.0 and stats.get("attack", "melee") == "shout" and not _dead:
		var total := maxf(float(stats["windup"]), 0.001)
		var t := clampf(1.0 - _windup / total, 0.0, 1.0)
		_shout_fan_mat.albedo_color = WARN_EARLY.lerp(WARN_LATE, t)
		_shout_fan.visible = true
		return
	# 예고가 끊겼습니다(맞아서 풀렸거나 죽었거나). 그 자리에서 사라집니다.
	_shout_fan.visible = false


func _target_facing() -> Vector3:
	## 주인공이 보고 있는 쪽(수평).
	##
	## 조준(aim)이 아니라 **몸이 보는 쪽**입니다.
	##
	## 처음에는 조준을 썼습니다. 몸이 조준을 뒤늦게 따라 도니까 그쪽이 더
	## 정확할 것 같았는데, 그러면 이 적이 **아무도 못 잡습니다** - 자동 조준이
	## 3.9m 안의 가장 가까운 적으로 그 자리에서 튀므로, 달려오는 아이는 언제나
	## 조준의 정면에 놓입니다. 등 뒤가 영영 열리지 않습니다.
	##
	## 몸은 정해진 속도로 돌아갑니다. 그래서 "돌아서면 막힌다" 가 공짜가 아닌
	## 판단이 되고, 화면에서 보이는 등과 판정이 같은 것을 가리킵니다.
	if not is_instance_valid(target):
		return Vector3.FORWARD
	var pv: Variant = target.get("pivot")
	if pv is Node3D:
		var f: Vector3 = -(pv as Node3D).global_transform.basis.z
		f.y = 0.0
		if f.length_squared() > 0.001:
			return f.normalized()
	var b: Vector3 = -target.global_transform.basis.z
	b.y = 0.0
	return b.normalized() if b.length_squared() > 0.001 else Vector3.FORWARD


func _behind_target() -> Vector3:
	## 등 뒤의 자리. 여기로 걸어가서 잡습니다.
	return target.global_position - _target_facing() * 0.75


## "등 뒤" 로 치는 각. 이 값보다 **넓게 벗어나 있으면** 등 쪽입니다.
##
## 처음에는 120 이었습니다(정면 60도 밖). 8층 봇 4000프레임에서 이 아이가
## 실제로 그 자리에 있었던 것은 **네 번에 한 번**뿐이었고, 붙잡기는 0건이었습니다.
## 자동 조준이 3.9m 안의 적을 계속 붙잡고, 봇은 늘 적 쪽으로 걸어가므로 몸이
## 이쪽을 향해 있는 시간이 깁니다.
##
## 90 으로 넓혔습니다 - **정면 45도만 아니면** 등 쪽입니다. "정면으로 보고
## 있으면 막힌다" 는 규칙은 그대로이고, 눈을 뗀 순간의 폭만 넓어집니다.
const BEHIND_ARC := 90.0


func is_behind_target() -> bool:
	## 지금 주인공의 등 쪽에 있는지.
	var to_me: Vector3 = global_position - target.global_position
	to_me.y = 0.0
	if to_me.length_squared() < 0.0001:
		return true
	return to_me.normalized().dot(_target_facing()) < cos(deg_to_rad(BEHIND_ARC) * 0.5)


## 붙잡는 아이가 지키는 거리. 이 거리에서 옆으로 돕니다.
const CLING_KEEP := 2.4
## 등이 열렸을 때 파고들기 시작하는 거리.
const CLING_REACH := 3.6
## 파고들 때의 속도 배수와, 그 안에 못 닿으면 포기하는 시간.
const CLING_RUSH_MULT := 2.6
const CLING_RUSH_TIME := 1.3


func _pursue_cling(delta: float, to_target: Vector3, dist: float,
		visible_now: bool) -> Vector3:
	## 붙잡는 아이의 걸음. **등 뒤가 열릴 때까지 멀찍이 맴돌다 파고듭니다.**
	##
	## # 왜 곧장 달려들지 않는가
	##
	## 처음에는 등 뒤 0.75m 자리로 곧장 걸어가게 했습니다. 그러면 **아무도 못
	## 잡습니다.** 주인공의 자동 조준은 3.9m 안의 가장 가까운 적으로 그 자리에서
	## 튀는데, 달려오는 이 아이가 곧 가장 가까운 적이 되므로 다가갈수록 정면에
	## 놓입니다. 봇 4000프레임에서 거리 0.40m 까지 붙고도 등뒤 판정은 한 번도
	## 참이 아니었습니다.
	##
	## 그래서 **조준이 닿지 않는 거리(4.3m)에서 맴돕니다.** 그동안 주인공의
	## 눈은 다른 적에게 가 있고, 등이 열리는 순간 파고듭니다. 한 번 파고들기
	## 시작하면 되돌아가지 않습니다 - 그 사이에 주인공이 돌아서면 정면에서
	## 잡히지만, 그때는 이미 달려오는 것이 보이므로 구르거나 밀칠 수 있습니다
	## (구르는 중에는 안 잡힙니다 - player.gd 의 bind_by).
	if _cling_rush > 0.0:
		_cling_rush -= delta
		if dist <= float(stats["range"]):
			_cling_rush = 0.0
			_begin_attack()
			return Vector3.INF
		if _cling_rush <= 0.0:
			# 헛걸음. 대기를 절반만 줍니다 - 못 닿은 것까지 다 쉬면 이 적이
			# 하는 일이 거의 없어집니다.
			_cooldown = float(stats["cooldown"]) * 0.5
			return Vector3.ZERO
		return to_target.normalized() * CLING_RUSH_MULT

	if not visible_now or dist > 9.0:
		return _follow_path(delta)

	# **붙어서 옆으로 돕니다.**
	#
	# 처음에는 자동 조준 밖(4.3m)에서 등 뒤 지점으로 걸어가게 했습니다. 그
	# 아이가 **일을 못 하고 죽었습니다** - 8층 봇 4000프레임에서 열한 마리가
	# 나왔는데 파고든 것은 한 번, 붙잡은 것은 0건이었습니다. 멀찍이 걸어가는
	# 동안 고함과 폭발에 휩쓸립니다.
	#
	# 지금은 2.4m 까지 붙어서 그 거리를 지키며 **옆으로 돕니다.** 늘 눈에
	# 보이고, 돌다가 등이 열리는 순간 파고듭니다. 자동 조준 안이지만 상관
	# 없습니다 - 막는 방법이 "쳐다보는 것" 이라, 다른 적을 보는 동안 이 아이가
	# 뒤로 돌아가는 것이 그대로 규칙이 됩니다.
	if _cooldown <= 0.0 and is_behind_target() and dist <= CLING_REACH:
		_cling_rush = CLING_RUSH_TIME
		Sfx.play(Sfx.WARN, -16.0, 0.12)
		return to_target.normalized() * CLING_RUSH_MULT

	var to_me := global_position - target.global_position
	to_me.y = 0.0
	if to_me.length() < 0.25:
		return Vector3.ZERO
	var radial := to_me.normalized()
	# 도는 방향은 **등 뒤에 가까워지는 쪽**입니다. 한쪽으로만 돌면 주인공이
	# 같은 쪽으로 계속 돌 때 영영 못 따라잡습니다.
	var back := -_target_facing()
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	if tangent.dot(back) < 0.0:
		tangent = -tangent
	# 지키는 거리에서 벗어난 만큼 안팎으로 섞습니다.
	var pull := clampf((to_me.length() - CLING_KEEP) / CLING_KEEP, -1.0, 1.0)
	var want := tangent - radial * pull
	return want.normalized() if want.length_squared() > 0.0001 else tangent


func _cling_grab(dist: float) -> void:
	## 등에 매달립니다. 붙잡히면 주인공이 잠시 못 움직입니다.
	# 넉넉하게 봅니다. 예고 동안 따라붙기는 하지만, 주인공이 그 사이 구르면
	# 한 걸음 벌어집니다 - 그 정도는 손이 닿은 것으로 칩니다.
	if not is_instance_valid(target) or dist > float(stats["range"]) + 0.9:
		return
	var hold: float = float(stats.get("bind", 1.5))
	if not target.has_method("bind_by") or not target.bind_by(self, hold):
		# 구르는 중이거나 이미 다른 아이가 매달려 있으면 헛손질입니다.
		# 헛손질도 보여야 합니다 - 안 보이면 붙잡기가 될 때만 있는 기술로
		# 오해하게 됩니다.
		Fx.burst(get_parent(), global_position + Vector3(0, 0.9, 0),
			Color(0.75, 0.6, 1.0), 6, 2.4)
		return
	_cling = hold
	# **붙은 자리를 그 순간에 굳힙니다.**
	#
	# 예전에는 매 프레임 "주인공의 등 뒤 0.75m" 를 다시 계산했습니다. 그
	# 지점은 주인공이 보는 쪽에 매여 있는데, 자동 조준이 적을 갈아탈 때마다
	# 몸이 홱 도니까 매달린 아이가 **주인공 둘레를 팽팽 돌았습니다.**
	#
	# 붙은 자리는 붙은 순간에 정해지는 것이지 그 뒤로 바뀌는 값이 아닙니다.
	# 그 자리를 기억해 두고 따라만 다니면, 주인공이 어떻게 돌든 등에 붙어
	# 함께 끌려갑니다.
	var grip := global_position - target.global_position
	grip.y = 0.0
	if grip.length() > 0.05:
		_cling_offset = grip.normalized() * minf(grip.length(), 0.8)
	else:
		_cling_offset = -_target_facing() * 0.7
	# **밀어내지 않습니다**(knock 0). 붙잡는 것과 튕겨내는 것은 반대 방향의
	# 일이라, 잡으면서 밀면 다음 프레임에 손이 닿지 않습니다.
	target.call("take_damage", damage, global_position, 0.0)
	Sfx.play(Sfx.GRAB, -4.0, 0.12)
	Fx.popup_text(get_parent(), target.global_position + Vector3(0, 1.9, 0),
		"붙잡혔다!", Color(0.85, 0.7, 1.0))


func _drive_cling(delta: float) -> void:
	## 매달려 있는 동안. 걷지 않고 **주인공의 등에 붙어 따라다닙니다.**
	_cling -= delta
	if not is_instance_valid(target) or _cling <= 0.0:
		release_cling()
		return
	var at: Vector3 = target.global_position + _cling_offset
	var want := Vector3(at.x, target.global_position.y, at.z)
	# 따라붙는 속도도 낮췄습니다(20 -> 12). 빠르게 당기면 주인공이 방향을
	# 꺾을 때마다 아이가 튀어 다닙니다.
	global_position = global_position.lerp(want, 1.0 - exp(-12.0 * delta))
	velocity = Vector3.ZERO
	# **붙은 쪽을 봅니다.** 주인공이 보는 쪽을 따라가면 몸이 같이 돌아서,
	# 매달려 있는 것이 아니라 함께 춤추는 것처럼 보입니다.
	_face(-_cling_offset, delta, TURN_SPEED * 2.0)
	if _pose != null:
		_pose.pose = PoseOverride.CARRY
		_pose.weight = lerpf(_pose.weight, 1.0, 1.0 - exp(-16.0 * delta))
	if _anim != null and _idle != "" and _anim.current_animation != _idle:
		_anim.play(_idle)


func release_cling() -> void:
	## 떨어집니다. 주인공이 버둥거려 빠져나갔거나, 시간이 다 됐거나, 맞았거나.
	##
	## 떨어지면서 **뒤로 물러납니다.** 붙은 자리에 그대로 서 있으면 대기가
	## 끝나는 즉시 다시 잡아서, 한 번 잡히면 영영 못 움직입니다.
	if _cling <= 0.0:
		return
	_cling = 0.0
	_cling_rush = 0.0
	_cling_offset = Vector3.ZERO
	_cooldown = float(stats["cooldown"])
	_stagger = maxf(_stagger, 0.3)
	if _pose != null:
		_pose.weight = 0.0
	if is_instance_valid(target):
		if target.has_method("unbind_from"):
			target.unbind_from(self)
		var away: Vector3 = global_position - target.global_position
		away.y = 0.0
		if away.length_squared() > 0.001:
			knock_back(away.normalized() * 3.4)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.9, 0),
		Color(0.8, 0.7, 1.0), 8, 3.0)


func _slam_hit() -> void:
	## 베개로 내리칩니다. **고정한 자리에 놓이는 원** 하나입니다.
	##
	## 부채꼴(80도)이었습니다. 베개를 내려찍는 그림은 부채꼴이 아니라 **바닥에
	## 눌리는 원**이고, 예고도 그 원을 칠하므로 판정도 같아야 합니다 - 보이는
	## 것과 맞는 것이 다르면 피한 것이 억울해집니다.
	##
	## 크기는 부채꼴과 비슷하게 잡았습니다: 축을 따라 0.05~1.05 배, 옆으로는
	## 가운데에서 ±0.5 배(예전 부채꼴은 그 자리에서 ±0.46 배였습니다).
	## 옆으로 굴러 나가면 여전히 빗나갑니다.
	_slam_time = 0.28
	var reach: float = float(stats["range"]) + 0.4
	var at := _slam_center(reach)
	if is_instance_valid(target):
		var to: Vector3 = target.global_position - at
		to.y = 0.0
		if to.length() <= _slam_radius(reach):
			target.call("take_damage", damage, global_position,
				float(stats.get("knock", 8.0)))
	Fx.ring(get_parent(), at, Color(0.7, 0.85, 1.0), reach * 0.8, 0.3)
	Fx.burst(get_parent(), at + Vector3(0, 0.4, 0), Color(0.9, 0.95, 1.0), 12, 3.4)
	Sfx.play(Sfx.PUSH, -6.0, 0.14)
	Game.shake(0.26, 0.18)


func guard_blocks(from_pos: Vector3) -> bool:
	## 앞을 막는 적이 **그 자리에서 오는 것**을 막는지.
	##
	## 방향이 아니라 **자리**를 받습니다. 밀기는 밀어내는 힘을 한 군데에서만
	## 넣기로 해서 방향을 Vector3.ZERO 로 넘기는데(player.gd 의 _shove_one),
	## 방향으로 판정하면 밀기만 언제나 뚫고 들어갑니다.
	if _dead or float(stats.get("guard_arc", 0.0)) <= 0.0:
		return false
	var to: Vector3 = from_pos - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	var half := deg_to_rad(float(stats["guard_arc"])) * 0.5
	return to.normalized().dot(facing()) >= cos(half)


func _guard_bounce(from_pos: Vector3) -> void:
	## 막았다는 것을 보여 줍니다. 아무 일도 안 일어나면 공격이 안 닿은 것인지
	## 막힌 것인지 구분되지 않아, 플레이어가 규칙을 배울 수 없습니다.
	var to: Vector3 = from_pos - global_position
	to.y = 0.0
	var at := global_position + Vector3(0, _capsule_height * 0.6, 0)
	if to.length_squared() > 0.0001:
		at += to.normalized() * 0.45
	Fx.burst(get_parent(), at, Color(0.8, 0.9, 1.0), 8, 2.6)
	Fx.popup_text(get_parent(), global_position + Vector3(0, _capsule_height + 0.3, 0),
		"푹신", Color(0.75, 0.88, 1.0))
	Sfx.play(Sfx.PUSH, -14.0, 0.18)
	if _pillow != null:
		Fx.punch(_pillow, 0.28)


func _melee_in_fan(dist: float) -> bool:
	## 주인공이 **예고한 부채꼴 안**에 있나. 그림(`_show_melee_fan`)과 같은
	## 사거리·각도를 씁니다 - 두 곳에서 따로 정하면 언젠가 어긋납니다.
	if not is_instance_valid(target):
		return false
	if dist > float(stats["range"]) + 0.4:
		return false
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return true      # 발밑까지 붙었으면 각도를 물을 것이 없습니다
	return to.normalized().dot(_melee_dir) >= cos(deg_to_rad(MELEE_ARC) * 0.5)


func _strike() -> void:
	if not is_instance_valid(target):
		return
	target.call("take_damage", damage, global_position)


func _spit(to_target: Vector3) -> void:
	var proj := Projectile.new()
	get_parent().add_child(proj)
	proj.launch(global_position + Vector3(0, 0.8, 0), to_target.normalized(),
		damage, dungeon)


func _charge_contact(dist: float) -> void:
	## 달리는 중에 주인공에 닿았는지 봅니다.
	##
	## 미끄럼 충돌(get_slide_collision)로 잡지 않습니다. 주인공과 적은 서로
	## 밀어내므로, 닿는 순간에는 이미 조금씩 밀려나 접촉이 한 프레임 뜨거나
	## 두 번 잡힙니다. 거리로 보면 그 흔들림이 없습니다.
	if _charge_hit or not is_instance_valid(target):
		return
	# 두 몸이 **닿는 거리**입니다 - 내 반지름 + 주인공 반지름 + 손끝 여유.
	# 주인공의 달려들기(player.gd 의 _drive_lunge)와 같은 방식이라,
	# 어느 쪽이 커져도 둘이 같이 따라갑니다.
	var reach: float = float(get_meta("body_radius", 0.35)) + float(target.get("_body_radius")) + 0.12
	if dist > reach:
		return
	_charge_hit = true
	# 부딪힌 쪽도 멈춥니다. 뚫고 지나가면 맞은 사람이 어디서 맞았는지
	# 모르고, 무엇보다 한 번의 돌진이 계속 미는 벽이 됩니다.
	_charge = 0.0
	_stagger = maxf(_stagger, 0.45)
	target.call("take_damage", damage, global_position,
		float(stats.get("knock", 11.0)))
	Fx.burst(get_parent(), global_position + _charge_dir * 0.5 + Vector3(0, 0.8, 0),
		Color(1.0, 0.7, 0.4), 12, 4.0)
	Game.shake(0.32, 0.22)


func _drive_attack_pose(delta: float) -> void:
	## 예고·돌진·막기의 자세. 들썩임(_flinch)이 돌고 있으면 비켜 줍니다 -
	## 하나의 층에 둘이 같이 쓰면 나중에 쓴 쪽이 앞의 것을 지웁니다.
	if _pose == null or _flinch_time > 0.0:
		return
	_slam_time = maxf(0.0, _slam_time - delta)
	var mode: String = stats.get("attack", "melee")
	var want := 0.0
	var rate := 9.0
	if mode == "slam":
		# **늘 막고 있습니다.** 예고 때 들어 올리고, 친 직후에 내리꽂습니다.
		if _windup >= 0.0:
			_pose.pose = PoseOverride.SLAM_UP
		elif _slam_time > 0.0:
			_pose.pose = PoseOverride.SLAM_DOWN
			rate = 30.0
		else:
			_pose.pose = PoseOverride.GUARD
		want = 1.0
	elif _windup >= 0.0 and mode == "charge":
		_pose.pose = PoseOverride.REACH
		want = 1.0
	elif _windup >= 0.0 and mode == "cling":
		# 붙잡기 예고는 박치기와 같은 "손을 뻗는" 자세입니다. 실제로 다음에
		# 오는 것도 뻗은 손이라, 예고가 결과와 닮습니다.
		_pose.pose = PoseOverride.REACH
		want = 1.0
		rate = 22.0
	elif _windup >= 0.0 and mode == "shout":
		# 지르기 전에 몸을 젖혀 숨을 들입니다. 주인공이 쓰는 것과 같은
		# 자세라, 같은 기술이라는 것이 몸으로 읽힙니다.
		_pose.pose = PoseOverride.SHOUT
		want = 1.0
	elif _charge > 0.0:
		_pose.pose = PoseOverride.RAM
		want = 1.0
		rate = 26.0
	_pose.weight = lerpf(_pose.weight, want, 1.0 - exp(-rate * delta))
	_drive_pillow(delta)


func _drive_pillow(delta: float) -> void:
	## 베개가 자세를 따라 움직입니다.
	##
	## 손 본에 매달지 않고 `_pivot` 의 좌표로 옮깁니다. 손에 붙이면 두 손
	## 사이에 정확히 놓이지만, 그러려면 팔 각도가 바뀔 때마다 베개 크기와
	## 위치를 다시 재야 합니다 - 자세 셋의 손 높이에 맞춘 자리 셋을 오가는
	## 편이 값이 싸고 결과가 같습니다.
	if _pillow == null:
		return
	var height := _capsule_height
	var want := _pillow_rest(height, float(get_meta("body_radius", 0.35)))
	var tilt := 0.0
	if _windup >= 0.0 and stats.get("attack", "melee") == "slam":
		# 머리 위로. SLAM_UP 의 손이 오는 높이(키의 0.96배)에 맞춥니다.
		want = Vector3(0, height * 0.96, -0.08)
		tilt = -0.5
	elif _slam_time > 0.0:
		# 내리꽂은 자리. 앞아래 45도로 뻗은 손 끝입니다.
		want = Vector3(0, height * 0.24, -(float(get_meta("body_radius", 0.35)) + 0.44))
		tilt = 1.1
	var k := 1.0 - exp(-18.0 * delta)
	_pillow.position = _pillow.position.lerp(want, k)
	_pillow.rotation.x = lerpf(_pillow.rotation.x, tilt, k)
	# 충돌체를 그림에 맞춥니다. 몸통(_pivot)의 회전을 그대로 얹어야 베개가
	# 보이는 자리와 막는 자리가 같아집니다.
	if _pillow_shape != null and _pivot != null:
		var spin := Basis(Vector3.UP, _pivot.rotation.y)
		_pillow_shape.transform = Transform3D(spin, spin * _pillow.position)


func _pursue_toss(delta: float, to_target: Vector3, dist: float,
		visible_now: bool) -> Vector3:
	## 던지는 적의 걸음. 손에 든 것이 있으면 겨누고, 없으면 주우러 갑니다.
	##
	## Vector3.INF 를 돌려주면 "이번 프레임은 여기서 끝" 이라는 뜻입니다
	## (공격을 시작했거나 물건을 집었습니다).
	if _carry != null and not is_instance_valid(_carry):
		_carry = null
	if _carry != null:
		# **두 손으로 앞에 듭니다.**
		#
		# 예전에는 머리 위에 띄웠습니다. 적에게는 드는 자세가 없어서 손 위치를
		# 읽어 봐야 팔이 내려간 자리였기 때문입니다 - 그런데 자세가 없으면
		# **만들면 됩니다.** 주인공이 쓰는 것과 같은 층(PoseOverride.CARRY)을
		# 걸면 팔이 앞으로 나오고, 그 앞에 물건을 두면 손에 든 것이 됩니다.
		#
		# 자리는 베개와 같은 방법으로 잡습니다(_pillow_rest 참고) - 손 본에
		# 매달지 않고 몸 좌표로 둡니다. 머리가 커서 가슴 높이에 두면 위에서
		# 볼 때 가리므로, 머리 아래로 내리고 앞으로 내밉니다.
		var hands := _carry_point()
		_carry.global_position = _carry.global_position.lerp(hands,
			1.0 - exp(-18.0 * delta))
		if _pose != null and _flinch_time <= 0.0 and _windup < 0.0:
			_pose.pose = PoseOverride.CARRY
			_pose.weight = lerpf(_pose.weight, 1.0, 1.0 - exp(-12.0 * delta))
		if visible_now and dist <= float(stats["range"]) and _cooldown <= 0.0:
			_begin_attack()
			return Vector3.INF
		# 너무 붙으면 물러납니다. 던지는 적이 코앞까지 오면 그냥 근접 적입니다.
		if dist < float(stats["range"]) * 0.35:
			return -to_target.normalized()
		return _follow_path(delta)

	var prop := _nearest_free_prop()
	if prop == null:
		# 주울 것이 없으면 그냥 쫓아옵니다. 아무것도 안 하고 서 있으면
		# 고장 난 것으로 보입니다.
		return _follow_path(delta)
	var to_prop: Vector3 = prop.global_position - global_position
	to_prop.y = 0.0
	if to_prop.length() < 1.0 + float(get_meta("body_radius", 0.35)):
		if prop.grab(self):
			_carry = prop
			Fx.burst(get_parent(), prop.global_position,
				Color(1.0, 0.8, 0.5), 6, 2.5)
		return Vector3.INF
	return to_prop.normalized()


func _carry_point() -> Vector3:
	## 들고 있는 소품이 붙는 자리. 몸 앞, 머리 아래입니다.
	var radius: float = float(get_meta("body_radius", 0.35))
	var local := _pillow_rest(_capsule_height, radius)
	if _pivot == null:
		return global_position + Vector3(0, local.y, 0)
	return _pivot.global_transform * local


func _nearest_free_prop() -> Prop:
	## 가까이 있는, 아무도 안 든 소품. 너무 멀리 있는 것까지 주우러 가면
	## 적이 방을 가로질러 사라집니다.
	var best: Prop = null
	var closest: float = float(stats.get("fetch", 12.0))
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if not is_instance_valid(prop) or prop.held_by != null:
			continue
		# 우유는 던지지 않습니다. 방에 몇 개 없는 회복 수단이라, 적이 집어
		# 던져 없애 버리면 플레이어가 어쩌지 못한 채 사라집니다 - 소품을
		# 서로 뺏는 재미와 달리, 이건 그냥 빼앗기는 것입니다.
		if prop.is_drink() or prop.is_fixed():
			continue
		# **날아가는 중인 것은 안 줍습니다.**
		#
		# 이 적이 "들기만 하고 안 던지는" 것으로 보였던 원인입니다. 던질 때
		# 소품을 자기 몸 위치에 놓고 속도를 주는데(_toss), 그 다음 프레임에도
		# 아직 몸에서 0.4m 안이라 **줍는 거리(1.0m) 안**입니다. 던지자마자
		# 자기 공을 다시 받아서, 밖에서 보면 계속 들고만 있었습니다.
		#
		# 시간(주운 뒤 몇 초)으로 막지 않습니다. 멈춰 있는 물건은 언제 주워도
		# 되고, 날아가는 물건은 누가 던졌든 잡으면 안 됩니다 - 상태로 보는
		# 편이 규칙이 하나로 읽힙니다.
		if prop.linear_velocity.length() > 1.5:
			continue
		var to: Vector3 = prop.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < closest:
			closest = d
			best = prop
	return best


func _toss(to_target: Vector3) -> void:
	## 들고 있던 것을 던집니다.
	if _carry == null or not is_instance_valid(_carry):
		return
	var prop := _carry
	_carry = null
	var dir := to_target
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = facing()
	# 맞는 쪽을 뒤집습니다. 이걸 빼먹으면 적이 던진 물건이 **적을** 칩니다.
	prop.hostile = true
	# **손에서 놓습니다.** 몸 한가운데에서 나가면 어디서 나온 것인지 안
	# 보이고, 무엇보다 물건이 자기 몸 안에서 튀어나옵니다.
	prop.global_position = _carry_point()
	prop.throw(dir.normalized(), damage)
	# 같은 소리를 더 작게 냅니다. 날아오는 것을 화면 밖에서도 알아채야
	# 하는데, 주인공이 던질 때와 같은 크기면 누가 던졌는지 헷갈립니다.
	Sfx.play(Sfx.THROW, -9.0, 0.12)
	Fx.burst(get_parent(), prop.global_position, Color(1.0, 0.7, 0.35), 8, 3.0)


func _begin_charge(dir: Vector3) -> void:
	# 달리는 시간은 **거리에서 나옵니다**. 셋(예고 길이 / 달리는 거리 / 겨누기
	# 시작 거리)이 따로 적히면 반드시 어긋납니다 - 실제로 예고를 2.85m 로
	# 그려 놓고 4.9m 를 달린 적이 있습니다.
	_charge = float(stats.get("charge_dist", 5.0)) / float(stats.get("charge_speed", 6.0))
	_charge_dir = dir
	_charge_hit = false
	_cooldown = float(stats.get("cooldown", 2.6))
	# **발밑 고리를 뺐습니다.** 달려갈 길은 이미 띠(`_show_charge_lane`)가
	# 칠하고 있어서, 고리는 같은 말을 다른 모양으로 한 번 더 하는 것이었고
	# 예고와 헷갈렸습니다. 남는 것은 **박차고 나가는 먼지**뿐입니다.
	Fx.burst(get_parent(), global_position + Vector3(0, 0.12, 0),
		Color(0.86, 0.78, 0.66), 7, 2.0)


# ---------------------------------------------------------------- 피해

## 고함에 맞았을 때의 경직. 이 1초가 잡기를 성립시킵니다 - 굳어 있는 동안은
## **방향도 못 바꾸므로**(도는 것은 쫓아갈 때뿐입니다) 그 사이에 뒤로 돌아
## 들어갈 수 있습니다.
## 주인공의 몸 반지름(대략). 주인공은 이 값을 메타로 들고 있지 않아 여기서
## 잡습니다 - 박치기가 닿았는지 보는 데만 씁니다.
const PLAYER_RADIUS := 0.42

const SHOUT_STAGGER := 1.0
## 들썩이는 자세가 풀리는 데 걸리는 시간. 경직(1초)보다 짧아야 굳어 있는
## 동안 자세가 서서히 돌아옵니다.
const FLINCH_TIME := 0.45


func interrupt(hold: float) -> void:
	## **하던 동작을 통째로 끊습니다.** 고함이 하는 일입니다.
	##
	## 밀어내는 것과 다릅니다. 밀면 자리가 바뀌고 하던 일은 그대로라 다시
	## 달려옵니다. 끊으면 자리는 그대로인데 **하던 일이 없어집니다** - 정리한
	## 자리에서 그대로 잡거나 밀 수 있습니다(고함 → 밀기가 이어집니다).
	##
	## 끊는 것 넷:
	##
	##   예고     `_windup` — 들어 올리던 베개가 내려오다 맙니다
	##   돌진     `_charge` — 달려오던 몸이 그 자리에 섭니다
	##   내려치기 `_slam_time` — 이미 나간 것도 거둡니다
	##   예고 그림 띠와 원반 — 안 지우면 없는 공격의 예고가 남습니다
	if _dead:
		return
	_windup = -1.0
	_charge = 0.0
	_charge_hit = true
	_slam_time = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	# **다시 시작하기까지 쉽니다.** 끊기자마자 곧바로 다시 예고를 시작하면
	# 끊은 것이 눈에 안 보입니다 - 굳는 시간이 곧 파고들 틈입니다.
	_cooldown = maxf(_cooldown, hold)
	_stagger = maxf(_stagger, hold)
	if _lane != null:
		_lane.visible = false
	_lane_flash = 0.0
	if _disc != null:
		_disc.visible = false


## 밀려나는 **최고 빠르기**를 주인공 걸음의 몇 배로 묶을까.
##
## 안 묶으면 밀기·던지기·발 걸기가 저마다 다른 세기를 넣어서, 같은 「밀림」
## 인데 어떤 것은 걸어서 따라갈 수 있고 어떤 것은 방 끝까지 날아갑니다.
## 걸음의 1.2배면 **쫓아갈 수 있는 빠르기**입니다 - 밀어 놓고 그 자리에서
## 이어 갈 수 있어야 밀기가 정리하는 기술이 됩니다.
const KNOCK_SPEED_MULT := 1.2


func _cap_knock() -> void:
	## 바닥을 따라 미는 빠르기를 걸음의 1.2배로 자릅니다. **한 군데에서만**
	## 자릅니다 - 미는 곳마다 따로 자르면 새 기술을 더할 때 반드시 빠뜨립니다.
	var top := 3.1 * KNOCK_SPEED_MULT
	if Game.instance != null and Game.instance.state != null:
		top = Game.instance.state.move_speed * KNOCK_SPEED_MULT
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > top:
		flat = flat.normalized() * top
		velocity.x = flat.x
		velocity.z = flat.y


func knock_back(impulse: Vector3, chain: int = 0) -> void:
	## 밖에서 밀어냅니다.
	##
	## `chain` 은 **「밀기」 Lv3 의 연쇄**가 몇 번 더 남았는지입니다. 이 몸이
	## 다른 적에 부딪히면 그 적도 밀리고(`_crash_into_foe`), 남은 횟수가
	## 하나 줄어 넘어갑니다. 0 이면 부딪혀도 아프기만 하고 안 밀립니다.
	##
	## **돌진도 끊습니다.** 밀려나면서도 계속 달려오면 밀어낸 것으로 보이지
	## 않고, 무엇보다 "달려드는 것을 막는 수단" 이라는 쓸모가 사라집니다.
	if _dead:
		return
	_charge = 0.0
	_knock = 0.45
	_crash_used = false
	_chain_left = maxi(_chain_left, chain)
	# **밀기 전에 가던 속도를 끊습니다.**
	#
	# 달려오던 적을 밀면 그 운동량이 밀림을 거의 다 먹습니다(실측: 1.73m/s 로
	# 달려오는 적을 3.0m/s 로 밀었더니 0.1m 밖에 안 밀렸습니다). 서 있을 때와
	# 달려올 때가 이렇게 다르면 같은 기술로 안 보입니다 - 멈춰 세우고 미는
	# 편이 예측 가능하고, 미는 힘이 상대를 멈춰 세운다는 것도 사실입니다.
	velocity.x = 0.0
	velocity.z = 0.0
	velocity += impulse
	_cap_knock()
	velocity.y = maxf(velocity.y, 2.2)      # 살짝 띄워야 밀린 것으로 보입니다
	# **민 사람 쪽으로 몸을 돌립니다.**
	#
	# 옆에서 밀면 옆으로 미끄러지는데 몸은 딴 데를 보고 있어서, 무엇에 밀린
	# 것인지가 안 읽혔습니다. 밀린 쪽을 등으로 받게 하면 **적 입장에서는 뒤로
	# 물러나는 것**이 되고, 그러면 걷기 클립도 알아서 거꾸로 돕니다
	# (_drive_animation 의 _moving_back - 원거리 적이 물러날 때 쓰던 길입니다).
	var face_back := -impulse
	face_back.y = 0.0
	_knock_face = face_back.normalized() if face_back.length_squared() > 0.0001 else Vector3.ZERO
	Fx.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(0.85, 0.95, 1.0), 8, 3.5)


var _slip := 0.0
## 밀려나는 중인 시간. 이 동안에는 감속이 느슨합니다.
var _knock := 0.0
## 밀린 동안 바라볼 쪽. **민 사람 쪽**입니다.
var _knock_face := Vector3.ZERO


func slip_on(amount: float) -> void:
	## 적도 미끄러집니다. 함정이 한쪽에만 들으면 그건 함정이 아니라 벽입니다.
	_slip = maxf(_slip, 0.12 * amount)


func take_damage(amount: float, crit: bool, from_dir: Vector3,
		stagger: float = 0.0, from_pos: Vector3 = Vector3.INF) -> void:
	## `from_pos` 는 **때린 쪽의 자리**입니다. 안 주면 Vector3.INF - "어디서
	## 왔는지 모른다" 는 뜻이고, 그런 것은 앞을 막는 적도 막지 못합니다.
	## 함정(발밑에서 올라오는 압정)이 그쪽으로 남습니다.
	if _dead:
		return
	if from_pos.is_finite() and guard_blocks(from_pos):
		# **앞이 막혀 있습니다.** 피해도 경직도 들어가지 않습니다.
		#
		# 절반만 들어가게 하면 "덜 아픈 적" 이 되어, 그냥 계속 때리는 것이
		# 답이 됩니다. 아예 0 이라야 뒤로 돌아가는 것 말고 길이 없습니다.
		wake()
		_guard_bounce(from_pos)
		return
	hp -= amount
	wake()
	_bar_root.visible = true
	_bar_fill.scale.x = clampf(hp / max_hp, 0.0, 1.0)
	_bar_mat.albedo_color = Color(0.90, 0.30, 0.26, 0.95).lerp(
		Color(1.0, 0.75, 0.2, 0.95), 1.0 - clampf(hp / max_hp, 0.0, 1.0))

	Sfx.play(Sfx.FOE_HIT, -9.0 if not crit else -5.0, 0.16)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.4, 0), amount, crit)
	Fx.flash(_pivot, Fx.HIT_COLOR, 0.1)
	Fx.punch(_pivot, 0.2)
	if stagger > 0.5:
		_flinch()
	# 매달려 있다 맞으면 떨어집니다. 붙잡힌 주인공은 손을 못 쓰지만, 다른
	# 적의 가시나 폭죽이 대신 떼어 줄 수 있습니다.
	release_cling()

	# 돌진 중에는 밀리지 않습니다. 그래야 돌진이 위협으로 남습니다.
	if _charge <= 0.0:
		_stagger = maxf(stagger, 0.18 if not crit else 0.32)
		_windup = -1.0
		_knock = maxf(_knock, 0.35)
		velocity += from_dir * (5.0 if not crit else 8.0)

	if hp <= 0.0:
		_die()


## 부딪힘으로 아프려면 이만큼은 나가고 있어야 합니다. 걸어가다 벽에 닿는
## 것까지 세면 적이 벽 앞에서 저절로 죽습니다.
const CRASH_MIN_SPEED := 2.0
## 피해를 셀 때 인정하는 **최고 속도**.
##
## 물리가 겹친 몸을 밀어낼 때 한 프레임 동안 10~25m/s 가 찍힙니다(실측).
## 그대로 곱하면 벽에 낀 적이 한 방에 죽습니다 - 세게 민 것이 아니라
## 물리가 튄 것이라 게임에서 벌어진 일과 무관합니다.
const CRASH_MAX_SPEED := 9.0
## 부딪힌 속도 1m/s 당 피해. 벽이 더 아픕니다 - 벽은 안 물러나고 사람은
## 같이 밀려나므로, 같은 속도라도 벽 쪽이 더 세게 멈춥니다.
const CRASH_WALL := 2.6
const CRASH_FOE := 1.8
## **한 번의 밀림에 한 번만.** 안 그러면 벽에 붙어 밀리는 동안 매 프레임
## 피해가 들어가서, 벽 옆에서 민 것과 한가운데서 민 것이 딴 기술이 됩니다.
var _crash_used := false
## 부딪히기 직전에 가던 방향. 위와 같은 이유로 미리 적어 둡니다.
var _crash_dir := Vector3.ZERO


func _crash_pre() -> float:
	## `move_and_slide` 를 부르기 **직전에** 속도와 방향을 적어 둡니다.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	_crash_dir = flat / speed if speed > 0.0001 else Vector3.ZERO
	return speed


func _crash_check(pre_speed: float) -> void:
	## **밀리거나 던져진 몸이 벽이나 다른 적에 부딪히면 더 아픕니다.**
	##
	## 미는 힘이 셀수록 빨리 날아가고, 빠를수록 부딪힘이 아픕니다 - 피해를
	## 따로 정하지 않고 **속도에서** 뽑으므로 「밀치는 힘」이 그대로 반영되고,
	## 벽을 등진 적을 미는 것이 자리 선택이 됩니다.
	##
	## 속도는 **부딪히기 직전 값**을 받습니다. `move_and_slide` 는 벽에 닿는
	## 순간 그 방향 속도를 이미 지워서, 그 뒤에 재면 언제나 0 에 가깝습니다
	## (실측: 7.13m/s 로 벽에 박았는데 판정 뒤에는 0).
	if _crash_used or _dead:
		return
	if _knock <= 0.0 and _thrown <= 0.0:
		return
	if pre_speed < CRASH_MIN_SPEED or _crash_dir.length_squared() < 0.0001:
		return
	var speed := minf(pre_speed, CRASH_MAX_SPEED)
	if _crash_into_foe(speed):
		return
	_crash_into_wall(speed)


func _crash_into_foe(speed: float) -> bool:
	## 다른 적에 부딪혔나. **닿는 것이 아니라 가까워지는 것**으로 봅니다.
	##
	## 적끼리는 서로 통과합니다(`collision_mask` 에 적이 없습니다 - 겹침은
	## `_avoid_crowd` 가 벌려서 풉니다). 그래서 미끄러짐 충돌로는 영영 안
	## 잡히고, 날아가며 치는 것(`_hit_others_while_flying`)과 같은 방식으로
	## 거리를 봅니다.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as Enemy
		if other == null or other._dead:
			continue
		var to: Vector3 = other.global_position - global_position
		if to.y > 0.4 or to.y < -other._capsule_height - 0.3:
			continue
		to.y = 0.0
		var reach: float = float(get_meta("body_radius", 0.3)) + float(other.get_meta("body_radius", 0.3))
		if to.length() > reach + 0.15:
			continue
		# **가는 쪽에 있는 것만** 칩니다. 옆이나 뒤에 서 있는 적까지 세면
		# 밀기 한 번에 주변이 다 아픕니다.
		if to.length() > 0.05 and to.normalized().dot(_crash_dir) < 0.4:
			continue
		# 부딪힌 둘 다 아픕니다. 한쪽만 아프면 밀린 몸이 상처 없는 무기가
		# 되고, 그러면 적을 벽이 아니라 적에게 던지는 것만 답이 됩니다.
		var hurt := speed * CRASH_FOE
		# **어디서 왔는지를 넘깁니다.**
		#
		# 안 넘기면 `from_pos` 가 Vector3.INF 가 되고, 그건 「어디서 왔는지
		# 모른다」 는 뜻이라 **앞을 막는 적도 못 막습니다.** 베개 든 아이는
		# 앞이 막혀 있는데, 다른 적을 밀어서 부딪히면 그 판정이 통째로
		# 건너뛰어져 정면에서도 피해가 들어갔습니다.
		other.take_damage(hurt, false, Vector3.ZERO, 0.0, global_position)
		# **연쇄(「밀기」 Lv3).** 부딪힌 적도 같은 방향으로 밀리고, 그 적이
		# 또 부딪히면 한 번 더 - 남은 횟수를 하나 줄여 넘깁니다.
		#
		# 속도를 그대로 넘기지 않고 0.7 배로 깎습니다. 같은 힘이 계속 전해지면
		# 방 하나가 한 번에 정리되고, 그러면 밀기 말고 쓸 기술이 없어집니다.
		if _chain_left > 0:
			other.knock_back(_crash_dir * (speed * 0.7), _chain_left - 1)
		else:
			other.knock_back(_crash_dir * (throw_knock * 0.6))
		take_damage(hurt * 0.6, false, Vector3.ZERO, 0.0, other.global_position)
		_crash_mark()
		return true
	return false


func _crash_into_wall(speed: float) -> bool:
	## 벽에 정면으로 받았나. 스치며 지나가는 벽까지 세면 복도를 따라 밀리기만
	## 해도 아픕니다.
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var into := -hit.get_normal()
		into.y = 0.0
		if into.length_squared() < 0.0001:
			continue
		if _crash_dir.dot(into.normalized()) < 0.5:
			continue
		var other := hit.get_collider()
		if other is RigidBody3D:
			continue          # 소품은 튕겨 나갑니다(_push_what_we_hit)
		if other is Node and (other as Node).is_in_group("player"):
			continue
		take_damage(speed * CRASH_WALL, false, Vector3.ZERO)
		_crash_mark()
		return true
	return false


func _crash_mark() -> void:
	_crash_used = true
	Fx.burst(get_parent(), global_position + Vector3(0, 0.5, 0),
		Color(1.0, 0.85, 0.55), 10, 3.4)
	Sfx.play(Sfx.FOE_HIT, -2.0, 0.10)
	Game.shake(0.22, 0.14)
	# 부딪혔으면 거기서 멈춥니다. 벽을 타고 계속 미끄러지면 부딪힌 것으로
	# 안 보입니다.
	velocity.x *= 0.15
	velocity.z *= 0.15


func _push_what_we_hit() -> void:
	## 주인공과 같은 이유(player.gd 참고). 적도 굴러다니는 소품을 치고 갑니다.
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider()
		var away := -hit.get_normal()
		away.y = 0.0
		if away.length_squared() < 0.0001:
			continue
		if other is RigidBody3D:
			other.apply_central_impulse(away.normalized() * 1.8)
			velocity *= 0.9


## 날아가며 다른 적을 칠 때 미는 세기. 던진 쪽(주인공)이 자기 밀기 세기를
## 그대로 넘겨 줍니다 - 던지기는 밀기의 연장입니다.
var throw_knock := 3.0
## 연쇄로 더 밀 수 있는 횟수(「밀기」 Lv3). 0 이면 연쇄가 없습니다.
var _chain_left := 0


func _hit_others_while_flying() -> void:
	## 날아가면서 다른 적을 칩니다.
	##
	## 문턱을 4.0 에서 2.0 으로 내렸습니다. 던지는 거리를 크기로 정하면서
	## 수평 속도가 6 언저리로 내려왔는데, 날아가는 동안 중력에 꺾여 금세
	## 문턱 아래가 됐습니다.
	var speed := velocity.length()
	if speed < 2.0:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as Enemy
		# 소품과 같은 이유로 **수평 거리와 높이를 따로** 봅니다(prop.gd).
		# 3D 거리 하나로 재면, 떠서 날아가는 동안에는 상대 머리 위를 지나도
		# 원점까지 거리가 멀어 빗나간 것으로 처리됩니다.
		var to: Vector3 = other.global_position - global_position
		if to.y > 0.4 or to.y < -other._capsule_height - 0.3:
			continue
		to.y = 0.0
		if to.length() > 0.9 + float(other.get_meta("body_radius", 0.3)):
			continue
		# 날아가며 치는 것도 같습니다 - 어디서 왔는지를 넘깁니다.
		other.take_damage(damage * 1.2, false, Vector3.ZERO, 0.0, global_position)
		# 맞은 쪽도 **밀기와 같은 세기**로 밀립니다. 여기 숫자를 따로 두면
		# 미는 힘을 키워도 던져서 치는 것만 그대로라, 같은 손에서 나온 두
		# 기술이 다르게 자랍니다.
		other.knock_back(velocity.normalized() * throw_knock)
		velocity *= 0.4


func shove(impulse: Vector3) -> void:
	## 밖에서 밀 때. 주인공이 몸으로 밀거나 던져진 물건이 칠 때 씁니다.
	velocity += impulse
	_cap_knock()
	_stagger = maxf(_stagger, 0.12)


func stagger_for(seconds: float) -> void:
	## 푹신한 소품에 맞으면 아픈 대신 잠깐 멈춥니다. 인형을 던지는 것이
	## 피해가 아니라 **시간을 버는 수단**이 되게 하는 장치입니다.
	_stagger = maxf(_stagger, seconds)
	_windup = -1.0
	wake()


func _drop_carry() -> void:
	## 들고 있던 것을 놓습니다. 죽거나 잡힐 때 부릅니다 - 안 놓으면 소품이
	## 죽은 적을 따라다니거나, 아무도 못 줍는 유령이 됩니다.
	if _carry != null and is_instance_valid(_carry):
		_carry.drop()
	_carry = null


## 던져져 미끄러지는 중에 죽었나. 멈춘 뒤에 쓰러집니다.
var _die_when_landed := false
## 그 미룸에 **시간 제한**을 둡니다.
##
## 미루는 조건(`_knock`/`_thrown`)이 무슨 이유로든 안 풀리면 적이 영영 안
## 죽습니다. 죽음은 미룰 수는 있어도 **취소될 수는 없는 일**이라, 마지막
## 안전장치를 둡니다 - 여기 걸리는 일이 잦으면 그건 다른 데가 고장 난
## 것이므로, 값은 넉넉하되 무한이 아니어야 합니다.
const DIE_DEADLINE := 1.2
var _die_wait := 0.0


func _die() -> void:
	# **던져져 미끄러지는 중이면 멈춘 뒤에 쓰러집니다.**
	#
	# 예전에는 던진 순간 체력이 0 이 되면 그 자리에서 사라졌습니다. 던지기가
	# 곧 밀기인데(바닥으로 밀려납니다), 체력이 얼마 안 남은 적을 던지면
	# **날아가지 않고 손에서 증발**했습니다 - 던져진 몸으로 다른 적을 치는
	# 길이 "적의 체력이 충분할 때만" 열리는 셈이라, 쓸 만한 순간에 오히려
	# 안 되는 기술이었습니다.
	if (_thrown > 0.0 or _knock > 0.0) and not _dead:
		# 밀려나는 중(`_knock`)도 마찬가지입니다. 밀어서 죽인 적이 제자리에서
		# 사라지면, 밀린 몸으로 뒤엣것을 치는 길이 "체력이 충분할 때만"
		# 열립니다 - 마지막 한 대에서만 안 되는 셈입니다.
		_die_when_landed = true
		_die_wait = DIE_DEADLINE
		return
	# 매달린 채 죽으면 주인공이 영영 못 움직입니다. 죽는 것보다 먼저 놓습니다.
	release_cling()
	_drop_carry()
	Sfx.play(Sfx.FOE_DIE, -7.0, 0.12)
	if _dead:
		return
	_dead = true
	remove_from_group("enemies")
	set_physics_process(false)
	_bar_root.visible = false
	# 예고 원반은 **세계에 달려 있습니다**(적을 따라 돌면 안 되니까).
	# 물리가 멈추면 `_drive_slam_disc` 도 안 도므로 여기서 직접 끕니다.
	if is_instance_valid(_disc):
		_disc.visible = false
	if _anim != null:
		_anim.pause()

	# 터지는 조각만 남깁니다. 퍼지는 고리는 **예고와 같은 모양**이라, 죽는
	# 자리마다 "여기 뭔가 온다" 로 잘못 읽혔습니다.
	Fx.burst(get_parent(), global_position + Vector3(0, 0.6, 0),
		Color(1.0, 0.55, 0.35), 16, 5.0)

	var tween := _pivot.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_pivot, "rotation:x", -PI * 0.5, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_pivot, "scale", Vector3(0.01, 0.01, 0.01), 0.5).set_delay(0.25)
	tween.chain().tween_callback(queue_free)

	died.emit(self)
