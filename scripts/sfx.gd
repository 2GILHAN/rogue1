class_name Sfx
extends Node

## 소리. 지금은 고함 하나뿐이지만, 소리가 하나라도 생기면 둘 이상이 되므로
## 처음부터 재생을 한곳에 모아 둡니다.
##
## # 왜 3D 가 아닌가
##
## 카메라가 늘 주인공을 따라다녀서, 주인공이 내는 소리는 언제나 화면 한가운데
## 에서 납니다. 거리 감쇠와 방향을 계산해 봐야 결과가 같습니다. 적이 내는
## 소리를 넣게 되면 그때 3D 로 나누면 됩니다.
##
## # 왜 재생기를 여러 개 두는가
##
## 하나면 앞 소리가 끊기고 새 소리가 납니다. 고함은 재사용 대기가 있어 겹칠
## 일이 드물지만, 던지기·피격 소리가 붙으면 바로 겹칩니다. 미리 몇 개 만들어
## 놓고 노는 것을 골라 씁니다.

const SHOUT := "res://assets/audio/shout_a1.wav"
## 밀치기. vtos 에서 자른 클립(a2)입니다 - 고함과 같은 목소리라 두 기술이
## 같은 아이의 것으로 들립니다.
const PUSH := "res://assets/audio/push_a2.wav"
## 잡기와 던지기는 쓸 만한 녹음이 없어 합성했습니다(tools/make_sfx.py).
## 짧고 유쾌한 소리 둘이라 합성으로 충분합니다.
const GRAB := "res://assets/audio/grab_pop.wav"
const THROW := "res://assets/audio/throw_whoosh.wav"
## 아래는 자리는 있는데 소리가 없던 곳들입니다. 전부 합성이고 **나중에 녹음
## 으로 갈아 끼울 자리**입니다 - 파일 이름만 맞추면 코드는 그대로입니다.
const HURT := "res://assets/audio/hurt_yelp.wav"      ## 주인공이 맞음
const FOE_HIT := "res://assets/audio/foe_hit.wav"     ## 적이 맞음
const FOE_DIE := "res://assets/audio/foe_die.wav"     ## 적이 쓰러짐
const COIN := "res://assets/audio/coin.wav"           ## 사탕
const STEP := "res://assets/audio/step.wav"           ## 발소리
const WARN := "res://assets/audio/warn.wav"           ## 적의 공격 예고
const PAGE := "res://assets/audio/page.wav"           ## 책장 넘김
const STAIRS := "res://assets/audio/stairs.wav"       ## 다음 층
const PICK := "res://assets/audio/pick.wav"           ## 고르기
## 배경음. vtos 의 `bgm1` 클립(3.2초 스테레오 루프)입니다.
const BGM := "res://assets/audio/bgm1.ogg"

## 배경음 크기. 효과음보다 확실히 낮아야 합니다 - 같은 크기로 깔면 고함이
## 배경에 묻혀서, 무엇이 신호이고 무엇이 분위기인지 구분되지 않습니다.
const MUSIC_DB := -14.0

## 동시에 낼 수 있는 소리 수.
## 소리가 넷에서 열셋으로 늘었습니다. 적 여럿이 한꺼번에 맞으면 피격음만
## 서너 개가 겹치므로, 그 위에 고함·발소리가 얹힐 자리를 남겨 둡니다.
const VOICES := 10

static var instance: Sfx

var _players: Array[AudioStreamPlayer] = []
## 배경음은 따로 둡니다. 효과음 재생기를 나눠 쓰면 배경음이 끊기거나
## 효과음이 배경음에 밀립니다.
var _music: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 소리는 끝까지
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = MUSIC_DB
	add_child(_music)


static func play_at(path: String, pitch: float, volume_db: float = 0.0) -> void:
	## **음높이를 정해서** 냅니다. 흔드는 것(pitch_spread)과 다릅니다 - 계단을
	## 올라가는 소리처럼 값이 정확해야 하는 자리에 씁니다(필살기 명령).
	if instance == null:
		return
	instance._play(path, volume_db, 0.0, pitch)


## 고함 소리의 길이(초). `shout_a1.wav` 를 재서 적은 값입니다.
##
## **모으는 시간이 이 길이입니다.** 소리가 끝나는 순간이 최대 범위라, 귀로
## 언제까지 눌러야 하는지 알 수 있습니다 - 화면의 부채꼴과 소리가 같은 것을
## 말합니다.
const SHOUT_LEN := 1.05


static func play_loose(path: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	## **끊을 수 있는 소리.** 재생기를 그대로 돌려주므로 부르는 쪽이 멈출 수
	## 있습니다.
	##
	## 보통 `play` 는 소리를 내고 잊습니다(끝나면 스스로 지웁니다). 고함은
	## 손을 떼는 순간 소리도 끊겨야 해서, 그 하나만 손잡이가 필요합니다.
	if instance == null:
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	instance.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


static func play(path: String, volume_db: float = 0.0,
		pitch_spread: float = 0.0) -> void:
	## 소리 하나를 냅니다. 파일이 없으면 조용히 넘어갑니다 - 소리가 없다고
	## 게임이 멈출 이유는 없습니다.
	if instance == null:
		return
	instance._play(path, volume_db, pitch_spread)


func _play(path: String, volume_db: float, pitch_spread: float,
		pitch: float = 1.0) -> void:
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		if not ResourceLoader.exists(path):
			return
		stream = load(path)
		if stream == null:
			return
		# 게임 소리는 반복 재생이 아닙니다. wav 가 루프로 들어오면 끝나지
		# 않고 계속 웁니다.
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_cache[path] = stream

	unlock()
	var voice := _free_voice()
	voice.stream = stream
	voice.volume_db = volume_db
	# 같은 소리가 연달아 나면 기계처럼 들립니다. 음높이를 조금씩 흔들면
	# 같은 파일이라도 매번 다른 소리로 들립니다.
	voice.pitch_scale = pitch + randf_range(-pitch_spread, pitch_spread)
	voice.play()


static func play_music(path: String = BGM) -> void:
	## 배경음을 겁니다. 이미 같은 것이 돌고 있으면 다시 시작하지 않습니다 -
	## 층이 바뀔 때마다 처음으로 되감기면 끊긴 것으로 들립니다.
	if instance == null or instance._music == null:
		return
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	# 짧은 조각이라 반드시 이어 붙여야 합니다. 원본에 반복 표시가 있어도
	# 들여올 때 꺼질 수 있어서 여기서 못 박습니다.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if instance._music.stream == stream and instance._music.playing:
		return
	instance._music.stream = stream
	unlock()
	instance._music.play()


static func stop_music() -> void:
	if instance != null and instance._music != null:
		instance._music.stop()


static func unlock() -> void:
	## 브라우저의 오디오를 엽니다.
	##
	## 브라우저는 사용자가 화면을 건드리기 전에는 소리를 내지 못하게 막습니다.
	## 엔진이 알아서 여는 길이 있지만 폰에서 안 열린 채로 남았습니다.
	##
	## **엔진 내부(GodotAudio)는 JavaScriptBridge 에서 안 보입니다.** 모듈
	## 안에 갇혀 있어서 폰에서 계속 "엔진없음" 이 떴습니다. 그래서 엔진에
	## 기대지 않고, 내보낸 HTML 머리에 심어 둔 스크립트가 AudioContext
	## 생성자를 감싸 **누가 만들든 참조를 붙잡아 둡니다**(export_presets.cfg).
	## 여기서는 그 참조를 깨우기만 합니다.
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.__r1_resume ? window.__r1_resume() : -1", true)


func _free_voice() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# 전부 울고 있으면 가장 오래된 것을 뺏습니다. 소리를 안 내는 것보다
	# 하나를 끊는 편이 낫습니다.
	return _players[0]
