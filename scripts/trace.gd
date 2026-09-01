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
	out.append("   ms  그리기  노드  적  층  무슨 일")
	for r in rows.slice(0, WORST):
		var i2: int = int(r[1])
		out.append("%5.1f %6d %6d %3d %3d  %s" % [
			float(r[0]) * 1000.0, _draw[i2], _node[i2], _foe[i2], _floor[i2],
			_mark[i2] if _mark[i2] != "" else "-"])
	return "\n".join(out)
