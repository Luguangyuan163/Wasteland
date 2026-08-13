class_name SimpleNoise
## 简易2D值噪声工具 —— 用于地图群系生成
## 不需要 Perlin/Simplex 外部库，纯 GDScript 实现
##
## 为什么自己写而不引入噪声库：
## 1. 30 行代码就能实现自然连续的地形噪声，理解成本低
## 2. 不依赖外部插件，导出 Windows 不会漏文件
## 3. 确定性：同一 (x, y, seed) 永远返回同一值 —— 存档/读档一致
##
## 算法流程（参照《我的世界》地形生成核心思想）：
## 1. 把地图按 GRID 间距划分成整数格点
## 2. 每个格点用哈希函数映射到 0~1 的随机值（种子驱动，确定性）
## 3. 对任意坐标，取包围它的 4 个格点值，用 smoothstep 做双线性插值
## 4. FBM = 多层噪声叠加（频率加倍、振幅减半），产生自然的地形纹理

const GRID := 20  ## 格点间距（像素）。值越大 → 群系块越大、边界越平滑


## 整数哈希 → 0~1 浮点数（种子驱动，确定性）
## 使用经典混合哈希：乘质数 → 异或移位 → 再乘大质数
static func _hash(x: int, y: int, seed_value: int) -> float:
	var h := (x * 1619 + y * 31337 + seed_value * 7703) & 0x7fffffff
	h = (h >> 13) ^ h
	h = (h * (h * h * 60493 + 19990303) + 1376312589) & 0x7fffffff
	return float(h) / 2147483647.0


## smoothstep 缓动函数：让格点之间平滑过渡，没有硬边界
static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## 单层值噪声（Value Noise）
## 返回 0~1 的连续值，相邻坐标的值不会突变
static func value_noise(x: float, y: float, seed_value: int) -> float:
	# 找到包围 (x, y) 的 4 个格点
	var gx := floori(x / GRID)
	var gy := floori(y / GRID)
	# 计算在格点单元内的位置（0~1），smoothstep 保证边界平滑
	var fx := _smooth((x - gx * GRID) / float(GRID))
	var fy := _smooth((y - gy * GRID) / float(GRID))
	# 4 个角点的哈希值
	var a := _hash(gx,     gy,     seed_value)
	var b := _hash(gx + 1, gy,     seed_value)
	var c := _hash(gx,     gy + 1, seed_value)
	var d := _hash(gx + 1, gy + 1, seed_value)
	# 双线性插值
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## FBM 多层噪声叠加（Fractal Brownian Motion）
## 多层 octave 叠加：频率逐层加倍、振幅逐层减半
## 产生自然界常见的"大块套小块 纹理 —— MC 的地形高度图就是这么做出来的
## octaves=3 够用于群系划分（更多 octave 会让边界更碎）
static func fbm_noise(x: float, y: float, seed_value: int, octaves: int = 3) -> float:
	var value := 0.0
	var amp := 1.0     # 当前层的振幅
	var freq := 1.0    # 当前层的频率
	var total := 0.0   # 振幅总和（用于归一化）
	for i in octaves:
		value += value_noise(x * freq, y * freq, seed_value + i * 1000) * amp
		total += amp
		amp *= 0.5   # 振幅减半：高频细节贡献越来越小
		freq *= 2.0   # 频率加倍：每层细节越来越密
	return value / total
