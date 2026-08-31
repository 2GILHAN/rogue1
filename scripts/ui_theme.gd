class_name UiTheme
extends RefCounted

## Godot 내장 폰트에는 한글 글리프가 없습니다. 그대로 두면 모든 안내문이
## 빈 네모로 나옵니다.
##
## 글꼴을 구하는 길이 둘입니다.
##
##   1. 번들 (assets/fonts/ui.ttf) - **웹에서는 이 길뿐입니다.** 브라우저는
##      OS 글꼴을 빌려 주지 않습니다. tools/make_font.py 가 소스에 나오는
##      글자만 남겨 90KB 로 줄여 둡니다.
##   2. SystemFont - 번들이 없을 때 데스크톱에서 OS 글꼴을 빌립니다.
const FAMILIES := ["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "NanumGothic", "Segoe UI"]

const BG := Color(0.07, 0.06, 0.06, 0.92)
const PANEL := Color(0.11, 0.09, 0.09, 0.97)
const ACCENT := Color(1.0, 0.62, 0.28)
const TEXT := Color(0.94, 0.92, 0.90)
const DIM := Color(0.62, 0.58, 0.56)
const GOOD := Color(0.55, 0.86, 0.55)
const BAD := Color(0.94, 0.38, 0.34)

static var _font: Font = null
static var _theme: Theme = null


const BUNDLED := "res://assets/fonts/ui.ttf"


static func font() -> Font:
	if _font != null:
		return _font
	if ResourceLoader.exists(BUNDLED):
		var bundled: Font = load(BUNDLED)
		if bundled != null:
			_font = bundled
			return _font
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FAMILIES)
	f.allow_system_fallback = true
	_font = f
	return _font


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.16, 0.14, 0.13)
	btn.set_corner_radius_all(8)
	btn.set_content_margin_all(12)
	btn.border_color = Color(0.30, 0.26, 0.24)
	btn.set_border_width_all(2)

	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.19, 0.15)
	hover.border_color = ACCENT

	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.24, 0.16)
	pressed.border_color = ACCENT

	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.12, 0.11, 0.11)
	disabled.border_color = Color(0.20, 0.18, 0.18)

	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", hover)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))

	_theme = t
	return t


static func panel_style(color: Color = PANEL, radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(16)
	sb.border_color = Color(0.26, 0.22, 0.20)
	sb.set_border_width_all(2)
	return sb


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
