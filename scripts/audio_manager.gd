extends Node
## 音频管理器（第十二课）：程序化生成占位音效与环境音，统一播放入口
## 用法：AudioManager.play_sfx("attack") / AudioManager.set_ambient("surface")
## 说明：首版不依赖外部素材，全部在运行时合成（与 player.gd 代码生成光照同理）；
##       P4「音乐音效统一与混音」阶段再替换为 CC0 素材，届时只需改 _build_stream()

const SAMPLE_RATE := 22050
const BUS := "Master"
const SFX_POOL_SIZE := 8  # 同时可播放的音效数，超过后循环复用，避免高频音效被截断

## 各类音效的额外音量补偿（dB）：重要反馈稍响、UI 点击稍轻
const SFX_VOLUME_DB := {
	"ui_click": -8.0,
	"ui_close": -8.0,
	"equip": -10.0,
	"gather": -8.0,
	"build": -6.0,
	"remove": -8.0,
	"craft": -6.0,
	"craft_fail": -8.0,
	"attack": -8.0,
	"hit": -6.0,
	"enemy_die": -6.0,
	"hurt": -6.0,
	"player_die": -4.0,
	"respawn": -8.0,
	"portal": -4.0,
	"puzzle_press": -6.0,
	"door_open": -8.0,
	"pipe_toggle": -6.0,
	"pickup": -6.0,
	"save": -8.0,
	"load": -8.0,
}

const AMBIENT_VOLUME_DB := {
	"surface": -16.0,
	"underworld": -14.0,
}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambient: AudioStreamPlayer = null
var _ambient_id := ""
var _stream_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停菜单里也要能播放 UI 音效
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Ambient"
	_ambient.bus = BUS
	_ambient.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambient)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)


## 播放一次性音效；连续触发时循环使用播放池，后一个会顶掉前一个
func play_sfx(id: String) -> void:
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = _get_stream(id)
	player.volume_db = SFX_VOLUME_DB.get(id, -6.0)
	player.play()


## 切换环境音循环：surface=地表风声 / underworld=地心低鸣；空字符串=停止
func set_ambient(id: String) -> void:
	if _ambient_id == id:
		return
	_ambient_id = id
	if id.is_empty():
		_ambient.stop()
		return
	_ambient.stream = _get_stream(id)
	_ambient.volume_db = AMBIENT_VOLUME_DB.get(id, -16.0)
	_ambient.play()


func stop_ambient() -> void:
	set_ambient("")


## 按 id 生成（并缓存）音频流：音效是一次性波形，环境音做成无缝循环
func _get_stream(id: String) -> AudioStreamWAV:
	if _stream_cache.has(id):
		return _stream_cache[id]
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var data: PackedFloat32Array = _build_stream(id)
	wav.data = _to_pcm16(data)
	if id.begins_with("ambient_"):
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size()  # loop 按样本数计（16bit 单声道一个样本 = 2 字节）
	_stream_cache[id] = wav
	return wav


## 各音效的合成配方；想替换成真实素材时改这里即可
func _build_stream(id: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(id)  # 固定种子：同一音效每次生成完全一致
	match id:
		"ui_click": return _concat([_tone(rng, 920.0, 0.05, 0.30, 0.10)])
		"ui_close": return _concat([_tone(rng, 620.0, 0.05, 0.28, 0.10)])
		"equip": return _concat([_tone(rng, 760.0, 0.05, 0.25, 0.05)])
		"gather": return _concat([_sweep(rng, 340.0, 190.0, 0.09, 0.32, 0.45), _noise(rng, 0.06, 0.25)])
		"build": return _concat([_tone(rng, 150.0, 0.12, 0.45, 0.25), _noise(rng, 0.04, 0.20)])
		"remove": return _concat([_tone(rng, 110.0, 0.10, 0.40, 0.20)])
		"craft": return _concat([_tone(rng, 523.0, 0.09, 0.26, 0.0), _tone(rng, 784.0, 0.13, 0.26, 0.0)])
		"craft_fail": return _concat([_tone(rng, 160.0, 0.16, 0.30, 0.30)])
		"attack": return _sweep(rng, 520.0, 170.0, 0.15, 0.30, 0.55)
		"hit": return _concat([_tone(rng, 230.0, 0.08, 0.36, 0.25), _noise(rng, 0.05, 0.22)])
		"enemy_die": return _sweep(rng, 330.0, 70.0, 0.30, 0.38, 0.35)
		"hurt": return _sweep(rng, 430.0, 150.0, 0.16, 0.34, 0.40)
		"player_die": return _sweep(rng, 240.0, 55.0, 0.85, 0.38, 0.25)
		"respawn": return _sweep(rng, 180.0, 430.0, 0.45, 0.20, 0.10)
		"portal": return _concat([_noise(rng, 0.50, 0.32), _sweep(rng, 420.0, 1500.0, 0.50, 0.20, 0.15)])
		"puzzle_press": return _concat([_tone(rng, 520.0, 0.05, 0.32, 0.05), _tone(rng, 140.0, 0.09, 0.28, 0.10)])
		"door_open": return _concat([_sweep(rng, 95.0, 68.0, 0.38, 0.26, 0.40), _noise(rng, 0.10, 0.14)])
		"pipe_toggle": return _concat([_tone(rng, 700.0, 0.04, 0.28, 0.05), _tone(rng, 420.0, 0.06, 0.24, 0.05)])
		"pickup": return _concat([_tone(rng, 660.0, 0.06, 0.24, 0.0), _tone(rng, 990.0, 0.10, 0.24, 0.0)])
		"save": return _concat([_tone(rng, 880.0, 0.06, 0.22, 0.0), _tone(rng, 1320.0, 0.09, 0.22, 0.0)])
		"load": return _concat([_tone(rng, 660.0, 0.06, 0.22, 0.0), _tone(rng, 990.0, 0.09, 0.22, 0.0)])
		"ambient_surface": return _ambient_loop(rng, 8.0, 0.12, 55.0, 0.03, 0.0)
		"ambient_underworld": return _ambient_loop(rng, 8.0, 0.14, 48.0, 0.045, 0.45)
		_:
			return _noise(rng, 0.05, 0.10)  # 未注册的 id 给个静默兜底


## 单音：频率可滑向 freq_end（0 表示不变），noise_ratio 混入噪声，指数衰减避免爆音
func _tone(rng: RandomNumberGenerator, freq: float, duration: float, volume: float, noise_ratio: float, freq_end: float = 0.0) -> PackedFloat32Array:
	var n := maxi(1, int(duration * SAMPLE_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var end_freq := freq if freq_end <= 0.0 else freq_end
	for i in n:
		var t := float(i) / n
		var env := exp(-4.0 * t) * (1.0 - t)
		phase += TAU * lerpf(freq, end_freq, t) / SAMPLE_RATE
		var s := sin(phase) * (1.0 - noise_ratio) + (rng.randf() * 2.0 - 1.0) * noise_ratio
		out[i] = s * env * volume
	return out


## 噪声爆音：指数衰减的随机噪声，用于打击、风声等
func _noise(rng: RandomNumberGenerator, duration: float, volume: float) -> PackedFloat32Array:
	var n := maxi(1, int(duration * SAMPLE_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / n
		var env := exp(-4.0 * t) * (1.0 - t)
		out[i] = (rng.randf() * 2.0 - 1.0) * env * volume
	return out


## 频率滑音（whoosh）：正弦从 f1 滑到 f2，混入噪声
func _sweep(rng: RandomNumberGenerator, f1: float, f2: float, duration: float, volume: float, noise_ratio: float) -> PackedFloat32Array:
	var n := maxi(1, int(duration * SAMPLE_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var env := exp(-3.0 * t) * (1.0 - t)
		phase += TAU * lerpf(f1, f2, t) / SAMPLE_RATE
		var s := sin(phase) * (1.0 - noise_ratio) + (rng.randf() * 2.0 - 1.0) * noise_ratio
		out[i] = s * env * volume
	return out


## 拼接多段波形（如"两段上行音符"的合成音）
func _concat(parts: Array) -> PackedFloat32Array:
	var total := 0
	for p in parts:
		total += (p as PackedFloat32Array).size()
	var out := PackedFloat32Array()
	out.resize(total)
	var at := 0
	for p in parts:
		var arr := p as PackedFloat32Array
		for i in arr.size():
			out[at + i] = arr[i]
		at += arr.size()
	return out


## 环境音循环：布朗噪声（低频风声/地鸣）+ 可选次低音脉冲（心跳感）
## 首尾交叉淡化，保证循环衔接处不爆音
func _ambient_loop(rng: RandomNumberGenerator, duration: float, noise_vol: float, bass_freq: float, bass_vol: float, pulse_rate: float) -> PackedFloat32Array:
	var n := int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		brown = clampf(brown + (rng.randf() * 2.0 - 1.0) * 0.08, -1.0, 1.0)
		var s := brown * noise_vol
		if bass_freq > 0.0:
			phase += TAU * bass_freq / SAMPLE_RATE
			var pulse := 1.0 if pulse_rate <= 0.0 else 0.55 + 0.45 * sin(TAU * pulse_rate * t)
			s += sin(phase) * bass_vol * pulse
		out[i] = clampf(s, -1.0, 1.0)
	# 首尾交叉淡化：循环处音量连续，听不出接缝
	var fade := mini(n, int(0.15 * SAMPLE_RATE))
	for i in fade:
		var k := float(i) / fade
		out[n - fade + i] = lerpf(out[n - fade + i], out[i], k)
	return out


## float 样本数组 → 16bit PCM 字节
func _to_pcm16(data: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		var v := int(clampf(data[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	return bytes


## 简单字符串哈希：同一 id 得到同一随机种子，音效每次生成一致
func _hash(s: String) -> int:
	var h := 0
	for b in s.to_ascii_buffer():
		h = (h * 31 + b) & 0x7FFFFFFF
	return h
