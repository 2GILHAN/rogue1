class_name Trace
extends RefCounted

## **판을 하는 동안의 프레임을 담아 둡니다.** 폰에서 왜 끊기는지 찾는 자리입니다.
##
## # 왜 필요한가
##
## 느려지는 것은 **폰에서만** 나타납니다. 데스크톱에서는 봇으로 9000프레임을
## 돌려도 안 나옵니다 - GPU 가 남아돌고 열도 안 납니다. 그래서 "그때 무엇이
## 있었나" 를 폰에서 직접 담아 와야 합니다.
##
## 깃허브 페이지는 **정적**이라 서버로 못 보냅니다. 대신 브라우저 안에 담았다가
## 파일로 내보냅니다(공유창이나 내려받기).
##
## # 무엇을 담나
##
## 매 프레임 한 줄씩, 최근 `CAP` 개만 굴려 가며 담습니다. 그 위에 **표시**를
## 얹습니다 - 적이 죽었다, 고함을 질렀다, 층이 바뀌었다. 나쁜 프레임 옆에
## 무엇이 있었는지가 곧 답입니다.
##
## 값이 싸야 합니다. 담는 것이 무거우면 재는 행위가 결과를 바꿉니다 - 한 줄에
## 숫자 몇 개뿐이고, 배열은 미리 잡아 둡니다.

## 담아 두는 프레임 수. 60프레임에서 30초입니다.
const CAP := 1800
## 이 시간을 넘긴 프레임을 **나쁜 프레임**으로 봅니다(초).
##
## 60fps 는 16.7ms 입니다. 33ms 면 한 장을 통째로 놓친 것이고, 손은 그때부터
## "걸린다" 고 느낍니다.
const BAD := 0.033
## 나쁜 프레임을 몇 개까지 따로 들고 있나.
const WORST := 12

static var _ms: PackedFloat32Array = PackedFloat32Array()
static var _draw: PackedInt32Array = PackedInt32Array()
static var _node: PackedInt32Array = PackedInt32Array()
static var _foe: PackedInt32Array = PackedInt32Array()
static var _floor: PackedInt32Array = PackedInt32Array()
## **시간을 셋으로 쪼갭니다.** 어디서 쓰는지가 이것 하나로 갈립니다.
##
##   스크립트  `_process` 들(우리 코드)
##   물리      `_physics_process` 들
##   나머지    프레임 시간 - 위 둘 = **엔진이 그리는 시간**
##
## 나쁜 프레임 열둘에 표시가 하나도 안 붙었을 때(v0.60 기록) 이걸 넣었습니다 -
## 「무슨 일이 있었나」 로는 못 잡는 끊김이라 「어디서 썼나」 를 봐야 합니다.
static var _proc: PackedFloat32Array = PackedFloat32Array()
static var _phys: PackedFloat32Array = PackedFloat32Array()
## 그 프레임에 자원 수가 얼마나 늘었나. 무언가를 **처음 불러온** 프레임이면
## 여기가 튑니다(그림·소리·셰이더).
static var _res: PackedInt32Array = PackedInt32Array()
static var _res_last := 0
## 그 프레임에 있었던 일. 대부분 빈 문자열입니다.
static var _mark: PackedStringArray = PackedStringArray()
static var _at := 0
static var _n := 0
static var _on := false
## 이번에 담는 동안의 통계.
static var _total := 0
static var _bad := 0
static var _sum := 0.0
static var _peak := 0.0
## 다음 프레임에 붙일 표시. 한 프레임에 여럿이면 이어 붙입니다.
static var _pending := ""


static func start() -> void:
	## 담기 시작합니다. 배열은 **한 번만** 잡습니다 - 매번 늘리면 그 자체가
	## 끊김이 됩니다.
	if _ms.size() != CAP:
		_ms.resize(CAP)
		_draw.resize(CAP)
		_node.resize(CAP)
		_foe.resize(CAP)
		_proc.resize(CAP)
		_phys.resize(CAP)
		_res.resize(CAP)
		_floor.resize(CAP)
		_mark.resize(CAP)
	_at = 0
	_n = 0
	_total = 0
	_bad = 0
	_sum = 0.0
	_peak = 0.0
	_pending = ""
	_on = true


static func stop() -> void:
	_on = false


static func running() -> bool:
	return _on


static func mark(what: String) -> void:
	## **이번 프레임에 무슨 일이 있었는지** 적어 둡니다.
	##
	## 부르는 쪽이 담기 중인지 안 물어봐도 되게 여기서 걸러냅니다 - 물어보게
	## 하면 부르는 자리마다 조건이 하나씩 붙습니다.
	if not _on:
		return
	_pending = what if _pending == "" else _pending + "+" + what


static func sample(delta: float, draw_calls: int, nodes: int,
		foes: int, floor_num: int) -> void:
	## 한 프레임. `Game._process` 가 매 프레임 부릅니다.
	if not _on:
		return
	_proc[_at] = float(Performance.get_monitor(Performance.TIME_PROCESS))
	_phys[_at] = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_res[_at] = res - _res_last
	_res_last = res
	_ms[_at] = delta
	_draw[_at] = draw_calls
	_node[_at] = nodes
	_foe[_at] = foes
	_floor[_at] = floor_num
	_mark[_at] = _pending
	_pending = ""
	_at = (_at + 1) % CAP
	_n = mini(_n + 1, CAP)
	_total += 1
	_sum += delta
	_peak = maxf(_peak, delta)
	if delta > BAD:
		_bad += 1


## 담은 것을 **브라우저에 적어 둡니다.**
##
## 죽으면 화면이 바뀌고, 그 판에서 「내보내기」를 못 누르면 담은 것이 통째로
## 사라집니다 - 실제로 그랬습니다. 끊기는 폰일수록 죽기 쉬운데, 그때가 바로
## 담은 것이 가장 값진 때입니다.
##
## 죽는 순간 적어 두면 다음에 열었을 때도 그대로 있습니다.
const STORE_KEY := "toto_frames"


static func save() -> void:
	if not OS.has_feature("web"):
		return
	var text := report()
	JavaScriptBridge.eval("try{localStorage.setItem('%s',%s);}catch(e){}"
		% [STORE_KEY, JSON.stringify(text)], true)


static func load_saved() -> String:
	if not OS.has_feature("web"):
		return ""
	var got = JavaScriptBridge.eval(
		"(function(){try{return localStorage.getItem('%s')||'';}catch(e){return '';}})()"
		% STORE_KEY, true)
	return String(got) if got != null else ""


static func device_line() -> String:
	## **어느 기기에서 잰 것인가.**
	##
	## 이 줄이 없어서 기록 넷을 읽는 동안 어느 폰인지, 어느 GPU 인지, 어느
	## 브라우저인지 한 번도 몰랐습니다. 같은 100ms 라도 원인이 갈립니다 -
	## 셰이더를 처음 굽는 멈춤은 드라이버마다 크게 다르고(Mali 가 특히
	## 느린 것으로 알려져 있습니다), GPU 이름 한 줄이면 그 칸이 정해집니다.
	##
	## # 왜 브라우저에게 물어보나
	##
	## 웹에서 `RenderingServer.get_video_adapter_name()` 은 "WebGL" 처럼
	## 쓸모없는 값을 돌려줍니다. 진짜 이름은 `WEBGL_debug_renderer_info`
	## 확장에만 있고, 그건 자바스크립트로만 물어볼 수 있습니다.
	##
	## **못 받아도 그냥 넘어갑니다.** 확장을 막아 둔 브라우저가 있고, 기기
	## 이름을 못 읽었다고 기록을 못 내보내면 본말이 뒤집힙니다.
	if not OS.has_feature("web"):
		return "기기   %s · %s" % [OS.get_name(),
			RenderingServer.get_video_adapter_name()]
	var js := """(function(){
	  try {
	    var ua = navigator.userAgent || "?";
	    var c = document.createElement('canvas');
	    var gl = c.getContext('webgl2') || c.getContext('webgl');
	    var gpu = "?";
	    if (gl) {
	      var e = gl.getExtension('WEBGL_debug_renderer_info');
	      gpu = e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL)
	              : gl.getParameter(gl.RENDERER);
	    }
	    var mem = navigator.deviceMemory ? (navigator.deviceMemory + "GB") : "?";
	    return ua + " ||| " + gpu + " ||| "
	      + screen.width + "x" + screen.height + " x" + (window.devicePixelRatio || 1)
	      + " ||| " + (navigator.hardwareConcurrency || "?") + "코어 " + mem;
	  } catch (err) { return "?"; }
	})()"""
	var raw: Variant = JavaScriptBridge.eval(js, true)
	if raw == null:
		return "기기   못 읽었습니다"
	var parts := String(raw).split(" ||| ")
	if parts.size() < 4:
		return "기기   %s" % String(raw)
	return "기기   %s
GPU    %s
화면   %s · %s" % [
		_short_ua(parts[0]), parts[1], parts[2], parts[3]]


static func _short_ua(ua: String) -> String:
	## 사용자 에이전트는 200 자가 넘습니다. **OS · 브라우저 · 기기 이름**만
	## 뽑습니다 - 나머지는 1990년대부터 끌고 다니는 호환용 찌꺼기입니다.
	var os_name := "?"
	for pair in [["Android", "Android"], ["iPhone", "iOS"], ["iPad", "iPadOS"],
			["Windows", "Windows"], ["Mac OS X", "macOS"], ["Linux", "Linux"]]:
		if ua.contains(String(pair[0])):
			os_name = String(pair[1])
			break

	# 순서가 중요합니다. 엣지·삼성·오페라는 자기 이름 **뒤에** Chrome 도 함께
	# 적으므로, 크롬을 먼저 보면 전부 크롬으로 읽힙니다.
	#
	# 사파리는 `Version/` 을 봅니다. `Safari/604.1` 은 **엔진 판**이라 어느
	# 사파리인지 알려 주지 않습니다 - 실제로 iOS 17.5 가 604 로 찍혔습니다.
	var browser := "?"
	for pair in [["Edg/", "Edge"], ["SamsungBrowser/", "Samsung"],
			["OPR/", "Opera"], ["Firefox/", "Firefox"],
			["CriOS/", "Chrome(iOS)"], ["Chrome/", "Chrome"],
			["Version/", "Safari"]]:
		var tag := String(pair[0])
		var i := ua.find(tag)
		if i < 0:
			continue
		var ver := ua.substr(i + tag.length(), 8).split(".")[0]
		browser = "%s %s" % [pair[1], ver] if ver.is_valid_int() else String(pair[1])
		break
	if browser == "?" and ua.contains("Safari/"):
		browser = "Safari"

	return "%s · %s%s" % [os_name, browser, _model_of(ua)]


static func _model_of(ua: String) -> String:
	## 기기 이름. 괄호 안에 세미콜론으로 나뉘어 있는데 **자리가 일정하지
	## 않습니다.**
	##
	##   Linux; Android 14; SM-S918N Build/UP1A...; wv    -> SM-S918N
	##   Linux; Android 13; SM-A536E                      -> SM-A536E
	##
	## 처음에는 첫 `"; "` 를 찾아 `" Build/"` 까지 잘랐습니다. 첫 것은
	## `Linux;` 라 "Android 14; SM-S918N" 이 통째로 나왔고, `Build/` 가 없는
	## 삼성 브라우저에서는 이름이 아예 빠졌습니다.
	##
	## 그래서 자리를 세지 않고 **아닌 것을 걸러냅니다** - 알맹이는 남는
	## 하나입니다.
	var lp := ua.find("(")
	var rp := ua.find(")", lp + 1)
	if lp < 0 or rp <= lp:
		return ""
	for raw in ua.substr(lp + 1, rp - lp - 1).split("; "):
		var part := String(raw).strip_edges()
		# `wv` 는 앱 안의 웹뷰라는 표시일 뿐 기기 이름이 아닙니다.
		if part == "" or part == "wv" or part == "Linux" or part == "U":
			continue
		if part.begins_with("Android") or part.begins_with("Windows") 				or part.begins_with("Intel") or part.begins_with("CPU") 				or part.begins_with("Macintosh") or part.begins_with("X11") 				or part.begins_with("iPhone") or part.begins_with("iPad") 				or part.begins_with("Win64") or part.begins_with("x64"):
			continue
		var cut := part.find(" Build/")
		return " · " + (part.substr(0, cut) if cut > 0 else part)
	return ""


static func report() -> String:
	## 담은 것을 사람이 읽을 글로 만듭니다.
	##
	## 통째로 내보내지 않습니다 - 1800줄을 폰에서 넘겨 보게 하면 아무도 안
	## 읽습니다. **나쁜 프레임 열두 개와 그 앞뒤**만 뽑고, 나머지는 요약합니다.
	if _total == 0:
		return "담긴 것이 없습니다. 옵션에서 「기록」을 켜고 한 판 해 주세요."
	var out := PackedStringArray()
	out.append("TOTO FIGHTCLUB %s  프레임 기록" % Game.VERSION)
	out.append("담은 프레임 %d  평균 %.1fms (%.0f fps)  가장 나쁜 %.1fms" % [
		_total, _sum / float(_total) * 1000.0,
		float(_total) / maxf(_sum, 0.001), _peak * 1000.0])
	out.append("%.0fms 넘긴 프레임 %d개 (%.1f%%)" % [
		BAD * 1000.0, _bad, 100.0 * float(_bad) / float(_total)])
	out.append(device_line())
	out.append("")

	# **나쁜 프레임 옆에 무엇이 있었나.** 표시를 세어 보면 무엇이 값을
	# 치르는지가 이름으로 나옵니다.
	var blame: Dictionary = {}
	var rows: Array = []
	for k in _n:
		var i := (_at - _n + k + CAP) % CAP
		if _ms[i] <= BAD:
			continue
		rows.append([_ms[i], i])
		# 그 프레임과 **앞 넉 장**까지 봅니다. 일이 벌어진 프레임과 화면이
		# 걸리는 프레임이 한 장 어긋나는 일이 흔합니다.
		for b in 5:
			var j := (i - b + CAP) % CAP
			if _mark[j] == "":
				continue
			for name in _mark[j].split("+"):
				blame[name] = int(blame.get(name, 0)) + 1
			break
	if blame.is_empty():
		out.append("나쁜 프레임 옆에 잡힌 일이 없습니다.")
	else:
		var names: Array = blame.keys()
		names.sort_custom(func(a, b): return int(blame[a]) > int(blame[b]))
		out.append("나쁜 프레임 옆에 있던 일:")
		for name in names:
			out.append("  %-14s %d번" % [name, int(blame[name])])
	out.append("")

	rows.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	out.append("가장 나쁜 프레임 %d개:" % mini(rows.size(), WORST))
	out.append("   ms  스크립트  물리  나머지  그리기  노드  적  층  자원  무슨 일")
	for r in rows.slice(0, WORST):
		var i2: int = int(r[1])
		var ms := float(r[0]) * 1000.0
		var pr := _proc[i2] * 1000.0
		var ph := _phys[i2] * 1000.0
		out.append("%5.1f %9.1f %5.1f %7.1f %7d %5d %3d %3d %5d  %s" % [
			ms, pr, ph, maxf(ms - pr - ph, 0.0),
			_draw[i2], _node[i2], _foe[i2], _floor[i2], _res[i2],
			_mark[i2] if _mark[i2] != "" else "-"])
	out.append("")
	out.append("「나머지」가 크면 우리 코드가 아니라 엔진이 그리는 시간입니다")
	out.append("(셰이더를 처음 굽거나 그림을 처음 올릴 때 여기가 튑니다).")
	out.append("「자원」이 그 프레임에 늘었으면 무언가를 처음 불러온 것입니다.")
	return "
".join(out)
