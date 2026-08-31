class_name DotIcon
extends Control

## **도트로 그린 기술 아이콘**과 그 위에 도는 쿨다운 시계.
##
## # 왜 글자가 아니라 도트인가
##
## 버튼에 "밀기(잡기)" 같은 글자를 넣으면 두 가지가 나빠집니다. 둥근 버튼
## 안에 네 글자를 욱여넣느라 글자가 작아져 폰에서 안 읽히고, 무엇보다 **읽어야**
## 압니다 - 급할 때 엄지는 글자를 읽지 않고 모양을 봅니다.
##
## 그림 파일을 쓰지 않고 문자열 격자에서 그립니다. 아이콘 셋을 바꾸려면
## 아래 표의 점을 고치면 되고, 해상도가 달라져도 늘 선명합니다(격자 칸을
## 화면 크기에 맞춰 그리므로 흐려지지 않습니다).
##
## # 쿨다운
##
## 남은 쿨다운을 **부채꼴로 덮습니다.** 12시에서 시계 방향으로 도는데, 다 돌면
## 덮개가 사라지고 그때 쓸 수 있습니다. 숫자로 적지 않는 이유는 급할 때 숫자를
## 읽을 겨를이 없기 때문입니다 - 얼마나 남았는지는 남은 넓이로 봅니다.

## 격자. `.` 은 빈칸, `X` 는 채움, `o` 는 옅게 채움(강조가 아니라 그림자로
## 쓰는 자리입니다).
const SHOUT := [
	"...........",
	"........X..",
	"......X.X..",
	"....X.X.X..",
	".XX.X.X.X..",
	".XX.X.X.X..",
	".XX.X.X.X..",
	"....X.X.X..",
	"......X.X..",
	"........X..",
	"...........",
]

## 구르기. 공 하나와 뒤에 남는 자취입니다. 둥근 것이 굴러간다는 뜻이
## 화살표보다 작은 크기에서 잘 읽힙니다.
const ROLL := [
	"...........",
	"...........",
	"......XXX..",
	".XX..XXXXX.",
	"....XXXXXXX",
	"XXX.XXXXXXX",
	"....XXXXXXX",
	".XX..XXXXX.",
	"......XXX..",
	"...........",
	"...........",
]

## 밀기(잡기). 손바닥입니다. 이 버튼 하나가 밀기와 잡기와 말 걸기를 다
## 겸하므로, 특정 기술이 아니라 **손**을 그립니다.
const GRAB := [
	"...........",
	"..X.X.X....",
	"..X.X.X.X..",
	"..X.X.X.X..",
	"..XXXXXXX..",
	".XXXXXXXX..",
	".XXXXXXX...",
	"..XXXXXX...",
	"...XXXX....",
	"...........",
	"...........",
]

## 어떤 그림을 그릴지. 위 상수 중 하나를 넣습니다.
var pattern: Array = SHOUT
## 점 색깔.
var tint := Color(1, 1, 1)
## 0 = 방금 썼음, 1 = 준비됨. 1 이면 덮개를 아예 그리지 않습니다.
##
## 이름이 `ready` 가 아닌 이유: `Node` 에 같은 이름의 시그널이 있어서, 밖에서
## `icon.ready = ...` 를 쓰면 그 시그널로 잡혀 파싱이 깨집니다.
var charge := 1.0:
	set(value):
		var v := clampf(value, 0.0, 1.0)
		if is_equal_approx(v, charge):
			return
		charge = v
		queue_redraw()
## 숨이 모자라 못 쓰는 상태. 쿨다운과 **다른 이유**라 다르게 보여야 합니다 -
## 쿨다운은 기다리면 되고 이쪽은 기다려도 안 됩니다(다른 기술을 써야 합니다).
## 덮개 부채꼴의 반지름. 0 이면 이 칸에 맞춰 자릅니다.
##
## **둥근 버튼 위에서는 값을 줍니다.** 네모로 자르면 동그란 버튼 안에 검은
## 상자가 들어앉은 것처럼 보입니다 - 버튼 반지름을 그대로 주면 부채꼴이
## 버튼 모양을 따라갑니다.
var wedge_radius := 0.0
var winded := false:
	set(value):
		if value == winded:
			return
		winded = value
		queue_redraw()


func setup(dots: Array, color: Color) -> void:
	pattern = dots
	tint = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 반지름을 안 받았으면 이 칸 안으로 자릅니다. 부채꼴은 네 귀퉁이까지
	# 덮으려고 반지름을 대각선 길이로 잡는데, 그대로 두면 아이콘 밖으로
	# 삐져나온 검은 원이 됩니다. 잘라 내면 칸이 위에서부터 시계 방향으로
	# 지워지는 그림이 됩니다.
	clip_contents = wedge_radius <= 0.0
	queue_redraw()


func _draw() -> void:
	# 그림 없이 **덮개만** 쓰기도 합니다. 버튼이 그려진 그림 파일로 바뀌면서
	# 도트는 그 안에 이미 들어 있고, 여기서는 쿨다운만 얹으면 됩니다.
	if pattern.is_empty():
		if charge < 0.999:
			_draw_cooldown()
		return
	var rows := pattern.size()
	var cols := String(pattern[0]).length()
	if rows <= 0 or cols <= 0:
		return
	# 격자를 **정사각형 칸**으로 유지합니다. 가로세로를 따로 늘이면 원이
	# 타원이 되어 무엇을 그린 것인지 알아보기 어려워집니다.
	var cell := minf(size.x / float(cols), size.y / float(rows))
	var origin := Vector2((size.x - cell * cols) * 0.5, (size.y - cell * rows) * 0.5)
	var alpha := 0.35 if winded else 1.0
	for r in rows:
		var line := String(pattern[r])
		for c in mini(cols, line.length()):
			var ch := line[c]
			if ch == ".":
				continue
			var a := alpha * (1.0 if ch == "X" else 0.45)
			# 칸을 0.5px 겹쳐 그립니다. 딱 맞춰 그리면 칸 사이에 배경색
			# 실선이 비쳐 그림이 체크무늬로 보입니다.
			draw_rect(Rect2(origin + Vector2(c * cell, r * cell),
				Vector2(cell + 0.5, cell + 0.5)),
				Color(tint.r, tint.g, tint.b, tint.a * a))
	if charge < 0.999:
		_draw_cooldown()


func _draw_cooldown() -> void:
	## 남은 쿨다운을 덮는 부채꼴. 12시에서 **시계 방향**으로 남습니다.
	##
	## 남은 쪽을 덮습니다(찬 쪽을 칠하지 않습니다). 다 차면 덮개가 없으므로,
	## "아무것도 없을 때가 쓸 수 있을 때" 라는 가장 단순한 규칙이 됩니다.
	var center := size * 0.5
	var radius := wedge_radius if wedge_radius > 0.0 else maxf(size.x, size.y) * 0.72
	var left := (1.0 - charge) * TAU
	if left <= 0.0:
		return
	var steps := maxi(3, int(ceil(left / (TAU / 48.0))))
	var points := PackedVector2Array()
	points.append(center)
	for i in range(steps + 1):
		# -PI/2 가 12시입니다. 각이 커질수록 시계 방향으로 갑니다.
		var a := -PI * 0.5 + left * (1.0 - float(i) / float(steps))
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, Color(0.04, 0.05, 0.09, 0.62))
