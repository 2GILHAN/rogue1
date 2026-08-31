extends Node3D
class_name Game

## 화면 오른쪽 아래에 뜨는 판 번호.
##
## **고칠 때마다 올립니다.** 폰은 빌드를 캐시할 수 있고, 새로고침을 했는지
## 안 했는지도 화면만 봐서는 알 수 없습니다 - 번호가 바뀌었는지로 "지금 내가
## 고친 것을 하고 있나" 를 한눈에 확인합니다.
##
## 자릿수 규칙: 수치·값만 바뀌면 뒷자리(0.1 -> 0.1.1), 규칙이나 기능이
## 바뀌면 앞자리(0.1 -> 0.2).
const VERSION := "v0.20.1"

## 게임 전체를 묶는 곳. 층을 짓고, 상태를 넘기고, 카메라를 따라가게 합니다.
##
## 씬 파일은 이 스크립트가 붙은 빈 Node3D 하나뿐입니다. 던전이 매번 다르게
## 생성되는 게임에서는 어차피 배치를 코드가 정하므로, 씬 파일에 미리 놓아 둘
## 것이 거의 없습니다.

enum Phase { TITLE, PLAYING, BOON, SHOP, PAUSED, DEAD }

## 카메라까지의 거리 6.24m. 예전(12.5m)의 절반이라 캐릭터가 두 배로 보입니다.
##
## 각도는 58 -> 70 -> 63도를 거쳤습니다. 58도는 당겼을 때 남쪽 벽 윗면이 화면
## 아래 절반을 덮었고, 70도는 너무 내려다봐서 **벽 옆면의 그림이 안 보였습니다.**
## 63도가 그림이 보이면서도 벽에 붙어 섰을 때 가려지지 않는 지점입니다
## (가려지기 시작하는 거리 0.23m, 캐릭터 반지름 0.20m).
##
## 거리(6.24m)는 건드리지 않습니다 - 각도만 바꾸면 캐릭터 크기는 그대로입니다.
##
## 보이는 범위가 절반이 되는 것은 피할 수 없습니다. 적의 인지 거리(17m)가
## 화면 밖이라, 안 보이는 곳에서 오는 적은 미니맵으로 알아야 합니다.
const CAM_OFFSET := Vector3(0, 5.56, 2.83)
const CAM_PITCH := -63.0
## 옵션으로 움직일 수 있는 폭. 40도보다 눕히면 벽 윗면이 화면 절반을 덮고,
## 78도를 넘으면 캐릭터 정수리만 보입니다.
const CAM_PITCH_MIN := 40.0
const CAM_PITCH_MAX := 78.0
const CAM_PITCH_STEP := 4.0

## 카메라 방식. 두 가지입니다.
##
## `TOPDOWN` 은 지금까지의 화면입니다 - 위에서 내려다보고, 방 전체와 적의
## 배치가 한눈에 들어옵니다. 로그라이크가 위에서 보는 데는 이유가 있습니다.
##
## `SHOULDER` 는 어깨 너머입니다. 보이는 범위가 좁아지는 대신 눈높이가
## 아이의 것이 되어, 같은 적도 훨씬 크고 가깝게 옵니다. 소울라이크의 화면이고,
## **덜 보이는 것이 곧 긴장**이라는 쪽의 선택입니다.
enum CamMode { TOPDOWN, SHOULDER }

## 어깨 너머일 때의 거리·높이·내려다보는 각도.
##
## 거리를 3.0m 로 잡은 이유: 아이 키가 1.25m 라 어른 기준(4~5m)으로 두면
## 화면에서 너무 작아집니다. 높이는 어깨보다 조금 위(1.45m)에 두어 캐릭터가
## 화면 아래쪽 절반을 가리지 않게 했습니다.
const SHOULDER_DIST := 3.0
const SHOULDER_HEIGHT := 1.45
const SHOULDER_PITCH := 11.0
## 카메라가 몸을 따라 도는 속도. 너무 빠르면 방향을 바꿀 때마다 화면이
## 휙 돌아 멀미가 나고, 느리면 벽을 보고 달리게 됩니다.
## 6.0 에서 낮췄습니다. 이동 기준을 손 뗄 때만 갱신하게 되면서, 옆으로
## 계속 누르면 몸은 직진하는데 카메라만 뒤로 돌아옵니다 - 그 회전이 빠르면
## 화면이 휙 돌아 멀미가 납니다.
const SHOULDER_TURN := 3.5
## 어깨 너머일 때 옆으로 비켜서는 정도. 정확히 뒤에 서면 캐릭터가 화면
## 한가운데를 가려서 무엇을 겨누는지 안 보입니다.
const SHOULDER_SIDE := 0.42
## 어깨 너머일 때 벽을 걷어내는 반경. 카메라가 가까워 크게 잡으면 벽이
## 통째로 사라집니다.
const SHOULDER_FADE := 0.55
## 카메라가 벽에 파묻히지 않도록 앞으로 당겨 오는 최소 여유.
const SHOULDER_CLEAR := 0.25
## 벽에 몰려도 이만큼은 물러섭니다.
const SHOULDER_MIN := 1.7

static var instance: Game

var state: RunState
var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.TITLE

var world: Node3D
var dungeon: Dungeon
var player: Player
var portal: Portal
var shop: Shopkeeper
var ui: Ui

var world_env: Environment
var cam_rig: Node3D
var camera: Camera3D

var _alive := 0
var _shake := 0.0
var _shake_time := 0.0
var _boon_options: Array = []
## 지금 뜬 고르기 화면이 책장에서 왔는가. 층 보상과 화면을 함께 쓰므로,
## 고른 뒤에 무엇을 할지는 이 값으로 갈립니다.
var _boon_from_shelf := false
## 읽는 중인 책에서 나올 지식. 다 읽고 나서 화면에 씁니다.
var _pending_line := ""
## 읽는 동안의 어두워짐(0~1).
var _read_focus := 0.0
var _shop_items: Array = []
var _boon_names: Array = []
var _debug_floor := 1

# 개발용. 창을 띄우지 않고 사람이 눌러 보는 대신 확인하려고 둡니다.
var _shot_path := ""
var _shot_at := 240
var _frames := 0
var _quit_at := -1
var _cam_mult := 1.0
## --pitch=<도>. 벽 옆면을 확인할 때처럼 각도만 바꿔 보고 싶을 때 씁니다.
var _cam_pitch := 0.0
## 지금 보고 있는 각도(도, 양수). 거리는 그대로 두고 이것만 바꿉니다 -
## 각도만 움직이면 캐릭터 크기는 변하지 않습니다.
var cam_pitch := absf(CAM_PITCH)
var cam_mode: CamMode = CamMode.TOPDOWN
var _auto_start := false
## --face=<도> 로 조준을 고정합니다. 모델이 어느 쪽을 보는지 확인할 때 씁니다.
var debug_aim := Vector3.ZERO
## --bot: 사람 대신 게임을 끝까지 돌려 봅니다. 층 전환·축복·상점·죽음까지
## 한 번에 지나가므로, 화면을 안 보고도 흐름이 끊긴 곳을 찾을 수 있습니다.
var _bot := false
var _bot_path: PackedVector3Array = PackedVector3Array()
var _bot_repath := 0.0
var _bot_deaths := 0
var _bot_shopped := false
var _debug_ui := ""
## --seed=<수>. 같은 던전을 다시 불러올 수 있어야 버그를 두 번 볼 수 있습니다.
var _seed := 0
## --die-at=<프레임>. 쓰러지는 연출을 같은 시점에 다시 보려고 둡니다.
var _die_at := -1
## --pose=run|roll|shout. 그 동작만 계속 시켜서 화면으로 확인합니다.
var _pose := ""
## 확인용 자세(--pose=milk / pool)가 눈앞에 놓는 소품.
var _probe_prop: Prop = null
var _pool_from := Vector3.ZERO
## --pose=shelf 로 볼 소품 종류. --foe= 를 재활용합니다.
var _shelf_kind := "bookshelf"
var _shelf_at: Prop = null
var _trap_a: Trap = null
var _knock_from := Vector3.ZERO
## --pose=pitch 에서 세워 두는 표적.
var _pitch_foe: Enemy = null
var _ram_foe: Enemy = null
## --pose=cling / guard / scream 에서 세워 두는 새 적.
## 오래 하면 느려지는 것을 재는 스위치. `--leak` 으로 켭니다.
## **필살 모드 동안 세상이 멈춥니다.** 적·가시·날아가는 것이 이 값을 봅니다.
##
## `get_tree().paused` 를 쓰지 않는 이유: 그러면 주인공까지 멈춥니다. 멈춰야
## 하는 것은 **주인공 말고 전부**라, 멈추는 쪽이 스스로 보게 두는 편이
## 간단합니다(고르기 화면이 `phase` 를 보는 것과 같은 방식).
var world_frozen := false
## 필살 모드 동안 감춰 둔 것들과, 되돌릴 배경 색.
##
## 감춘 것을 **목록으로 들고 있습니다.** 끝날 때 "전부 다시 보이게" 로 풀면
## 원래 안 보이던 것(주운 소품, 죽은 적)까지 되살아납니다.
var _blacked: Array[Node3D] = []
var _bg_was := Color.BLACK
var _amb_was := 0.0
var _fog_was := false

## 필살기가 마지막으로 알려 온 한마디(동작 이름이나 끝난 까닭). 게이지 옆에
## 그대로 뜹니다.
var _ult_note := ""
var _force_lean := false
var _leak_proc := 0.0
var _leak_phys := 0.0
var _leak_n := 0
var _leak_probe := false
var _spam_prev := {}
var _spam_count := {}
var _probe_arg := ""
var _probe_foe: Enemy = null
var _probe_hp := 0.0
## --push-lv=N 으로 밀기 계통을 미리 올려 둡니다(비교용).
var _push_lv := 0
var _push_far := 0.0
var _riglab: RigLab = null
var _lab_hip := 0.0
var _lab_clip := ""
var _lab_char := -1
var _lab_motion := 0.0
var _start_shoulder := false
var _forced_boons: PackedStringArray = []
var _stride_L: BoneAttachment3D = null
var _stride_R: BoneAttachment3D = null
var _stride_lz := 0.0
var _stride_rz := 0.0
var _stride_sum := 0.0
var _stride_frames := 0
var _stride_have := false
var _stride_run := false
var _stride_kind := "grunt"
var _skate_prev := Vector3.ZERO
var _skate_moved := 0.0
var _pitch_mate: Enemy = null
## --fps-log: 1초마다 최악 프레임 시간을 찍습니다. "끊긴다" 가 실제로 프레임이
## 튀는 것인지, 조작이 막히는 느낌인지 가르려면 숫자가 필요합니다.
var _trace_at := -1
## --teacher-here: 선생님을 시작 방에 세웁니다. 호통을 바로 보려고 둡니다.
var _teacher_here := false
## 카툰 렌더링은 **기본으로 켭니다**. 이 게임의 에셋이 전부 수채화라
## 사진처럼 그리는 쪽이 오히려 어긋납니다. --no-toon 은 비교용입니다.
var _toon_start := true
## 화면 색감 필터(지브리 톤). **기본으로 켭니다** - 이 게임의 그림이 원래
## 수채화라, 원색으로 두면 버튼과 캐릭터의 톤이 갈라집니다. `--no-grade` 는
## 비교용입니다.
var _grade_on := true
## 실험용 방. 네모난 방 하나에 고른 적만 계속 나옵니다.
var test_mode := false
var _test_kind := ""
var _test_timer := 0.0
## 실험용 방에서 한 번에 두는 적 수와 다시 내보내는 간격(초).
const TEST_ALIVE := 3
const TEST_GAP := 2.5
var _fps_log := false
var _fps_worst := 0.0
var _fps_sum := 0.0
var _fps_count := 0


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read_args()
	_setup_input()
	var sfx := Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	# 녹화는 UI 보다 먼저 만듭니다 - 제목 화면이 "녹화하며 내려가기" 를 낼지
	# 말지를 이 노드에게 물어서 정합니다.
	var rec := Recorder.new()
	rec.name = "Recorder"
	add_child(rec)
	rec.stopped_by_itself.connect(_on_record_stopped)
	# 배경음은 제목 화면부터 끝까지 한 번만 걸어 둡니다. 층이 바뀔 때마다
	# 다시 걸면 이어지지 않고 끊깁니다.
	Sfx.play_music()
	_setup_environment()
	_setup_camera()

	ui = Ui.new()
	add_child(ui)
	ui.boon_chosen.connect(_on_boon_chosen)
	ui.shop_bought.connect(_on_shop_bought)
	ui.shop_closed.connect(_close_overlay)
	ui.restart_requested.connect(start_run)
	ui.start_requested.connect(start_run)
	if ui.touch != null:
		ui.touch.attack_pressed.connect(_on_touch_attack)
		ui.touch.dash_pressed.connect(_on_touch_dash)
		ui.touch.grab_pressed.connect(_on_touch_grab)
		ui.touch.grab_released.connect(_on_touch_grab_release)
		ui.touch.interact_pressed.connect(_do_interact)
	ui.toon_toggled.connect(toggle_toon)
	ui.grade_toggled.connect(toggle_grade)
	ui.test_requested.connect(start_test)
	ui.test_kind_picked.connect(_on_test_kind)
	ui.test_boons_requested.connect(_on_test_boons)
	ui.test_clear_requested.connect(_on_test_clear)
	ui.test_skill_picked.connect(_on_test_skill)
	ui.test_reset_requested.connect(start_test)
	ui.test_tiger_toggled.connect(_on_test_tiger)
	ui.quit_pressed.connect(_on_quit)
	ui.riglab_requested.connect(open_riglab)
	ui.cam_mode_toggled.connect(toggle_cam_mode)
	ui.cam_pitch_nudged.connect(nudge_cam_pitch)
	ui.set_cam_pitch(cam_pitch)   # UI 는 카메라보다 나중에 생깁니다

	world = Node3D.new()
	world.name = "World"
	add_child(world)

	if _seed != 0:
		rng.seed = _seed
	else:
		rng.randomize()
	phase = Phase.TITLE
	get_tree().paused = true
	ui.show_title()
	if _auto_start:
		call_deferred("start_run")


func _read_args() -> void:
	## --auto 로 제목 화면을 건너뛰고, --shot=<경로> 로 몇 프레임 뒤의 화면을
	## 파일로 남깁니다. 손으로 눌러 보지 않고도 회귀를 잡을 수 있습니다.
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			_auto_start = true
		elif a.begins_with("--shot="):
			_shot_path = a.substr(7)
			_auto_start = true
		elif a.begins_with("--shot-frame="):
			_shot_at = int(a.substr(13))
		elif a.begins_with("--floor="):
			_debug_floor = maxi(1, int(a.substr(8)))
			_auto_start = true
		elif a == "--toon":
			_toon_start = true
		elif a == "--no-toon":
			_toon_start = false
		elif a == "--grade":
			_grade_on = true
		elif a == "--no-grade":
			_grade_on = false
		elif a.begins_with("--push-lv="):
			_push_lv = int(a.substr(10))
		elif a == "--lean":
			# 폰과 같은 설정(글로우·그림자 없음)을 데스크톱에서 재려고 씁니다.
			_force_lean = true
		elif a == "--leak":
			_leak_probe = true
		elif a.begins_with("--side="):
			# 확인용 배치에 곁들이는 낱말. 지금은 벽 확인(`wallhug`)에서
			# 등 뒤 벽/가리는 벽을 고르는 데 씁니다.
			_probe_arg = a.substr(7)
		elif a.begins_with("--tiger="):
			# 고함 Lv5 의 호랑이를 옆얼굴/정면 중에 고릅니다. 둘 다 남겨 두고
			# 화면에서 견줍니다.
			Fx.face_front = a.substr(8) != "side"
		elif a == "--teacher-here":
			_teacher_here = true
			_auto_start = true
		elif a.begins_with("--trace-at="):
			_trace_at = int(a.substr(11))
		elif a == "--fps-log":
			_fps_log = true
		elif a.begins_with("--pose="):
			_pose = a.substr(7)
		elif a.begins_with("--boon="):
			# 축복을 미리 걸고 시작합니다(쉼표로 여럿). 성격을 바꾸는 축복은
			# 뽑기로 기다리면 확인이 안 됩니다.
			_forced_boons = a.substr(7).split(",", false)
		elif a == "--shoulder":
			# 어깨 너머 시점으로 시작합니다.
			_start_shoulder = true
		elif a.begins_with("--motion="):
			# 실험실의 동작 크기 슬라이더를 그 값으로 열어 둡니다. 두 값을
			# 비교할 때 손으로 맞추면 같은 값인지 알 수 없습니다.
			_lab_motion = float(a.substr(9))
		elif a.begins_with("--char="):
			# 실험실을 그 캐릭터로 엽니다(0=도원 1=서진 2=블랙 3=선생님).
			_lab_char = int(a.substr(7))
		elif a.begins_with("--clip="):
			# 실험실을 그 동작으로 열어 둡니다(Idle/Walk/Run/Push).
			_lab_clip = a.substr(7)
		elif a.begins_with("--hip="):
			# 실험실을 그 골반 값으로 열어 둡니다. 화면으로 비교할 때
			# 슬라이더를 손으로 맞추면 두 장이 같은 값인지 알 수 없습니다.
			_lab_hip = float(a.substr(6))
		elif a.begins_with("--prop="):
			_shelf_kind = a.substr(7)
		elif a.begins_with("--foe="):
			_stride_kind = a.substr(6)
			_auto_start = true
		elif a.begins_with("--die-at="):
			_die_at = int(a.substr(9))
			_auto_start = true
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
		elif a.begins_with("--ui="):
			_debug_ui = a.substr(5)
			_auto_start = true
		elif a == "--bot":
			_bot = true
			_auto_start = true
		elif a.begins_with("--face="):
			var yaw := deg_to_rad(float(a.substr(7)))
			debug_aim = Vector3(-sin(yaw), 0.0, -cos(yaw))
		elif a.begins_with("--pitch="):
			_cam_pitch = float(a.substr(8))
		elif a.begins_with("--cam="):
			_cam_mult = float(a.substr(6))
		elif a.begins_with("--quit-after="):
			_quit_at = int(a.substr(13))
			_auto_start = true


# ---------------------------------------------------------------- 준비

func _setup_input() -> void:
	## 코드로 등록합니다. project.godot 의 입력 맵은 형식이 버전마다 달라
	## 손으로 적기에 부서지기 쉽고, 여기 두면 키 목록이 한눈에 보입니다.
	var bind := func(action: String, keys: Array, buttons: Array = []) -> void:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.2)
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k     # 물리 위치 기준이라 자판 배열과 무관합니다
			InputMap.action_add_event(action, ev)
		for b in buttons:
			var mb := InputEventMouseButton.new()
			mb.button_index = b
			InputMap.action_add_event(action, mb)

	bind.call("move_up", [KEY_W, KEY_UP])
	bind.call("move_down", [KEY_S, KEY_DOWN])
	bind.call("move_left", [KEY_A, KEY_LEFT])
	bind.call("move_right", [KEY_D, KEY_RIGHT])
	bind.call("attack", [KEY_J], [MOUSE_BUTTON_LEFT])
	bind.call("dash", [KEY_SPACE, KEY_K], [MOUSE_BUTTON_RIGHT])
	bind.call("grab", [KEY_F, KEY_L], [MOUSE_BUTTON_MIDDLE])
	bind.call("toon", [KEY_T])
	bind.call("cam_up", [KEY_BRACKETRIGHT, KEY_PAGEUP])
	bind.call("cam_down", [KEY_BRACKETLEFT, KEY_PAGEDOWN])
	bind.call("interact", [KEY_E])
	bind.call("pause", [KEY_ESCAPE])
	bind.call("help", [KEY_F1])
	bind.call("restart", [KEY_R])
	bind.call("confirm", [KEY_ENTER, KEY_KP_ENTER])
	bind.call("slot1", [KEY_1])
	bind.call("slot2", [KEY_2])
	bind.call("slot3", [KEY_3])


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.085, 0.072)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.56, 0.46)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.6
	# 먼 방을 흐리게 깔아 두면 깊이가 생기고, 아직 못 간 곳이 남습니다.
	# 색이 중요합니다 - 푸른 안개는 차가운 지하실이 되고, 따뜻한 갈색 안개는
	# 저녁 빛이 도는 실내가 됩니다. 에셋이 전부 수채화라 뒤쪽입니다.
	env.fog_enabled = true
	env.fog_light_color = Color(0.24, 0.19, 0.14)
	env.fog_density = 0.0045
	# 폰과 웹(Compatibility 렌더러)에서는 후처리를 끕니다. 글로우는 화면 전체를
	# 여러 번 다시 그리는 작업이라, 폰에서 프레임을 가장 많이 잡아먹습니다.
	var lean := _force_lean or OS.has_feature("web") or OS.has_feature("mobile")
	# **폰에서는 초당 60장에서 멈춥니다.**
	#
	# 아무것도 안 걸어 두면 기기가 낼 수 있는 만큼 냅니다 - 120Hz 화면이면
	# 두 배를 그리고, 그 몫이 그대로 열이 됩니다. 오래 할수록 뜨거워지고,
	# 뜨거워지면 기기가 스스로 성능을 낮춰서 **나중에 느려집니다.**
	# 이 게임은 60장이면 충분합니다(물리도 60Hz 입니다).
	if lean:
		Engine.max_fps = 60
	env.glow_enabled = not lean
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15

	world_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	# 해를 조금 더 세웁니다(-62 -> -70). 비스듬할수록 그림자가 발이 아니라
	# 옆으로 길게 눕습니다. 데스크톱에서만 보이는 그림자이지만, 발밑 그림자
	# (Models.add_shadow)와 방향이 어긋나면 둘이 따로 놉니다.
	sun.rotation_degrees = Vector3(-70, 38, 0)
	sun.light_energy = 0.80
	sun.light_color = Color(1.00, 0.93, 0.78)
	# 그림자도 같은 이유로 끕니다. 방마다 놓은 점광원이 분위기를 만들고 있어
	# 그림자가 없어도 평평해 보이지 않습니다.
	sun.shadow_enabled = not lean
	add_child(sun)


func _setup_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.name = "CamRig"
	add_child(cam_rig)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.far = 220.0
	cam_rig.add_child(camera)
	set_cam_pitch(absf(_cam_pitch) if _cam_pitch != 0.0 else absf(CAM_PITCH))
	if _start_shoulder:
		call_deferred("set_cam_mode", CamMode.SHOULDER)


func _drive_shoulder(delta: float) -> void:
	## 어깨 너머 카메라. 몸이 보는 쪽 **뒤에** 섭니다.
	##
	## 따로 시점 조작을 두지 않았습니다. 폰에서는 엄지가 둘뿐이고 하나는
	## 이동, 하나는 버튼에 가 있어서, 시점을 맡길 손가락이 없습니다.
	## 대신 카메라가 몸을 따라 돌므로 **가는 쪽이 곧 보는 쪽**입니다.
	var want_yaw: float = player.pivot.rotation.y if player.pivot != null else 0.0
	cam_rig.rotation.y = lerp_angle(cam_rig.rotation.y, want_yaw,
		1.0 - exp(-SHOULDER_TURN * delta))

	# 벽 안으로 들어가지 않게 앞으로 당겨 옵니다. 복도가 3m 폭이라 뒤로 3m 를
	# 그냥 두면 카메라가 자주 벽 속에 박히고, 그러면 화면이 통째로 벽 색이
	# 됩니다.
	var basis := cam_rig.global_transform.basis
	# 카메라가 실제로 서는 자리에서 쏩니다 - 옆으로 비켜선 만큼도 함께
	# 세지 않으면, 몸은 통로 가운데인데 카메라만 벽 속인 경우를 놓칩니다.
	var head := player.global_position + Vector3(0, SHOULDER_HEIGHT, 0) 		+ basis.x * SHOULDER_SIDE
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(head, head + basis.z * SHOULDER_DIST)
	q.collision_mask = 1                            # 벽/바닥만
	var hit := space.intersect_ray(q)
	var dist := SHOULDER_DIST
	if not hit.is_empty():
		# **너무 붙이지는 않습니다.** 벽에 몰렸다고 0.8m 까지 당기면 뒤통수가
		# 화면의 절반을 덮어, 벽에 파묻히는 것보다 오히려 안 보입니다.
		dist = maxf(SHOULDER_MIN, head.distance_to(hit["position"]) - SHOULDER_CLEAR)
	camera.position = Vector3(SHOULDER_SIDE, SHOULDER_HEIGHT, dist)


func set_cam_pitch(degrees: float) -> void:
	## 내려다보는 각도를 바꿉니다. **거리는 건드리지 않습니다** - 각도만
	## 움직이면 캐릭터 크기는 그대로이고 벽에 가리는 정도만 달라집니다.
	## 거리까지 같이 바꾸면 각도를 조절할 때마다 캐릭터가 커졌다 작아져서,
	## 무엇을 조절하고 있는지 알 수 없게 됩니다.
	cam_pitch = clampf(degrees, CAM_PITCH_MIN, CAM_PITCH_MAX)
	var dist := CAM_OFFSET.length() * _cam_mult
	var rad := deg_to_rad(cam_pitch)
	camera.position = Vector3(0.0, dist * sin(rad), dist * cos(rad))
	camera.rotation_degrees = Vector3(-cam_pitch, 0, 0)
	if ui != null:
		ui.set_cam_pitch(cam_pitch)


func nudge_cam_pitch(steps: float) -> void:
	set_cam_pitch(cam_pitch + steps * CAM_PITCH_STEP)
	ui.toast("시야 각도 %d도" % roundi(cam_pitch), UiTheme.DIM)


# ---------------------------------------------------------------- 진행

func start_run() -> void:
	# 앞 판의 녹화가 아직 돌고 있으면 여기서 끊어 저장합니다. 그대로 두고 새
	# 판을 시작하면 두 판이 한 영상에 이어 붙습니다.
	Recorder.stop()
	# 녹화는 **고른 그 한 판만** 입니다. 여기서 꺼 두지 않으면 죽고 다시
	# 도전할 때마다 저절로 다시 녹화돼, 방금 남긴 영상이 덮여 사라집니다.
	if Recorder.armed:
		Recorder.armed = false
		if not Recorder.start():
			ui.toast("녹화를 시작하지 못했습니다", UiTheme.BAD)
	test_mode = false
	_test_kind = ""
	state = RunState.new()
	_boon_names.clear()
	for forced in _forced_boons:
		state.apply_boon(forced)
	# HUD 는 스킬 이름이 아니라 **계통 Lv** 을 보여 줍니다. 강제로 건 것도
	# 같은 자리에서 뽑아야 화면과 실제가 어긋나지 않습니다.
	_boon_names = state.skill_summary()
	if _seed != 0:
		rng.seed = _seed
	else:
		rng.randomize()
	if _debug_floor > 1:
		# 깊은 층을 바로 확인할 때. 그 층까지 살아서 온 것처럼 능력치도 올립니다.
		state.floor_num = _debug_floor
		for _i in range(_debug_floor - 1):
			state.apply_boon(String(RunState.BOONS[rng.randi_range(0, RunState.BOONS.size() - 1)]["id"]))
	_close_overlay()
	build_floor()
	ui.toast("지하 %d층" % state.floor_num, UiTheme.ACCENT)


func start_test() -> void:
	## 실험용 방으로 들어갑니다. 업데이트가 제대로 됐는지 보는 자리입니다.
	test_mode = true
	_test_kind = ""
	_test_timer = 0.0
	Recorder.armed = false
	state = RunState.new()
	_boon_names = state.skill_summary()
	rng.randomize()
	# **제목 화면을 닫습니다.** start_run 은 이 줄을 부르는데 여기만 빠져
	# 있어서, 테스트 방에 들어가도 시작 메뉴가 그대로 덮고 있었습니다.
	_close_overlay()
	build_floor()
	ui.toast("테스트 방 - 왼쪽에서 적과 스킬을 고르세요", UiTheme.ACCENT)


func _on_test_kind(kind: String) -> void:
	_test_kind = kind
	_test_timer = 0.0
	ui.set_test_kind(kind)


func _on_test_clear() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if is_instance_valid(e):
			e.queue_free()
	_alive = 0


func _on_test_tiger() -> void:
	Fx.face_front = not Fx.face_front
	ui.set_tiger_face(Fx.face_front)
	ui.toast("호랑이 " + ("정면" if Fx.face_front else "옆얼굴"), UiTheme.ACCENT)


func _on_test_skill(family: String) -> void:
	## 그 계통을 **한 단계** 올립니다. 고르기 화면을 거치지 않습니다.
	if not test_mode:
		return
	var picked := state.apply_family(family, rng)
	if picked == "":
		return
	_boon_names = state.skill_summary()
	ui.set_boons(_boon_names)
	ui.set_test_skills(_boon_names)
	ui.toast("%s Lv%d - %s" % [
		RunState.FAMILY_NAME.get(family, family),
		state.family_level(family), picked], UiTheme.GOOD)


func _on_test_boons() -> void:
	## 실험용 방에서는 **몇 번이든** 스킬을 찍습니다.
	if phase != Phase.PLAYING:
		return
	_boon_from_shelf = true      # 층을 새로 짓지 않는 쪽으로 갑니다
	_boon_options = _label_boons(state.offer_boons(rng))
	phase = Phase.BOON
	get_tree().paused = true
	ui.show_boons(_boon_options, "무엇을 익힐까", "실험용이라 몇 번이든 고를 수 있습니다.")


func _drive_test_spawns(delta: float) -> void:
	## 고른 적을 시간마다 다시 내보냅니다. 한 번에 셋까지만 둡니다 - 실험은
	## 하나를 자세히 보는 일이라, 떼로 몰리면 무엇 때문인지 알 수 없습니다.
	if not test_mode or _test_kind == "" or phase != Phase.PLAYING:
		return
	if not is_instance_valid(player) or dungeon == null:
		return
	_test_timer -= delta
	if _test_timer > 0.0:
		return
	var alive := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			alive += 1
	if alive >= TEST_ALIVE:
		return
	_test_timer = TEST_GAP
	var e := Enemy.new()
	world.add_child(e)
	e.setup(_test_kind, state.floor_num, dungeon, player)
	# 방 안 아무 데나, 다만 **주인공에게서 떨어진** 자리에 냅니다. 발밑에서
	# 솟으면 무엇이 일어났는지 볼 틈이 없습니다.
	for _i in 12:
		var at := dungeon.random_point_in_room(0, rng)
		if at.distance_to(player.global_position) > 5.0:
			e.global_position = at
			break
		e.global_position = at
	e.died.connect(_on_enemy_died)
	# **새로 나온 적에게도 카툰을 걸어 줍니다.** 층을 지을 때 한 번만 걸면
	# 그 뒤에 나온 적은 테두리 없이 남습니다.
	Toon.refresh(e)
	_alive += 1


func build_floor() -> void:
	for c in world.get_children():
		world.remove_child(c)
		c.queue_free()
	portal = null
	shop = null
	_alive = 0

	dungeon = Dungeon.new()
	dungeon.name = "Dungeon"
	world.add_child(dungeon)
	if test_mode:
		dungeon.generate_test_room(rng)
	else:
		dungeon.generate(state.floor_num, rng)

	player = Player.new()
	player.name = "Player"
	world.add_child(player)
	player.setup(state, rng)
	player.breath_empty.connect(_on_breath_empty)
	player.ultimate_changed.connect(_on_ultimate)
	player.bot_active = _bot
	# 폰에서는 마우스가 없으니 가장 가까운 적을 자동으로 겨눕니다.
	player.auto_aim = ui.touch != null and DisplayServer.is_touchscreen_available()
	player.global_position = dungeon.room_center(0)
	player.died.connect(_on_player_died)
	player.read_done.connect(_on_read_done)

	cam_rig.global_position = player.global_position

	if test_mode:
		# 실험용 방에는 출구도 상점도 소품도 두지 않습니다. 보려는 것 하나만
		# 남기는 것이 이 방의 전부입니다.
		ui.set_minimap(dungeon, player.global_position, player.global_position)
		ui.set_boons(_boon_names)
		if _toon_start and not Toon.enabled:
			Toon.apply(world, world_env, true)
		ui.set_toon(Toon.enabled)
		ui.set_color_grade(_grade_on)
		ui.set_grade_label(_grade_on)
		Toon.refresh(world)
		ui.set_hud_visible(true)
		ui.set_test_panel(true)
		ui.set_test_kind(_test_kind)
		ui.set_test_skills(_boon_names)
		ui.set_tiger_face(Fx.face_front)
		phase = Phase.PLAYING
		get_tree().paused = false
		return

	# 마지막 방이 시작 방에서 가장 멉니다. 출구를 거기 두면 층 전체를 훑게 됩니다.
	var exit_room := dungeon.rooms.size() - 1
	portal = Portal.new()
	world.add_child(portal)
	portal.global_position = dungeon.room_center(exit_room)
	portal.entered.connect(_on_portal_entered)

	# 상점은 시작 방과 출구 사이 어딘가. 1층에는 두지 않습니다 - 살 금화가 없습니다.
	var shop_room := -1
	if state.floor_num >= 2 and dungeon.rooms.size() >= 4:
		shop_room = rng.randi_range(1, dungeon.rooms.size() - 2)
		shop = Shopkeeper.new()
		world.add_child(shop)
		shop.global_position = dungeon.room_center(shop_room)

	_spawn_enemies(exit_room, shop_room)
	_place_teacher(exit_room)
	_scatter_props()
	# 방이 하나뿐인 층이 나오면 적을 놓을 곳이 없습니다. 그때 문이 잠긴 채로
	# 남으면 나갈 방법이 사라지므로, 처음부터 비어 있으면 열어 둡니다.
	if _alive == 0:
		portal.unlock()
	_bot_shopped = false
	if _bot:
		print("[bot] 지하 %d층 시작 - 적 %d, 방 %d" % [state.floor_num, _alive, dungeon.rooms.size()])
	ui.set_test_panel(false)
	# 시작 자리도 같이 넘깁니다 - 층을 지을 때의 주인공 자리입니다.
	ui.set_minimap(dungeon, portal.global_position, player.global_position)
	ui.set_boons(_boon_names)
	# 층이 통째로 새로 만들어지므로 새 메시에도 다시 걸어야 합니다.
	if _toon_start and not Toon.enabled:
		Toon.apply(world, world_env, true)
	ui.set_toon(Toon.enabled)
	ui.set_color_grade(_grade_on)
	ui.set_grade_label(_grade_on)
	Toon.refresh(world)   # 켜져 있을 때만 다시 겁니다(toon.gd)
	Fx.warm_up(world)
	ui.set_hud_visible(true)
	phase = Phase.PLAYING
	get_tree().paused = false
	if _debug_ui != "":
		call_deferred("_show_debug_ui")


func _spawn_enemies(exit_room: int, shop_room: int) -> void:
	## 방마다 조금씩. 한 방에 몰아넣으면 나머지 방이 빈 복도가 됩니다.
	var budget := 4 + state.floor_num * 2
	var rooms_available: Array[int] = []
	for i in range(1, dungeon.rooms.size()):
		if i != shop_room:
			rooms_available.append(i)
	if rooms_available.is_empty():
		return

	var pool := _kind_pool()
	var per_room := maxi(1, int(ceil(float(budget) / float(rooms_available.size()))))
	var placed := 0
	for room in rooms_available:
		var n := mini(per_room, budget - placed)
		# 출구 방은 마지막 관문이라 조금 더 둡니다.
		if room == exit_room:
			n += 1
		for _i in range(n):
			var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
			var e := Enemy.new()
			world.add_child(e)
			e.setup(kind, state.floor_num, dungeon, player)
			e.global_position = dungeon.random_point_in_room(room, rng)
			e.died.connect(_on_enemy_died)
			_alive += 1
			placed += 1
		if placed >= budget:
			break


func _kind_pool() -> Array:
	## 층이 오를수록 종류가 늘어납니다. 처음부터 다 나오면 배울 틈이 없습니다.
	##
	## 선생님은 여기 넣지 않습니다 - 뽑기로 나오면 한 층에 셋씩 나올 수도 있고,
	## 그러면 관문이 아니라 잡몹이 됩니다. 배치는 _spawn_enemies 가 직접 합니다.
	## 새 종류는 **한 층에 하나씩** 들어옵니다. 두 가지를 같은 층에서 처음
	## 만나면 어느 쪽 때문에 죽었는지 알 수 없어, 배우는 대신 외우게 됩니다.
	var pool := ["grunt", "grunt", "grunt"]
	if state.floor_num >= 2:
		pool.append("spitter")
		pool.append("screamer")
	if state.floor_num >= 3:
		pool.append("brute")
		pool.append("spitter")
	if state.floor_num >= 4:
		# 붙잡는 아이는 **혼자서는 약합니다.** 다른 적이 여럿 있어야 위협이
		# 되므로, 방에 둘셋씩 서기 시작하는 층부터 넣습니다.
		pool.append("clinger")
		pool.append("screamer")
	if state.floor_num >= 5:
		pool.append("brute")
		# 베개는 "뒤로 돌아가라" 를 묻는 적입니다. 구르기와 고함의 쓰임을
		# 어느 정도 익힌 뒤라야 그 질문에 답이 있습니다.
		pool.append("pillow")
	if state.floor_num >= 7:
		pool.append("clinger")
		pool.append("pillow")
	return pool


func _scatter_props() -> void:
	## 방마다 소품을 흩습니다.
	##
	## 방 한가운데는 비워 둡니다 - 시작 지점·출구·상인이 거기 서고, 소품이
	## 겹치면 나오자마자 물건에 걸립니다. 복도에도 두지 않습니다: 폭이 2칸
	## 뿐이라 굴러온 소품 하나가 길을 막으면 갈 곳이 없어집니다.
	# 마시는 것은 뽑기에서 뺍니다. 같이 두면 종류 수만큼(1/10) 나와서 층마다
	# 서너 개씩 굴러다니고, 그러면 체력이 자원이 아니라 배경이 됩니다.
	# 층마다 새로 셉니다. 안 비우면 아래층에서 벽 자리가 점점 줄어듭니다.
	_wall_taken.clear()
	var kinds := []
	for k in Prop.KINDS:
		# 마시는 것과 붙박이는 뽑기에서 뺍니다. 같이 두면 종류 수만큼 나와서
		# 층마다 서너 개씩 굴러다닙니다 - 회복은 자원이 아니라 배경이 되고,
		# 풀장은 방을 가로막는 장애물이 됩니다. 개수를 직접 정합니다.
		var st: Dictionary = Prop.KINDS[k]
		if st.has("heal") or String(st.get("class", "")) == "fixed":
			continue
		kinds.append(k)
	for room in dungeon.rooms.size():
		var count := rng.randi_range(2, 5)
		for _i in count:
			var at := dungeon.random_point_in_room(room, rng)
			if at.distance_to(dungeon.room_center(room)) < 2.2:
				continue
			var prop := Prop.new()
			world.add_child(prop)
			prop.setup(String(kinds[rng.randi_range(0, kinds.size() - 1)]))
			# 살짝 띄워 놓으면 물리가 알아서 바닥에 앉힙니다. 정확한 높이를
			# 계산하는 것보다 이쪽이 소품 종류에 상관없이 맞습니다.
			prop.global_position = at + Vector3(0, 0.45, 0)
			prop.rotation.y = rng.randf() * TAU

	_scatter_fixed_count("milk", 2)
	# 풀장은 방 하나에 하나면 충분합니다. 몸으로 부딪히는 물건이라
	# 여러 개를 흩으면 방이 통로가 됩니다.
	_scatter_fixed_count("pool", 1)
	# 책장은 벽 가구라 여러 개 있어도 방을 막지 않습니다.
	_scatter_fixed_count("bookshelf", 3)
	# 액자는 벽 위쪽이라 바닥을 차지하지 않습니다. 방마다 하나쯤 보이도록.
	_scatter_fixed_count("frame", 2)
	_scatter_fixed_count("frame2", 2)
	# 시계는 방마다 하나면 충분합니다.
	_scatter_fixed_count("clock", 1)

	# assets/source 에서 구운 보육원 가구. 서 있는 것은 벽에, 깔리는 것은
	# 바닥에 놓입니다(자리 고르는 법은 `wants_wall` 이 가릅니다).
	#
	# 한 종류를 여럿 두지 않습니다. 옷장 세 개가 한 방에 서 있으면 보육원이
	# 아니라 창고입니다 - 종류가 여럿인 편이 같은 개수로 방이 다양해집니다.
	_scatter_fixed_count("wardrobe", 1)
	_scatter_fixed_count("toyshelf", 1)
	_scatter_fixed_count("kidcloset", 1)
	# 미끄럼틀은 방 안에 섭니다. 큰 물건이라 하나면 충분하고, 들어갈 고리가
	# 없는 작은 방은 `_spot_for` 가 알아서 건너뜁니다.
	_scatter_fixed_count("slide", 1)
	# 깔리는 것은 막지 않으므로 여럿이어도 길을 좁히지 않습니다.
	_scatter_fixed_count("rug", 2)
	_scatter_fixed_count("playmat", 1)
	_scatter_traps()


func _scatter_fixed_count(kind: String, count: int) -> void:
	## 개수를 직접 정해 놓는 소품들. 뽑기에 섞으면 종류 수만큼 나와서
	## 곤란한 것들입니다(우유·풀장).
	##
	## 개수를 층에 따라 늘리지 않습니다. 적은 층마다 늘어나므로, 회복이
	## 그대로 있으면 아래층으로 갈수록 저절로 빡빡해집니다 - 난이도 곡선을
	## 적 쪽에서만 만들고 회복은 고정해 두는 편이 조절하기 쉽습니다.
	##
	## 시작 방(0번)은 건너뜁니다. 나오자마자 마시면 아직 안 깎인 체력을
	## 채우는 것이고, 시작하자마자 길을 막는 풀장도 반갑지 않습니다.
	if dungeon.rooms.size() < 2:
		return
	for _i in count:
		var item := Prop.new()
		world.add_child(item)
		item.setup(kind)
		# 놓을 자리를 **물건 크기에 맞춰** 고릅니다. 작은 것(우유)은 아무
		# 데나 되지만, 풀장은 반지름이 1.8m 라 벽에서 그만큼 떨어진 자리가
		# 아니면 벽을 뚫고 박힙니다 - 얼린 물건은 밀려나 빠지지도 못합니다.
		# 벽에 붙는 것과 방 안에 놓는 것은 자리를 고르는 법이 다릅니다.
		var at: Variant = null
		if item.wants_wall():
			var spot: Variant = _spot_on_wall(item.depth())
			if spot != null:
				at = (spot as Array)[0]
				item.rotation.y = float((spot as Array)[1])
		else:
			at = _spot_for(item.footprint_radius())
		if at == null:
			item.queue_free()
			continue
		# 얼린 물건은 **중력을 안 받습니다.** 다른 소품처럼 띄워 놓고 물리에
		# 맡기면 그 자리에 그대로 떠 있습니다 - 붙박이만 바닥에 바로 놓습니다.
		# 벽에 걸리는 것은 그 높이로, 붙박이는 바닥에, 나머지는 살짝 띄워서
		# 물리가 앉히게 둡니다.
		var lift := 0.0 if Prop.KINDS[kind].get("class", "") == "fixed" else 0.45
		if item.mount_height() > 0.0:
			lift = item.mount_height()
		item.global_position = (at as Vector3) + Vector3(0, lift, 0)
		if not item.wants_wall():
			item.rotation.y = rng.randf() * TAU


## 이번 층에서 이미 가구가 선 벽 칸. 안 보면 옷장과 책장이 같은 자리에
## 겹쳐 서서 한 덩어리가 됩니다 - 예전에는 책장 셋뿐이라 잘 안 드러났는데,
## 벽 가구가 여섯으로 늘면서 눈에 띕니다.
var _wall_taken := {}


func _spot_on_wall(depth: float):
	## 벽에 등을 붙일 자리. [위치, 각도] 이고, 없으면 null 입니다.
	##
	## 방은 네모로 파낸 것이라 **테두리 칸**이 곧 벽에 닿은 칸입니다. 다만
	## 복도가 뚫린 자리는 벽이 아니므로, 바깥쪽 칸이 실제로 막혀 있는지
	## 봅니다 - 안 보면 문간을 책장으로 막습니다.
	var order: Array[int] = []
	for i in range(1, dungeon.rooms.size()):
		order.append(i)
	order.shuffle()
	## 바깥쪽 네 방향. 칸 단위입니다.
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for room in order:
		var rect: Rect2i = dungeon.rooms[room]
		for _t in 30:
			var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1),
				rng.randi_range(rect.position.y, rect.end.y - 1))
			if dungeon.is_solid(c.x, c.y):
				continue
			var d: Vector2i = dirs[rng.randi_range(0, 3)]
			if not dungeon.is_solid(c.x + d.x, c.y + d.y):
				continue          # 그쪽은 벽이 아닙니다
			# 벽을 따라 옆으로도 이어져 있어야 합니다. 모서리나 문간에 놓으면
			# 책장이 벽을 비스듬히 뚫고 나옵니다.
			var side := Vector2i(d.y, d.x)
			if dungeon.is_solid(c.x + side.x, c.y + side.y) 					or dungeon.is_solid(c.x - side.x, c.y - side.y):
				continue
			# 자기 칸과 **양옆 한 칸씩**을 봅니다. 가구는 한 칸(1.5m)보다
			# 넓은 것이 많아서, 붙은 칸에 나란히 세우면 서로 파고듭니다.
			if _wall_taken.has(c) or _wall_taken.has(c + side) or _wall_taken.has(c - side):
				continue
			_wall_taken[c] = true
			var face := Vector3(float(d.x), 0.0, float(d.y)).normalized()
			# 칸 가운데는 벽면에서 반 칸(0.75m) 떨어져 있습니다. 등이 벽에
			# 닿도록 그만큼에서 두께의 절반을 뺀 만큼 밀어 넣습니다.
			var at: Vector3 = dungeon.cell_to_world(c) 				+ face * maxf(Dungeon.TILE * 0.5 - depth * 0.5, 0.0)
			# 책장의 **앞면이 +Z** 입니다. 방 쪽을 보게 돌립니다.
			#
			# Godot 의 관습은 -Z 가 앞이지만 이 메시는 반대입니다 - 텍스처를
			# 재서 확인했습니다(+Z 쪽 정점의 12%가 나무색이 아닌 책 색,
			# -Z 쪽은 0%). 눈으로는 두 면이 다 갈색 상자라 구분이 안 됩니다.
			#
			# yaw 에서 +Z 는 월드로 (sin yaw, 0, cos yaw) 입니다. 그것이
			# -face(벽 반대쪽)와 같아야 하므로 yaw = atan2(-face.x, -face.z).
			var yaw := atan2(-face.x, -face.z)
			return [at, yaw]
	return null


func _scatter_traps() -> void:
	## 함정을 흩습니다. 층이 깊어질수록 조금씩 늘어납니다.
	##
	## 시작 방은 건너뜁니다 - 나오자마자 밟는 함정은 배울 기회가 아니라
	## 그냥 손해입니다. 방 한가운데도 비워 둡니다(출구·상인 자리).
	if dungeon.rooms.size() < 2:
		return
	var count := 2 + state.floor_num / 2
	var kinds := ["tack", "tack", "puddle"]
	for _i in count:
		var room := rng.randi_range(1, dungeon.rooms.size() - 1)
		var at := dungeon.random_point_in_room(room, rng)
		if at.distance_to(dungeon.room_center(room)) < 2.4:
			continue
		var trap := Trap.new()
		world.add_child(trap)
		trap.setup(String(kinds[rng.randi_range(0, kinds.size() - 1)]), rng)
		trap.global_position = at


func _spot_for(radius: float):
	## 반지름 `radius` 짜리가 통째로 들어가는 자리. 없으면 null 입니다.
	##
	## 방 한가운데(2.2m)는 늘 비워 둡니다 - 시작 지점·출구·상인이 서는
	## 자리입니다. 그래서 큰 물건은 **가운데도 벽도 아닌 고리 안**에만
	## 들어가고, 작은 방에서는 그 고리가 아예 없을 수도 있습니다.
	var order: Array[int] = []
	for i in range(1, dungeon.rooms.size()):
		order.append(i)
	order.shuffle()
	for room in order:
		var rect: Rect2i = dungeon.rooms[room]
		# 방의 절반 크기에서 벽 한 칸을 뺀 것이 실제로 설 수 있는 범위입니다.
		var half_span := float(mini(rect.size.x, rect.size.y)) * Dungeon.TILE * 0.5
		var half := half_span - Dungeon.TILE
		if half - radius < 2.2:
			continue          # 이 방에는 들어갈 고리가 없습니다
		var center := dungeon.room_center(room)
		for _t in 12:
			var at := dungeon.random_point_in_room(room, rng)
			var d := at.distance_to(center)
			if d >= 2.2 and d + radius <= half:
				return at
	return null


func _place_teacher(exit_room: int) -> void:
	## 선생님은 3층부터, 출구 방에 **한 명만** 섭니다.
	##
	## 층마다 마지막에 넘어야 할 벽이 하나 있어야 층이 기억에 남습니다. 출구
	## 방에 두면 "다 왔다" 싶을 때 마주치게 되고, 한 명뿐이라 다른 적과 섞여
	## 흐려지지 않습니다.
	if not _teacher_here and (state.floor_num < 3 or dungeon.rooms.size() < 2):
		return
	if _teacher_here:
		exit_room = 0
	var teacher := Enemy.new()
	world.add_child(teacher)
	teacher.setup("teacher", state.floor_num, dungeon, player)
	teacher.global_position = dungeon.room_center(exit_room)
	if _teacher_here:
		# 시작 방의 한가운데는 플레이어가 서 있는 자리입니다. 겹쳐 놓으면
		# 충돌이 서로를 밀어내다 한쪽이 위로 튕겨 나갑니다(실제로 그랬습니다 -
		# 플레이어가 30m 상공에 떠 있었습니다).
		teacher.global_position += Vector3(3.0, 0.0, 0.0)
	teacher.died.connect(_on_enemy_died)
	_alive += 1


func _on_enemy_died(enemy: Enemy) -> void:
	_alive = maxi(0, _alive - 1)
	state.kills += 1
	var p := Pickup.new()
	world.add_child(p)
	p.setup(enemy.gold, enemy.global_position)
	if _alive == 0 and portal != null:
		portal.unlock()


func _on_portal_entered() -> void:
	if phase != Phase.PLAYING:
		return
	Sfx.play(Sfx.STAIRS, -5.0)
	state.floor_num += 1
	_boon_from_shelf = false
	_boon_options = _label_boons(state.offer_boons(rng))
	phase = Phase.BOON
	get_tree().paused = true
	ui.show_boons(_boon_options)


func _label_boons(options: Array) -> Array:
	## 고르는 화면에 쓸 값을 채워 넣습니다. 표(BOONS)에는 없고 지금 판에만
	## 있는 값이라(몇 번 찍었는지) 여기서 붙입니다.
	# **복사해서** 채웁니다. offer_boons 가 돌려주는 것은 상수 표(BOONS)의
	# 얕은 복사라, 그 사전에 직접 쓰면 상수를 고치는 셈입니다 - 판을 넘길수록
	# 값이 쌓이거나 엔진이 막습니다.
	var out: Array = []
	for opt in options:
		var copy: Dictionary = (opt as Dictionary).duplicate()
		copy["lv"] = state.level_of(String(copy["id"]))
		copy["family_name"] = RunState.FAMILY_NAME.get(
			String(copy.get("family", "")), "")
		out.append(copy)
	return out


func _on_boon_chosen(id: String) -> void:
	if phase != Phase.BOON:
		return
	state.apply_boon(id)
	Sfx.play(Sfx.PICK, -5.0)
	_boon_names = state.skill_summary()
	if test_mode:
		ui.set_test_skills(_boon_names)
	ui.hide_overlay()
	if _boon_from_shelf:
		# **책장에서 온 고르기는 층을 새로 짓지 않습니다.**
		#
		# 층 보상과 화면을 함께 쓰는 바람에 뒤처리까지 같이 돌았습니다 -
		# 책을 읽었을 뿐인데 방이 통째로 새로 그려지고 다음 층으로 넘어간
		# 것처럼 보였습니다. 읽은 자리에서 그대로 이어서 놉니다.
		_boon_from_shelf = false
		get_tree().paused = false
		phase = Phase.PLAYING
		ui.toast("스킬을 익혔다", UiTheme.ACCENT)
		return
	build_floor()
	ui.toast("지하 %d층" % state.floor_num, UiTheme.ACCENT)


func _on_record_stopped(reason: String) -> void:
	## 저 혼자 멈췄을 때만 옵니다 - 한도에 닿았거나 브라우저가 끊었거나.
	## 사람이 누른 정지는 UI 가 자기 자리에서 알립니다.
	if reason == "한도":
		ui.toast("%d분이 차서 녹화를 마쳤습니다 - 위의 공유 버튼으로 보내세요"
			% (Recorder.MAX_SEC / 60), UiTheme.ACCENT)
	else:
		ui.toast("녹화가 멈췄습니다 - %s" % reason, UiTheme.BAD)


func _on_player_died() -> void:
	phase = Phase.DEAD
	# 마지막 상태를 한 번 더 그립니다. 이걸 안 하면 체력이 가득 찬 채로
	# 쓰러진 화면이 남습니다 - HUD 갱신이 PLAYING 일 때만 돌기 때문입니다.
	ui.update_hud(state, _alive, 1.0)
	# 쓰러지는 모습을 잠깐 보여 준 뒤 결과를 띄웁니다. 즉시 덮으면 왜 죽었는지
	# 모른 채 화면만 바뀝니다.
	var t := get_tree().create_timer(1.1)
	t.timeout.connect(func() -> void:
		if phase == Phase.DEAD:
			get_tree().paused = true
			# 쓰러지는 장면까지 담고 끊습니다. 죽는 순간 끊으면 영상이 늘
			# 한창 싸우다 잘린 것처럼 끝나서, 남에게 보낼 것이 못 됩니다.
			ui.stop_recording()
			ui.show_death(state))


# ---------------------------------------------------------------- 상점

func _open_shop() -> void:
	_shop_items = state.shop_stock(rng)
	if _bot:
		var names: Array = []
		for item in _shop_items:
			names.append(item["name"])
		print("[bot] 상점 - 금화 %d, 재고 %s" % [state.gold, names])
	phase = Phase.SHOP
	get_tree().paused = true
	ui.show_shop(_shop_items, state.gold)


func _on_shop_bought(index: int) -> void:
	if phase != Phase.SHOP or index >= _shop_items.size():
		return
	var item: Dictionary = _shop_items[index]
	if item.get("sold", false):
		return
	if state.buy(item):
		ui.mark_sold(index)
		ui.refresh_shop(state.gold)
	else:
		ui.toast("금화가 모자랍니다", UiTheme.BAD)


func _close_overlay() -> void:
	ui.hide_overlay()
	if phase == Phase.SHOP or phase == Phase.PAUSED:
		phase = Phase.PLAYING
	if phase == Phase.PLAYING:
		get_tree().paused = false


# ---------------------------------------------------------------- 입력/루프

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help") and phase == Phase.PLAYING:
		phase = Phase.PAUSED
		get_tree().paused = true
		ui.show_help("도움말")
		return
	if event.is_action_pressed("pause"):
		match phase:
			Phase.PLAYING:
				phase = Phase.PAUSED
				get_tree().paused = true
				ui.show_help("일시정지")
			Phase.PAUSED, Phase.SHOP:
				_close_overlay()
		return
	if event.is_action_pressed("toon"):
		# 제목 화면에서는 **테스트 방**입니다. 아직 그릴 세계가 없어서
		# 카툰을 켜고 끌 것도 없습니다.
		if phase == Phase.TITLE:
			start_test()
		else:
			toggle_toon()
		return
	if event.is_action_pressed("cam_up"):
		nudge_cam_pitch(+1.0)
		return
	if event.is_action_pressed("cam_down"):
		nudge_cam_pitch(-1.0)
		return
	if event.is_action_pressed("restart") and phase == Phase.DEAD:
		start_run()
		return
	if _riglab != null:
		# 실험실이 열려 있는 동안에는 게임 조작을 받지 않습니다. 뒤에서
		# 판이 시작되면 무엇을 보고 있는지 알 수 없습니다.
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close_riglab()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R 			and phase == Phase.TITLE:
		open_riglab()
		return
	if event.is_action_pressed("confirm") and phase == Phase.TITLE:
		start_run()
		return
	if event.is_action_pressed("interact"):
		_do_interact()
		return

	var slot := -1
	if event.is_action_pressed("slot1"):
		slot = 0
	elif event.is_action_pressed("slot2"):
		slot = 1
	elif event.is_action_pressed("slot3"):
		slot = 2
	if slot < 0:
		return
	if phase == Phase.BOON and slot < _boon_options.size():
		_on_boon_chosen(String(_boon_options[slot]["id"]))
	elif phase == Phase.SHOP:
		_on_shop_bought(slot)


func _drive_pose_stride() -> void:
		# 걷기 클립이 1배속에서 **바닥을 얼마나 밀어내는지** 잽니다.
		# 심어진 발(뒤로 가는 쪽)의 뒷걸음 거리를 한 주기 동안 더하면
		# 그것이 곧 그 클립이 약속하는 이동 거리입니다.
		player.bot_active = true
		player.bot_move = Vector2(0, -1)
		if _stride_L == null:
			_stride_L = Models.add_anchor(player.body, "LeftFoot")
			_stride_R = Models.add_anchor(player.body, "RightFoot")
			return
		player.stride_probe = true
		var ap: AnimationPlayer = player._anim
		var which: String = player._run if _stride_run else player._walk
		if ap.current_animation != which:
			ap.play(which)
		ap.speed_scale = 1.0
		var basis_inv := player.pivot.global_transform.basis.inverse()
		var lz: float = (basis_inv * (_stride_L.global_position - player.global_position)).z
		var rz: float = (basis_inv * (_stride_R.global_position - player.global_position)).z
		if _stride_have:
			# 로컬 -Z 가 앞입니다. 뒤로 간다 = z 가 커진다.
			_stride_sum += maxf(maxf(lz - _stride_lz, rz - _stride_rz), 0.0)
		_stride_lz = lz
		_stride_rz = rz
		_stride_have = true
		_stride_frames += 1
		if _stride_frames == 240:
			var clip := ap.get_animation(ap.current_animation)
			print("STRIDE 클립=%s 길이=%.3f초 4초간_바닥거리=%.3fm -> 1배속 속도=%.3f m/s"
				% [ap.current_animation, clip.length, _stride_sum, _stride_sum / 4.0])


func _drive_pose() -> void:
	## 확인용. 한 동작만 계속 시킵니다.
	match _pose:
		"run":
			player.bot_active = true
			player.bot_move = Vector2(0, -1)
		"roll":
			player.bot_active = true
			player._roll_probe = _trace_at > 0
			# 옆으로 굴립니다. 앞뒤로 구르면 위에서 내려다보는 카메라에서는
			# 앞구르기인지 뒤구르기인지 구분이 안 됩니다.
			player.bot_move = Vector2(1, 0)
			# 동작(ROLL_TIME)보다 길게 둬야 꼬리(반동·복귀)까지 볼 수 있습니다.
			# 짧게 두면 끝나기 전에 다시 굴러 반동이 안 보입니다.
			state.dash_cooldown = 0.62
			player.dash()
		"shout":
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			player.attack()
		"float":
			# 머리 위에 뜨는 버그 확인용. 적을 공중에 올려 둔 채 잡습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _ram_foe == null:
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				_ram_foe.setup("grunt", 1, dungeon, player)
				_ram_foe.global_position = player.global_position + Vector3(0.7, 0, 0)
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
			if _frames == 20:
				# 공중에 띄웁니다(넉백으로 뜨는 상황을 흉내).
				_ram_foe.global_position += Vector3(0, 1.1, 0)
			if _frames == 26:
				player._take(_ram_foe)
			if _frames % 30 == 0 and _frames >= 30 and is_instance_valid(_ram_foe):
				print("[뜸] f=%d 적높이=%.2f 사람높이=%.2f 손에=%s" % [_frames,
					_ram_foe.global_position.y, player.global_position.y,
					str(player._held != null)])
		"knock":
			# 밀기 넉백 확인용. 적을 앞에 세우고 밀친 뒤 **간 거리**를 잽니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _ram_foe == null:
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				_ram_foe.setup("grunt", 1, dungeon, player)
				var fwd0 := -player.pivot.global_transform.basis.z
				_ram_foe.global_position = player.global_position + fwd0.normalized() * 1.0
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
			# 조준을 적에게 맞춰 둡니다. 확인용 실행에서는 마우스가 구석에
			# 있어 자동 조준이 안 걸립니다.
			if is_instance_valid(_ram_foe):
				var to_foe: Vector3 = _ram_foe.global_position - player.global_position
				to_foe.y = 0.0
				if to_foe.length() > 0.01:
					player.aim = to_foe.normalized()
			if _frames == 60:
				_knock_from = _ram_foe.global_position
				player.grab_press()
				print("[누름] f=%d 손에=%s 달려듦=%s 읽는중=%s 화면=%d 숨=%.0f 대기=%.2f" % [
					_frames, str(player._held != null), str(player._lunge_at != null),
					str(player.is_reading()), phase, state.breath, player._grab_cd])
			if _frames > 60 and _frames % 5 == 0 and is_instance_valid(_ram_foe):
				var flat: Vector3 = _ram_foe.global_position - _knock_from
				flat.y = 0.0
				print("[넉백] f=%d 간거리=%.2fm 속도=%.2fm/s" % [_frames, flat.length(),
					Vector3(_ram_foe.velocity.x, 0, _ram_foe.velocity.z).length()])
		"newprops":
			# 새로 구운 소품 확인용. 눈앞에 한 줄로 세워 놓고 봅니다.
			#
			# 던전에 흩어 놓고 찾아다니면 한 종류를 보는 데 여러 판이 걸립니다.
			if _frames == 4:
				var line := ["wardrobe", "toyshelf", "kidcloset", "slide",
					"rug", "playmat", "toybox", "ridecar"]
				var fwd := -player.global_transform.basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				var side := Vector3(fwd.z, 0.0, -fwd.x)
				for i in line.size():
					var it := Prop.new()
					world.add_child(it)
					it.setup(String(line[i]))
					# 두 줄로 놓습니다. 한 줄로 여덟이면 양끝이 화면 밖입니다.
					it.rotation.y = 0.0
					it.global_position = player.global_position 						+ fwd * (2.4 + float(i / 4) * 2.6) 						+ side * (float(i % 4) - 1.5) * 1.7
					print("[소품] %-10s 놓인크기 %.2f x %.2f x %.2f  붙박이=%s 깔림=%s" % [
						line[i], it._bounds().x * it.scale_of(),
						it.standing_height(), it._bounds().z * it.scale_of(),
						str(it.is_fixed()), str(it.is_flat())])
			player.bot_active = true
			player.bot_move = Vector2.ZERO
		"trap":
			# 함정 확인용. 눈앞에 압정과 웅덩이를 하나씩 놓고 밟아 봅니다.
			player.bot_active = true
			if _trap_a == null:
				var fwd0 := -player.pivot.global_transform.basis.z
				var side0 := Vector3(-fwd0.z, 0, fwd0.x)
				_trap_a = Trap.new()
				world.add_child(_trap_a)
				_trap_a.setup("tack", rng)
				_trap_a.global_position = player.global_position + side0.normalized() * 2.0
				var b2 := Trap.new()
				world.add_child(b2)
				b2.setup("puddle", rng)
				b2.global_position = player.global_position + fwd0.normalized() * 2.2
			# 압정 쪽으로 계속 걸어갑니다.
			player.bot_move = Vector2(0, -1)
			if _frames % 40 == 0 and _frames > 0:
				print("[함정] f=%d 체력=%.0f 미끄러짐=%.2f 압정높이=%+.2f" % [
					_frames, state.hp, player._slip,
					_trap_a._spikes[0].position.y if _trap_a._spikes.size() > 0 else 0.0])
		"stamina":
			# 연타 벌금 확인용. 앞 300프레임은 **밀기만** 연타하고, 그 뒤에는
			# 밀기·고함·구르기를 **번갈아** 씁니다. 값이 오르는지, 섞으면
			# 안 오르는지를 한 번에 봅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			state.breath = state.max_breath
			if _frames > 20 and _frames % 20 == 0:
				var before := state.breath
				if _frames <= 300:
					player.grab_press()
				else:
					match int(_frames / 20) % 3:
						0: player.grab_press()
						1: player.attack()
						_: player.dash()
				print("[숨] f=%d %s 든숨=%.1f (연타 %d번째)" % [
					_frames, "밀기만" if _frames <= 300 else "번갈아",
					before - state.breath, player._repeat_n])
		"perf":
			# 성능 표시를 켜 두고 찍습니다. 폰에서 읽을 글자라 화면에서
			# 실제로 읽히는지 봐야 합니다.
			if _frames == 20:
				ui._toggle_perf()
			player.bot_active = true
		"fxmap":
			# 이펙트 세기가 **찍은 스킬**을 따라가는지 봅니다.
			#
			#   --pose=fxmap --boon=lunge_reach,lunge_reach,lunge_reach
			#   --pose=fxmap --boon=shove_knock,shove_knock,shove_knock
			#
			# 앞쪽은 계통 Lv3 이지만 넉백을 안 찍었으니 잔상이 가장 적어야
			# 하고, 뒤쪽은 같은 Lv3 에 잔상이 늘어야 합니다.
			if _frames == 30:
				var st: RunState = state
				var knock: int = player._picks(st.shove_knock, 0.7)
				print("[이펙트] 밀기Lv%d 고함Lv%d 구르기Lv%d" % [
					st.family_level("push"), st.family_level("shout"),
					st.family_level("roll")])
				print("  밀기   넉백=%.1f 피해=%.2f -> 잔상 %d장(진하게=%s) 아지랑이 %d조각" % [
					st.shove_knock, st.shove_damage,
					clampi(2 + knock, 2, 6), str(st.shove_damage >= 0.8),
					clampi(6 + knock * 2, 6, 14)])
				print("  고함   경직=%.1f 돌풍=%.0f -> 구슬 %d개(맞은자리 폭발=%s)" % [
					st.shout_stun, st.shout_knock,
					clampi(5 + player._picks(st.shout_stun, 0.5) * 3, 5, 14),
					str(st.shout_knock > 0.0)])
				print("  구르기 뚫기=%.0f -> 밝은 잔상=%s" % [
					st.roll_pierce, str(st.roll_pierce > 0.0)])
			player.bot_active = true
			player.bot_move = Vector2.ZERO
		"crash":
			# **벽에 부딪히는 피해**를 잽니다. 적을 벽 앞에 세우고 벽 쪽으로
			# 밉니다 - 밀기만으로 들어간 피해와 부딪혀 더 들어간 피해가
			# 나뉘어 보이도록 체력을 프레임마다 찍습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _frames == 20:
				# 북쪽이 벽인 칸을 찾아 그 앞에 둘을 세웁니다.
				for y in range(2, 60):
					var done := false
					for x in range(2, 60):
						# 벽에 붙은 칸이면서 **아래 두 칸이 뚫려 있어야** 합니다.
						# 주인공이 설 자리가 없으면 벽 안에서 시작해 물리가
						# 튕겨 냅니다(처음에 속도 25m/s 가 나온 이유입니다).
						if dungeon.is_solid(x, y) or not dungeon.is_solid(x, y - 1):
							continue
						if dungeon.is_solid(x, y + 1) or dungeon.is_solid(x, y + 2):
							continue
						if dungeon.is_solid(x - 1, y) or dungeon.is_solid(x + 1, y):
							continue
						var spot: Vector3 = dungeon.cell_to_world(Vector2i(x, y))
						player.global_position = spot + Vector3(0, 0, 1.5)
						done = true
						break
					if done:
						break
			if _probe_foe == null and _frames > 22:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("grunt", 1, dungeon, player)
				_probe_foe.global_position = player.global_position + Vector3(0, 0, -1.2)
				_probe_foe.died.connect(_on_enemy_died)
				Toon.refresh(_probe_foe)
				_alive += 1
				# 벽 대신 **다른 적**에 부딪히는 것도 봅니다(--side=foe).
				if _probe_arg == "foe":
					_ram_foe = Enemy.new()
					world.add_child(_ram_foe)
					_ram_foe.setup("grunt", 1, dungeon, player)
					_ram_foe.global_position = player.global_position 						+ Vector3(0, 0, -2.1)
					_ram_foe.died.connect(_on_enemy_died)
					Toon.refresh(_ram_foe)
					_alive += 1
			if is_instance_valid(_probe_foe):
				player.aim = Vector3(0, 0, -1)
				if _probe_arg == "foe" and is_instance_valid(_ram_foe):
					# 맞는 쪽도 **길목에 붙잡아 둡니다.** 안 그러면 서로
					# 비켜서는 규칙(_avoid_crowd)에 밀려 옆으로 빠지고,
					# 밀린 몸이 그 뒤의 벽에 부딪힙니다.
					if _frames < 47:
						_ram_foe.global_position = player.global_position 							+ Vector3(0, 0, -2.0)
						_ram_foe.hp = 200.0
					if _frames % 10 == 0 and _frames > 45 and _frames < 90:
						print("[부딪힘] ↳ 맞은 적 체력=%.0f" % _ram_foe.hp)
				# 밀기 전까지는 **벽 앞에 붙잡아 둡니다.** 깨어 있어야
				# 이쪽을 보고, 그래야 잡기가 아니라 밀기가 나갑니다
				# (등 뒤에서 닿으면 잡힙니다 - 처음에 그래서 적이 손에
				# 들린 채로 측정되고 있었습니다).
				if _frames < 45:
					_probe_foe.global_position = player.global_position 						+ Vector3(0, 0, -1.2)
				if _frames == 40:
					_probe_foe.hp = 200.0
					print("[부딪힘] 밀기 전 체력=%.0f" % _probe_foe.hp)
				if _frames == 45:
					# **밀기 판정을 곧바로 부릅니다.**
					#
					# 버튼을 누르면 달려들기가 나가는데, 이 배치에서는 적이
					# 아직 이쪽을 다 안 봐서 등 뒤로 판정되어 **잡혀 버립니다**
					# (처음에 그래서 적이 손에 들린 채로 측정됐습니다).
					# 재려는 것은 밀린 몸이 벽에 부딪히는 것이므로, 갈림길을
					# 건너뛰고 밀기 쪽을 바로 부릅니다.
					player._shove_one(_probe_foe)
				if _frames % 10 == 0 and _frames > 45 and _frames < 130:
					print("[부딪힘] f=%d 체력=%.0f 속도=%.2f 자리=%.2f,%.2f,%.2f 밀림=%.2f 던짐=%.2f" % [
						_frames, _probe_foe.hp,
						Vector2(_probe_foe.velocity.x, _probe_foe.velocity.z).length(),
						_probe_foe.global_position.x, _probe_foe.global_position.y,
						_probe_foe.global_position.z,
						_probe_foe._knock, _probe_foe._thrown])
		"mapstat":
			# **맵이 얼마나 복도인지** 잽니다. "긴 복도가 나와서 흐름이 느리다"
			# 는 말을 숫자로 바꿉니다 - 방이 차지하는 비율, 복도 칸 수, 그리고
			# 가장 긴 곧은 복도 한 줄.
			if _frames == 8:
				var open_n := 0
				var room_n := 0
				for y in dungeon.h:
					for x in dungeon.w:
						if not dungeon.is_solid(x, y):
							open_n += 1
				for r in dungeon.rooms:
					room_n += r.size.x * r.size.y
				# 곧은 복도: 방에 안 든 칸이 가로/세로로 몇 칸 이어지나.
				var longest := 0
				for y in dungeon.h:
					var run := 0
					for x in dungeon.w:
						var inside := false
						for r in dungeon.rooms:
							if r.has_point(Vector2i(x, y)):
								inside = true
								break
						if dungeon.is_solid(x, y) or inside:
							run = 0
						else:
							run += 1
							longest = maxi(longest, run)
				for x in dungeon.w:
					var run2 := 0
					for y in dungeon.h:
						var inside2 := false
						for r in dungeon.rooms:
							if r.has_point(Vector2i(x, y)):
								inside2 = true
								break
						if dungeon.is_solid(x, y) or inside2:
							run2 = 0
						else:
							run2 += 1
							longest = maxi(longest, run2)
				print("[맵] %dx%d 방=%d 열린칸=%d 방칸=%d 방비율=%d%% 복도칸=%d 가장긴복도=%d칸(%.1fm)" % [
					dungeon.w, dungeon.h, dungeon.rooms.size(), open_n, room_n,
					int(round(float(room_n) / maxf(open_n, 1) * 100.0)),
					open_n - room_n, longest, longest * 1.5])
			player.bot_active = true
		"ult":
			# **필살기 한 바퀴.** 게이지를 채우고, 명령을 넣고, 세 동작을
			# 차례로 써 보고, 시간이 지나 풀리는 것까지 봅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _frames == 10:
				for _i in 5:
					state.apply_family("push", rng)
				_boon_names = state.skill_summary()
			if _frames == 20:
				print("[필살] 열림=%s 게이지=%.2f" % [
					str(player.ultimate.unlocked()), player.ultimate.ratio()])
				state.courage = Ultimate.MAX
			# 적 셋을 눈앞에 세웁니다 - 달려들기와 포효가 맞을 것이 있어야
			# 합니다.
			if _frames == 24:
				for i in 3:
					var e := Enemy.new()
					world.add_child(e)
					e.setup("grunt", 1, dungeon, player)
					e.global_position = player.global_position 						+ Vector3(1.2 + float(i) * 1.4, 0, -1.0)
					e.died.connect(_on_enemy_died)
					Toon.refresh(e)
					_alive += 1
					if i == 0:
						_probe_foe = e
			# 명령: 구르기 → 밀기 → 고함
			if _frames == 30:
				player._try_dash()
			if _frames == 34:
				player.grab_press()
			if _frames == 38:
				player.attack()
			if _frames == 40:
				print("[필살] 발동=%s 세상멈춤=%s 게이지=%.2f" % [
					str(player.ultimate.active), str(world_frozen),
					player.ultimate.ratio()])
			# 동작 셋
			if _frames == 46:
				player._try_dash()          # 달려들기
			if _frames == 49:
				# 연달아 누르면 **다음 적**으로 가야 합니다.
				var b1 := player._ult_visited[0] as Node3D if player._ult_visited.size() > 0 else null
				player._try_dash()
				var b2 := player._ult_visited[player._ult_visited.size() - 1] as Node3D 					if player._ult_visited.size() > 0 else null
				print("[필살] 두 번째 달려들기: 같은 적인가=%s (들른 수=%d)" % [
					str(b1 == b2), player._ult_visited.size()])
			if _frames == 52:
				print("[필살] 달려든 뒤 게이지=%.2f 가장가까운적까지=%.2f" % [
					player.ultimate.ratio(),
					(player._nearest_enemy(20.0).global_position - player.global_position).length()
						if player._nearest_enemy(20.0) != null else -1.0])
				player.grab_press()         # 밀어붙이기
			if _frames == 58:
				var alive_hp := 0.0
				for n in get_tree().get_nodes_in_group("enemies"):
					alive_hp += float((n as Enemy).hp)
				print("[필살] 밀친 뒤 게이지=%.2f 적 체력합=%.0f" % [
					player.ultimate.ratio(), alive_hp])
				player.attack()             # 포효
			if _frames == 64:
				var hp2 := 0.0
				var n2 := 0
				for n in get_tree().get_nodes_in_group("enemies"):
					hp2 += float((n as Enemy).hp)
					n2 += 1
				print("[필살] 포효 뒤 게이지=%.2f 적 %d마리 체력합=%.0f" % [
					player.ultimate.ratio(), n2, hp2])
			# 아무것도 안 누르고 두면 풀려야 합니다(IDLE_LIMIT 1.6초).
			if _frames == 175:
				print("[필살] 손 놓고 1.85초 뒤: 발동=%s 세상멈춤=%s" % [
					str(player.ultimate.active), str(world_frozen)])
		"zombie":
			# **밀어도 안 죽는 적**을 재현합니다.
			#
			# 체력을 1 로 깎아 두고 계속 밉니다. 규칙대로면 첫 밀기에서
			# 밀려난 뒤 쓰러져야 합니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null and _frames > 12:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("grunt", 1, dungeon, player)
				var fwd := -player.pivot.global_transform.basis.z
				_probe_foe.global_position = player.global_position + fwd.normalized() * 1.3
				_probe_foe.died.connect(_on_enemy_died)
				Toon.refresh(_probe_foe)
				_alive += 1
			if is_instance_valid(_probe_foe):
				var to: Vector3 = _probe_foe.global_position - player.global_position
				to.y = 0.0
				if to.length() > 0.05:
					player.aim = to.normalized()
				if _frames == 40:
					_probe_foe.hp = 1.0
				# 0.95초(대기)마다 한 번씩 밉니다.
				if _frames >= 45 and (_frames - 45) % 58 == 0:
					player.grab_press()
				if _frames % 30 == 0 and _frames > 45:
					print("[좀비] f=%d 체력=%.1f 죽음=%s 밀림=%.4f 휘청=%.2f 보류=%s" % [
						_frames, _probe_foe.hp, str(_probe_foe._dead),
						_probe_foe._knock, _probe_foe._stagger,
						str(_probe_foe._die_when_landed)])
			elif _frames % 30 == 0:
				print("[좀비] f=%d 적이 죽어 사라졌습니다" % _frames)
		"wallhug":
			# 벽에 등을 붙였을 때 생기는 **거뭇한 얼룩**을 재는 자리.
			#
			# 카메라 쪽에서 보면 그 벽은 캐릭터 **뒤**에 있는데도 걷어내는
			# 규칙에 걸립니다. 지워진 자리는 뒤에 아무것도 없어서 검게
			# 남고, 그것이 얼룩으로 보입니다.
			if _frames == 20:
				# 북쪽이 벽인 바닥 칸을 찾아 그 벽에 등을 붙입니다.
				var found := false
				for y in range(2, 60):
					for x in range(2, 60):
						var behind: bool = _probe_arg != "front"
						var wy: int = y - 1 if behind else y + 1
						if dungeon.is_solid(x, y) or not dungeon.is_solid(x, wy):
							continue
						if dungeon.is_solid(x - 1, y) or dungeon.is_solid(x + 1, y):
							continue
						player.global_position = dungeon.cell_to_world(Vector2i(x, y)) 							+ Vector3(0, 0, -0.45 if behind else 0.45)
						player.aim = Vector3(0, 0, -1)
						found = true
						break
					if found:
						break
				print("[벽등] 자리=%s 찾음=%s" % [str(player.global_position), str(found)])
			player.bot_active = true
			player.bot_move = Vector2.ZERO
		"spam":
			# 연타 확인용. **테스트 방에서** 밀기와 고함을 매 프레임 누르고,
			# 실제로 몇 번 나가는지 셉니다. 쿨다운(밀기 0.95초, 고함 0.55초)
			# 대로면 3초에 밀기 3번·고함 5번쯤이어야 합니다.
			#
			# 앞 절반은 눈앞에 적을 두고, 뒤 절반은 치우고 셉니다 - 차이가
			# 나면 "범위 안에 적이 있을 때만" 이라는 말이 맞는 것입니다.
			if _frames == 10:
				phase = Phase.TITLE
				ui.show_title()
				start_test()
				for _i in _push_lv:
					state.apply_family("shout", rng)
				print("[연타] 고함 Lv%d  공격속도=%.2f" % [_push_lv, state.attack_rate])
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null and _frames > 12 and _frames < 200:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("grunt", 1, dungeon, player)
				var fwd := -player.pivot.global_transform.basis.z
				_probe_foe.global_position = player.global_position + fwd.normalized() * 1.4
				_probe_foe.died.connect(_on_enemy_died)
				Toon.refresh(_probe_foe)
				_alive += 1
			if is_instance_valid(_probe_foe):
				# 적을 붙잡아 두고 죽지 않게 합니다 - 세는 것은 누름뿐입니다.
				var fwd2 := -player.pivot.global_transform.basis.z
				_probe_foe.global_position = player.global_position + fwd2.normalized() * 1.4
				_probe_foe.hp = _probe_foe.max_hp
			if _frames == 200 and is_instance_valid(_probe_foe):
				print("[연타] --- 여기부터 적 없음 ---")
				_probe_foe.queue_free()
			# 숨이 바닥나면 셈이 흐려지므로 계속 채웁니다.
			state.breath = state.max_breath
			if _frames > 20:
				player.grab_press()
				player.attack()
			# **몇 번 나갔는지는 대기가 말해 줍니다.** 기술이 나가는 순간
			# 대기가 가득 차므로(남은 비율 0), 그 내려앉는 지점을 셉니다 -
			# 세느라 player.gd 에 출력을 심을 필요가 없습니다.
			for k in ["grab", "shout"]:
				var now: float = player.skill_charge(k)
				if float(_spam_prev.get(k, 1.0)) > 0.3 and now < 0.05:
					_spam_count[k] = int(_spam_count.get(k, 0)) + 1
				_spam_prev[k] = now
			if _frames == 199 or _frames == 399:
				print("[연타] %s 적=%s  밀기 %d회  고함 %d회 / 3.0초" % [
					"앞" if _frames < 300 else "뒤",
					str(is_instance_valid(_probe_foe)),
					int(_spam_count.get("grab", 0)), int(_spam_count.get("shout", 0))])
				_spam_count = {}
		"pushcmp":
			# **테스트 방에서** 직접 밀기와 잡은 후 던지기의 거리를 나란히
			# 잽니다. 본 게임에서 재면 다른 적과 소품이 끼어들어 값이 흔들리고,
			# 스킬을 올려 보려면 층을 여러 번 넘겨야 합니다.
			if _frames == 10:
				phase = Phase.TITLE
				ui.show_title()
				start_test()
				for _i in _push_lv:
					state.apply_family("push", rng)
				_boon_names = state.skill_summary()
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null and _frames > 12:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("grunt", 1, dungeon, player)
				var fwd := -player.pivot.global_transform.basis.z
				_probe_foe.global_position = player.global_position + fwd.normalized() * 1.4
				_probe_foe.died.connect(_on_enemy_died)
				Toon.refresh(_probe_foe)
				_alive += 1
			if is_instance_valid(_probe_foe):
				var to: Vector3 = _probe_foe.global_position - player.global_position
				to.y = 0.0
				if to.length() > 0.05:
					player.aim = to.normalized()
				# 적이 안 죽게 체력을 계속 채웁니다 - 거리만 보려는 것입니다.
				_probe_foe.hp = _probe_foe.max_hp
				if _frames == 40:
					_knock_from = _probe_foe.global_position
					_push_far = 0.0
					player.grab_press()          # 직접 밀기
				# **가장 멀리 간 거리**를 잽니다. 멈춘 뒤에 재면 적이 도로
				# 걸어와서 값이 줄어듭니다(처음에 그렇게 재서 0.12m 가
				# 나왔습니다 - 실제로는 그 두 배를 갔습니다).
				if _frames > 40:
					var dn: Vector3 = _probe_foe.global_position - _knock_from
					dn.y = 0.0
					_push_far = maxf(_push_far, dn.length())
				if _frames == 90:
					print("[비교] 밀기 Lv%d 간거리=%.2f" % [_push_lv, _push_far])
					# 이제 잡아서 던져 봅니다.
					_probe_foe.global_position = player.global_position 						+ Vector3(0.6, 0, 0)
					player._take(_probe_foe)
				if _frames == 110:
					_knock_from = _probe_foe.global_position
					_push_far = 0.0
					player.grab_press()          # 던지기
				if _frames == 175:
					print("[비교] 던지기 Lv%d 간거리=%.2f" % [_push_lv, _push_far])
		"heave":
			# 던지기 확인용. 적을 잡아 던지고 **간 거리**를 잽니다.
			#
			# --boon=shove_knock 을 함께 주면 밀기 스킬이 던지기에도 붙는지
			# 같은 방법으로 볼 수 있습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("grunt", 1, dungeon, player)
				_probe_foe.global_position = player.global_position + Vector3(0.6, 0, 0)
				_probe_foe.died.connect(_on_enemy_died)
				_alive += 1
			if _frames == 20 and is_instance_valid(_probe_foe):
				player._take(_probe_foe)
			# **체력을 1 로 깎아 두고** 던집니다. 죽는 적이 밀려나는지 봅니다.
			if _frames == 55 and is_instance_valid(_probe_foe):
				_probe_foe.hp = 1.0
			if _frames == 60 and is_instance_valid(_probe_foe):
				_knock_from = _probe_foe.global_position
				player.aim = Vector3(0, 0, 1)
				player.grab_press()
			if _frames > 60 and _frames % 20 == 0 and is_instance_valid(_probe_foe):
				var d: Vector3 = _probe_foe.global_position - _knock_from
				d.y = 0.0
				var to_me: Vector3 = player.global_position - _probe_foe.global_position
				to_me.y = 0.0
				var look := 180.0
				if to_me.length_squared() > 0.0001:
					look = rad_to_deg(acos(clampf(
						_probe_foe.facing().dot(to_me.normalized()), -1.0, 1.0)))
				print("[던짐] f=%d 간거리=%.2f 속도=%.2f 높이=%.2f 사람과각도=%.0f도" % [
					_frames, d.length(),
					Vector2(_probe_foe.velocity.x, _probe_foe.velocity.z).length(),
					_probe_foe.global_position.y - _knock_from.y, look])
		"toss":
			# 던지는 적 확인용. 소품 옆에 세워 두고 무엇을 하는지 찍습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("brute", 1, dungeon, player)
				_probe_foe.global_position = player.global_position + Vector3(0, 0, 5.0)
				_probe_foe.died.connect(_on_enemy_died)
				_alive += 1
				var toy := Prop.new()
				world.add_child(toy)
				toy.setup("daycare_pandatoy")
				toy.global_position = _probe_foe.global_position + Vector3(1.0, 0.4, 0)
			if _frames % 20 == 0 and is_instance_valid(_probe_foe):
				print("[던지는적] f=%d 손에=%s 예고=%.2f 대기=%.2f 거리=%.1f 경직=%.2f" % [
					_frames,
					str(_probe_foe._carry.kind) if is_instance_valid(_probe_foe._carry) else "-",
					_probe_foe._windup, _probe_foe._cooldown,
					_probe_foe.global_position.distance_to(player.global_position),
					_probe_foe._stagger])
		"cling":
			# 붙잡는 아이 확인용. 가만히 서 있으면 등 뒤로 돌아 들어옵니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("clinger", 1, dungeon, player)
				_probe_foe.global_position = player.global_position + Vector3(0, 0, 3.0)
				_probe_foe.died.connect(_on_enemy_died)
				_alive += 1
			# 300프레임 뒤부터는 **버튼을 두드려** 빨리 풀리는지 봅니다.
			if _frames > 300 and _frames % 6 == 0:
				player.grab_press()
			if _frames % 15 == 0 and is_instance_valid(_probe_foe):
				print("[붙잡기] f=%d 거리=%.2f 등뒤=%s 붙잡힘=%.2f 체력=%.0f" % [
					_frames,
					_probe_foe.global_position.distance_to(player.global_position),
					str(_probe_foe.is_behind_target()),
					player._bound_time, state.hp])
		"guard":
			# 베개 확인용.
			#
			# 앞에서는 **실제 밀기**로 눌러 봅니다(게임에서 실제로 일어나는 길).
			# 뒤는 그 방법으로 못 잽니다 - 밀기는 0.23초 동안 달려들어 닿는
			# 것이라, 그 사이에 적이 몸을 돌리면 앞뒤가 뒤집힙니다. 규칙 자체를
			# 보려는 것이므로 뒤쪽은 **자리를 직접 주어** 재는 편이 맞습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("pillow", 1, dungeon, player)
				_probe_foe.global_position = player.global_position + Vector3(0, 0, 1.6)
				_probe_foe.died.connect(_on_enemy_died)
				_alive += 1
			if _frames == 30 and is_instance_valid(_probe_foe):
				# 베개를 어디에 둘지 **재서** 정합니다. 머리가 큰 아이라
				# 가슴 높이를 눈으로 찍으면 베개가 머리에 가립니다.
				var mdl := _probe_foe.get_node("Pivot").get_child(0)
				var sk := Models.find_skeleton(mdl)
				if sk != null:
					for bn in ["Head", "Neck", "Chest", "Spine", "Hips"]:
						var bi := sk.find_bone(bn)
						if bi < 0:
							continue
						var wp: Vector3 = (sk.global_transform * sk.get_bone_global_pose(bi)).origin
						print("[뼈] %-6s 높이=%.3f 앞뒤=%.3f" % [bn,
							wp.y - _probe_foe.global_position.y,
							(wp - _probe_foe.global_position).dot(_probe_foe.facing())])
					print("[뼈] 캡슐높이=%.3f 반지름=%.3f" % [
						_probe_foe._capsule_height,
						float(_probe_foe.get_meta("body_radius", 0.0))])
			if is_instance_valid(_probe_foe):
				var to: Vector3 = _probe_foe.global_position - player.global_position
				to.y = 0.0
				player.aim = to.normalized()
				# **베개를 뚫는지** 봅니다. 앞으로 계속 걸어 들어가 멈추는
				# 거리를 잽니다 - 베개에 몸이 있으면 그만큼 멀리서 막힙니다.
				if _frames > 240 and _frames <= 300:
					player.bot_move = Vector2(to.normalized().x, to.normalized().z)
					if _frames == 300:
						print("[베개몸] 멈춘거리=%.2f (몸 반지름합 0.40)" % to.length())
				elif _frames > 300:
					player.bot_move = Vector2.ZERO
				if _frames <= 240:
					if _frames > 30 and _frames % 60 == 0:
						_probe_hp = _probe_foe.hp
						player.grab_press()
					if _frames > 30 and _frames % 60 == 40:
						print("[베개] f=%d 앞(밀기) 체력 %.1f -> %.1f (%s)" % [
							_frames, _probe_hp, _probe_foe.hp,
							"막힘" if is_equal_approx(_probe_hp, _probe_foe.hp) else "들어감"])
				elif _frames % 60 == 0:
					var face: Vector3 = _probe_foe.facing()
					var front: Vector3 = _probe_foe.global_position + face * 2.0
					var back: Vector3 = _probe_foe.global_position - face * 2.0
					# 옆에서 때리는 자리도 함께 봅니다.
					var side_dir := Vector3(-face.z, 0.0, face.x)
					var side: Vector3 = _probe_foe.global_position + side_dir * 2.0
					var hs := _probe_foe.hp
					_probe_foe.take_damage(5.0, false, Vector3.ZERO, 0.0, side)
					print("[베개] 옆=%s" % ("막힘" if is_equal_approx(hs, _probe_foe.hp) else "들어감"))
					var h0 := _probe_foe.hp
					_probe_foe.take_damage(5.0, false, Vector3.ZERO, 0.0, front)
					var h1 := _probe_foe.hp
					_probe_foe.take_damage(5.0, false, Vector3.ZERO, 0.0, back)
					print("[베개] f=%d 앞=%s 뒤=%s (체력 %.0f -> %.0f -> %.0f)" % [
						_frames,
						"막힘" if is_equal_approx(h0, h1) else "들어감",
						"막힘" if is_equal_approx(h1, _probe_foe.hp) else "들어감",
						h0, h1, _probe_foe.hp])
		"scream":
			# 고함치는 아기 확인용. 사거리 안에 서서 맞아 봅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _probe_foe == null:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("screamer", 1, dungeon, player)
				_probe_foe.global_position = player.global_position + Vector3(0, 0, 2.6)
				_probe_foe.died.connect(_on_enemy_died)
				_alive += 1
			if _frames % 20 == 0:
				print("[고함] f=%d 체력=%.0f 거리=%.2f" % [_frames, state.hp,
					_probe_foe.global_position.distance_to(player.global_position)
					if is_instance_valid(_probe_foe) else -1.0])
		"shield":
			# 방패 확인용. 적을 잡은 채 앞뒤에서 가시를 맞아 봅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _ram_foe == null:
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				_ram_foe.setup("grunt", 1, dungeon, player)
				_ram_foe.global_position = player.global_position + Vector3(0.6, 0, 0)
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
			if _frames == 20:
				player._take(_ram_foe)
			# 앞(200프레임까지)에서 쏘다가, 그 뒤에는 뒤에서 쏩니다.
			if _frames > 30 and _frames % 40 == 0:
				var side := 1.0        # 계속 앞에서 쏴서 방패가 죽는 순간까지 봅니다
				var face: Vector3 = -player.pivot.global_transform.basis.z
				var shot := Projectile.new()
				world.add_child(shot)
				shot.launch(player.global_position + face * (2.6 * side) + Vector3(0, 0.8, 0),
					-face * side, 8.0, dungeon)
			if _frames % 40 == 20 and _frames > 30:
				print("[방패] f=%d %s 체력=%.0f 적체력=%.0f 손에=%s" % [_frames,
					"앞" if _frames <= 200 else "뒤", state.hp,
					_ram_foe.hp if is_instance_valid(_ram_foe) else -1.0,
					str(player._held != null)])
		"dodge":
			# 구르기 통과 확인용. 적 AI 를 기다리지 않고 **탄을 직접** 쏩니다 -
			# 바뀐 것은 탄이 사람을 만났을 때의 처리뿐이라, 누가 쐈는지는
			# 상관이 없습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			# 앞 240프레임은 서서 맞고(명중), 그 뒤에는 계속 굴러 무적을
			# 유지합니다(통과). 한 번에 두 경우를 다 봅니다.
			if _frames > 240:
				state.dash_cooldown = 0.05
				player.dash()
			if _frames % 40 == 20:
				var shot := Projectile.new()
				world.add_child(shot)
				var from: Vector3 = player.global_position + Vector3(2.6, 0.8, 0)
				shot.launch(from, Vector3(-1, 0, 0), 8.0, dungeon)
			if _frames % 80 == 0:
				print("[검사] f=%d 체력 %.0f 무적=%s" % [
					_frames, state.hp, str(player.is_invulnerable())])
		"shelfread":
			# 책장 읽기 확인용. 읽고 **곧바로** 스킬을 골라서, 그 뒤에 층이
			# 새로 지어지지 않는지 봅니다(일시정지 중에는 이 함수가 안 돌아서
			# 두 동작을 한 프레임에 합칩니다).
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _frames == 30:
				for n in get_tree().get_nodes_in_group("props"):
					if n is Prop and (n as Prop).kind == "bookshelf":
						_shelf_at = n
						break
				if _shelf_at != null:
					var od := _shelf_at.global_transform.basis.z
					player.global_position = Vector3(_shelf_at.global_position.x, 0.0,
						_shelf_at.global_position.z) + od * 1.2
			if _frames == 34:
				player.grab_press()      # E 가 아니라 **잡기**로
			if _frames % 20 == 0 and _frames > 34:
				var foe_at := Vector3.ZERO
				for n in world.get_children():
					if n is Enemy and not (n as Enemy)._dead:
						foe_at = n.global_position
						break
				print("[읽기] f=%d 마디=%d aim=%s 몸=%s yaw=%.2f" % [
					_frames, player.read_phase(), str(player.aim.round()),
					str((-player.pivot.global_transform.basis.z).round()),
					player.pivot.rotation.y])
			if false:
				var was_floor := state.floor_num
				var was_at := player.global_position
				var was_props := get_tree().get_nodes_in_group("props").size()
				print("[읽기] 전  층=%d 소품=%d 위치=%s" % [was_floor, was_props,
					str(was_at.round())])
				_do_interact()
				_on_boon_chosen(String(_boon_options[0]["id"]))
				print("[읽기] 후  층=%d 소품=%d 위치=%s 화면=%d 읽음=%s" % [
					state.floor_num, get_tree().get_nodes_in_group("props").size(),
					str(player.global_position.round()), phase,
					str(_shelf_at.was_read) if is_instance_valid(_shelf_at) else "?"])
		"testroom":
			# 테스트 방 확인용. 방을 열고 붙잡는 아기를 계속 내보냅니다.
			# **제목 화면을 실제로 띄운 뒤** 테스트 방으로 들어갑니다.
			# 자동 시작으로 들어오면 제목이 애초에 없어서, 닫히는지를
			# 확인할 수 없습니다(그래서 처음에 놓쳤습니다).
			# 제목 화면을 띄우고 **같은 프레임에** 테스트 방으로 들어갑니다.
			# 확인용 자세는 PLAYING 일 때만 도는데(_process), 제목을 띄우고
			# 다음 프레임을 기다리면 그 뒤로는 영영 안 돌아옵니다.
			if _frames == 10:
				phase = Phase.TITLE
				ui.show_title()
				start_test()
				_on_test_kind("clinger")
			if _frames % 60 == 0 and _frames > 20:
				var n := 0
				for node in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(node):
						n += 1
				print("[테스트방] f=%d 방=%d 적=%d 종류=%s" % [
					_frames, dungeon.rooms.size() if dungeon != null else -1,
					n, _test_kind])
		"fx":
			# 밀기·고함 이펙트 확인용. 스킬을 Lv5 까지 올리고 눈앞의 적을
			# 밀거나 지릅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _frames == 10 and _forced_boons.is_empty():
				# --boon 을 준 게 없을 때만 계통을 통째로 올립니다. 주면
				# 그것만 걸어야 이펙트가 그 스킬을 따라가는지 볼 수 있습니다.
				for _i in 5:
					state.apply_family("push", rng)
					state.apply_family("shout", rng)
				_boon_names = state.skill_summary()
				ui.set_boons(_boon_names)
			if _probe_foe == null and _frames > 12:
				_probe_foe = Enemy.new()
				world.add_child(_probe_foe)
				_probe_foe.setup("grunt", 1, dungeon, player)
				var fwd := -player.pivot.global_transform.basis.z
				_probe_foe.global_position = player.global_position + fwd.normalized() * 1.6
				_probe_foe.died.connect(_on_enemy_died)
				_alive += 1
			if is_instance_valid(_probe_foe):
				var to: Vector3 = _probe_foe.global_position - player.global_position
				to.y = 0.0
				if to.length() > 0.05:
					player.aim = to.normalized()
			# 40 프레임마다 번갈아 - 밀기, 고함.
			if _frames == 58 and is_instance_valid(_probe_foe):
				_probe_foe.hp = 1.0
				_knock_from = _probe_foe.global_position
			if _frames == 60 or _frames == 110:
				player.grab_press()
			if _frames > 60 and _frames % 20 == 0 and is_instance_valid(_probe_foe):
				var d: Vector3 = _probe_foe.global_position - _knock_from
				d.y = 0.0
				print("[죽밀기] f=%d 간거리=%.2f 체력=%.0f" % [_frames, d.length(), _probe_foe.hp])
			if _frames == 160:
				player.attack()
		"frame":
			# 벽 소품이 캐릭터를 가릴 때 비치는지 확인용.
			#
			# 카메라는 캐릭터의 +Z 쪽 위에서 내려다봅니다. 그러니 **그쪽 벽**에 걸린
			# 것만 카메라와 캐릭터 사이에 놓입니다 - 그 앞(북쪽)에 사람을
			# 세워야 가리는 상황이 만들어집니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _frames == 20:
				var best: Prop = null
				for n in world.get_children():
					var pr := n as Prop
					if not is_instance_valid(pr) or not pr.wants_wall():
						continue
					# 앞면(+Z, 방 쪽)이 북쪽을 보는 것 = 남쪽 벽에 걸린 것.
					var face: Vector3 = pr.global_transform.basis.z
					if face.z < -0.7:
						best = pr
						break
				if best != null:
					player.global_position = best.global_position 						+ Vector3(0, 0, -1.1) - Vector3(0, best.global_position.y, 0)
					print("[벽소품] %s 를 앞에 두고 섰습니다" % best.kind)
				else:
					print("[벽소품] 남쪽 벽에 걸린 것이 없습니다")
		"shelf":
			# 책장 확인용. 첫 책장 앞으로 사람을 옮겨 놓고 봅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _frames == 3:
				var found: Prop = null
				for n in get_tree().get_nodes_in_group("props"):
					if n is Prop and (n as Prop).kind == _shelf_kind:
						found = n
						break
				if found != null:
					# 책장이 보는 쪽(-Z) 앞 2.2m 에 섭니다.
					var out_dir := found.global_transform.basis.z    # 이 메시는 +Z 가 앞
					player.global_position = Vector3(found.global_position.x, 0.0,
						found.global_position.z) + out_dir * 2.2
					player.aim = -out_dir          # 책장을 마주 봅니다
					# 어느 쪽이 벽인지는 지형에 물어봅니다.
					var back_cell := dungeon.world_to_cell(
						found.global_position - out_dir * 0.9)
					var front_cell := dungeon.world_to_cell(
						found.global_position + out_dir * 0.9)
					_shelf_at = found
					print("[책장] 각도=%.0f도  앞(+Z)쪽=%s  등(-Z)쪽=%s" % [
						rad_to_deg(found.rotation.y),
						"벽" if dungeon.is_solid(front_cell.x, front_cell.y) else "방",
						"벽" if dungeon.is_solid(back_cell.x, back_cell.y) else "방"])
				else:
					print("[책장] 이 층에 없습니다")
		"pool":
			# 움직이는지 확인용. 앞에 하나 놓고 밀어 보고, 잡기도 눌러 봅니다.
			#
			# `--prop=` 로 종류를 고릅니다(기본 풀장). 가구는 안 밀려야 하고
			# 장난감은 밀려야 하는데, 같은 시험을 두 벌 두면 한쪽만 고치게
			# 됩니다 - 한 자리에서 종류만 바꿔 재는 편이 규칙이 하나입니다.
			player.bot_active = true
			if not is_instance_valid(_probe_prop) and _frames < 5:
				var fwd0 := -player.pivot.global_transform.basis.z
				_probe_prop = Prop.new()
				world.add_child(_probe_prop)
				_probe_prop.setup(_shelf_kind if _shelf_kind != "bookshelf" else "pool")
				_probe_prop.global_position = player.global_position + fwd0.normalized() * 3.6
				_pool_from = _probe_prop.global_position
			player.bot_move = Vector2(0, -1)          # 계속 밀어붙입니다
			if _frames == 120:
				player.grab_press()
			if _frames % 40 == 0 and _frames >= 40 and is_instance_valid(_probe_prop):
				print("[밀기] %s f=%d 밀린거리=%.3f 사람과거리=%.2f 손에=%s" % [
					_probe_prop.kind, _frames,
					_probe_prop.global_position.distance_to(_pool_from),
					player.global_position.distance_to(_probe_prop.global_position),
					str(player._held.kind) if player._held is Prop else "없음"])
		"milk":
			# 우유 확인용. 눈앞에 하나 놓고 체력을 깎은 뒤 잡기를 누릅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if not is_instance_valid(_probe_prop) and _frames < 5:
				state.hp = 40.0
				_probe_prop = Prop.new()
				world.add_child(_probe_prop)
				_probe_prop.setup("milk")
				var fwd := -player.pivot.global_transform.basis.z
				_probe_prop.global_position = player.global_position + fwd.normalized() * 0.55 + player.pivot.global_transform.basis.x * 0.95 + Vector3(0, 0.3, 0)
			if _frames == 40:
				player.grab_press()
			if _frames % 10 == 0 and _frames >= 30:
				print("[우유] f=%d 체력=%.0f 마시는중=%.2f 손에=%s 남은우유=%d" % [
					_frames, state.hp, player._drink_time, str(player._held != null),
					get_tree().get_nodes_in_group("props").size()])
		"hold":
			# 손에 제대로 붙는지 보려면 확실히 잡고 있어야 합니다. 봇이
			# 돌아다니다 우연히 소품 앞에 서기를 기다리는 것은 불안정합니다.
			player.bot_active = true
			# 들고 **걸어야** 밀려나는 문제가 드러납니다. 서 있으면 사람이
			# 물건을 밀어낼 일이 없어서 아무 일도 일어나지 않습니다.
			player.bot_move = Vector2.ZERO if player._held == null else Vector2(0, -1)
			if player._held == null and _frames % 30 == 0:
				var prop := Prop.new()
				world.add_child(prop)
				# 가장 큰 소품을 씁니다. 들었을 때 사람을 밀어내는 문제는 소품이
				# 클수록 크게 나타나므로, 확인은 최악의 경우로 해야 합니다.
				prop.setup("daycare_leafbedding")
				prop.global_position = player.global_position + player.aim * 0.9
				await get_tree().process_frame
				player.grab_press()
		"back":
			# 뒷걸음질 검사. 적을 앞에 세워 자동 조준이 걸리게 하고, 그
			# 상태로 뒤로 걷습니다. 발이 앞으로 밀면(비율 음수) 문워크입니다.
			player.bot_active = true
			if _ram_foe == null or not is_instance_valid(_ram_foe):
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				# --foe= 로 종류를 고릅니다. 박치기(grunt)뿐 아니라 던지는
				# 적(brute)도 이 자리에서 봐야 합니다.
				_ram_foe.setup(_stride_kind, 1, dungeon, player)
				_ram_foe.global_position = player.global_position + Vector3(0, 0, -2.2)
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
				_skate_prev = player.global_position
				return
			# 적을 **한 자리에 붙들어** 둡니다. 움직이면 밀고 밀리느라
			# 물러나는 속도가 흐트러져 무엇을 재는지 알 수 없게 됩니다.
			_ram_foe.global_position = _skate_prev + Vector3(0, 0, -2.2)
			_ram_foe.velocity = Vector3.ZERO
			player.bot_move = Vector2(0, 1)          # 적 반대쪽으로
			if _stride_L == null:
				_stride_L = Models.add_anchor(player.body, "LeftFoot")
				_stride_R = Models.add_anchor(player.body, "RightFoot")
				return
			var bi2 := player.pivot.global_transform.basis.inverse()
			var l3: float = (bi2 * (_stride_L.global_position - player.global_position)).z
			var r3: float = (bi2 * (_stride_R.global_position - player.global_position)).z
			if _stride_have:
				# 뒷걸음질에서는 심어진 발이 **앞으로** 갑니다. 그쪽으로
				# 가장 많이 간 발을 골라 더합니다 - 걸을 때와 같은 자를
				# 방향만 뒤집어 쓴 것입니다.
				_stride_sum += maxf(maxf(_stride_lz - l3, _stride_rz - r3), 0.0)
				_skate_moved += (player.global_position - _skate_prev).dot(
					-player.pivot.global_transform.basis.z)
			_stride_lz = l3
			_stride_rz = r3
			_skate_prev = player.global_position
			_stride_have = true
			_stride_frames += 1
			if _stride_frames % 45 == 0 and _stride_frames <= 90:
				print("BACK 뒤로간거리=%.2fm 발이민거리=%.2fm 비율=%.2f 배속=%+.2f" % [
					absf(_skate_moved), _stride_sum,
					_stride_sum / maxf(absf(_skate_moved), 0.01),
					player._anim.speed_scale])
				_stride_sum = 0.0
				_skate_moved = 0.0
		"foeskate":
			# 적의 스케이팅 검사. 발이 민 거리와 적이 실제로 간 거리를
			# 나란히 더합니다. 주인공 것(--pose=skate)과 같은 자입니다.
			#
			# 주인공이 **천천히 물러납니다.** 가만히 서 있으면 적이 붙어서
			# 공격에 들어가 걷는 구간이 몇 프레임뿐입니다.
			player.bot_active = true
			player.bot_move = Vector2(-1, 0)
			if _ram_foe == null or not is_instance_valid(_ram_foe):
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				_ram_foe.setup(_stride_kind, 1, dungeon, player)
				_ram_foe.global_position = player.global_position + Vector3(7.0, 0, 0)
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
				_skate_prev = _ram_foe.global_position
				return
			if _stride_L == null:
				_stride_L = Models.add_anchor(_ram_foe, "LeftFoot")
				_stride_R = Models.add_anchor(_ram_foe, "RightFoot")
				return
			# **걷고 있는 동안만** 셉니다. 순간이동으로 되돌리거나 멈춰 선
			# 구간을 같이 더하면 몸이 간 거리가 엉뚱해집니다(처음에 그렇게
			# 재서 비율이 5배로 나왔습니다).
			var fv := Vector3(_ram_foe.get_real_velocity().x, 0.0,
				_ram_foe.get_real_velocity().z).length()
			if fv < 0.5:
				_skate_prev = _ram_foe.global_position
				_stride_have = false
				return
			var fb2 := _ram_foe._pivot.global_transform.basis.inverse()
			var fl: float = (fb2 * (_stride_L.global_position - _ram_foe.global_position)).z
			var fr: float = (fb2 * (_stride_R.global_position - _ram_foe.global_position)).z
			if _stride_have:
				_stride_sum += maxf(maxf(fl - _stride_lz, fr - _stride_rz), 0.0)
				_skate_moved += _ram_foe.global_position.distance_to(_skate_prev)
			_stride_lz = fl
			_stride_rz = fr
			_skate_prev = _ram_foe.global_position
			_stride_have = true
			_stride_frames += 1
			if _stride_frames % 60 == 0 and _skate_moved > 0.05:
				print("FOESKATE(%s) 발=%.2f 몸=%.2f 비율=%.2f 배속=%.2f" % [
					_stride_kind, _stride_sum, _skate_moved,
					_stride_sum / _skate_moved, _ram_foe._anim.speed_scale])
				_stride_sum = 0.0
				_skate_moved = 0.0
		"skate":
			# 스케이팅 검사. 발이 바닥을 민 거리와 몸이 실제로 간 거리를
			# 나란히 더합니다. 둘이 같으면(비율 1.0) 미끄러지지 않습니다.
			player.bot_active = true
			player.bot_move = Vector2(0, -1)
			# 구르기 직후를 보려고 주기적으로 구릅니다. 구르는 동안과 그
			# 직후가 검사에 반드시 들어가야 합니다.
			if _frames % 150 == 0:
				state.dash_cooldown = 0.0
				player.dash()
			if _stride_L == null:
				_stride_L = Models.add_anchor(player.body, "LeftFoot")
				_stride_R = Models.add_anchor(player.body, "RightFoot")
				_skate_prev = player.global_position
				return
			var bi := player.pivot.global_transform.basis.inverse()
			var l2: float = (bi * (_stride_L.global_position - player.global_position)).z
			var r2: float = (bi * (_stride_R.global_position - player.global_position)).z
			if _stride_have:
				# 뒷걸음질 중이면 심어진 발이 **앞으로** 갑니다. 같은 자를
				# 방향만 뒤집어 씁니다.
				var dl := l2 - _stride_lz
				var dr := r2 - _stride_rz
				if player._moving_back:
					dl = -dl
					dr = -dr
				_stride_sum += maxf(maxf(dl, dr), 0.0)
				_skate_moved += player.global_position.distance_to(_skate_prev)
			_stride_lz = l2
			_stride_rz = r2
			_skate_prev = player.global_position
			_stride_have = true
			_stride_frames += 1
			if _stride_frames % 75 == 0 and _skate_moved > 0.01:
				print("SKATE 발=%.2fm 몸=%.2fm 비율=%.2f (1.0 이면 안 미끄러짐)"
					% [_stride_sum, _skate_moved, _stride_sum / _skate_moved])
				_stride_sum = 0.0
				_skate_moved = 0.0
		"stridefoe":
			# 적의 걷기 클립이 바닥을 미는 속도. 캐릭터마다 다리 길이와
			# 흔드는 각도가 달라 값도 다릅니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _ram_foe == null or not is_instance_valid(_ram_foe):
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				_ram_foe.setup(_stride_kind, 1, dungeon, player)
				_ram_foe.global_position = player.global_position + Vector3(3.0, 0, 0)
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
				return
			if _stride_L == null:
				_stride_L = Models.add_anchor(_ram_foe, "LeftFoot")
				_stride_R = Models.add_anchor(_ram_foe, "RightFoot")
				return
			_ram_foe.stride_probe = true
			var fp: AnimationPlayer = _ram_foe._anim
			if fp.current_animation != _ram_foe._walk:
				fp.play(_ram_foe._walk)
			fp.speed_scale = 1.0
			# **몸통(_pivot) 기준**으로 재야 합니다. 적은 자기 노드를 돌리지
			# 않고 _pivot 만 돌리므로, 루트 기준으로 재면 옆으로 걸어갈 때
			# 앞뒤 성분이 거의 0 이 됩니다 - 그래서 처음에 보폭을 5배나
			# 작게 쟀고, 적이 그만큼 미끄러졌습니다.
			var fb := _ram_foe._pivot.global_transform.basis.inverse()
			var flz: float = (fb * (_stride_L.global_position - _ram_foe.global_position)).z
			var frz: float = (fb * (_stride_R.global_position - _ram_foe.global_position)).z
			if _stride_have:
				_stride_sum += maxf(maxf(flz - _stride_lz, frz - _stride_rz), 0.0)
			_stride_lz = flz
			_stride_rz = frz
			_stride_have = true
			_stride_frames += 1
			if _stride_frames == 240:
				print("STRIDE(%s) 클립=%s 배속=%.2f 4초간=%.3fm -> %.3f m/s"
					% [_stride_kind, fp.current_animation, fp.speed_scale,
					   _stride_sum, _stride_sum / 4.0])
		"striderun":
			_stride_run = true
			_drive_pose_stride()
		"stride":
			_drive_pose_stride()
		"ram":
			# 박치기를 눈으로 보는 자리. 서진이 사거리(6.2m) 안으로 들어와
			# 겨누기를 기다리면 언제 일어날지 모르므로, 직접 세워 놓습니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _ram_foe == null or not is_instance_valid(_ram_foe):
				_ram_foe = Enemy.new()
				world.add_child(_ram_foe)
				_ram_foe.setup("grunt", 1, dungeon, player)
				_ram_foe.global_position = player.global_position + Vector3(0, 0, -5.0)
				_ram_foe.died.connect(_on_enemy_died)
				_alive += 1
		"pitch":
			# 던진 소품이 적을 맞히는지 보는 자리. 우연에 기대면 확인이
			# 안 되므로 적과 소품을 직접 세워 놓고 던집니다.
			player.bot_active = true
			player.bot_move = Vector2.ZERO
			if _pitch_foe == null or not is_instance_valid(_pitch_foe):
				_pitch_foe = Enemy.new()
				world.add_child(_pitch_foe)
				_pitch_foe.setup("grunt", 1, dungeon, player)
				_pitch_foe.global_position = player.global_position + Vector3(1.6, 0, 0)
				_pitch_foe.died.connect(_on_enemy_died)
				_alive += 1
				return
			if _pitch_mate == null or not is_instance_valid(_pitch_mate):
				# 던져질 적. 이 아이를 표적에게 던집니다.
				_pitch_mate = Enemy.new()
				world.add_child(_pitch_mate)
				_pitch_mate.setup("grunt", 1, dungeon, player)
				_pitch_mate.global_position = player.global_position + Vector3(0, 0, -0.9)
				_pitch_mate.died.connect(_on_enemy_died)
				_alive += 1
				return
			if player._held == null and _frames % 90 == 0:
				var pp := Prop.new()
				world.add_child(pp)
				pp.setup("daycare_traintoy")
				pp.global_position = player.global_position + Vector3(0, 0.8, 0.4)
				await get_tree().process_frame
				player.grab_press()
			elif player._held != null and _frames % 90 == 20:
				player.bot_move = Vector2(1, 0)
				player.grab_press()          # 두 번째 누름 = 던지기
			if _frames % 30 == 0:
				print("[체력] 적 %.0f / %.0f" % [_pitch_foe.hp, _pitch_foe.max_hp])
		"drag":
			# 적을 끄는 모습. 적이 다가오기를 기다리면 언제 붙을지 모르므로
			# 바로 앞에 하나 세우고 잡습니다. 끌리는 것을 보려면 플레이어가
			# 움직여야 하므로 앞으로 걷게 둡니다.
			player.bot_active = true
			player._roll_probe = _trace_at > 0
			if player._held == null and _frames % 40 == 0:
				var e := Enemy.new()
				world.add_child(e)
				e.setup("grunt", state.floor_num, dungeon, player)
				e.global_position = player.global_position + player.aim * 0.9
				e.died.connect(_on_enemy_died)
				_alive += 1
				await get_tree().process_frame
				# 잡기는 등 뒤에서만 됩니다. 확인용이라 등을 보이게 세웁니다.
				e.look_away_from(player.global_position)
				player.bot_move = Vector2.ZERO
				player.grab_press()

			elif _frames % 200 == 150:
				# 잠시 끌고 가다 방향을 준 채 다시 누릅니다 = 던지기.
				player.bot_move = Vector2(1, 0)
				player.grab_press()
			else:
				player.bot_move = Vector2(0, -1)


func open_riglab() -> void:
	## 리그 실험실을 엽니다. 제목 화면에서만 들어갑니다 - 판이 도는 중에
	## 열면 뒤에서 적이 계속 움직이고, 무엇을 보고 있는지 헷갈립니다.
	if _riglab != null:
		return
	ui.hide_all()
	# 던전을 감춥니다. 실험실은 자기 조명과 바닥을 세우는데, 그 뒤로 던전이
	# 비치면 무엇이 실험실 것이고 무엇이 게임 것인지 알 수 없습니다.
	if world != null:
		world.visible = false
	_riglab = RigLab.new()
	if _lab_hip > 0.0:
		_riglab.start_hip = _lab_hip
	if _lab_clip != "":
		_riglab.start_clip = _lab_clip
	if _lab_char >= 0:
		_riglab.start_char = _lab_char
	if _lab_motion > 0.0:
		_riglab.start_motion = _lab_motion
	_riglab.closed.connect(close_riglab)
	add_child(_riglab)


func close_riglab() -> void:
	if _riglab == null:
		return
	_riglab.queue_free()
	_riglab = null
	if world != null:
		world.visible = true
	if camera != null:
		camera.current = true
	ui.show_hud()
	phase = Phase.TITLE
	get_tree().paused = true
	ui.show_title()


func _on_quit() -> void:
	## 게임을 그만둡니다.
	##
	## 브라우저 탭은 스크립트가 닫을 수 없습니다(`get_tree().quit()` 은 웹에서
	## 아무 일도 하지 않습니다). 그래서 웹에서는 **판을 접고 제목 화면으로**
	## 돌아갑니다 - 거기서 다시 시작하거나 탭을 닫으면 됩니다.
	##
	## 녹화를 먼저 끊습니다. 그대로 두면 다음 판이 같은 파일에 이어 붙습니다.
	Recorder.stop()
	ui.stop_recording()
	if OS.has_feature("web"):
		phase = Phase.TITLE
		get_tree().paused = true
		ui.show_title()
		return
	get_tree().quit()


func set_cam_mode(mode: CamMode) -> void:
	## 카메라 방식을 바꿉니다.
	##
	## 위치와 각도만 바꾸는 것이 아닙니다. **이동 입력의 기준**도 같이
	## 바뀝니다(player.gd) - 어깨 너머에서 위 키가 세계의 북쪽을 뜻하면,
	## 카메라가 돌 때마다 같은 키가 다른 쪽으로 갑니다.
	cam_mode = mode
	if camera == null:
		return
	if mode == CamMode.SHOULDER:
		camera.position = Vector3(SHOULDER_SIDE, SHOULDER_HEIGHT, SHOULDER_DIST)
		camera.rotation_degrees = Vector3(-SHOULDER_PITCH, 0, 0)
		camera.fov = 62.0
	else:
		cam_rig.rotation.y = 0.0
		camera.fov = 58.0
		set_cam_pitch(cam_pitch)
	if ui != null:
		ui.set_cam_mode(mode == CamMode.SHOULDER)


func toggle_cam_mode() -> void:
	set_cam_mode(CamMode.TOPDOWN if cam_mode == CamMode.SHOULDER else CamMode.SHOULDER)


func cam_yaw() -> float:
	## 이동 입력을 이 각도로 돌려서 씁니다. 내려다보는 화면에서는 0 이라
	## 예전과 똑같이 동작합니다.
	return cam_rig.rotation.y if cam_mode == CamMode.SHOULDER else 0.0


func toggle_grade() -> void:
	## 화면 색감 필터를 켜고 끕니다.
	##
	## 캐릭터 텍스처를 직접 칠하는 길도 해 봤는데(tools/tint_models.py),
	## 되돌리려면 다시 구워야 하고 **바닥과 벽은 그대로**라 사람만 톤이 다른
	## 화면이 됐습니다. 색감은 그림 하나가 아니라 화면 전체의 성질입니다.
	_grade_on = not _grade_on
	ui.set_color_grade(_grade_on)
	ui.set_grade_label(_grade_on)
	ui.toast("색감 " + ("지브리" if _grade_on else "끔"), UiTheme.ACCENT)


func toggle_toon() -> void:
	## 카툰 렌더링을 켜고 끕니다. 지금은 오버레이 버튼과 T 키뿐이고,
	## 설정 메뉴가 생기면 그리로 옮길 자리입니다.
	Toon.apply(world, world_env, not Toon.enabled)
	ui.set_toon(Toon.enabled)
	ui.toast("카툰 렌더링 " + ("켬" if Toon.enabled else "끔"), UiTheme.ACCENT)


## 책장에서 배우는 것들. 아기가 알 만한 것으로만 골랐습니다 - 배운 내용이
## 어려우면 "지식" 이 농담이 아니라 설명문이 됩니다.
const KNOWLEDGE := [
	"소방차는 위잉위잉",
	"강아지는 멍멍",
	"해는 아침에 떠",
	"뜨거운 건 호 불어",
	"비 오면 우산 써",
	"우유는 소한테서 나와",
	"신발은 두 짝이야",
	"빨강 노랑 파랑",
	"넘어지면 아야 해",
	"밤에는 별이 나와",
	"기차는 칙칙폭폭",
	"고양이는 야옹",
	"물은 흘러내려",
	"불은 뜨거워 만지면 안 돼",
	"손은 씻고 밥 먹어",
	"눈은 차가워",
	"개구리는 폴짝",
	"바람 불면 나뭇잎이 흔들려",
	"코끼리 코는 길어",
	"자고 나면 아침이야",
]

## 상호작용이 닿는 거리. 조준은 안 봅니다 - 잡기와 달리 "그 앞에 섰다" 가
## 조건이라, 어디를 보고 있느냐로 갈리면 눌러도 안 되는 것처럼 느껴집니다.
const READ_RANGE := 2.0


func try_interact() -> bool:
	## 앞에 상호작용할 것이 있으면 하고 true 를 돌려줍니다.
	##
	## 잡기(밀기) 버튼이 이것을 먼저 물어봅니다 - 상인이나 책장 앞에서는
	## 잡기가 아니라 말 걸기가 되어야 합니다. 없으면 false 라, 잡기는 하던
	## 대로 이어집니다.
	if phase != Phase.PLAYING:
		return false
	if shop != null and shop.is_near():
		_open_shop()
		return true
	var shelf := _shelf_near()
	if shelf != null:
		_read_shelf(shelf)
		return true
	return false


func _do_interact() -> void:
	if phase == Phase.SHOP:
		_close_overlay()
		return
	if phase != Phase.PLAYING:
		return
	try_interact()


func _shelf_near() -> Prop:
	if not is_instance_valid(player):
		return null
	var best: Prop = null
	var closest := READ_RANGE
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop == null or not is_instance_valid(prop) or not prop.can_read():
			continue
		var to: Vector3 = prop.global_position - player.global_position
		to.y = 0.0
		if to.length() < closest:
			closest = to.length()
			best = prop
	return best


## 책 표지 색. 빨강 아니면 파랑입니다.
const BOOK_COLORS := [Color(0.82, 0.24, 0.22), Color(0.24, 0.42, 0.85)]


func _read_shelf(shelf: Prop) -> void:
	## 책장에서 책을 꺼내 **읽는 동안 기다립니다.**
	##
	## 예전에는 누르는 순간 고르기 화면이 떴습니다. 무엇을 했는지 화면에
	## 남지 않아, 책장이 그냥 "누르면 창이 뜨는 스위치" 였습니다.
	shelf.was_read = true
	_pending_line = KNOWLEDGE[rng.randi_range(0, KNOWLEDGE.size() - 1)]
	# 책장을 등지도록 돌려 세웁니다. 그래야 펼친 책이 화면을 향합니다.
	var away: Vector3 = player.global_position - shelf.global_position
	# 문구는 띄우지 않습니다. 꺼내고 돌아서서 펴는 동작이 이미 무엇을 하는지
	# 말하고 있어서, 글자까지 겹치면 설명이 두 번입니다. 배운 것은 다 읽고
	# 나서 한 번만 나옵니다(_on_read_done).
	player.begin_read(BOOK_COLORS[rng.randi_range(0, BOOK_COLORS.size() - 1)], away)


func _on_read_done() -> void:
	## 다 읽었습니다. 그제야 배운 것이 나오고 고르기가 열립니다.
	if phase != Phase.PLAYING:
		return
	ui.toast("지식을 습득했다  「%s」" % _pending_line, Color(1.0, 0.92, 0.6))
	# 고르는 화면은 층을 넘길 때와 같은 것을 씁니다 - 새 화면을 만들면 같은
	# 선택을 두 곳에서 관리하게 됩니다.
	_boon_options = _label_boons(state.offer_boons(rng))
	_boon_from_shelf = true
	phase = Phase.BOON
	get_tree().paused = true
	ui.show_boons(_boon_options, "지식을 습득했다",
		"「%s」   배운 것으로 무엇을 할까?" % _pending_line)


func _on_touch_attack() -> void:
	if phase == Phase.PLAYING and is_instance_valid(player):
		player.attack()


func blackout(on: bool) -> void:
	## **필살 모드 동안 사람만 남기고 화면을 검게 만듭니다.**
	##
	## 던전·소품·함정·문을 감추고 배경을 검정으로 둡니다. 남는 것은 주인공과
	## 적, 그리고 그 사이에 터지는 이펙트뿐입니다 - 세상이 멈췄다는 것을
	## 말이 아니라 화면이 말합니다.
	##
	## UI 는 손댈 것이 없습니다. 별도의 층(CanvasLayer)이라 3D 를 어떻게
	## 감추든 그대로 뜹니다.
	if world == null or world_env == null:
		return
	if on:
		_blacked.clear()
		for c in world.get_children():
			var n := c as Node3D
			# 사람은 남깁니다. 이펙트는 이 뒤에 생기므로 목록에 안 듭니다.
			if n == null or n == player or n is Enemy or not n.visible:
				continue
			_blacked.append(n)
			n.visible = false
		_bg_was = world_env.background_color
		_amb_was = world_env.ambient_light_energy
		_fog_was = world_env.fog_enabled
		world_env.background_color = Color.BLACK
		# 주변광은 **조금 남깁니다.** 0 으로 두면 해가 안 닿는 면이 새까매져
		# 아이가 실루엣만 남습니다 - 누가 누구인지 알아볼 수 없습니다.
		world_env.ambient_light_energy = 0.35
		world_env.fog_enabled = false
		return
	for n in _blacked:
		if is_instance_valid(n):
			n.visible = true
	_blacked.clear()
	world_env.background_color = _bg_was
	world_env.ambient_light_energy = _amb_was
	world_env.fog_enabled = _fog_was


func _on_ultimate(_ratio: float, on: bool, note: String) -> void:
	## 필살기가 알려 오는 한마디를 받아 둡니다. 켜지고 꺼지는 순간에는 화면
	# 가운데에도 띄웁니다 - 세상이 멈추는 일이라 게이지 옆 글자만으로는
	## 무슨 일이 일어났는지 안 읽힙니다.
	_ult_note = note
	# 켜지고 꺼지는 순간에 화면을 검게 했다 되돌립니다. 게이지 옆 글자만으로는
	# 세상이 멈췄다는 것이 안 읽힙니다.
	if on and note == "필살":
		blackout(true)
	elif not on:
		blackout(false)
	if on and note == "필살":
		ui.toast("필살 - 구르기·밀기·고함", Color(1.0, 0.85, 0.4))
	elif not on and note != "":
		ui.toast("필살 해제 (%s)" % note, UiTheme.DIM)


func _on_breath_empty() -> void:
	ui.toast("숨이 찼습니다", UiTheme.DIM)


func _on_touch_grab() -> void:
	if phase == Phase.PLAYING and is_instance_valid(player):
		player.grab_press()


func _on_touch_grab_release() -> void:
	if phase == Phase.PLAYING and is_instance_valid(player):
		player.grab_release()


func _on_touch_dash() -> void:
	if phase == Phase.PLAYING and is_instance_valid(player):
		player.dash()


func _drive_skill_hud() -> void:
	## 기술 셋의 준비 상태를 화면에 흘려 보냅니다.
	##
	## UI 가 주인공을 직접 들여다보지 않게 여기서 밀어 줍니다 - 그래야 확인용
	## 실행이나 제목 화면처럼 주인공이 없는 때에 UI 가 깨지지 않습니다.
	if ui == null or not is_instance_valid(player):
		return
	ui.set_ultimate(player.ultimate.ratio(), player.ultimate.active,
		_ult_note, player.ultimate.unlocked())
	for kind in ["shout", "grab", "roll"]:
		ui.set_skill_state(kind, player.skill_charge(kind),
			player.skill_winded(kind))


func _process(delta: float) -> void:
	_frames += 1
	if _leak_probe and _frames % 600 == 0:
		print("[쌓임] f=%d 노드=%d 고아=%d 자원=%d 그리기=%d 프레임=%.1fms 메모리=%.0fMB 텍스처=%.0fMB 비디오=%.0fMB" % [
			_frames,
			get_tree().get_node_count(),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	_drive_skill_hud()
	_drive_test_spawns(delta)
	# 읽는 동안 바깥부터 어두워집니다. 켜고 끄는 것이 아니라 **옮겨** 갑니다 -
	# 한 프레임에 바뀌면 화면이 깜빡인 것으로 보입니다.
	if is_instance_valid(player) and ui != null:
		var want: float = 1.0 if player.is_reading() else 0.0
		_read_focus = move_toward(_read_focus, want, delta * (2.2 if want > 0.0 else 3.5))
		# 남길 자리는 **아이의 화면 위치**입니다. 화면 한가운데로 고정하면
		# 카메라가 따라오는 중이거나 벽에 막혀 밀렸을 때 아이가 어둠에
		# 걸칩니다.
		var at := Vector2(0.5, 0.5)
		if _read_focus > 0.001 and camera != null:
			var sz: Vector2 = get_viewport().get_visible_rect().size
			if sz.x > 0.0 and sz.y > 0.0:
				var p2 := camera.unproject_position(
					player.global_position + Vector3(0, 0.45, 0))
				at = Vector2(p2.x / sz.x, p2.y / sz.y)
		ui.set_read_focus(_read_focus, at)

	if _trace_at > 0 and absi(_frames - _trace_at) < 3:
		print("[trace] f=%d phase=%d cam=%s player=%s 거리=%.2f vel=%.1f" % [
			_frames, phase, cam_rig.global_position.round(),
			player.global_position.round() if is_instance_valid(player) else Vector3.ZERO,
			cam_rig.global_position.distance_to(player.global_position) if is_instance_valid(player) else -1.0,
			player.velocity.length() if is_instance_valid(player) else -1.0])
	if _fps_log:
		_fps_worst = maxf(_fps_worst, delta)
		_fps_sum += delta
		_fps_count += 1
		if _fps_count >= 60:
			print("[fps] 평균 %.1fms  최악 %.1fms" % [
				_fps_sum / _fps_count * 1000.0, _fps_worst * 1000.0])
			_fps_worst = 0.0
			_fps_sum = 0.0
			_fps_count = 0
	if _shot_path != "" and _frames == _shot_at:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("[shot] ", _shot_path)
		get_tree().quit()
		return
	if _die_at > 0 and _frames == _die_at and is_instance_valid(player):
		print("[debug] ", _die_at, " 프레임에서 강제 사망")
		player.take_damage(99999.0, player.global_position + Vector3(0, 0, 2.5))

	if _quit_at > 0 and _frames >= _quit_at:
		print("[ok] ", _frames, " 프레임 무사히 지났습니다")
		get_tree().quit()
		return

	if _bot:
		_bot_think(delta)

	if not is_instance_valid(player) or state == null:
		return

	# 카메라는 조금 늦게 따라옵니다. 딱 붙으면 화면이 캐릭터와 함께 떨립니다.
	#
	# 다만 줌인한 뒤로는 늦는 정도를 조여야 합니다. 보이는 범위가 절반이 되면
	# 같은 지연이 화면에서 차지하는 비율은 두 배가 되고, 구르기(13.5m/s) 중에
	# 캐릭터가 화면 밖으로 밀려났습니다.
	var want := player.global_position
	cam_rig.global_position = cam_rig.global_position.lerp(want, 1.0 - exp(-17.0 * delta))
	if cam_mode == CamMode.SHOULDER:
		_drive_shoulder(delta)

	if _shake > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var k := _shake_time / maxf(0.001, _shake)
		camera.h_offset = randf_range(-1.0, 1.0) * 0.35 * k
		camera.v_offset = randf_range(-1.0, 1.0) * 0.35 * k
		if _shake_time <= 0.0:
			_shake = 0.0
			camera.h_offset = 0.0
			camera.v_offset = 0.0

	if _pose != "" and phase == Phase.PLAYING and is_instance_valid(player):
		_drive_pose()

	var _t0 := Time.get_ticks_usec()
	# 캐릭터를 가리는 벽을 걷어내려면 셰이더가 두 점을 알아야 합니다.
	if dungeon != null and is_instance_valid(player):
		var focus: Vector3 = player.global_position + Vector3(0, 0.7, 0)
		var radius: float = SHOULDER_FADE if cam_mode == CamMode.SHOULDER else 1.15
		dungeon.set_fade_focus(camera.global_position, focus, radius)
		# 벽에 걸린 소품(시계·액자·책장)도 **같은 값**으로 함께 비칩니다.
		# 값을 여기서 한 번 만들어 둘에 나눠 주므로 어긋날 자리가 없습니다.
		for node in get_tree().get_nodes_in_group("props"):
			var prop := node as Prop
			if is_instance_valid(prop) and prop.wants_wall():
				prop.set_fade_focus(camera.global_position, focus, radius)
	if _leak_probe:
		# 순간값은 흔들립니다. **평균**을 냅니다.
		_leak_proc += Performance.get_monitor(Performance.TIME_PROCESS)
		_leak_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_leak_n += 1
		if _frames % 600 == 0:
			print("  └ 걷어내기 %.2fms  소품=%d 적=%d  |  평균 process %.2fms + physics %.2fms = %.2fms" % [
				(Time.get_ticks_usec() - _t0) / 1000.0,
				get_tree().get_nodes_in_group("props").size(),
				get_tree().get_nodes_in_group("enemies").size(),
				_leak_proc / _leak_n * 1000.0, _leak_phys / _leak_n * 1000.0,
				(_leak_proc + _leak_phys) / _leak_n * 1000.0])
			_leak_proc = 0.0
			_leak_phys = 0.0
			_leak_n = 0

	if ui.touch != null and is_instance_valid(player):
		player.touch_move = ui.touch.move

	if phase == Phase.PLAYING:
		ui.update_hud(state, _alive, 0.0)
		if shop != null and shop.is_near():
			ui.set_prompt("E - 상점")
		elif _alive == 0 and portal != null:
			ui.set_prompt("파란 문으로 내려가세요")
		else:
			ui.set_prompt("")


func _show_debug_ui() -> void:
	## 화면 하나를 콕 집어 띄웁니다. 오버레이는 특정 순간에만 나오는데,
	## 그 순간을 기다렸다 찍는 것은 불안정합니다.
	match _debug_ui:
		"boon":
			_boon_options = _label_boons(state.offer_boons(rng))
			phase = Phase.BOON
			get_tree().paused = true
			ui.show_boons(_boon_options)
		"shop":
			state.gold = 220
			_open_shop()
		"death":
			state.kills = 37
			state.gold = 412
			state.elapsed = 254.0
			phase = Phase.DEAD
			get_tree().paused = true
			ui.show_death(state)
		"help":
			phase = Phase.PAUSED
			get_tree().paused = true
			ui.show_help("일시정지")
		"options":
			ui.toggle_options()
		"riglab":
			open_riglab()
		"title":
			ui.stop_recording()
			phase = Phase.TITLE
			get_tree().paused = true
			ui.show_title()


# ---------------------------------------------------------------- 자동 플레이

func _bot_think(delta: float) -> void:
	## 규칙은 단순합니다: 적이 있으면 가장 가까운 적에게 붙어 때리고, 없으면
	## 문으로 갑니다. 잘 싸우는 봇을 만드는 것이 목적이 아니라, 모든 화면을
	## 한 번씩 지나가게 하는 것이 목적입니다.
	match phase:
		Phase.BOON:
			_on_boon_chosen(String(_boon_options[0]["id"]))
			return
		Phase.SHOP:
			# 살 수 있는 것을 하나 사 보고 나갑니다.
			for i in _shop_items.size():
				_on_shop_bought(i)
			_close_overlay()
			return
		Phase.DEAD:
			if ui.overlay_visible():
				_bot_deaths += 1
				print("[bot] %d번째 죽음 - 지하 %d층, 처치 %d, 금화 %d"
					% [_bot_deaths, state.floor_num, state.kills, state.gold])
				start_run()
			return
		Phase.PLAYING:
			pass
		_:
			return

	if not is_instance_valid(player) or dungeon == null:
		return

	var goal := Vector3.ZERO
	var enemy: Node3D = null
	var best := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node3D
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			enemy = e
	if enemy != null:
		goal = enemy.global_position
	elif shop != null and not _bot_shopped:
		if shop.is_near():
			_bot_shopped = true
			_open_shop()
			return
		goal = shop.global_position
	elif portal != null:
		goal = portal.global_position
	else:
		return

	# 붙었으면 멈춰서 때립니다.
	if enemy != null and best < 2.3:
		player.bot_move = Vector2.ZERO
		var to := enemy.global_position - player.global_position
		to.y = 0.0
		if to.length_squared() > 0.001:
			debug_aim = to.normalized()
		# 주기적으로 **뒤로 돌아 들어가 봅니다.** 잡기가 등 뒤에서만 되므로,
		# 정면으로만 붙는 봇은 그 경로를 영영 안 지나갑니다. 사람이 하는
		# 것과 같은 방식(옆으로 돌기)으로 시도해야 실제로 잡히는지 알 수
		# 있습니다.
		var circling := (_frames % 300) < 150
		if circling and not player.behind_of(enemy):
			# 적을 중심으로 옆으로 돕니다.
			var side := Vector3(-to.z, 0.0, to.x).normalized()
			player.bot_move = Vector2(side.x, side.z)
			return
		if circling:
			if player._held == null:
				player.grab_press()
			elif _frames % 300 == 120:
				player.grab_press()          # 두 번째 누름 = 던지기
			return
		# 소리와 잡기를 번갈아 씁니다. 한 가지만 쓰면 나머지 경로가 검사되지
		# 않습니다 - 소품 집기·던지기가 여기서만 지나갑니다.
		player.attack()
		# 붙어 있고 든 것이 없을 때 누르면 밀기입니다.
		if _frames % 90 == 0:
			player.grab_press()
		return

	# 지나가다 소품을 집고, 잠시 뒤 방향을 준 채 다시 누릅니다 = 던지기.
	# 두 번 다 누름이므로, 봇도 사람과 같은 길을 지나갑니다.
	if _frames % 150 == 0:
		player.grab_press()
	elif _frames % 150 == 40:
		player.grab_press()
	if _frames % 1500 < 2:
		# 카툰 옵션을 켰다 껐다 해 봅니다. 되돌리는 쪽(끄기)은 켜는 쪽보다
		# 틀리기 쉬운데, 사람이 안 눌러 보면 영영 안 지나갑니다.
		toggle_toon()

	_bot_repath -= delta
	if _bot_repath <= 0.0:
		_bot_repath = 0.35
		_bot_path = dungeon.path_between(player.global_position, goal)

	var step := goal
	for wp in _bot_path:
		if wp.distance_to(player.global_position) > 1.2:
			step = wp
			break
	var dir := step - player.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		player.bot_move = Vector2.ZERO
		return
	dir = dir.normalized()
	player.bot_move = Vector2(dir.x, dir.z)
	debug_aim = dir


# ---------------------------------------------------------------- 정적 도우미

static func shake(duration: float, _amount: float = 0.2) -> void:
	if instance == null:
		return
	instance._shake = maxf(instance._shake, duration)
	instance._shake_time = maxf(instance._shake_time, duration)


static func add_gold(amount: int) -> void:
	if instance == null or instance.state == null:
		return
	instance.state.gold += amount
	Sfx.play(Sfx.COIN, -8.0, 0.14)
