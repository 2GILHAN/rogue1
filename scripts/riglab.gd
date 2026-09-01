class_name RigLab
extends Node3D

## 리그 실험실. 게임을 시작하기 전에 **뼈대를 만져 보고 그 결과를 바로 보는**
## 자리입니다.
##
## # 왜 필요한가
##
## 리그가 어긋나면 그 위의 모든 것이 어긋납니다. 골반이 키의 23% 에 잡혀 있던
## 것을 찾는 데 오래 걸렸는데, 이유는 단순합니다 - **눈으로 볼 방법이
## 없었습니다.** 게임을 띄우고, 봇을 돌리고, 프레임을 골라 찍고, 확대해서
## 봐야 했습니다. 값을 하나 바꾸려면 클립을 다시 굽고 임포트하고 그 과정을
## 처음부터 반복했습니다.
##
## 여기서는 슬라이더를 움직이면 그 자리에서 바뀝니다.
##
## # 미리보기와 실제 결과가 같아야 합니다
##
## 본의 쉬는 자세(rest)만 옮기면 살가죽이 따라 올라가 몸이 찌그러집니다.
## 오프라인 도구(tools/raise_hips.py)는 glTF 의 inverseBindMatrices 를 다시
## 계산해서 이것을 막습니다. 런타임에도 같은 것이 있습니다 -
## `Skin.set_bind_pose()` 가 그 행렬입니다. 여기서도 본을 옮길 때마다 바인드
## 자세를 새 쉬는 자세로 다시 계산하므로, **여기서 보이는 것이 구운 뒤에도
## 그대로** 나옵니다.
##
## # 여기서 값을 정하고, 굽는 것은 도구가 합니다
##
## 이 화면은 GLB 를 고치지 않습니다. 마음에 드는 값을 찾으면 그 값으로
## `tools/raise_hips.py` 를 부르는 명령을 찍어 줍니다. 실제로 굽는 것은
## 그쪽입니다 - 게임이 에셋을 몰래 고치기 시작하면 무엇이 원본인지
## 알 수 없게 됩니다.

signal closed

## 볼 수 있는 캐릭터. 게임에 실제로 쓰는 것만 올립니다.
const CHARACTERS := [
	{"name": "주인공", "path": "res://assets/characters/hero.glb"},
	{"name": "적1_박치기", "path": "res://assets/characters/foe_charger.glb"},
	{"name": "적3_던지기", "path": "res://assets/characters/foe_thrower.glb"},
	{"name": "보스_선생님", "path": "res://assets/characters/boss_teacher.glb"},
]

## 바닥을 미는 거리를 재는 창. 짧으면 걸음 하나에 걸려 값이 튀고, 길면
## 슬라이더를 움직이고 나서 한참 뒤에야 숫자가 따라옵니다.
const MEASURE_SECONDS := 2.0

## 미리보기 카메라. 게임보다 훨씬 낮게 봅니다 - 다리를 보러 온 자리인데
## 게임처럼 63도로 내려다보면 정수리만 보입니다.
const CAM_PITCH := 12.0
const CAM_DIST := 2.6

var _model: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _skins: Array[Skin] = []
var _cam: Camera3D
var _cam_yaw := 0.6

## 처음 불러왔을 때의 뼈 길이. 슬라이더는 늘 **원본 기준**으로 계산합니다 -
## 지금 값에 곱해 나가면 슬라이더를 움직일수록 값이 떠내려갑니다.
var _base_rest: Dictionary = {}

## 동작 크기 조절값. 캐릭터마다 따로 기억합니다.
##
## 왜 배율인가: 클립은 이미 구워진 회전 키의 나열입니다. 각 키를 **쉬는 자세
## 기준으로** 보면 그것이 곧 그 프레임의 각도이고, 거기에 배율을 곱하면
## 프레임마다의 각도가 그대로 비율만 바뀝니다. 리듬(어느 프레임에 가장 크게
## 벌어지는지)은 건드리지 않고 크기만 줄이고 늘립니다.
const TUNE_KEYS := ["legs", "arms", "torso", "bob"]
var _tune: Dictionary = {}

var _char_index := 0
var _clip := "Walk"
var _speed := 1.0
var _hip := 0.33
var _hip_base := 0.33
## 열자마자 이 값으로 시작합니다(--hip=). 두 값을 화면으로 비교할 때
## 슬라이더를 손으로 맞추면 같은 값인지 알 수 없습니다.
var start_hip := 0.0
## 열자마자 이 동작으로 시작합니다(--clip=).
var start_clip := ""
## 열자마자 이 캐릭터로 시작합니다(--char=).
var start_char := -1
## 열자마자 동작 크기를 이 배율로 둡니다(--motion=).
var start_motion := 0.0

# 측정
var _feet: Array[BoneAttachment3D] = []
var _prev_z := [0.0, 0.0]
var _ground_sum := 0.0
var _ground_time := 0.0
var _ground_speed := 0.0

# UI
var _ui: Control
var _readout: Label
var _hip_label: Label
var _speed_label: Label
var _clip_buttons: Array[Button] = []
var _tune_sliders: Dictionary = {}
var _frame_label: Label
## -1 이면 그냥 흐릅니다. 0~1 이면 그 지점에 세웁니다.
var _scrub_at := -1.0
## 측정값을 찍을지. 화면 없이 두 값을 비교할 때(--motion=)만 켭니다 -
## 늘 켜 두면 2초마다 한 줄씩 쌓여 다른 로그를 덮습니다.
var _probe_print := false
var _char_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # 게임이 멈춰 있어도 돕니다
	_probe_print = start_motion > 0.0
	_build_stage()
	_build_ui()
	_load_character(0 if start_char < 0 else start_char)


# ---------------------------------------------------------------- 무대

func _build_stage() -> void:
	## 게임 장면과 섞이지 않게 조명과 바닥을 따로 세웁니다. 던전 조명(따뜻하고
	## 어두운)으로 리그를 보면 다리가 그림자에 묻혀 보이지 않습니다.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.80)
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 34, 0)
	sun.light_energy = 1.0
	add_child(sun)

	# 격자 바닥. 발이 바닥을 미는지 보려면 **기준선**이 있어야 합니다 -
	# 민무늬 바닥에서는 제자리걸음과 전진이 똑같아 보입니다.
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(-10, 11):
		var v := float(i) * 0.25
		var c := Color(0.42, 0.42, 0.50) if i % 4 != 0 else Color(0.62, 0.62, 0.72)
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(v, 0.001, -2.5))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(v, 0.001, 2.5))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(-2.5, 0.001, v))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(2.5, 0.001, v))
	im.surface_end()
	grid.mesh = im
	add_child(grid)

	_cam = Camera3D.new()
	_cam.fov = 42.0
	add_child(_cam)
	# **이 카메라로 보게 합니다.** 안 그러면 게임 카메라가 그대로 살아 있어
	# 던전을 위에서 내려다보는 화면에 실험실 UI 만 얹힙니다(실제로 그랬습니다).
	_cam.current = true
	_place_camera()


func _place_camera() -> void:
	var rad := deg_to_rad(CAM_PITCH)
	var eye := Vector3(sin(_cam_yaw) * CAM_DIST * cos(rad), CAM_DIST * sin(rad) + 0.62,
		cos(_cam_yaw) * CAM_DIST * cos(rad))
	_cam.position = eye
	_cam.look_at(Vector3(0, 0.62, 0), Vector3.UP)


# ---------------------------------------------------------------- 캐릭터

func _load_character(index: int) -> void:
	_char_index = clampi(index, 0, CHARACTERS.size() - 1)
	if _model != null:
		_model.queue_free()
	_feet.clear()
	_skins.clear()
	_base_rest.clear()
	_reset_measure()

	var path: String = CHARACTERS[_char_index]["path"]
	_model = Models.spawn(path)
	add_child(_model)
	_skel = Models.find_skeleton(_model)
	_anim = Models.find_anim(_model)

	if _skel != null:
		for bone in ["Hips", "Spine", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]:
			var idx := _skel.find_bone(bone)
			if idx >= 0:
				_base_rest[bone] = _skel.get_bone_rest(idx)
		# 스킨은 GLB 에서 온 **공유 자원**입니다. 그대로 고치면 이 화면에서
		# 만진 것이 게임 안 캐릭터에까지 남습니다. 복제해서 씁니다.
		for mi in _mesh_list(_model):
			if mi.skin != null:
				var dup: Skin = mi.skin.duplicate()
				mi.skin = dup
				_skins.append(dup)
		for bone in ["LeftFoot", "RightFoot"]:
			var a := Models.add_anchor(_model, bone)
			if a != null:
				_feet.append(a)

	_snapshot_clips()
	if start_motion > 0.0:
		for key in TUNE_KEYS:
			if not _tune.has(_char_index):
				_tune[_char_index] = {}
			_tune[_char_index][key] = start_motion
	_apply_motion()
	_hip_base = _measure_hip_ratio()
	_hip = _hip_base if start_hip <= 0.0 else start_hip
	_apply_hip()
	_play(_clip if start_clip == "" else start_clip)
	_sync_tune_sliders()
	_refresh_buttons()


func _mesh_list(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _play(clip: String) -> void:
	_clip = clip
	if _anim == null:
		return
	var name := Models.clip(_anim, clip)
	if name == "":
		return
	_anim.play(name)
	_anim.speed_scale = _speed
	_reset_measure()


# ---------------------------------------------------------------- 리그 조정

func _bone_height(bone: String) -> float:
	## 그 본이 바닥에서 얼마나 높은가(월드 기준).
	if _skel == null:
		return 0.0
	var idx := _skel.find_bone(bone)
	if idx < 0:
		return 0.0
	var t: Transform3D = _skel.global_transform * _skel.get_bone_global_rest(idx)
	return t.origin.y - global_position.y


func _measure_hip_ratio() -> float:
	var foot := minf(_bone_height("LeftFoot"), _bone_height("RightFoot"))
	var head := _bone_height("Head")
	# 키는 머리 본이 아니라 정수리까지입니다. 본만으로는 모르니 일정한 배수를
	# 씁니다(raise_hips.py 와 같은 1.31) - 절대값이 아니라 **비교할 수 있는
	# 기준**이면 됩니다.
	var height := (head - foot) * 1.31
	if height <= 0.001:
		return 0.0
	return (_bone_height("Hips") - foot) / height


func _apply_hip() -> void:
	## 골반을 올리고 다리를 그만큼 늘립니다. tools/raise_hips.py 와 **같은
	## 계산**입니다 - 여기서 본 것이 구운 뒤에도 나와야 하므로 식이 갈라지면
	## 안 됩니다.
	if _skel == null or not _base_rest.has("Hips"):
		return
	# 원본 상태로 되돌린 뒤 다시 계산합니다. 지금 값에 이어서 곱하면
	# 슬라이더를 움직일수록 값이 떠내려갑니다.
	for bone in _base_rest:
		var i := _skel.find_bone(String(bone))
		if i >= 0:
			_skel.set_bone_rest(i, _base_rest[bone])
	_rebuild_binds()

	var base_ratio := _measure_hip_ratio()
	if base_ratio <= 0.001:
		return
	var foot := minf(_bone_height("LeftFoot"), _bone_height("RightFoot"))
	var hip_now := _bone_height("Hips") - foot
	var height := hip_now / base_ratio
	var delta := height * _hip - hip_now
	if absf(delta) < 0.0005:
		return
	var k := (hip_now + delta) / hip_now

	_shift("Hips", delta)
	_shift("Spine", -delta)
	for side in ["Left", "Right"]:
		_stretch(side + "Leg", k)
		_stretch(side + "Foot", k)
	_rebuild_binds()


func _shift(bone: String, amount: float) -> void:
	var i := _skel.find_bone(bone)
	if i < 0 or not _base_rest.has(bone):
		return
	var t: Transform3D = _base_rest[bone]
	t.origin.y += amount
	_skel.set_bone_rest(i, t)


func _stretch(bone: String, k: float) -> void:
	var i := _skel.find_bone(bone)
	if i < 0 or not _base_rest.has(bone):
		return
	var t: Transform3D = _base_rest[bone]
	t.origin *= k
	_skel.set_bone_rest(i, t)


func _rebuild_binds() -> void:
	## **바인드 자세를 새 쉬는 자세로 다시 계산합니다.**
	##
	## 이것이 이 화면의 핵심입니다. 빼먹으면 본을 올린 만큼 살가죽이 딸려
	## 올라가 몸이 찌그러지고, 미리보기가 실제 결과와 달라집니다.
	if _skel == null:
		return
	for skin in _skins:
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				var by_name := _skel.find_bone(skin.get_bind_name(b))
				if by_name < 0:
					continue
				bone = by_name
			skin.set_bind_pose(b, _skel.get_bone_global_rest(bone).affine_inverse())


# ---------------------------------------------------------------- 측정

func _reset_measure() -> void:
	_ground_sum = 0.0
	_ground_time = 0.0
	_prev_z = [0.0, 0.0]


func _measure(delta: float) -> void:
	## 발이 바닥을 미는 속도. player.gd 의 WALK_GROUND 와 **같은 자**입니다 -
	## 여기서 읽은 값을 그대로 옮겨 적을 수 있어야 합니다.
	if _feet.size() < 2 or _model == null:
		return
	# 모델 홀더에는 180도 요(Models.MODEL_YAW)가 걸려 있어서, 그 기준으로
	# 재면 앞뒤가 뒤집힙니다. 게임(player.gd 의 WALK_GROUND)과 **같은 숫자**가
	# 나와야 여기서 읽은 값을 그대로 옮겨 적을 수 있습니다.
	var inv := _model.global_transform.basis.inverse()
	var back := 0.0
	for i in 2:
		var z: float = -(inv * (_feet[i].global_position - _model.global_position)).z
		if _ground_time > 0.0:
			back = maxf(back, z - _prev_z[i])
		_prev_z[i] = z
	_ground_sum += maxf(back, 0.0)
	_ground_time += delta
	if _ground_time >= MEASURE_SECONDS:
		if _probe_print:
			print("LAB 배율=%.2f 바닥=%.3f m/s" % [_tune_of("legs"),
				(_ground_sum / _ground_time) / maxf(_speed, 0.01)])
		# 배속을 나눠 **1배속 기준**으로 환산합니다. 그래야 배속을 바꿔도
		# 같은 숫자가 나오고, 코드에 적을 값이 됩니다.
		_ground_speed = (_ground_sum / _ground_time) / maxf(_speed, 0.01)
		_reset_measure()


func _hand_gap() -> Vector2:
	## 손 사이 거리와 팔 길이. 고함·박치기 자세를 잡을 때 쓰던 자입니다.
	if _skel == null:
		return Vector2.ZERO
	var l := _skel.find_bone("LeftHand")
	var r := _skel.find_bone("RightHand")
	var sh := _skel.find_bone("LeftArm")
	if l < 0 or r < 0 or sh < 0:
		return Vector2.ZERO
	var lp: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(l)).origin
	var rp: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(r)).origin
	var sp: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(sh)).origin
	return Vector2(lp.distance_to(rp), sp.distance_to(lp))


func _process(delta: float) -> void:
	if _model == null:
		return
	_measure(delta)
	_cam_yaw += delta * 0.25
	_place_camera()
	var gap := _hand_gap()
	_readout.text = "\n".join([
		"골반   %.0f%%  (원본 %.0f%%)" % [_hip * 100.0, _hip_base * 100.0],
		"바닥   %.3f m/s  (1배속)" % _ground_speed,
		"손간격 %.3f m   팔길이 %.3f m" % [gap.x, gap.y],
		"본     %d 개" % (_skel.get_bone_count() if _skel != null else 0),
	])


# ---------------------------------------------------------------- 화면

func _build_ui() -> void:
	## 왼쪽에 한 줄로 세웁니다. 오른쪽은 캐릭터가 서는 자리입니다.
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = 336
	panel.offset_bottom = 704
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.07, 0.09, 0.94)
	box.border_color = Color(0.34, 0.34, 0.40)
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", box)
	_ui.add_child(panel)

	# 항목이 늘면 판 밖으로 흘러넘칩니다(실제로 저장·닫기 버튼이 화면
	# 아래로 잘렸습니다). 스크롤을 한 겹 끼워 두면 그 뒤로 무엇을 더해도
	# 다시 자리를 재지 않아도 됩니다.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(UiTheme.label("리그 실험실", 24, UiTheme.ACCENT))
	col.add_child(UiTheme.label("뼈대를 만지고 그 자리에서 결과를 봅니다", 14, UiTheme.DIM))

	col.add_child(_gap(6))
	col.add_child(UiTheme.label("캐릭터", 15, UiTheme.DIM))
	for i in CHARACTERS.size():
		var b := _button(String(CHARACTERS[i]["name"]))
		var at := i
		b.pressed.connect(func() -> void: _load_character(at))
		col.add_child(b)
		_char_buttons.append(b)

	col.add_child(_gap(6))
	col.add_child(UiTheme.label("동작", 15, UiTheme.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for name: String in ["Idle", "Walk", "Run", "Push"]:
		var b := _button(name)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var which := name
		b.pressed.connect(func() -> void:
			_play(which)
			_refresh_buttons())
		row.add_child(b)
		_clip_buttons.append(b)

	_speed_label = UiTheme.label("배속 1.00", 15, UiTheme.TEXT)
	col.add_child(_speed_label)
	var sp := _slider(0.1, 6.0, 0.05, 1.0)
	sp.value_changed.connect(func(v: float) -> void:
		_speed = v
		if _anim != null:
			_anim.speed_scale = v
		_speed_label.text = "배속 %.2f" % v
		_reset_measure())
	col.add_child(sp)

	_hip_label = UiTheme.label("골반 33%", 15, UiTheme.TEXT)
	col.add_child(_hip_label)
	# 골반은 이 화면의 이유입니다. 슬라이더를 움직이면 그 프레임에 바뀝니다 -
	# 굽고 임포트하고 다시 띄우는 한 바퀴가 사라집니다.
	var hp := _slider(0.18, 0.50, 0.005, 0.33)
	hp.value_changed.connect(func(v: float) -> void:
		_hip = v
		_hip_label.text = "골반 %.0f%%" % (v * 100.0)
		_apply_hip()
		_reset_measure())
	col.add_child(hp)

	# 동작 크기. 프레임마다의 각도에 배율을 곱합니다 - 리듬은 그대로 두고
	# 크기만 바뀝니다.
	col.add_child(_gap(4))
	col.add_child(UiTheme.label("동작 크기 (배율)", 15, UiTheme.DIM))
	for spec in [["legs", "다리"], ["arms", "팔"], ["torso", "상체"],
			["bob", "반동"]]:
		var key := String(spec[0])
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 6)
		col.add_child(row2)
		var lbl := UiTheme.label(String(spec[1]), 15, UiTheme.DIM)
		lbl.custom_minimum_size = Vector2(46, 24)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row2.add_child(lbl)
		var sl := _slider(0.0, 2.0, 0.05, 1.0)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(sl)
		var val := UiTheme.label("1.00", 15, UiTheme.TEXT)
		val.custom_minimum_size = Vector2(46, 24)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row2.add_child(val)
		sl.value_changed.connect(func(v: float) -> void:
			val.text = "%.2f" % v
			_set_tune(key, v)
			_reset_measure())
		_tune_sliders[key] = [sl, val]

	# 프레임 세우기. 크기를 조절할 때 **같은 프레임**을 놓고 비교해야 하는데,
	# 흐르는 동작에서는 매번 다른 순간을 보게 됩니다.
	col.add_child(_gap(4))
	_frame_label = UiTheme.label("프레임 (흐름)", 15, UiTheme.DIM)
	col.add_child(_frame_label)
	var fr := _slider(-1.0, 1.0, 0.02, -1.0)
	fr.value_changed.connect(func(v: float) -> void: _scrub(v))
	col.add_child(fr)

	col.add_child(_gap(6))
	_readout = UiTheme.label("", 15, UiTheme.TEXT)
	col.add_child(_readout)

	col.add_child(_gap(8))
	var save := _button("값 저장 (굽기에 반영)")
	save.pressed.connect(_save_tuning)
	col.add_child(save)
	var bake := _button("굽는 명령 찍기")
	bake.pressed.connect(_print_command)
	col.add_child(bake)
	var back := _button("닫기 (Esc)")
	back.pressed.connect(func() -> void: closed.emit())
	col.add_child(back)


func _print_command() -> void:
	## 여기서 GLB 를 고치지 않습니다. 게임이 에셋을 몰래 고치기 시작하면
	## 무엇이 원본인지 알 수 없게 됩니다. 대신 그대로 붙여 넣을 수 있는
	## 명령을 찍습니다.
	var path: String = CHARACTERS[_char_index]["path"].replace("res://", "")
	print("")
	print("  # 리그 실험실에서 고른 값")
	print("  python tools/raise_hips.py %s --hip %.3f" % [path, _hip])
	print("  # 다리 길이가 바뀌면 보폭도 바뀝니다. 다시 재서 옮겨 적으세요:")
	print("  #   player.gd  WALK_GROUND / RUN_GROUND")
	print("  #   enemy.gd   WALK_GROUND")
	print("  # 지금 이 화면의 측정값: %.3f m/s (1배속, %s)" % [_ground_speed, _clip])
	print("")


func _sync_tune_sliders() -> void:
	## 캐릭터를 바꾸면 슬라이더도 그쪽 값으로 돌아가야 합니다. 안 그러면
	## 앞 캐릭터의 숫자가 남아 있어서, 건드리지도 않은 값이 저장됩니다.
	for key in _tune_sliders:
		var pair: Array = _tune_sliders[key]
		var v := _tune_of(String(key))
		(pair[0] as HSlider).set_value_no_signal(v)
		(pair[1] as Label).text = "%.2f" % v


func _refresh_buttons() -> void:
	for i in _char_buttons.size():
		_char_buttons[i].modulate = Color(1, 1, 1) if i == _char_index else Color(0.62, 0.62, 0.66)
	var names := ["Idle", "Walk", "Run", "Push"]
	for i in _clip_buttons.size():
		_clip_buttons[i].modulate = Color(1, 1, 1) if names[i] == _clip else Color(0.62, 0.62, 0.66)


func _gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_override("font", UiTheme.font())
	b.add_theme_font_size_override("font_size", 15)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.14, 0.14, 0.17, 0.95)
	box.border_color = Color(0.34, 0.34, 0.40)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	for slot in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(slot, box)
	b.add_theme_color_override("font_color", UiTheme.TEXT)
	return b


func _slider(low: float, high: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 26)
	return s


# ---------------------------------------------------------------- 동작 크기

## 본 이름 -> 어느 손잡이에 묶이는가. 이름의 일부만 봅니다 - 리그마다
## 접두사가 달라도(LeftUpLeg, mixamorig:LeftUpLeg) 같이 잡히게.
const BONE_GROUP := {
	"UpLeg": "legs", "Leg": "legs", "Foot": "legs", "Toe": "legs",
	"Shoulder": "arms", "Arm": "arms", "ForeArm": "arms", "Hand": "arms",
	"Hips": "torso", "Spine": "torso", "Chest": "torso",
	"Neck": "torso", "Head": "torso",
}

## 원본 클립. 배율은 **늘 원본에서** 계산합니다 - 지금 값에 이어서 곱하면
## 슬라이더를 움직일수록 각도가 떠내려갑니다(골반 슬라이더와 같은 이유).
var _orig_clips: Dictionary = {}


func _tune_of(key: String) -> float:
	var t: Dictionary = _tune.get(_char_index, {})
	return float(t.get(key, 1.0))


func _set_tune(key: String, value: float) -> void:
	if not _tune.has(_char_index):
		_tune[_char_index] = {}
	_tune[_char_index][key] = value
	_apply_motion()


func _snapshot_clips() -> void:
	## 클립을 **복제해서 끼워 넣습니다.** GLB 에서 온 애니메이션은 공유
	## 자원이라, 그대로 고치면 여기서 만진 것이 게임 안 캐릭터에까지 남습니다.
	_orig_clips.clear()
	if _anim == null:
		return
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		for clip_name in lib.get_animation_list():
			var src: Animation = lib.get_animation(clip_name)
			_orig_clips[String(clip_name)] = src.duplicate(true)
			lib.remove_animation(clip_name)
			lib.add_animation(clip_name, src.duplicate(true))


func _bone_group(path: String) -> String:
	## 트랙 경로("...Skeleton3D:LeftUpLeg")에서 손잡이를 고릅니다.
	var bone := path.get_slice(":", path.get_slice_count(":") - 1)
	# 긴 이름부터 봅니다. "ForeArm" 이 "Arm" 보다 먼저 걸려야 합니다 -
	# 둘 다 arms 라 지금은 같지만, 나중에 나누면 조용히 틀립니다.
	for key in ["ForeArm", "UpLeg", "Shoulder", "Toe", "Hand", "Foot",
			"Leg", "Arm", "Hips", "Spine", "Chest", "Neck", "Head"]:
		if bone.contains(key):
			return String(BONE_GROUP[key])
	return ""


func _apply_motion() -> void:
	## 프레임마다의 각도를 배율만큼 줄이거나 늘립니다.
	##
	## 키 값은 **쉬는 자세를 포함한 절대 회전**입니다. 쉬는 자세로 나눠서
	## 그 프레임이 얼마나 돌아갔는지를 꺼내고, 항등 회전에서 그만큼 다시
	## 섞습니다(slerp). 배율 0 이면 쉬는 자세, 1 이면 원본입니다.
	if _anim == null or _skel == null or _orig_clips.is_empty():
		return
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		for clip_name in lib.get_animation_list():
			var src: Animation = _orig_clips.get(String(clip_name))
			var dst: Animation = lib.get_animation(clip_name)
			if src == null or dst == null:
				continue
			for t in src.get_track_count():
				var path := String(src.track_get_path(t))
				var group := _bone_group(path)
				if group == "":
					continue
				var kind := src.track_get_type(t)
				if kind == Animation.TYPE_ROTATION_3D:
					_scale_rotation(src, dst, t, path, _tune_of(group))
				elif kind == Animation.TYPE_POSITION_3D:
					# 위치 트랙은 상하 반동(bob)뿐입니다.
					_scale_position(src, dst, t, path, _tune_of("bob"))


func _scale_rotation(src: Animation, dst: Animation, t: int, path: String,
		k: float) -> void:
	var bone := _skel.find_bone(path.get_slice(":", path.get_slice_count(":") - 1))
	if bone < 0:
		return
	var rest: Quaternion = _skel.get_bone_rest(bone).basis.get_rotation_quaternion()
	var inv := rest.inverse()
	for i in src.track_get_key_count(t):
		var q: Quaternion = src.track_get_key_value(t, i)
		var rel := inv * q
		dst.track_set_key_value(t, i, rest * _scale_quat(rel, k))


static func _scale_quat(q: Quaternion, k: float) -> Quaternion:
	## 회전을 **각도만** 배율만큼 바꿉니다.
	##
	## 처음에는 항등에서 slerp 로 섞었는데, 배율이 1 을 넘으면 늘어나지
	## 않았습니다(1.0 과 1.5 의 보폭이 같게 나왔습니다). slerp 는 사이를
	## 채우는 것이지 밖으로 늘리는 것이 아닙니다. 축과 각도로 풀어서 각도에만
	## 곱하면 줄이는 쪽도 늘리는 쪽도 똑같이 됩니다.
	# **먼저 짧은 쪽으로 돌려놓습니다.** q 와 -q 는 같은 회전인데, w 가 음수인
	# 쪽으로 들어오면 get_angle() 이 340도 같은 값을 돌려줍니다. 그 상태로
	# 배율을 곱하면 20도를 30도로 늘리려다 340도를 510도로 돌려 버립니다
	# (실측: 1.5배가 210도로 나왔습니다).
	var short := q if q.w >= 0.0 else Quaternion(-q.x, -q.y, -q.z, -q.w)
	var angle := short.get_angle()
	if angle < 0.0001:
		return Quaternion.IDENTITY
	return Quaternion(short.get_axis(), angle * k)


func _scale_position(src: Animation, dst: Animation, t: int, path: String,
		k: float) -> void:
	var bone := _skel.find_bone(path.get_slice(":", path.get_slice_count(":") - 1))
	if bone < 0:
		return
	var rest: Vector3 = _skel.get_bone_rest(bone).origin
	for i in src.track_get_key_count(t):
		var p: Vector3 = src.track_get_key_value(t, i)
		dst.track_set_key_value(t, i, rest + (p - rest) * k)


# ---------------------------------------------------------------- 프레임 세우기

func _scrub(v: float) -> void:
	## 슬라이더를 맨 왼쪽에 두면 그냥 흐르고, 오른쪽으로 옮기면 그 지점에
	## 세웁니다. 크기를 조절할 때는 **같은 프레임**을 놓고 비교해야 합니다 -
	## 흐르는 동작에서는 매번 다른 순간을 보게 되어, 방금 바꾼 것이 좋아진
	## 것인지 프레임이 달라진 것인지 알 수 없습니다.
	_scrub_at = v
	if _anim == null:
		return
	if v < 0.0:
		_anim.play(_anim.current_animation)
		_anim.speed_scale = _speed
		_frame_label.text = "프레임 (흐름)"
		return
	var clip := _anim.get_animation(_anim.current_animation)
	if clip == null:
		return
	var at := clip.length * clampf(v, 0.0, 1.0)
	_anim.speed_scale = 0.0
	_anim.seek(at, true)
	_frame_label.text = "프레임 %.2f초 / %.2f초 (%d번째)" % [
		at, clip.length, int(at * 24.0)]


# ---------------------------------------------------------------- 저장

## 조절값을 적어 두는 곳. `tools/make_kids.py` 가 구울 때 읽습니다.
const TUNING_PATH := "res://assets/anim_tuning.json"


func _save_tuning() -> void:
	## **여기서 GLB 를 고치지는 않습니다.** 고른 값을 파일에 적어 두고, 굽는
	## 것은 도구가 합니다 - 게임이 에셋을 몰래 고치기 시작하면 무엇이 원본인지
	## 알 수 없게 됩니다.
	##
	## 파일 하나를 사이에 두는 덕에 미리보기와 굽기가 **같은 값**을 봅니다.
	## 화면에서 고른 숫자를 손으로 옮겨 적으면 언젠가 어긋납니다.
	var data: Dictionary = {}
	if FileAccess.file_exists(TUNING_PATH):
		var old := FileAccess.get_file_as_string(TUNING_PATH)
		var parsed = JSON.parse_string(old)
		if parsed is Dictionary:
			data = parsed
	# **곱해서 쌓습니다.** 슬라이더는 "지금 클립 대비" 배율입니다 - 한 번 굽고
	# 나면 그 값이 클립에 들어가 있으므로 슬라이더는 1.0 로 돌아갑니다.
	# 저장할 때 곱해 두면 파일에는 늘 **원본 대비 총량**이 남습니다.
	for index in _tune:
		var id := String(CHARACTERS[int(index)]["path"]).get_file().get_basename()
		var have: Dictionary = data.get(id, {})
		var merged: Dictionary = have.duplicate()
		for key in _tune[index]:
			merged[key] = float(have.get(key, 1.0)) * float(_tune[index][key])
		data[id] = merged
	var f := FileAccess.open(TUNING_PATH, FileAccess.WRITE)
	if f == null:
		# 내보낸 판에서는 res:// 에 못 씁니다. 그때는 화면에 찍어 줍니다.
		print("[!] 저장 실패. 값을 직접 옮겨 적으세요: ", JSON.stringify(data))
		return
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	print("[저장] ", ProjectSettings.globalize_path(TUNING_PATH))
	print("       python tools/make_kids.py --force --arms 38   <- 이걸로 구우면 반영됩니다")
