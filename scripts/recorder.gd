class_name Recorder
extends Node

## 판을 영상으로 남깁니다. 남의 폰으로 보낼 수 있는 파일 하나가 목표입니다.
##
## # 왜 브라우저에 맡기는가
##
## 엔진에도 녹화가 있습니다(`--write-movie`). 그런데 그건 데스크톱 실행 파일을
## 명령줄 옵션과 함께 새로 띄워야 하고, 소리는 따로 나오며, 결과는 PC 안의
## 폴더에 떨어집니다. **이 게임을 실제로 하는 곳은 폰의 브라우저입니다.**
## 거기서는 그 길이 통째로 막혀 있습니다.
##
## 브라우저에는 이미 필요한 것이 다 있습니다 - 화면은 `canvas.captureStream`,
## 소리는 WebAudio 의 갈래 하나, 묶는 것은 `MediaRecorder`, 보내는 것은
## `navigator.share`(카톡·메시지 공유창이 그대로 열립니다). 우리가 할 일은
## 이 넷을 잇는 것뿐이라, 엔진 쪽에 프레임을 퍼내는 코드를 두지 않습니다.
##
## # 소리를 어떻게 가로채는가
##
## `captureStream` 은 그림만 줍니다. 소리는 엔진이 WebAudio 로 따로 냅니다.
## 그래서 내보낸 HTML 머리에 심어 둔 스크립트(export_presets.cfg)가
## `AudioNode.connect` 를 감싸 **스피커로 가는 노드를 전부 적어 둡니다**
## (`window.__r1out`). 녹화를 시작할 때 그 노드들을 녹음용 갈래에도 한 번 더
## 이어 붙이면, 스피커로 가던 소리가 그대로 파일에도 들어갑니다.
##
## 적어만 두고 갈래는 녹화할 때 만듭니다. 늘 만들어 두면 녹화하지 않는
## 사람도 오디오 노드 하나를 계속 더 돌리게 됩니다.
##
## # 저장·공유 버튼이 왜 게임 UI 가 아닌가
##
## `navigator.share` 는 **사용자가 방금 누른 그 순간에만** 열립니다. 그런데
## 엔진의 버튼은 브라우저 이벤트가 끝나고 다음 프레임에 눌린 것으로 처리돼서,
## 거기서 부르면 브라우저가 "사용자 동작이 아니다" 라며 거절합니다. 그래서
## 녹화가 끝나면 **HTML 쪽에 진짜 버튼을 띄웁니다.** 게임 화면 위쪽에 뜨는
## 작은 판이 그것입니다.

## 한 판에 남기는 최대 길이(초)와 크기(MB).
##
## 둘 다 폰의 메모리를 생각한 값입니다. 녹화한 것은 파일이 되기 전까지 전부
## 메모리에 쌓입니다 - 길이만 막고 크기를 안 막으면 화면이 복잡한 판에서
## 생각보다 훨씬 커집니다. 2분이면 남에게 보낼 한 판으로 충분하고,
## 2.5Mbps 로 40MB 남짓이라 메신저로도 넘어갑니다.
const MAX_SEC := 120
const MAX_MB := 64

static var instance: Recorder

## 제목 화면에서 "녹화하며 내려가기" 를 고르면 켜집니다. **한 판만** 켜집니다 -
## 시작하면서 꺼집니다. 죽고 다시 도전할 때 저절로 또 녹화되면, 방금 남긴
## 영상이 새 녹화에 덮여 사라집니다.
static var armed := false

## 스스로 멈췄을 때(시간·크기 한도, 또는 오류) 한 번 알립니다.
signal stopped_by_itself(reason: String)

var _ok := false
## JS 쪽 상태를 매 프레임 물으면 프레임마다 eval 이 하나씩 붙습니다. 0.2초에
## 한 번만 묻고 그 사이에는 여기 적어 둔 것을 씁니다.
var _poll := 0.0
var _rec := false
var _sec := 0.0
var _err := ""


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS   # 죽어서 멈춘 화면도 영상에는 들어갑니다
	if not OS.has_feature("web"):
		return
	_ok = int(JavaScriptBridge.eval(_INSTALL, true)) == 1
	if _ok:
		_ok = int(JavaScriptBridge.eval("window.__r1rec.ready()", true)) == 1


static func available() -> bool:
	## 이 기기에서 녹화가 되는가. 제목 화면이 이걸 보고 선택지를 냅니다.
	return instance != null and instance._ok


static func recording() -> bool:
	return instance != null and instance._rec


static func start() -> bool:
	if instance == null or not instance._ok:
		return false
	var code := "window.__r1rec.start(%d, %d)" % [MAX_SEC, MAX_MB]
	instance._rec = int(JavaScriptBridge.eval(code, true)) == 1
	instance._sec = 0.0
	instance._poll = 0.2
	return instance._rec


static func stop() -> void:
	if instance == null or not instance._ok or not instance._rec:
		return
	instance._rec = false
	JavaScriptBridge.eval("window.__r1rec.stop()", true)


static func label() -> String:
	## HUD 에 그대로 찍는 줄. 남은 시간을 같이 보여 줍니다 - 2분이 한도라는 것을
	## 시작할 때 한 번 알려 줘 봐야, 정작 궁금해지는 때는 녹화 중입니다.
	if instance == null:
		return ""
	var sec := int(instance._sec)
	return "● 녹화 %d:%02d   남은 %d초" % [sec / 60, sec % 60, maxi(0, MAX_SEC - sec)]


func _process(delta: float) -> void:
	if not _ok:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.2
	var raw: Variant = JavaScriptBridge.eval("window.__r1rec.state()", true)
	if typeof(raw) != TYPE_STRING:
		return
	var data: Variant = JSON.parse_string(String(raw))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = data
	var now := int(dict.get("rec", 0)) == 1
	_sec = float(dict.get("sec", 0.0))
	_err = String(dict.get("err", ""))
	if _rec and not now:
		# 우리가 세운 것이 아니라 저 혼자 섰습니다 - 한도에 닿았거나, 탭이
		# 가려져 캔버스가 멈췄거나. 어느 쪽이든 화면에는 알려야 합니다.
		_rec = false
		stopped_by_itself.emit(_err if _err != "" else "한도")
	else:
		_rec = now


## HTML 쪽에 심는 코드. 한 번만 심고 그 뒤로는 여기서 함수만 부릅니다.
##
## 백슬래시와 큰따옴표를 쓰지 않습니다 - GDScript 의 여러 줄 문자열도 이스케이프를
## 해석하기 때문에, JS 안에 백슬래시가 있으면 조용히 다른 코드가 됩니다.
const _INSTALL := """
(function(){
if (window.__r1rec) { return 1; }
var st = {rec:null, chunks:[], blob:null, mime:'', url:'', t0:0, bytes:0,
          err:'', timer:0, secs:0, panel:null};

function canvasEl(){
  return document.getElementById('canvas') || document.querySelector('canvas');
}

function pickMime(){
  if (typeof MediaRecorder === 'undefined' || !MediaRecorder.isTypeSupported) { return ''; }
  // mp4 를 먼저 봅니다. webm 은 아이폰에서 재생이 안 되는 일이 흔해서,
  // 보낸 사람은 멀쩡한데 받은 사람만 검은 화면을 봅니다.
  var want = ['video/mp4;codecs=avc1.42E01E,mp4a.40.2', 'video/mp4',
              'video/webm;codecs=vp9,opus', 'video/webm;codecs=vp8,opus',
              'video/webm'];
  for (var i = 0; i < want.length; i++) {
    try { if (MediaRecorder.isTypeSupported(want[i])) { return want[i]; } } catch (e) {}
  }
  return '';
}

function ready(){
  var el = canvasEl();
  return !!(el && el.captureStream && pickMime());
}

function tapAudio(stream){
  // HTML 머리의 스크립트가 적어 둔 '스피커로 가는 노드' 들을 녹음용 갈래에도
  // 잇습니다. 갈래는 여기서 처음 만듭니다.
  var list = window.__r1out || [];
  var ctxs = [];
  for (var i = 0; i < list.length; i++) {
    var n = list[i];
    var c = n && n.context;
    if (!c) { continue; }
    if (!c.__r1tap) {
      try { c.__r1tap = c.createMediaStreamDestination(); } catch (e) { continue; }
    }
    try { n.connect(c.__r1tap); } catch (e) {}
    if (ctxs.indexOf(c) < 0) { ctxs.push(c); }
  }
  for (var j = 0; j < ctxs.length; j++) {
    var tr = ctxs[j].__r1tap.stream.getAudioTracks();
    for (var k = 0; k < tr.length; k++) {
      try { stream.addTrack(tr[k]); } catch (e) {}
    }
  }
  return ctxs.length;
}

function ext(){ return st.mime.indexOf('mp4') >= 0 ? 'mp4' : 'webm'; }

function fileName(){
  var d = new Date();
  function p(n){ return (n < 10 ? '0' : '') + n; }
  return 'emberling-' + d.getFullYear() + p(d.getMonth()+1) + p(d.getDate())
       + '-' + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + '.' + ext();
}

function finish(){
  st.secs = (Date.now() - st.t0) / 1000;
  if (!st.chunks.length) {
    if (!st.err) { st.err = '녹화된 화면이 없습니다'; }
    showPanel();
    return;
  }
  st.blob = new Blob(st.chunks, {type: st.mime.split(';')[0]});
  st.chunks = [];
  showPanel();
}

function doSave(){
  if (!st.blob) { return; }
  if (!st.url) { st.url = URL.createObjectURL(st.blob); }
  var a = document.createElement('a');
  if (typeof a.download === 'undefined') {
    // download 를 모르는 아주 오래된 사파리. 새 창으로 열어 주면 영상을 길게
    // 눌러 저장할 수 있습니다.
    window.open(st.url, '_blank');
    return;
  }
  a.href = st.url;
  a.download = fileName();
  // 내려받기를 무시하고 **그 자리에서 영상으로 넘어가 버리는** 브라우저가
  // 있습니다(구형 iOS). 그러면 게임이 통째로 날아갑니다 - 새 창을 지정해
  // 두면 최악이라도 옆 탭에서 열립니다.
  a.target = '_blank';
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

function doShare(){
  if (!st.blob) { return; }
  var f = null;
  try { f = new File([st.blob], fileName(), {type: st.blob.type}); } catch (e) { f = null; }
  if (f && navigator.share && navigator.canShare && navigator.canShare({files:[f]})) {
    try {
      navigator.share({files:[f], title:'TOTO FIGHTCLUB'}).then(function(){}, function(){});
      return;
    } catch (e) {}
  }
  // 공유창이 없는 브라우저(대개 PC)면 내려받기로 대신합니다. 버튼이 아무
  // 일도 안 하는 것보다 낫습니다.
  doSave();
}

function button(text, accent, fn){
  var b = document.createElement('button');
  b.textContent = text;
  b.style.cssText = 'font:600 15px system-ui,-apple-system,sans-serif;padding:10px 16px;'
    + 'margin:0 4px;border-radius:8px;border:2px solid ' + (accent ? '#e0a355' : '#4a423c')
    + ';background:' + (accent ? '#e0a355' : '#1b1817')
    + ';color:' + (accent ? '#1b1817' : '#d8cfc4')
    + ';cursor:pointer;-webkit-appearance:none;';
  b.addEventListener('click', fn);
  return b;
}

function hidePanel(){
  if (st.panel) { st.panel.style.display = 'none'; }
}

function showPanel(){
  if (!st.panel) {
    // 화면 위쪽에 답니다. 아래는 조이스틱과 버튼 자리라, 거기 띄우면 판을
    // 닫기 전까지 조작이 막힙니다.
    st.panel = document.createElement('div');
    st.panel.id = 'r1panel';
    st.panel.style.cssText = 'position:fixed;left:50%;top:14px;transform:translateX(-50%);'
      + 'z-index:100;background:rgba(12,11,10,0.95);border:2px solid #4a423c;'
      + 'border-radius:12px;padding:12px 14px;text-align:center;color:#d8cfc4;'
      + 'font:15px system-ui,-apple-system,sans-serif;max-width:92vw;';
    document.body.appendChild(st.panel);
  }
  var p = st.panel;
  while (p.firstChild) { p.removeChild(p.firstChild); }
  p.style.display = 'block';

  var line = document.createElement('div');
  line.style.cssText = 'margin-bottom:10px;';
  if (st.blob) {
    line.textContent = '녹화 완료 - ' + Math.round(st.secs) + '초 · '
      + (st.blob.size / 1048576).toFixed(1) + 'MB';
  } else {
    line.textContent = '녹화 실패 - ' + (st.err || '알 수 없는 이유');
    line.style.color = '#d9736a';
  }
  p.appendChild(line);

  if (st.blob) {
    // 미리보기를 답니다. 화면이 검게 녹화되는 브라우저가 있어서, 보내고 나서
    // 알게 되는 것보다 여기서 보이는 편이 낫습니다.
    if (!st.url) { st.url = URL.createObjectURL(st.blob); }
    var v = document.createElement('video');
    v.src = st.url;
    v.muted = true;
    v.loop = true;
    v.autoplay = true;
    v.playsInline = true;
    v.setAttribute('playsinline', '');
    // 막대를 답니다. 폰에서는 여기서 전체화면으로 키우고 길게 눌러 저장하는
    // 길이 하나 더 생깁니다.
    v.controls = true;
    v.style.cssText = 'display:block;margin:0 auto 10px;width:200px;max-width:70vw;'
      + 'border-radius:8px;background:#000;';
    p.appendChild(v);
    try { v.play(); } catch (e) {}

    var row = document.createElement('div');
    row.appendChild(button('공유하기', true, doShare));
    row.appendChild(button('내려받기', false, doSave));
    p.appendChild(row);

    // 폰에서 '저장' 이 어디로 가는지는 기기마다 다릅니다. 안드로이드는
    // 내려받기가 곧 파일이지만, 아이폰에서 사진첩에 넣는 길은 공유창의
    // '비디오 저장' 입니다 - 안 적어 두면 못 찾습니다.
    var tip = document.createElement('div');
    tip.textContent = '아이폰은 공유하기 → 비디오 저장, 안드로이드·PC 는 내려받기';
    tip.style.cssText = 'margin-top:8px;font-size:12px;color:#8e857b;';
    p.appendChild(tip);
  }

  var close = document.createElement('div');
  close.style.cssText = 'margin-top:10px;';
  close.appendChild(button('닫기', false, function(){ hidePanel(); }));
  p.appendChild(close);
}

function stop(){
  if (st.timer) { clearTimeout(st.timer); st.timer = 0; }
  var r = st.rec;
  st.rec = null;
  if (!r) { return 0; }
  try { r.stop(); } catch (e) { st.err = '정지 실패'; }
  // 화면 갈래만 끊습니다. 소리 갈래는 오디오 그래프에 물려 있어서 한 번
  // 끊으면 되살아나지 않습니다 - 두 번째 녹화가 통째로 무음이 됩니다.
  try {
    var vt = r.stream.getVideoTracks();
    for (var i = 0; i < vt.length; i++) { vt[i].stop(); }
  } catch (e) {}
  return 1;
}

window.__r1rec = {
  ready: function(){ return ready() ? 1 : 0; },

  start: function(maxSec, maxMb){
    if (st.rec) { return 1; }
    hidePanel();
    st.chunks = [];
    st.blob = null;
    st.bytes = 0;
    st.err = '';
    st.secs = 0;
    if (st.url) { try { URL.revokeObjectURL(st.url); } catch (e) {} st.url = ''; }
    var el = canvasEl();
    if (!el || !el.captureStream) { st.err = '이 브라우저는 화면을 잡지 못합니다'; return 0; }
    st.mime = pickMime();
    if (!st.mime) { st.err = '이 브라우저는 녹화 형식을 못 씁니다'; return 0; }
    var s;
    try { s = el.captureStream(30); } catch (e) { st.err = '화면을 잡지 못했습니다'; return 0; }
    tapAudio(s);
    var r;
    try {
      r = new MediaRecorder(s, {mimeType: st.mime, videoBitsPerSecond: 2500000,
                                audioBitsPerSecond: 96000});
    } catch (e) { st.err = '녹화기를 만들지 못했습니다'; return 0; }
    r.ondataavailable = function(e){
      if (!e.data || !e.data.size) { return; }
      st.chunks.push(e.data);
      st.bytes += e.data.size;
      if (st.bytes > maxMb * 1048576) { stop(); }
    };
    r.onstop = finish;
    r.onerror = function(){ st.err = '녹화 중 오류'; };
    // 1초마다 토막을 받습니다. 통째로 받으면 도중에 크기를 알 수 없어서
    // 한도를 걸 수가 없습니다.
    try { r.start(1000); } catch (e) { st.err = '녹화를 시작하지 못했습니다'; return 0; }
    st.rec = r;
    st.t0 = Date.now();
    if (maxSec > 0) { st.timer = setTimeout(stop, maxSec * 1000); }
    return 1;
  },

  stop: stop,

  state: function(){
    return JSON.stringify({
      rec: st.rec ? 1 : 0,
      sec: st.rec ? (Date.now() - st.t0) / 1000 : st.secs,
      mb: st.bytes / 1048576,
      has: st.blob ? 1 : 0,
      err: st.err
    });
  }
};
return 1;
})()
"""
