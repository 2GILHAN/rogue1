class_name Record
extends RefCounted

## **판과 판을 잇는 한 줄.** 가장 깊이 간 반과 가장 빠르게 나간 시간.
##
## # 왜 필요한가
##
## 한 판이 끝나면 아무것도 안 남습니다. 다섯 반을 다 지나든 씨앗반에서 죽든
## 다음 판은 똑같이 처음부터이고, **어제보다 나아졌는지 알 길이 없습니다.**
## 로그라이크에서 판을 다시 시작하는 이유는 그 한 줄입니다.
##
## # 왜 브라우저에 저장하나
##
## 깃허브 페이지는 정적이라 서버에 못 씁니다. 브라우저의 `localStorage` 는
## 주소마다 따로 남으므로 폰에서 껐다 켜도 그대로입니다.
##
## 기록기(`recorder.gd`)와 프레임 기록(`trace.gd`)이 이미 같은 자리를 씁니다 -
## 새 방법을 들이지 않았습니다.
##
## **못 써도 그냥 넘어갑니다.** 사생활 보호 모드나 저장 공간이 꽉 찬 브라우저가
## 있고, 기록을 못 남겼다고 판이 안 끝나면 본말이 뒤집힙니다.

const KEY_FLOOR := "toto_best_floor"
const KEY_TIME := "toto_best_time"
const KEY_RUNS := "toto_runs"

## 데스크톱에는 `localStorage` 가 없습니다. 한 번 켠 동안만 기억합니다 -
## 만드는 사람이 화면을 확인할 수 있으면 충분합니다.
static var _mem: Dictionary = {}


## `_get` · `_set` 이 아니라 `_read` · `_write` 입니다. 앞의 둘은 Object 의
## 내장 이름이라 덮어쓰면 "부모와 서명이 다르다" 로 컴파일이 막힙니다.
static func _read(key: String) -> String:
	if not OS.has_feature("web"):
		return String(_mem.get(key, ""))
	var raw: Variant = JavaScriptBridge.eval(
		"(function(){try{return localStorage.getItem('%s')||'';}catch(e){return '';}})()"
		% key, true)
	return "" if raw == null else String(raw)


static func _write(key: String, value: String) -> void:
	if not OS.has_feature("web"):
		_mem[key] = value
		return
	JavaScriptBridge.eval("try{localStorage.setItem('%s','%s');}catch(e){}"
		% [key, value], true)


static func runs() -> int:
	return int(_read(KEY_RUNS)) if _read(KEY_RUNS).is_valid_int() else 0


static func is_first_run() -> bool:
	## **아직 한 판도 안 끝냈나.** 손 안내를 첫 판에만 띄우는 데 씁니다.
	return runs() <= 0


static func note(state: RunState, cleared: bool) -> Dictionary:
	## 한 판이 끝났습니다. 기록을 갱신하고 **무엇이 새로 갱신됐는지** 돌려줍니다.
	##
	## 판 수는 끝날 때마다 셉니다 - 시작할 때 세면 창을 닫고 나간 판까지
	## 세어져서, "첫 판" 이 첫 판이 아니게 됩니다.
	_write(KEY_RUNS, str(runs() + 1))
	var out := {"floor": false, "time": false}

	var reached := int(state.floor_num)
	var best_floor := int(_read(KEY_FLOOR)) if _read(KEY_FLOOR).is_valid_int() else 0
	if reached > best_floor:
		_write(KEY_FLOOR, str(reached))
		out["floor"] = true

	# **나간 판만 시간을 셉니다.** 죽은 판의 시간은 "빨리 죽었다" 는 뜻이라
	# 기록으로 두면 거꾸로 된 목표가 생깁니다.
	if cleared:
		var secs := int(state.elapsed)
		var best := int(_read(KEY_TIME)) if _read(KEY_TIME).is_valid_int() else 0
		if best <= 0 or secs < best:
			_write(KEY_TIME, str(secs))
			out["time"] = true
	return out


static func best_line() -> String:
	## 제목 화면에 한 줄. 기록이 없으면 빈 글자입니다 - 처음 여는 사람에게
	## "최고 기록 없음" 은 알려 줄 것이 없는 줄입니다.
	var floor_s := _read(KEY_FLOOR)
	var time_s := _read(KEY_TIME)
	var parts := PackedStringArray()
	if floor_s.is_valid_int() and int(floor_s) > 0:
		parts.append("가장 깊이 %s" % RunState.floor_name(int(floor_s)))
	if time_s.is_valid_int() and int(time_s) > 0:
		parts.append("가장 빠르게 %d분 %d초" % [int(time_s) / 60, int(time_s) % 60])
	if parts.is_empty():
		return ""
	return "최고 기록  " + "  ·  ".join(parts)


static func line(state: RunState, cleared: bool) -> String:
	## 결말 화면에 한 줄. **기록을 갱신하면서** 만듭니다 - 화면을 그리는
	## 자리에서 저장까지 하면 부르는 쪽이 순서를 안 틀립니다.
	var fresh := note(state, cleared)
	var marks := PackedStringArray()
	if bool(fresh["floor"]):
		marks.append("가장 깊이 왔습니다")
	if bool(fresh["time"]):
		marks.append("가장 빠릅니다")
	if not marks.is_empty():
		return "새 기록!  " + "  ·  ".join(marks)
	var best := best_line()
	return best if best != "" else ""
