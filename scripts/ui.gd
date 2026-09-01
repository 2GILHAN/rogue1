class_name Ui
extends CanvasLayer

## 화면 위의 모든 것. 코드로만 짓습니다 - 씬 파일에 위젯을 늘어놓으면
## 값이 두 곳(씬과 스크립트)에 흩어져 고칠 때마다 둘을 맞춰야 합니다.

signal boon_chosen(id: String)
signal shop_bought(index: int)
signal shop_closed
signal restart_requested
signal start_requested
signal toon_toggled
signal grade_toggled
signal lock_toggled
## 게임을 그만둡니다. 무엇을 할지는 game.gd 가 정합니다
## (데스크톱은 앱 종료, 웹은 제목 화면).
signal quit_pressed
## 제목 화면에서 리그 실험실을 엽니다.
signal riglab_requested
## 제목 화면의 **개발자 옵션**을 열고 닫습니다. 화면은 UI 가 그리지만 지금
## 어느 화면인지는 Game 이 들어야 합니다 - 키 조작(T·R·Esc)이 거기서 갈립니다.
signal devmenu_requested
signal title_requested
signal test_requested
signal test_kind_picked(kind: String)
signal test_boons_requested
signal test_skill_picked(family: String)
signal test_reset_requested
signal test_tiger_toggled
signal test_clear_requested
## 카메라 방식(내려다보기 / 어깨 너머)을 바꿉니다.
signal cam_mode_toggled
signal cam_pitch_nudged(steps: float)

const MINIMAP_PX := 160
## 화면 가장자리 여백. 아이폰 노치와 홈 인디케이터를 피하는 값입니다
## (1280 기준 40px = 실기기에서 대략 80~90px).
const SAFE_INSET := 40
## 화면 위 기술 표시의 한 변. 버튼(116)보다 훨씬 작습니다 - 누르는 것이
## 아니라 곁눈으로 보는 것이라 크면 시야를 가립니다.
const SKILL_ICON := 42

var _root: Control
var _hud: Control
var touch: TouchControls
var _rotate: Control
var _toon_button: Button
var _grade_button: Button
var _cam_mode_button: Button
var _quit_button: Button
## 그만두기를 처음 누른 시각(ms). 0 이면 안 눌린 상태입니다.
var _quit_armed := 0
## 두 번째 누름을 기다리는 시간.
const QUIT_CONFIRM_MS := 2500
var _cam_label: Label
var _options_button: Button
var _options_panel: PanelContainer
var _hp_bar: ProgressBar
var _hp_text: Label
var _gold: Label
var _floor: Label
var _enemies: Label
var _boons_line: Label
var _stats_line: Label
var _prompt: Label
var _toast: Label
var _dash_bar: ProgressBar
var _breath_text: Label
## 녹화 중임을 알리는 작은 판. 녹화하지 않을 때는 아예 감춥니다.
var _rec_box: PanelContainer
var _rec_label: Label

var _minimap: TextureRect
var _dot_player: ColorRect
var _dot_exit: ColorRect
## 시작 자리 하나와, 적 표시들. 적은 **미리 만들어 두고 돌려 씁니다** -
## 매 프레임 만들었다 지우면 층이 깊어질수록(적 35마리) 그 값이 그대로 듭니다.
## 용기(필살기) 게이지. 색은 필살 이펙트와 같은 파랑으로 가되, **찼을 때만**
## 노랑으로 바뀝니다 - 색이 바뀌는 것이 "지금 쓸 수 있다" 는 신호입니다.
const ULT_COLOR := Color(0.45, 0.72, 0.95)
const ULT_FULL_COLOR := Color(1.0, 0.82, 0.35)
var _ult_row: HBoxContainer
var _ult_bar: ProgressBar
var _ult_fill: StyleBoxFlat
var _ult_text: Label
var _dot_start: ColorRect
var _dots_foe: Array[ColorRect] = []
var _start_pos := Vector3.ZERO
var _minimap_dungeon: Dungeon
var _exit_pos := Vector3.ZERO

var _overlay: Control
var _overlay_box: VBoxContainer
var _shop_buttons: Array[Button] = []
var _shop_items: Array = []
var _shop_gold_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.theme()
	add_child(_root)
	_build_version()

	_build_hud()
	_build_perf()
	_build_skill_strip()
	_build_overlay()

	# 폰/웹이면 화면 조작을 얹습니다. 오버레이보다 아래에 둬야 상점이나 축복
	# 화면을 누를 때 조이스틱이 먼저 먹지 않습니다.
	if TouchControls.wanted():
		touch = TouchControls.new()
		_hud.add_child(touch)
		_build_rotate_notice()


# ---------------------------------------------------------------- HUD

## 화면 위에 겹쳐 뜨는 기술 표시. 종류 -> 아이콘.
var _skill_icons: Dictionary = {}


func _build_skill_strip() -> void:
	## 준비된 기술을 **화면 위쪽에 조그맣게** 겹쳐 보여 줍니다.
	##
	## 폰에는 버튼이 있어서 거기서 쿨다운이 보이지만, 키보드로 할 때는 볼 곳이
	## 없었습니다. 그리고 버튼은 화면 오른쪽 아래에 있어서 **눈이 가 있는 곳과
	## 멉니다** - 싸우는 동안 시선은 화면 가운데 위쪽(적이 오는 쪽)에 있습니다.
	##
	## 배경 판을 두지 않습니다. 항상 떠 있는 표시라, 판까지 있으면 화면을
	## 가리는 띠가 하나 생깁니다. 아이콘만 옅게 겹칩니다.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.offset_left = -110
	row.offset_right = 110
	row.offset_top = 62
	row.offset_bottom = 62 + SKILL_ICON
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(row)

	# **버튼과 같은 그림**을 씁니다. 두 곳에서 다르게 그리면 폰과 키보드가
	# 서로 다른 게임이 됩니다 - 순서(고함 - 밀기 - 구르기)도 같습니다.
	for kind in ["shout", "grab", "roll"]:
		var art := TextureRect.new()
		art.texture = load(TouchControls.BUTTON_ART[kind])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(SKILL_ICON, SKILL_ICON)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(art)
		# 쿨다운 덮개만 그 위에 얹습니다.
		var icon := DotIcon.new()
		icon.pattern = []
		icon.wedge_radius = SKILL_ICON * 0.47
		icon.setup([], Color(1, 1, 1))
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.add_child(icon)
		_skill_icons[kind] = {"icon": icon, "art": art}


func set_skill_state(kind: String, charge: float, winded: bool) -> void:
	## 기술 하나의 상태를 위쪽 표시와 터치 버튼에 함께 알립니다. 한 곳에서
	## 갈라야 둘이 어긋나지 않습니다.
	var entry: Variant = _skill_icons.get(kind)
	if entry is Dictionary:
		var icon: DotIcon = entry["icon"]
		icon.charge = charge
		icon.winded = winded
		var art: TextureRect = entry["art"]
		art.modulate = Color(0.55, 0.55, 0.62, 0.7) if winded else Color(1, 1, 1, 0.92)
	if touch != null:
		touch.set_ready(kind, charge, winded)


func _build_version() -> void:
	## 판 번호. **`_hud` 가 아니라 `_root`** 에 답니다 - 제목 화면에서도 보여야
	## 합니다. 시작하기 전에 "새로고침이 먹었나" 를 확인하는 것이 이 표시의
	## 쓸모라, 판이 시작된 뒤에만 보이면 늦습니다.
	##
	## 오른쪽 아래 구석입니다. 왼쪽 위는 층·사탕·체력, 아래 가운데는 조작
	## 안내, 위 가운데는 녹화 표시가 이미 차 있습니다.
	var label := UiTheme.label(Game.VERSION, 13, UiTheme.DIM)
	# 테두리를 두릅니다. 흐린 글자가 밝은 바닥이나 흰 소품 위에 오면 통째로
	# 사라집니다 - 배경이 무엇이든 읽혀야 하는 표시입니다.
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.offset_left = -120
	label.offset_right = -10
	label.offset_top = -26
	label.offset_bottom = -6
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)


func _build_hud() -> void:
	# 제목 화면에서는 통째로 감춥니다. 아직 시작하지 않은 판의 수치를 보여 주면
	# 그것이 진짜 상태인 줄 알게 됩니다.
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	_root.add_child(_hud)

	# 화면 가장자리에서 조금 띄웁니다. 아이폰을 가로로 들면 한쪽 끝에 노치가
	# 있어서, 딱 붙이면 체력바나 미니맵이 그 밑으로 들어갑니다.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG))
	panel.position = Vector2(SAFE_INSET, 20)
	panel.custom_minimum_size = Vector2(310, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_floor = UiTheme.label("지하 1층", 22, UiTheme.ACCENT)
	top.add_child(_floor)
	_gold = UiTheme.label("◆ 0", 20, Fx.GOLD_COLOR)
	top.add_child(_gold)

	_enemies = UiTheme.label("남은 적 0", 16, UiTheme.DIM)
	col.add_child(_enemies)
	_stats_line = UiTheme.label("", 14, UiTheme.DIM)
	col.add_child(_stats_line)
	_boons_line = UiTheme.label("", 14, UiTheme.GOOD)
	_boons_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boons_line.custom_minimum_size = Vector2(280, 0)
	col.add_child(_boons_line)

	_build_vitals()

	_build_minimap()
	_build_options()
	_build_rec_badge()

	_prompt = UiTheme.label("", 22, UiTheme.ACCENT)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -260
	_prompt.offset_right = 260
	_prompt.offset_top = -140
	_prompt.offset_bottom = -110
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_prompt)

	_toast = UiTheme.label("", 26, UiTheme.TEXT)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -360
	_toast.offset_right = 360
	_toast.offset_top = 90
	_toast.offset_bottom = 130
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_toast)

	# 폰에서는 키 안내가 거짓말입니다. 조작 방법이 화면에 이미 그려져 있으니
	# 대신 자동 조준을 알려 줍니다 - 안 알려 주면 "왜 조준이 안 되지" 가 됩니다.
	var hint := UiTheme.label(
		"왼쪽을 끌어 이동   고함은 **누르는 만큼** 넓어집니다   물놀이터·책장 앞에서는 밀기로 말을 겁니다" if TouchControls.wanted()
		else "이동 WASD   고함 좌클릭   밀기(잡기) F   구르기 Space   도움말 F1",
		14, UiTheme.DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_left = -420
	hint.offset_right = 420
	hint.offset_top = -36
	hint.offset_bottom = -12
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hint)


func _build_rec_badge() -> void:
	## 녹화 중에만 뜨는 표시입니다. **화면 위 한가운데**에 답니다 - 아래쪽
	## 절반은 조이스틱과 버튼 자리라, 거기 두면 정지 버튼을 누르려다 고함이
	## 나갑니다. 위쪽 좌우는 이미 체력·미니맵이 차 있습니다.
	_rec_box = PanelContainer.new()
	_rec_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rec_box.offset_left = -190
	_rec_box.offset_right = 190
	_rec_box.offset_top = 14
	_rec_box.offset_bottom = 58
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.14, 0.05, 0.05, 0.90)
	back.border_color = Color(0.72, 0.24, 0.22)
	back.set_border_width_all(2)
	back.set_corner_radius_all(10)
	back.set_content_margin_all(8)
	_rec_box.add_theme_stylebox_override("panel", back)
	_rec_box.visible = false
	_hud.add_child(_rec_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_rec_box.add_child(row)
	_rec_label = UiTheme.label("● 녹화 0:00", 16, Color(0.95, 0.62, 0.58))
	_rec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_rec_label)
	# 정지는 녹화를 **끝내는** 것이 아니라 **저장하는** 것입니다. 그렇게 읽히게
	# 이름을 붙입니다 - "정지" 만 있으면 지금까지 찍은 것이 버려지는 줄 압니다.
	row.add_child(_small_button("여기까지 저장", func() -> void: stop_recording()))


func stop_recording() -> void:
	if not Recorder.recording():
		return
	Recorder.stop()
	toast("녹화를 마쳤습니다 - 화면 위의 공유 버튼을 누르세요", UiTheme.ACCENT)


## 화면 아래 가운데 목숨 표시의 크기.
const VITALS_WIDTH := 400
const VITALS_BAR := 250


func _outlined(label: Label) -> Label:
	## 배경 없이 화면 위에 뜨는 글자에 테두리를 둘러 줍니다. 흐린 글자가 밝은
	## 바닥이나 흰 소품 위에 오면 통째로 사라집니다.
	# 테두리는 **불투명한 검정**입니다. 반투명으로 두면 글자색과 섞여 흐릿한
	# 덩어리가 되어, 테두리를 두르기 전보다 오히려 안 읽힙니다.
	# 테두리 두께는 글자 크기에 맞춥니다. 14px 글자에 6 을 두르면 획 사이가
	# 메워져 글자가 검은 덩어리가 됩니다.
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	return label


func _build_vitals() -> void:
	## 체력과 호흡을 **화면 아래 가운데**에 둡니다.
	##
	## 예전에는 왼쪽 위 판에 층·사탕·적 수와 함께 있었습니다. 거기서는 두
	## 가지가 나빴습니다.
	##
	## **눈이 가 있는 곳과 멉니다.** 싸우는 동안 시선은 화면 가운데, 주인공과
	## 그 앞의 적에 있습니다. 체력이 얼마 안 남은 것을 왼쪽 위를 봐야 알면
	## 그 순간 적을 못 봅니다.
	##
	## **위험한 것과 참고할 것이 섞여 있었습니다.** 층·사탕·남은 적은 언제
	## 봐도 되는 값이고 체력·호흡은 지금 봐야 하는 값인데, 한 판에 있으면
	## 급할 때 그 안에서 다시 찾아야 합니다.
	##
	## 아래 가운데인 이유: 폰에서 왼쪽 아래는 조이스틱, 오른쪽 아래는 버튼
	## 자리입니다. 그 사이가 비어 있고, 엄지에 가리지 않습니다.
	# **배경 없이** 막대만 띄웁니다.
	#
	# 화면 한가운데 아래에 어두운 상자가 있으면 그것이 바닥의 일부처럼 보여
	# 화면이 좁아 보입니다. 대신 글자에 테두리를 둘러 어떤 바닥 위에서도
	# 읽히게 합니다(판 번호와 같은 방법) - 막대 자체는 어두운 배경색을 이미
	# 가지고 있어 그대로 보입니다.
	var panel := MarginContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -VITALS_WIDTH * 0.5
	panel.offset_right = VITALS_WIDTH * 0.5
	# 조작 안내(-36)보다 위, 알림 문구(-140)보다 아래입니다.
	panel.offset_top = -108
	panel.offset_bottom = -46
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	col.add_child(hp_row)
	# 두 이름의 너비를 맞춰야 아래위 막대의 시작점이 같아집니다.
	var hp_name := _outlined(UiTheme.label("투지", 16, UiTheme.TEXT))
	hp_name.custom_minimum_size = Vector2(38, 0)
	hp_row.add_child(hp_name)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(VITALS_BAR, 20)
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.16, 0.10, 0.10)
	hp_bg.set_corner_radius_all(6)
	var hp_fg := StyleBoxFlat.new()
	hp_fg.bg_color = Color(0.85, 0.26, 0.24)
	hp_fg.set_corner_radius_all(6)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_bar.add_theme_stylebox_override("fill", hp_fg)
	hp_row.add_child(_hp_bar)
	_hp_text = _outlined(UiTheme.label("100 / 100", 17))
	hp_row.add_child(_hp_text)

	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 8)
	col.add_child(dash_row)
	var br_name := _outlined(UiTheme.label("호흡", 16, UiTheme.TEXT))
	br_name.custom_minimum_size = Vector2(38, 0)
	dash_row.add_child(br_name)
	_dash_bar = ProgressBar.new()
	# 체력바와 **같은 두께**입니다. 얇게 두면 "곁다리 값" 으로 읽히는데,
	# 실제로는 기술을 쓸 수 있느냐를 정하는 값이라 체력만큼 중요합니다.
	_dash_bar.custom_minimum_size = Vector2(VITALS_BAR, 20)
	_dash_bar.show_percentage = false
	_dash_bar.max_value = 1.0
	_dash_bar.value = 1.0
	var d_bg := StyleBoxFlat.new()
	d_bg.bg_color = Color(0.14, 0.14, 0.18)
	d_bg.set_corner_radius_all(6)
	var d_fg := StyleBoxFlat.new()
	d_fg.bg_color = Color(0.45, 0.72, 0.95)
	d_fg.set_corner_radius_all(6)
	_dash_bar.add_theme_stylebox_override("background", d_bg)
	_dash_bar.add_theme_stylebox_override("fill", d_fg)
	dash_row.add_child(_dash_bar)
	_breath_text = _outlined(UiTheme.label("500 / 500", 17))
	dash_row.add_child(_breath_text)

	# **용기 — 필살기 게이지.** 호흡 바로 아래입니다.
	#
	# 셋을 위에서부터 투지 → 호흡 → 용기로 둡니다. 급할 때 보는 순서가
	# 그대로입니다 - 살아 있나, 기술을 쓸 수 있나, 뒤집을 수 있나.
	#
	# **아직 못 쓰는 동안에는 줄째로 감춥니다.** 늘 비어 있는 게이지가 떠
	# 있으면 무엇을 보라는 표시인지 알 수 없습니다(계통 하나가 Lv5 가 되면
	# 그때 나타납니다).
	_ult_row = HBoxContainer.new()
	_ult_row.add_theme_constant_override("separation", 8)
	_ult_row.visible = false
	col.add_child(_ult_row)
	var ult_name := _outlined(UiTheme.label("용기", 16, UiTheme.TEXT))
	ult_name.custom_minimum_size = Vector2(38, 0)
	_ult_row.add_child(ult_name)
	_ult_bar = ProgressBar.new()
	# 두 바보다 얇습니다. 늘 보는 값이 아니라 **찼는지만** 보면 되는 값입니다.
	_ult_bar.custom_minimum_size = Vector2(VITALS_BAR, 12)
	_ult_bar.show_percentage = false
	_ult_bar.max_value = 1.0
	_ult_bar.value = 0.0
	var u_bg := StyleBoxFlat.new()
	u_bg.bg_color = Color(0.18, 0.15, 0.10)
	u_bg.set_corner_radius_all(5)
	_ult_fill = StyleBoxFlat.new()
	_ult_fill.bg_color = ULT_COLOR
	_ult_fill.set_corner_radius_all(5)
	_ult_bar.add_theme_stylebox_override("background", u_bg)
	_ult_bar.add_theme_stylebox_override("fill", _ult_fill)
	_ult_row.add_child(_ult_bar)
	_ult_text = _outlined(UiTheme.label("", 15))
	_ult_row.add_child(_ult_text)


func _build_minimap() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.offset_left = -(MINIMAP_PX + SAFE_INSET + 8)
	holder.offset_top = 20
	holder.offset_right = -SAFE_INSET
	holder.offset_bottom = 20 + MINIMAP_PX + 8
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(holder)

	var back := PanelContainer.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG, 8))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)

	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(MINIMAP_PX, MINIMAP_PX)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_minimap)

	_dot_exit = ColorRect.new()
	_dot_exit.color = Color(0.45, 0.75, 1.0)
	_dot_exit.size = Vector2(6, 6)
	_dot_exit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(_dot_exit)

	# **시작 자리.** 나온 곳이 어디였는지가 보여야 지금 어느 쪽으로 가고
	# 있는지 압니다. 출구(파랑)와 헷갈리지 않게 초록입니다.
	_dot_start = ColorRect.new()
	_dot_start.color = Color(0.45, 0.90, 0.55)
	_dot_start.size = Vector2(5, 5)
	_dot_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(_dot_start)

	# **적.** 미리 스무 개를 만들어 두고 필요한 만큼만 보입니다.
	for _i in FOE_DOTS:
		var d := ColorRect.new()
		d.color = Color(0.95, 0.35, 0.35)
		d.size = Vector2(4, 4)
		d.visible = false
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap.add_child(d)
		_dots_foe.append(d)

	# 주인공은 **맨 나중에** 답니다. 겹쳤을 때 위에 와야 내가 어디 있는지
	# 잃지 않습니다.
	_dot_player = ColorRect.new()
	_dot_player.color = Color(1.0, 0.75, 0.35)
	_dot_player.size = Vector2(6, 6)
	_dot_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.add_child(_dot_player)


var _test_panel: PanelContainer
var _test_label: Label
var _test_skill_label: Label
var _tiger_button: Button


func set_test_panel(on: bool) -> void:
	if _test_panel == null:
		if not on:
			return
		_build_test_panel()
	_test_panel.visible = on


func set_test_skills(summary: Array) -> void:
	if _test_skill_label != null:
		_test_skill_label.text = ("  ".join(summary)) if not summary.is_empty() else "아직 없음"


func set_tiger_face(front: bool) -> void:
	if _tiger_button != null:
		_tiger_button.text = "호랑이: 정면" if front else "호랑이: 옆얼굴"


func set_test_kind(kind: String) -> void:
	if _test_label != null:
		_test_label.text = "지금: %s" % (kind if kind != "" else "없음")


func _build_test_panel() -> void:
	## 실험용 조작판. **세로 한 줄**로 쌓습니다.
	##
	## 왼쪽 가운데에 답니다 - 위는 층 정보, 아래 가운데는 목숨 표시, 오른쪽은
	## 미니맵과 버튼이라 왼쪽 허리가 비어 있습니다.
	_test_panel = PanelContainer.new()
	_test_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG))
	_test_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_test_panel.offset_left = 12
	_test_panel.offset_right = 212
	# 왼쪽 위 판(층·사탕·능력치)의 아래를 살짝 피해 내려 답니다.
	_test_panel.offset_top = -228
	_test_panel.offset_bottom = 272
	_hud.add_child(_test_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_test_panel.add_child(col)
	col.add_child(UiTheme.label("테스트", 17, UiTheme.ACCENT))
	_test_label = UiTheme.label("지금: 없음", 13, UiTheme.DIM)
	col.add_child(_test_label)

	# 적 종류. 고른 것이 시간마다 다시 나옵니다.
	# **이름은 `Enemy.LABEL` 한 곳에서 옵니다.** 여기 따로 적어 두면 이름을
	# 고칠 때 한쪽만 바뀝니다.
	for kind in ["grunt", "screamer", "spitter", "brute", "clinger", "pillow",
			"teacher"]:
		var b := _small_button(Enemy.label_of(kind),
			func() -> void: test_kind_picked.emit(kind))
		b.custom_minimum_size = Vector2(0, 26)
		col.add_child(b)

	var stop := _small_button("적 안 나오게", func() -> void: test_kind_picked.emit(""))
	stop.custom_minimum_size = Vector2(0, 26)
	col.add_child(stop)
	var clear := _small_button("지금 적 지우기", func() -> void: test_clear_requested.emit())
	clear.custom_minimum_size = Vector2(0, 26)
	col.add_child(clear)

	# ── 스킬 ────────────────────────────────────────────────────────
	#
	# 세 장 중에 고르는 화면을 거치지 않습니다. **누르면 그 계통이 곧바로
	# 한 단계 오릅니다.** 보려는 것은 이펙트가 갈리는 Lv3·Lv5 인데, 거기까지
	# 가려면 고르기 화면을 다섯 번 넘겨야 하고 그때마다 원하는 계통이 안
	# 나올 수도 있습니다 - 실험이 아니라 운을 기다리는 일이 됩니다.
	col.add_child(UiTheme.label("스킬 +1", 14, UiTheme.ACCENT))
	_test_skill_label = UiTheme.label("아직 없음", 12, UiTheme.DIM)
	_test_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_test_skill_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for fam in ["push", "shout", "roll", "hp", "move", "breath"]:
		var name: String = RunState.FAMILY_NAME.get(fam, fam)
		var fb := _small_button(name, func() -> void: test_skill_picked.emit(fam))
		fb.custom_minimum_size = Vector2(88, 28)
		grid.add_child(fb)
	var rs := _small_button("처음부터", func() -> void: test_reset_requested.emit())
	rs.custom_minimum_size = Vector2(88, 28)
	grid.add_child(rs)

	# 고함 Lv5 의 호랑이를 옆얼굴/정면 중에 골라 봅니다. 둘 다 남겨 두고
	# 화면에서 견주는 자리이므로, 여기 있는 편이 인자보다 빠릅니다.
	_tiger_button = _small_button("호랑이: 옆얼굴",
		func() -> void: test_tiger_toggled.emit())
	_tiger_button.custom_minimum_size = Vector2(0, 28)
	col.add_child(_tiger_button)

	# 세 장 중에 고르는 화면도 남깁니다. 그 화면 자체를 볼 일이 있습니다.
	var boon := _small_button("고르기 화면", func() -> void: test_boons_requested.emit())
	boon.custom_minimum_size = Vector2(0, 28)
	col.add_child(boon)


var _perf_button: Button
var _lock_button: Button
var _perf_label: Label
var _perf_wait := 0.0
## 프레임 시간의 **가장 나쁜 값**도 같이 보여 줍니다. 평균만 보면 0.5초마다
## 한 번씩 멎는 것이 안 보입니다 - 사람이 렉이라고 부르는 것은 대개 그쪽입니다.
var _perf_worst := 0.0


func set_lock_on(on: bool) -> void:
	if _lock_button != null:
		_lock_button.text = "켬" if on else "끔"


func _toggle_perf() -> void:
	if _perf_label == null:
		return
	_perf_label.visible = not _perf_label.visible
	_perf_button.text = "켬" if _perf_label.visible else "끔"


func _build_perf() -> void:
	## 왼쪽 위 층 정보 **아래**에 붙입니다. 화면 가운데를 가리지 않으면서
	## 엄지에 안 눌리는 자리입니다.
	_perf_label = UiTheme.label("", 13, Color(0.75, 0.95, 0.75))
	_perf_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_perf_label.add_theme_constant_override("outline_size", 3)
	_perf_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# 층 정보 판이 끝나는 자리 바로 아래입니다(판 아래 끝 ~152).
	_perf_label.position = Vector2(SAFE_INSET + 6, SAFE_INSET + 122)
	_perf_label.add_theme_constant_override("line_spacing", -2)
	_perf_label.visible = false
	_hud.add_child(_perf_label)


func _drive_perf(delta: float) -> void:
	if _perf_label == null or not _perf_label.visible:
		return
	_perf_worst = maxf(_perf_worst, delta)
	_perf_wait -= delta
	if _perf_wait > 0.0:
		return
	_perf_wait = 0.5
	var tree := get_tree()
	# **텍스처 메모리를 같이 보여 줍니다.** 데스크톱에서 재니 262MB 였습니다 -
	# 폰에서는 이 값이 곧 병목일 수 있어서, 다른 무엇보다 먼저 읽을 숫자입니다.
	_perf_label.text = "%.0f fps  최악 %.0fms
노드 %d  고아 %d  적 %d
메모리 %.0fMB  텍스처 %.0fMB  그리기 %d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		_perf_worst * 1000.0,
		tree.get_node_count(),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		tree.get_nodes_in_group("enemies").size(),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	_perf_worst = 0.0


func _build_options() -> void:
	## 옵션. 화면에는 **버튼 하나만** 두고, 누르면 작은 판이 열립니다.
	##
	## 항목을 화면에 늘어놓으면 옵션이 늘 때마다 HUD 를 잠식합니다. 폰에서는
	## 그 자리가 곧 화면이라 더 그렇습니다. 미니맵 바로 아래에 두는 것은
	## 오른쪽 위가 이미 정보를 보는 자리이고, 조작 버튼(오른쪽 아래)과 멀어
	## 잘못 누를 일이 없어서입니다.
	_options_button = _small_button("옵션", func() -> void: toggle_options())
	_options_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_options_button.offset_left = -(SAFE_INSET + 74)
	_options_button.offset_top = 20 + MINIMAP_PX + 20
	_options_button.offset_right = -SAFE_INSET
	_options_button.offset_bottom = 20 + MINIMAP_PX + 58
	_hud.add_child(_options_button)

	_options_panel = PanelContainer.new()
	_options_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_options_panel.offset_left = -(SAFE_INSET + 208)
	_options_panel.offset_top = 20 + MINIMAP_PX + 64
	_options_panel.offset_right = -SAFE_INSET
	_options_panel.offset_bottom = 20 + MINIMAP_PX + 274
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.06, 0.06, 0.94)
	back.border_color = Color(0.34, 0.30, 0.26)
	back.set_border_width_all(2)
	back.set_corner_radius_all(10)
	back.set_content_margin_all(10)
	_options_panel.add_theme_stylebox_override("panel", back)
	_options_panel.visible = false
	_hud.add_child(_options_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_options_panel.add_child(col)

	var toon_row := HBoxContainer.new()
	toon_row.add_theme_constant_override("separation", 6)
	col.add_child(toon_row)
	var toon_name := UiTheme.label("카툰", 15, UiTheme.DIM)
	toon_name.custom_minimum_size = Vector2(64, 34)
	toon_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toon_row.add_child(toon_name)
	_toon_button = _small_button("켬 (T)", func() -> void: toon_toggled.emit())
	_toon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toon_row.add_child(_toon_button)

	var grade_row := HBoxContainer.new()
	grade_row.add_theme_constant_override("separation", 6)
	col.add_child(grade_row)
	var grade_name := UiTheme.label("색감", 15, UiTheme.DIM)
	grade_name.custom_minimum_size = Vector2(64, 34)
	grade_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_row.add_child(grade_name)
	_grade_button = _small_button("끔", func() -> void: grade_toggled.emit())
	_grade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade_row.add_child(_grade_button)

	# **록온(자동 조준).** 기본은 **켬**입니다.
	#
	# 밀기 사거리(3.8m) 안의 가장 가까운 적으로 몸이 돌아갑니다. 그 밖에서는
	# 안 걸리므로, 멀리서 겨누는 일은 그대로 손에 남습니다.
	var lock_row := HBoxContainer.new()
	lock_row.add_theme_constant_override("separation", 6)
	col.add_child(lock_row)
	var lock_name := UiTheme.label("록온", 15, UiTheme.DIM)
	lock_name.custom_minimum_size = Vector2(64, 34)
	lock_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_row.add_child(lock_name)
	_lock_button = _small_button("켬", func() -> void: lock_toggled.emit())
	_lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_row.add_child(_lock_button)

	# **성능 표시.** 폰에서만 나타나는 느려짐을 재려고 답니다 - 데스크톱에서
	# 11분을 돌려도 아무것도 쌓이지 않아서, 폰에서 직접 읽는 수밖에 없습니다.
	var perf_row := HBoxContainer.new()
	perf_row.add_theme_constant_override("separation", 6)
	col.add_child(perf_row)
	var perf_name := UiTheme.label("성능", 15, UiTheme.DIM)
	perf_name.custom_minimum_size = Vector2(64, 34)
	perf_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	perf_row.add_child(perf_name)
	_perf_button = _small_button("끔", func() -> void: _toggle_perf())
	_perf_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perf_row.add_child(_perf_button)

	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 6)
	col.add_child(cam_row)
	var cam_name := UiTheme.label("시야", 15, UiTheme.DIM)
	cam_name.custom_minimum_size = Vector2(64, 34)
	cam_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cam_row.add_child(cam_name)
	# 버튼 둘로 나눈 것은 폰 때문입니다 - 하나로 순환시키면 원하는 각도를
	# 지나쳤을 때 한 바퀴를 다시 돌아야 합니다.
	cam_row.add_child(_small_button("–", func() -> void: cam_pitch_nudged.emit(-1.0)))
	_cam_label = UiTheme.label("63°", 15, UiTheme.TEXT)
	_cam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cam_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cam_label.custom_minimum_size = Vector2(42, 34)
	cam_row.add_child(_cam_label)
	cam_row.add_child(_small_button("+", func() -> void: cam_pitch_nudged.emit(+1.0)))

	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 6)
	col.add_child(view_row)
	var view_name := UiTheme.label("시점", 15, UiTheme.DIM)
	view_name.custom_minimum_size = Vector2(64, 34)
	view_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_row.add_child(view_name)
	# 이름을 "위에서 / 어깨 너머" 로 둡니다. 켜짐/꺼짐이면 무엇이 켜진
	# 상태인지 눌러 보기 전에는 알 수 없습니다.
	_cam_mode_button = _small_button("위에서", func() -> void: cam_mode_toggled.emit())
	_cam_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_row.add_child(_cam_mode_button)

	var quit_row := HBoxContainer.new()
	quit_row.add_theme_constant_override("separation", 6)
	col.add_child(quit_row)
	var quit_name := UiTheme.label("게임", 15, UiTheme.DIM)
	quit_name.custom_minimum_size = Vector2(64, 34)
	quit_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quit_row.add_child(quit_name)
	# 브라우저 탭은 스크립트가 닫을 수 없습니다. 폰에서는 "그만두기"(제목
	# 화면으로)가 실제로 일어나는 일이라 이름도 그렇게 답니다 - 눌러 보고
	# 아무 일도 안 일어나는 것이 가장 나쁩니다.
	_quit_button = _small_button(_quit_label(), func() -> void: _on_quit_press())
	_quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_row.add_child(_quit_button)

	set_toon(true)


func _small_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(34, 34)
	b.add_theme_font_override("font", UiTheme.font())
	b.add_theme_font_size_override("font_size", 15)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.10, 0.09, 0.92)
	box.border_color = Color(0.32, 0.28, 0.25)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	for slot in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(slot, box)
	b.add_theme_color_override("font_color", UiTheme.DIM)
	b.pressed.connect(on_press)
	return b


func _quit_label() -> String:
	## 웹에서는 탭을 못 닫으니 실제로 하는 일(제목 화면으로)을 이름에 씁니다.
	return "그만두기" if OS.has_feature("web") else "종료"


func _on_quit_press() -> void:
	## **두 번 눌러야 나갑니다.** 판 하나에 다른 옵션과 나란히 있는 버튼이라,
	## 한 번에 나가면 시야를 조절하려다 판을 통째로 날립니다.
	##
	## 따로 확인 창을 띄우지 않은 것은 폰 때문입니다 - 작은 화면에 창이
	## 하나 더 뜨면 그 창을 닫는 법을 또 찾아야 합니다. 버튼 이름이 바뀌는
	## 것으로 "한 번 더 누르면 진짜" 를 알립니다.
	var now := Time.get_ticks_msec()
	if _quit_armed > 0 and now - _quit_armed < QUIT_CONFIRM_MS:
		_reset_quit()
		quit_pressed.emit()
		return
	_quit_armed = now
	if _quit_button != null:
		_quit_button.text = "정말?"


func _reset_quit() -> void:
	_quit_armed = 0
	if _quit_button != null:
		_quit_button.text = _quit_label()


func set_cam_mode(shoulder: bool) -> void:
	if _cam_mode_button != null:
		_cam_mode_button.text = "어깨 너머" if shoulder else "위에서"
	# 어깨 너머에서는 시야 각도 조절이 뜻이 없습니다(카메라가 뒤에 붙습니다).
	if _cam_label != null:
		_cam_label.modulate = Color(1, 1, 1, 0.35 if shoulder else 1.0)


func toggle_options() -> void:
	if _options_panel == null:
		return
	_options_panel.visible = not _options_panel.visible
	# 판을 여닫으면 확인이 풀립니다. "정말?" 인 채로 남아 있으면 다음에
	# 열었을 때 한 번만 눌러도 나가 버립니다.
	_reset_quit()
	# 열려 있는 동안에는 터치 버튼을 감춥니다.
	#
	# 판이 오른쪽 위에 열리는데 상호작용 버튼이 그 아래에 있어, 판이 버튼을
	# 덮으면 **화면은 눌리는데 아무 일도 일어나지 않습니다.** 자리를 옮겨
	# 피할 수도 있지만 옵션이 하나 늘 때마다 다시 어긋납니다. 메뉴가 열린
	# 동안은 조작하지 않는 때이므로 통째로 감추는 편이 어긋날 일이 없습니다.
	if touch != null:
		touch.visible = not _options_panel.visible


func set_cam_pitch(degrees: float) -> void:
	if _cam_label != null:
		_cam_label.text = "%d°" % roundi(degrees)


func set_toon(on: bool) -> void:
	if _toon_button == null:
		return
	_toon_button.text = ("켬" if on else "끔") + " (T)"
	_toon_button.add_theme_color_override("font_color",
		UiTheme.ACCENT if on else UiTheme.DIM)


## 읽는 동안 화면 가장자리를 덮는 판.
var _focus: ColorRect
var _focus_mat: ShaderMaterial


func set_read_focus(amount: float, center: Vector2 = Vector2(0.5, 0.5)) -> void:
	## 0 이면 평소, 1 이면 가장자리가 다 어둡습니다. game.gd 가 매 프레임
	## 조금씩 옮겨 줍니다 - 여기서 시간을 재지 않는 이유는, 읽기를 언제
	## 시작하고 끝내는지는 게임 쪽만 알기 때문입니다.
	if _focus == null:
		_build_focus()
	if _focus_mat == null:
		return
	_focus.visible = amount > 0.002
	_focus_mat.set_shader_parameter("amount", amount)
	_focus_mat.set_shader_parameter("center", center)
	var vp := get_viewport()
	if vp != null:
		var size: Vector2 = vp.get_visible_rect().size
		if size.y > 0.0:
			_focus_mat.set_shader_parameter("aspect", size.x / size.y)


var _grade: ColorRect
var _grade_mat: ShaderMaterial
var _grade_want := 0.0
var _grade_now := 0.0


func _drive_grade(delta: float) -> void:
	## 색감 필터의 세기를 옮겨 갑니다. 켜고 끄는 것이 아니라 **옮겨** 갑니다 -
	## 한 프레임에 바뀌면 화면이 깜빡인 것으로 보입니다(읽기 어둠과 같은 이유).
	if _grade == null or _grade_mat == null:
		return
	if not is_equal_approx(_grade_now, _grade_want):
		_grade_now = move_toward(_grade_now, _grade_want, delta * 3.0)
		_grade_mat.set_shader_parameter("amount", _grade_now)
	_grade.visible = _grade_now > 0.002


func set_grade_label(on: bool) -> void:
	if _grade_button != null:
		_grade_button.text = "지브리" if on else "끔"


func set_color_grade(on: bool) -> void:
	## 화면 색감 필터를 켜고 끕니다. 값은 매 프레임 조금씩 옮겨 갑니다
	## (`_process`) - 한 프레임에 바뀌면 화면이 깜빡인 것으로 보입니다.
	_grade_want = 1.0 if on else 0.0
	if _grade == null:
		_build_grade()


func _build_grade() -> void:
	var shader: Shader = load("res://assets/shaders/ghibli.gdshader")
	if shader == null:
		return
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = shader
	_grade_mat.set_shader_parameter("amount", 0.0)
	_grade = ColorRect.new()
	_grade.name = "ColorGrade"
	_grade.material = _grade_mat
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# **HUD 보다 뒤, 읽기 어둠보다도 뒤**입니다. 체력·버튼·판 번호까지
	# 물들이면 글자가 읽히지 않고, 무엇보다 색감은 **그려진 세계**의
	# 성질이지 화면에 얹은 글자의 성질이 아닙니다.
	add_child(_grade)
	move_child(_grade, 0)


func _build_focus() -> void:
	var shader: Shader = load("res://assets/shaders/read_focus.gdshader")
	if shader == null:
		return
	_focus_mat = ShaderMaterial.new()
	_focus_mat.shader = shader
	_focus = ColorRect.new()
	_focus.name = "ReadFocus"
	_focus.material = _focus_mat
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus.set_anchors_preset(Control.PRESET_FULL_RECT)
	_focus.visible = false
	# HUD 보다 **뒤에** 깝니다. 체력과 버튼까지 어두워지면 화면이 고장 난
	# 것으로 보입니다.
	add_child(_focus)
	move_child(_focus, 0)


func _build_rotate_notice() -> void:
	## 세로로 들면 화면이 좁고 길어져서, HUD 와 조작 버튼이 서로 겹치고 던전은
	## 거의 안 보입니다. 억지로 돌릴 방법이 브라우저에는 없으니(전체화면 없이는
	## Screen Orientation API 가 막혀 있습니다) 부탁하는 화면을 덮습니다.
	_rotate = Control.new()
	_rotate.anchor_right = 1.0
	_rotate.anchor_bottom = 1.0
	_rotate.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate.visible = false
	_root.add_child(_rotate)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.03, 0.03, 0.04, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var icon := UiTheme.label("■", 64, UiTheme.ACCENT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon)
	var text := UiTheme.label("가로로 돌려주세요", 30, UiTheme.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)


func set_hud_visible(on: bool) -> void:
	_hud.visible = on


## 미니맵에 한 번에 찍을 수 있는 적의 수. 깊은 층이 33마리쯤이라 넉넉합니다.
const FOE_DOTS := 40


func set_minimap(dungeon: Dungeon, exit_pos: Vector3,
		start_pos: Vector3 = Vector3.INF) -> void:
	## 층이 바뀔 때 한 번만 그립니다. 갈 수 있는 칸만 밝게 칠하면 방과 복도의
	## 모양이 그대로 드러납니다.
	_minimap_dungeon = dungeon
	_exit_pos = exit_pos
	# 시작 자리는 **층을 지을 때 한 번** 받습니다. 그 뒤로는 안 바뀝니다 -
	# 매 프레임 주인공 자리에서 뽑으면 그건 시작 자리가 아니라 현재 자리입니다.
	if start_pos.is_finite():
		_start_pos = start_pos
	var img := Image.create(dungeon.w, dungeon.h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.35))
	for y in dungeon.h:
		for x in dungeon.w:
			if not dungeon.is_solid(x, y):
				img.set_pixel(x, y, Color(0.62, 0.56, 0.50, 0.95))
	_minimap.texture = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_drive_grade(delta)
	_drive_perf(delta)
	if _rotate != null:
		# 뷰포트가 아니라 **창**을 봅니다. 늘이기 모드가 canvas_items/keep 이라
		# 뷰포트는 언제나 1280x720 이고, 세로로 들면 위아래에 검은 띠가 생길 뿐
		# 크기는 그대로입니다 - 뷰포트로는 세로인지 알 수 없습니다.
		var win := Vector2(DisplayServer.window_get_size())
		_rotate.visible = win.y > win.x * 1.05

	if _rec_box != null:
		_rec_box.visible = Recorder.recording()
		if _rec_box.visible:
			_rec_label.text = Recorder.label()

	if _minimap_dungeon == null or not _hud.visible:
		return
	var players := get_tree().get_nodes_in_group("player")
	var px := float(MINIMAP_PX) / float(_minimap_dungeon.w)
	if players.size() > 0:
		var c := _minimap_dungeon.world_to_cell((players[0] as Node3D).global_position)
		_dot_player.position = Vector2(c.x * px - 3.0, c.y * px - 3.0)
	var e := _minimap_dungeon.world_to_cell(_exit_pos)
	_dot_exit.position = Vector2(e.x * px - 3.0, e.y * px - 3.0)
	var st := _minimap_dungeon.world_to_cell(_start_pos)
	_dot_start.position = Vector2(st.x * px - 2.5, st.y * px - 2.5)
	# 적은 살아 있는 것만 찍습니다. 남는 표시는 숨겨 두고 다음에 씁니다.
	var foes := get_tree().get_nodes_in_group("enemies")
	for i in _dots_foe.size():
		var dot := _dots_foe[i]
		if i >= foes.size():
			dot.visible = false
			continue
		var foe := foes[i] as Node3D
		if not is_instance_valid(foe):
			dot.visible = false
			continue
		var fc := _minimap_dungeon.world_to_cell(foe.global_position)
		dot.position = Vector2(fc.x * px - 2.0, fc.y * px - 2.0)
		dot.visible = true


func set_ultimate(ratio: float, on: bool, note: String, shown: bool) -> void:
	## 게이지와 상태를 한 번에 받습니다. 부르는 쪽(game.gd)이 매 프레임 넘겨
	## 주므로, 여기서는 그림만 맞춥니다.
	if _ult_row == null:
		return
	_ult_row.visible = shown
	if not shown:
		return
	_ult_bar.value = ratio
	var full := ratio >= 0.999
	_ult_fill.bg_color = ULT_FULL_COLOR if (full or on) else ULT_COLOR
	if on:
		_ult_text.text = note if note != "" else "필살"
	elif full:
		# **쓰는 법을 여기에 적습니다.** 명령을 아무 데도 안 적어 두면
		# 찼다는 것만 알고 쓸 줄은 모르게 됩니다.
		_ult_text.text = "구르기→밀기→고함"
	else:
		_ult_text.text = "%d%%" % int(round(ratio * 100.0))


func update_hud(state: RunState, enemies_left: int, _unused: float) -> void:
	_floor.text = RunState.floor_name(state.floor_num)
	# 사탕 개수. 마름모(◆)는 금화의 기호라 그대로 두면 이름만 바뀐 것이
	# 됩니다.
	_gold.text = "사탕 %d" % state.gold
	_hp_bar.max_value = state.max_hp
	_hp_bar.value = state.hp
	_hp_text.text = "%d / %d" % [int(ceil(state.hp)), int(state.max_hp)]
	_enemies.text = ("남은 적 %d" % enemies_left) if enemies_left > 0 else "정리 완료 - 파란 문으로"
	# 숨. 기술을 쓸 밑천이라 체력 바로 아래에 둡니다.
	_dash_bar.max_value = state.max_breath
	_dash_bar.value = state.breath
	_breath_text.text = "%d / %d" % [int(ceil(state.breath)), int(state.max_breath)]
	# 고함(80) 을 지를 수 없는 동안에는 색을 죽입니다. 숫자를 읽지 않아도
	# "지금은 못 지른다" 가 보여야 합니다.
	# 고함을 지를 수 없는 동안에는 색을 죽입니다. 값을 여기 적어 두면 기술
	# 값을 바꿀 때 반드시 어긋나므로 Player 의 상수를 그대로 봅니다.
	var box := _dash_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if box != null:
		box.bg_color = (Color(0.45, 0.72, 0.95) if state.breath >= Player.BREATH_SHOUT
			else Color(0.36, 0.44, 0.55))
	_stats_line.text = "공격 %d   속도 %.1f   치명 %d%%  x%.1f" % [
		int(round(state.damage)), state.move_speed, int(round(state.crit_chance * 100)),
		state.crit_mult]


func set_boons(names: Array) -> void:
	## 계통 Lv 목록입니다("고함 Lv3, 구르기 Lv2"). 스킬 이름을 다 늘어놓으면
	## 한 줄을 넘기고, 무엇을 파고 있는지도 안 보입니다.
	_boons_line.text = ("스킬  " + "   ".join(names)) if names.size() > 0 else ""


func set_prompt(text: String) -> void:
	_prompt.text = text


func toast(text: String, color: Color = UiTheme.TEXT) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------- 오버레이

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, 16))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)

	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 14)
	panel.add_child(_overlay_box)


func _clear_overlay() -> void:
	for c in _overlay_box.get_children():
		_overlay_box.remove_child(c)
		c.queue_free()
	_shop_buttons.clear()
	_shop_items.clear()


func _title(text: String, color: Color = UiTheme.ACCENT) -> void:
	var l := UiTheme.label(text, 34, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(l)


func _sub(text: String, color: Color = UiTheme.DIM) -> void:
	var l := UiTheme.label(text, 17, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_box.add_child(l)


func _card(icon: String, name: String, desc: String, footer: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(216, 150)
	b.focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := UiTheme.label(icon, 34, UiTheme.ACCENT)
	i.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(i)
	var n := UiTheme.label(name, 20)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)
	var d := UiTheme.label(desc, 15, UiTheme.DIM)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)
	if footer != "":
		var f := UiTheme.label(footer, 17, Fx.GOLD_COLOR)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(f)
	b.add_child(box)
	return b


func show_title() -> void:
	_clear_overlay()
	_title("TOTO FIGHTCLUB")
	_sub("불꽃 깃털의 모험가가 지하로 내려갑니다. 층의 적을 모두 쓰러뜨리면 파란 문이 열립니다.\n"
		+ "죽으면 처음부터입니다 - 대신 매번 다른 던전, 다른 축복을 만납니다.")
	_sub("왼쪽 아래를 끌어 이동 · 밀기(잡기)는 앞이면 밀고 등 뒤면 잡습니다"
		if TouchControls.wanted()
		else "이동 WASD · 조준 마우스 · 고함 좌클릭 · 밀기(잡기) F · 구르기 Space(무적) · 일시정지 Esc",
		UiTheme.TEXT)
	_sub("캐릭터 세 종류는 test3 카탈로그가 원화 한 장씩에서 만든 것을 그대로 씁니다.")
	# **세로로 놓습니다.** 가로로 늘어놓으면 버튼이 늘어날 때마다 화면 밖으로
	# 밀리고, 폰 세로 폭에서는 글자가 줄어듭니다. 세로는 몇 개가 되든 같은
	# 크기로 쌓입니다.
	# **세로로 놓습니다.** 가로로 늘어놓으면 버튼이 늘어날 때마다 화면 밖으로
	# 밀리고, 폰 세로 폭에서는 글자가 줄어듭니다. 세로는 몇 개가 되든 같은
	# 크기로 쌓입니다.
	var row := VBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_overlay_box.add_child(row)
	row.add_child(_menu_button("  시작하기  (Enter)  ", func() -> void:
		Recorder.armed = false
		start_requested.emit()))
	# **만드는 사람만 쓰는 것은 한 겹 안으로 넣습니다.**
	#
	# 테스트 방과 리그 실험실을 첫 화면에 그대로 두면, 처음 열어 본 사람에게는
	# 무엇을 눌러야 하는지가 넷 중 하나가 됩니다. 안쪽으로 넣으면 첫 화면이
	# "시작한다 / 안 한다" 로 줄고, 만드는 사람은 한 번만 더 누르면 됩니다.
	row.add_child(_menu_button("  개발자 옵션  (D)  ", func() -> void:
		devmenu_requested.emit()))
	row.add_child(_menu_button("  종료하기  (Esc)  ", func() -> void:
		quit_pressed.emit()))

	if Recorder.available():
		_sub("녹화는 개발자 옵션 안에 있습니다. 판을 소리까지 함께 최대 %d분 담습니다."
			% (Recorder.MAX_SEC / 60))
	elif OS.has_feature("web"):
		_sub("이 브라우저는 녹화를 지원하지 않습니다. 크롬이나 사파리에서 열면 판을 영상으로 남길 수 있습니다.")
	_overlay.visible = true


func _menu_button(label: String, on_press: Callable) -> Button:
	## 제목 화면의 버튼. 크기와 눌렀을 때가 늘 같아야 해서 한 곳에서 만듭니다.
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(300, 52)
	b.pressed.connect(on_press)
	return b


func show_devmenu() -> void:
	## **개발자 옵션.** 확인용으로 만든 자리들만 모읍니다.
	_clear_overlay()
	_title("개발자 옵션")
	_sub("만들면서 확인하는 자리입니다. 게임을 하려면 뒤로 돌아가세요.")
	var row := VBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_overlay_box.add_child(row)
	row.add_child(_menu_button("  테스트 방  (T)  ", func() -> void:
		Recorder.armed = false
		test_requested.emit()))
	row.add_child(_menu_button("  리그 실험실  (R)  ", func() -> void:
		riglab_requested.emit()))
	if Recorder.available():
		# 녹화는 **스위치가 아니라 시작 버튼 하나 더**입니다. 켜고 끄는
		# 스위치로 두면 시작하기 전에 지금 켜져 있는지를 확인해야 하는데,
		# 버튼이 둘이면 누르는 순간 정해집니다.
		row.add_child(_menu_button("  ● 녹화하며 내려가기  ", func() -> void:
			Recorder.armed = true
			start_requested.emit()))
	row.add_child(_menu_button("  뒤로  (Esc)  ", func() -> void:
		title_requested.emit()))
	_overlay.visible = true


func show_boons(options: Array, title: String = "층을 정리했다",
		sub: String = "축복 하나를 고르세요. 1 2 3 키로도 고를 수 있습니다.") -> void:
	## 제목을 밖에서 받습니다. 층을 넘길 때와 책장을 읽을 때가 **같은 고르기**
	## 인데, 화면에 뜨는 말까지 같으면 방금 무엇을 했는지가 안 보입니다.
	_clear_overlay()
	_title(title)
	_sub(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_overlay_box.add_child(row)
	for i in options.size():
		var opt: Dictionary = options[i]
		# 이미 찍은 스킬이면 **다음 Lv 을 적어 줍니다.** 무엇을 쌓고 있는지가
		# 고르는 순간에 보여야 "계속 팔까 갈아탈까" 가 선택이 됩니다.
		var lv := int(opt.get("lv", 0))
		var tag := "[%d]" % (i + 1)
		if lv > 0:
			tag = "Lv%d → Lv%d   [%d]" % [lv, lv + 1, i + 1]
		# **계통이 곧 스킬입니다.** 예전에는 계통 안에 스킬이 여럿이라
		# 「밀기 · 억센 손」처럼 둘을 붙여 적었는데, 스킬을 여섯 계통으로
		# 줄이면서 두 이름이 같아졌습니다 - 「구르기 · 구르기」가 떴습니다.
		var fam := String(opt.get("family_name", ""))
		var label: String = String(opt["name"])
		if fam != "" and fam != label:
			label = "%s · %s" % [fam, label]
		var b := _card(String(opt["icon"]), label, String(opt["desc"]), tag)
		var id := String(opt["id"])
		b.pressed.connect(func() -> void: boon_chosen.emit(id))
		row.add_child(b)
		_shop_buttons.append(b)
	_overlay.visible = true


func show_shop(items: Array, gold: int) -> void:
	_clear_overlay()
	_shop_items = items
	# **「상점」 이 아니라 「물물교환」 입니다.**
	#
	# 파는 사람과 사는 사람이 아니라 **같은 처지의 아이 둘**이 가진 것을
	# 바꾸는 자리입니다. 이 게임의 적이 전부 또래인데 도와주는 쪽도 또래라야,
	# 어린이집 안의 일이라는 것이 흐려지지 않습니다.
	_title("물물교환")
	_sub("어린이집에도 아군은 있다.", UiTheme.ACCENT)
	_shop_gold_label = UiTheme.label("가진 사탕 %d 개" % gold, 20, Fx.GOLD_COLOR)
	_shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_box.add_child(_shop_gold_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_overlay_box.add_child(row)
	for i in items.size():
		var item: Dictionary = items[i]
		var b := _card(String(item["icon"]), String(item["name"]), String(item["desc"]),
			"사탕 %d   [%d]" % [int(item["price"]), i + 1])
		var idx := i
		b.pressed.connect(func() -> void: shop_bought.emit(idx))
		row.add_child(b)
		_shop_buttons.append(b)
	var close := Button.new()
	close.text = "  나가기  (E / Esc)  "
	close.custom_minimum_size = Vector2(220, 44)
	close.pressed.connect(func() -> void: shop_closed.emit())
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_child(close)
	_overlay_box.add_child(crow)
	refresh_shop(gold)
	_overlay.visible = true


func refresh_shop(gold: int) -> void:
	if _shop_gold_label != null:
		_shop_gold_label.text = "가진 사탕 %d 개" % gold
	for i in _shop_items.size():
		if i < _shop_buttons.size():
			var sold: bool = _shop_items[i].get("sold", false)
			_shop_buttons[i].disabled = sold or gold < int(_shop_items[i]["price"])


func mark_sold(index: int) -> void:
	if index < _shop_items.size():
		_shop_items[index]["sold"] = true
	if index < _shop_buttons.size():
		_shop_buttons[index].disabled = true


func show_death(state: RunState) -> void:
	_clear_overlay()
	_title("쓰러졌다", UiTheme.BAD)
	_sub("%s까지. 처치 %d · 사탕 %d · %d분 %d초" % [
		RunState.floor_name(state.floor_num), state.kills, state.gold,
		int(state.elapsed) / 60, int(state.elapsed) % 60], UiTheme.TEXT)
	_sub("다음 던전은 다른 모양입니다.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_child(row)
	var b := Button.new()
	b.text = "  다시 도전  (R)  "
	b.custom_minimum_size = Vector2(240, 52)
	b.pressed.connect(func() -> void: restart_requested.emit())
	row.add_child(b)
	_overlay.visible = true


func show_win(state: RunState) -> void:
	## **5층을 정리했습니다.** 끝이 있어야 한 판이 이야기가 됩니다 - 끝없이
	## 깊어지기만 하면 죽는 것 말고는 판이 끝나는 길이 없습니다.
	_clear_overlay()
	_title("나갔다!", UiTheme.ACCENT)
	_sub("%s까지 다 지났습니다. 처치 %d · 사탕 %d · %d분 %d초" % [
		RunState.floor_name(Game.FINAL_FLOOR), state.kills, state.gold,
		int(state.elapsed) / 60, int(state.elapsed) % 60], UiTheme.TEXT)
	_sub("다음 던전은 다른 모양입니다.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_child(row)
	var b := Button.new()
	b.text = "  다시 도전  (R)  "
	b.custom_minimum_size = Vector2(240, 52)
	b.pressed.connect(func() -> void: restart_requested.emit())
	row.add_child(b)
	_overlay.visible = true


func show_help(paused_text: String) -> void:
	_clear_overlay()
	_title(paused_text)
	_sub("이동 WASD    조준 마우스    고함 좌클릭    밀기(잡기) F    구르기 Space", UiTheme.TEXT)
	_sub("**고함은 아프지 않습니다.** 넓게 굳혀 놓고, 아픈 일은 밀기가 합니다.
"
		+ "바닥에 칠해지는 부채꼴이 곧 닿는 범위입니다.")
	_sub("적의 공격도 **바닥에 칠해집니다.** 예고가 시작되면 방향이 굳으므로,
"
		+ "옆으로 반 발만 굴러 나가면 빗나갑니다 - 멀리 도망칠 필요가 없습니다.")
	_sub("붉은 큰 적은 돌진합니다 - 정면으로 맞서지 말고 옆으로 빠지세요.
"
		+ "초록 적은 멀리서 가시를 뱉습니다 - 벽을 방패로 쓰면서 붙으세요.")
	_sub("**자동차**에 F 로 올라타면 잠깐 무적으로 방을 휘젓습니다(조종은 안 됩니다).
"
		+ "**물놀이터**에서는 층마다 한 번 체력과 숨을 다 채웁니다.")
	_sub("층을 정리하면 계통 하나를 올립니다 - 여섯 계통, 각 3 단계가 끝입니다.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_child(row)
	var b := Button.new()
	b.text = "  계속하기  (Esc)  "
	b.custom_minimum_size = Vector2(220, 46)
	b.pressed.connect(func() -> void: shop_closed.emit())
	row.add_child(b)
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func hide_all() -> void:
	## 제목과 HUD 를 한 번에 감춥니다. 리그 실험실처럼 화면을 통째로 쓰는
	## 자리에 들어갈 때 씁니다 - 하나씩 끄면 나중에 하나를 빠뜨립니다.
	_overlay.visible = false
	if _hud != null:
		_hud.visible = false
	if touch != null:
		touch.visible = false


func show_hud() -> void:
	if _hud != null:
		_hud.visible = true
	if touch != null:
		touch.visible = TouchControls.wanted()
	_clear_overlay()


func overlay_visible() -> bool:
	return _overlay.visible
