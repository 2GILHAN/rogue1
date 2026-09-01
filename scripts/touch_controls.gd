class_name TouchControls
extends Control

## 폰용 화면 조작. 왼쪽은 이동 스틱, 오른쪽은 버튼입니다.
##
## # 왜 조준 스틱이 없는가
##
## 데스크톱에서는 이동(WASD)과 조준(마우스)이 분리돼 있습니다. 그대로 옮기면
## 폰에서는 양손 엄지로 스틱 두 개를 굴려야 하는데, 근접 공격 게임에서는
## 그 정밀도가 재미로 이어지지 않습니다. 대신 **가장 가까운 적을 자동으로
## 겨눕니다.** 적이 없으면 가는 방향을 봅니다.
##
## 그래서 폰에서 플레이어가 결정하는 것은 "어디로 움직일지"와 "언제 때리고
## 언제 구를지" 입니다 - 이 게임의 재미는 원래 거기 있습니다.
##
## # 왜 InputMap 을 흉내 내지 않는가
##
## 가짜 InputEvent 를 만들어 넣으면 눌림/뗌 상태를 직접 관리해야 하고, 실제
## 키보드 입력과 섞이면 어긋납니다. 그냥 Player 가 읽는 값을 직접 채웁니다.

signal attack_pressed
signal attack_released
signal dash_pressed
signal grab_pressed
signal grab_released
signal interact_pressed

const STICK_RADIUS := 110.0
const DEAD_ZONE := 0.16
## 버튼 하나의 지름. **셋이 같습니다.**
##
## 예전에는 자주 쓰는 것을 크게 뒀습니다(밀기 133, 고함 116, 구르기 104).
## 그림이 들어오면서 크기가 곧 그림 크기가 되어, 큰 것만 또렷하고 작은 것은
## 뭉개졌습니다. 어느 것을 자주 쓰는지는 **자리**가 말하게 두고 크기는
## 맞춥니다.
const BUTTON_SIZE := 116.0
## 구르기를 중심으로 한 **가상의 큰 원**의 반지름. 나머지 둘이 이 원 위에
## 앉습니다.
const BUTTON_ARC := 128.0
## 그 원의 테두리와 화면 가장자리 사이. **아래변과 오른변에서 같습니다** -
## 그래야 뭉치가 구석에 비스듬히 치우치지 않고 같은 모양으로 놓입니다.
##
## 30 에서 16 으로 줄였습니다. 구르기(원의 한가운데)가 오른쪽 아래로 그만큼
## 내려가고, 나머지 둘도 같은 만큼 따라갑니다 - 한 값이 셋을 함께 옮기므로
## 뭉치의 모양은 그대로입니다.
const BUTTON_MARGIN := 16.0
## 원 위에서 두 버튼이 앉는 각도(화면 좌표, x 오른쪽 / y 아래).
## 252도는 거의 바로 위, 172도는 거의 바로 왼쪽입니다 - 엄지가 구석을 축으로
## 훑는 방향이라, 예전 배치의 위아래 관계를 그대로 지킵니다.
##
## 둘을 **같은 각도(+22도)만큼 함께** 돌렸습니다. 고함만 오른쪽으로 옮기면
## 둘 사이가 80도에서 102도로 벌어져, 구르기-밀기 간격과 고함-밀기 간격이
## 서로 달라집니다. 함께 돌리면 셋 사이의 간격이 예전 그대로입니다 -
## 움직인 것은 뭉치가 놓인 **방향**뿐입니다.
const BUTTON_ANGLES := {"shout": 252.0, "grab": 172.0}

## 버튼 그림. 무슨 일이 일어나는지가 그림에 그대로 들어 있습니다 -
## 소리 지르는 아이(빨강), 미는 아이(노랑), 구르는 아이(파랑).
const BUTTON_ART := {
	"shout": "res://assets/textures/buttons/button_red.png",
	"grab": "res://assets/textures/buttons/button_yellow.png",
	"roll": "res://assets/textures/buttons/button_blue.png",
}

var move := Vector2.ZERO

var _stick_origin := Vector2.ZERO
var _stick_point := Vector2.ZERO
var _stick_touch := -1
## 버튼 목록과, 어느 손가락이 어느 버튼을 누르고 있는지.
var _buttons: Array = []
var _touch_button: Dictionary = {}

var _base: Control
var _knob: Control
var _pad: Control


static func wanted() -> bool:
	## 터치 화면이거나 웹이면 켭니다. 데스크톱 브라우저에서도 뜨지만, 마우스와
	## 키보드가 그대로 살아 있어 방해가 되지 않습니다.
	if OS.get_cmdline_user_args().has("--touch"):
		return true      # 데스크톱에서 화면 조작을 눈으로 확인할 때
	return DisplayServer.is_touchscreen_available() or OS.has_feature("web") \
		or OS.has_feature("mobile")


func _ready() -> void:
	# 화면 전체를 덮습니다. set_anchors_preset(PRESET_FULL_RECT) 은 트리에 들어간
	# 뒤(_ready)에 부르면 크기가 0 으로 남았습니다 - 버튼이 화면 밖 음수 좌표로
	# 밀려나 아예 안 보였습니다. 앵커와 오프셋을 직접 적어 그 여지를 없앱니다.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stick()
	_build_buttons()


# ---------------------------------------------------------------- 스틱

func _build_stick() -> void:
	# 스틱을 놓을 자리. 왼쪽 아래 넓은 영역 어디를 눌러도 거기가 중심이 됩니다.
	# 고정된 원 안을 정확히 눌러야 하면 엄지가 계속 화면을 더듬게 됩니다.
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pad.offset_left = 0
	_pad.offset_top = -430
	_pad.offset_right = 470
	_pad.offset_bottom = 0
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)

	_base = _ring(STICK_RADIUS, Color(1, 1, 1, 0.16))
	_base.visible = false
	add_child(_base)
	_knob = _ring(46.0, Color(1.0, 0.72, 0.35, 0.55))
	_knob.visible = false
	add_child(_knob)


func _ring(radius: float, color: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(radius * 2, radius * 2)
	c.size = Vector2(radius * 2, radius * 2)
	var draw := ColorRect.new()
	draw.color = color
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 둥글게. ColorRect 에는 모서리 반경이 없어 StyleBox 를 쓴 패널로 만듭니다.
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	panel.add_theme_stylebox_override("panel", sb)
	c.add_child(panel)
	return c


## 버튼 중심에서 이만큼 안에 닿으면 그 버튼을 누른 것으로 봅니다.
##
## 버튼 반지름(70~90px)보다 훨씬 넉넉합니다. 엄지는 화면을 보지 않고 누르므로
## 늘 조금씩 빗나가는데, 그때마다 아무 일도 안 일어나면 게임이 먹통처럼
## 느껴집니다. 버튼끼리는 140px 넘게 떨어져 있어서 이 정도로는 헷갈리지
## 않습니다 - 어차피 **가장 가까운 하나**만 고릅니다.
const SNAP_RADIUS := 170.0


func _press_nearest(at: Vector2, index: int) -> bool:
	## 닿은 자리에서 가장 가까운 버튼을 누릅니다.
	var best := -1
	var best_d := SNAP_RADIUS
	for i in _buttons.size():
		var node: Control = _buttons[i]["node"]
		var d := at.distance_to(node.get_global_rect().get_center())
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	_touch_button[index] = best
	_set_hot(best, true)
	(_buttons[best]["pressed"] as Signal).emit()
	return true


## 버튼에서 손을 떼지 않고 **옆 버튼으로 훑을 때** 그것도 누름으로 봅니다.
##
## 필살기 명령이 "구르기에서 밀기·고함으로 미끄러뜨리기" 라, 이게 없으면
## 폰에서는 세 번을 따로 탁탁탁 눌러야 합니다 - 손가락 하나로 훑는 것이
## 훨씬 빠르고, 명령이 **한 동작**으로 느껴집니다.
##
## 자리를 옮겨 간 것이므로 **떠난 버튼은 떼고** 새 버튼을 누릅니다.
const SLIDE_RADIUS := 80.0


func _slide_to(at: Vector2, index: int) -> void:
	var now: int = _touch_button[index]
	var best := -1
	var best_d := SLIDE_RADIUS
	for i in _buttons.size():
		var node: Control = _buttons[i]["node"]
		var d := at.distance_to(node.get_global_rect().get_center())
		if d < best_d:
			best_d = d
			best = i
	if best < 0 or best == now:
		return
	_set_hot(now, false)
	var released = _buttons[now]["released"]
	if released is Signal:
		(released as Signal).emit()
	_touch_button[index] = best
	_set_hot(best, true)
	(_buttons[best]["pressed"] as Signal).emit()


func _release_touch(index: int) -> void:
	if not _touch_button.has(index):
		return
	var i: int = _touch_button[index]
	_touch_button.erase(index)
	_set_hot(i, false)
	var released = _buttons[i]["released"]
	if released is Signal:
		(released as Signal).emit()


func _set_hot(i: int, on: bool) -> void:
	## 눌린 표시. 그림이라 색을 바꾸는 대신 **살짝 눌러 넣습니다.**
	##
	## 밝기만 바꾸면 숨 부족 표시(옅어짐)와 헷갈립니다. 크기가 줄었다 도로
	## 커지는 것은 실제 단추가 하는 일이라 다른 어떤 표시와도 안 겹칩니다.
	var b: TextureRect = _buttons[i]["node"]
	var scale := 0.90 if on else 1.0
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(scale, scale)


func _input(event: InputEvent) -> void:
	## **감춰져 있으면 아무것도 안 받습니다.**
	##
	## `_input` 은 화면에 안 보여도 그대로 돕니다 - `visible` 은 그리기만
	## 끕니다. 옵션 판이 열리면 이 버튼들을 감추는데(`Ui.toggle_options`),
	## 감춘 채로 판정은 살아 있어서 **옵션 줄을 누르면 스킬이 같이 나갔습니다.**
	##
	## 게다가 여기는 **가장 가까운 버튼**으로 보냅니다(정확히 눌러야 먹으면
	## 폰에서 못 씁니다). 그래서 판 어디를 눌러도 스킬 하나가 걸렸습니다.
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _stick_touch < 0 and _pad.get_global_rect().has_point(touch.position):
				_stick_touch = touch.index
				_stick_origin = touch.position
				_stick_point = touch.position
				_show_stick(true)
				get_viewport().set_input_as_handled()
			elif _press_nearest(touch.position, touch.index):
				get_viewport().set_input_as_handled()
		elif touch.index == _stick_touch:
			_stick_touch = -1
			move = Vector2.ZERO
			_show_stick(false)
		else:
			_release_touch(touch.index)
	elif event is InputEventMouseButton:
		# 데스크톱에서 화면 조작을 확인할 때(--touch). 마우스는 터치 사건을
		# 만들지 않으므로 따로 받습니다.
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _pad.get_global_rect().has_point(mb.position):
					_press_nearest(mb.position, -2)
			else:
				_release_touch(-2)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch:
			_stick_point = drag.position
			_update_stick()
		elif _touch_button.has(drag.index):
			_slide_to(drag.position, drag.index)


func _notification(what: int) -> void:
	## **감춰지는 순간 잡고 있던 것을 놓습니다.**
	##
	## 누른 채로 판이 열리면 뗌 신호가 영영 안 옵니다 - 그 버튼은 눌린 채로
	## 남고, 잡기 같은 것은 손에 든 채로 굳습니다.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		for index in _touch_button.keys():
			_release_touch(index)
		_stick_touch = -1
		move = Vector2.ZERO
		_show_stick(false)


func _show_stick(on: bool) -> void:
	_base.visible = on
	_knob.visible = on
	if on:
		_base.position = _stick_origin - _base.size * 0.5
		_knob.position = _stick_origin - _knob.size * 0.5


func _update_stick() -> void:
	var offset := _stick_point - _stick_origin
	var length := offset.length()
	if length > STICK_RADIUS:
		offset = offset / length * STICK_RADIUS
		length = STICK_RADIUS
	_knob.position = _stick_origin + offset - _knob.size * 0.5
	var amount := length / STICK_RADIUS
	move = Vector2.ZERO if amount < DEAD_ZONE else offset.normalized() * amount


# ---------------------------------------------------------------- 버튼

func _build_buttons() -> void:
	# 오른쪽 아래. 오른쪽·아래 끝에서 띄웁니다 - 홈 인디케이터와 노치를
	# 피하려는 값입니다.
	#
	# 엄지가 가장 편한 구석은 위험을 넘기는 쪽(구르기)이 차지합니다. 그래서
	# 구르기가 **가상 원의 한가운데**, 즉 구석에서 가장 가까운 자리입니다.
	var c := Vector2(-(BUTTON_ARC + BUTTON_MARGIN), -(BUTTON_ARC + BUTTON_MARGIN))
	_button(BUTTON_ART["roll"], "roll", _spot(c, 0.0, 0.0), BUTTON_SIZE,
		dash_pressed)
	# 고함은 원의 **위쪽**입니다. 멀리서 쓰는 기술이라 엄지가 가장 멀리
	# 뻗는 자리에 둡니다.
	# **뗄 때의 신호도 보냅니다.** 고함은 누르는 동안 모으는 기술이라,
	# 떼는 순간이 곧 지르는 순간입니다.
	_button(BUTTON_ART["shout"], "shout",
		_spot(c, BUTTON_ANGLES["shout"], BUTTON_ARC), BUTTON_SIZE,
		attack_pressed, attack_released)
	# 뗄 때의 신호도 그대로 보냅니다. 지금은 받는 쪽이 아무 일도 하지 않지만
	# (한 번 눌러 잡고 다시 눌러 던집니다), 신호를 끊어 두면 나중에 길게 누르기
	# 같은 것을 붙일 때 세 곳을 다시 이어야 합니다.
	# 이름도 바꿉니다. "잡기" 만 적어 두면 밀기가 따로 있는 기술인 줄 압니다 -
	# 실제로는 한 버튼이고, 적의 앞이냐 뒤냐로 갈립니다.
	# 밀기는 원의 **아래쪽**입니다. 붙어서 자주 쓰는 기술이라 엄지가 덜
	# 움직여도 닿습니다.
	_button(BUTTON_ART["grab"], "grab",
		_spot(c, BUTTON_ANGLES["grab"], BUTTON_ARC), BUTTON_SIZE,
		grab_pressed, grab_released)
	# **E 버튼은 없앴습니다.**
	#
	# 상호작용(상점·책장)은 밀기(잡기) 버튼이 겸합니다. 폰 화면에서 엄지가
	# 갈 곳이 하나 줄고, "앞에 있는 것에 손을 댄다" 는 뜻이 한 버튼에 모입니다 -
	# 상인 앞에서 잡기를 눌러 밀치는 일도 없어집니다.


func _spot(center: Vector2, deg: float, radius: float) -> Vector2:
	## 가상 원 위의 한 점을 버튼의 **왼쪽 위 모서리**로 바꿉니다.
	##
	## 자리를 손으로 적지 않고 계산하는 이유: 원 반지름이나 여백을 고치면 셋이
	## 함께 움직여야 하는데, 좌표로 박아 두면 하나만 고치고 나머지를 잊습니다.
	var a := deg_to_rad(deg)
	return center + Vector2(cos(a), sin(a)) * radius - Vector2(BUTTON_SIZE, BUTTON_SIZE) * 0.5


func _button(art: String, kind: String, offset: Vector2, size: float,
		out: Signal, released: Variant = null) -> void:
	## 버튼 하나. **그려 둔 그림**이 통째로 버튼입니다.
	##
	## 색 원 + 도트 아이콘을 코드로 그리다가 그림 파일로 옮겼습니다. 그림에는
	## 무슨 일이 일어나는지가 그대로 들어 있습니다 - 소리 지르는 아이, 미는
	## 아이, 구르는 아이. 기호로 그린 것보다 한눈에 읽힙니다.
	##
	## 누르는 판정은 여전히 `_input` 이 직접 합니다(엄지가 빗나가도 가장 가까운
	## 버튼을 고릅니다). 그래서 이 노드는 그림만 맡습니다.
	var b := TextureRect.new()
	b.texture = load(art)
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + size
	b.offset_bottom = offset.y + size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)

	# 쿨다운 덮개. 그림 위에 얹습니다 - 그림에 도트가 이미 들어 있으므로
	# 여기서는 부채꼴만 그립니다.
	var icon := DotIcon.new()
	icon.pattern = []
	icon.wedge_radius = size * 0.47
	icon.setup([], Color(1, 1, 1))
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)

	_buttons.append({
		"node": b, "icon": icon, "kind": kind, "size": size, "pressed": out,
		"released": released,
	})


func set_ready(kind: String, charge: float, winded: bool) -> void:
	## 기술 하나의 준비 상태를 버튼에 알립니다. 매 프레임 불리지만, 값이
	## 그대로면 `DotIcon` 이 알아서 다시 그리지 않습니다.
	for entry in _buttons:
		if String(entry.get("kind", "")) != kind:
			continue
		var icon: DotIcon = entry["icon"]
		icon.charge = charge
		icon.winded = winded
		# 숨이 모자라면 그림 전체가 옅어집니다. 쿨다운(부채꼴)과 눈에 띄게
		# 달라야, 왜 못 쓰는지가 구분됩니다.
		var b: TextureRect = entry["node"]
		b.modulate = Color(0.55, 0.55, 0.62, 0.75) if winded else Color(1, 1, 1, 1)
		return
