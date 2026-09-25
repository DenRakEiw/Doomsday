class_name ColourAudit
extends RefCounted
## The colour floor of spec polish-visuals.md §8.3, re-implemented for the test
## suite: CIEDE2000 between two sRGB colours, for normal vision and the three
## simulated dichromacies of Machado, Oliveira and Fernandes (2009) at severity
## 1.0. The D6.1 audit script was a throwaway; this is its lasting form.

## Machado 2009, severity 1.0, applied to linear RGB. Rows of a 3 × 3 matrix.
const PROTAN: Array[Vector3] = [
	Vector3(0.152286, 1.052583, -0.204868),
	Vector3(0.114503, 0.786281, 0.099216),
	Vector3(-0.003882, -0.048116, 1.051998),
]
const DEUTAN: Array[Vector3] = [
	Vector3(0.367322, 0.860646, -0.227968),
	Vector3(0.280085, 0.672501, 0.047413),
	Vector3(-0.011820, 0.042940, 0.968881),
]
const TRITAN: Array[Vector3] = [
	Vector3(1.255528, -0.076749, -0.178779),
	Vector3(-0.078411, 0.930809, 0.147602),
	Vector3(0.004733, 0.691367, 0.303900),
]

## The D65 white point of CIE XYZ, for the Lab conversion.
const WHITE: Vector3 = Vector3(0.95047, 1.0, 1.08883)


## The smallest CIEDE2000 of the pair over normal vision and the three
## dichromacies — the number §8.3's floor is set on.
static func worst_delta_e(a: Color, b: Color) -> float:
	var worst: float = delta_e(_lab(_linear(a)), _lab(_linear(b)))
	for matrix: Array[Vector3] in [PROTAN, DEUTAN, TRITAN]:
		worst = minf(worst, delta_e(_lab(_simulate(_linear(a), matrix)),
			_lab(_simulate(_linear(b), matrix))))
	return worst


## WCAG 2.2 contrast ratio of two sRGB colours.
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(_linear(a))
	var lb: float = _luminance(_linear(b))
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## CIEDE2000 (Sharma, Wu and Dalal 2005) between two CIELAB colours.
static func delta_e(lab1: Vector3, lab2: Vector3) -> float:
	var l1: float = lab1.x
	var a1: float = lab1.y
	var b1: float = lab1.z
	var l2: float = lab2.x
	var a2: float = lab2.y
	var b2: float = lab2.z
	var c1: float = sqrt(a1 * a1 + b1 * b1)
	var c2: float = sqrt(a2 * a2 + b2 * b2)
	var c_mean: float = (c1 + c2) / 2.0
	var c_mean7: float = pow(c_mean, 7.0)
	var g: float = 0.5 * (1.0 - sqrt(c_mean7 / (c_mean7 + pow(25.0, 7.0))))
	var a1p: float = (1.0 + g) * a1
	var a2p: float = (1.0 + g) * a2
	var c1p: float = sqrt(a1p * a1p + b1 * b1)
	var c2p: float = sqrt(a2p * a2p + b2 * b2)
	var h1p: float = _hue(b1, a1p)
	var h2p: float = _hue(b2, a2p)

	var dl: float = l2 - l1
	var dc: float = c2p - c1p
	var dh: float = 0.0
	if c1p * c2p != 0.0:
		dh = h2p - h1p
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
	var dh_big: float = 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh / 2.0))

	var l_mean: float = (l1 + l2) / 2.0
	var cp_mean: float = (c1p + c2p) / 2.0
	var hp_mean: float = h1p + h2p
	if c1p * c2p != 0.0:
		if absf(h1p - h2p) <= 180.0:
			hp_mean = (h1p + h2p) / 2.0
		elif h1p + h2p < 360.0:
			hp_mean = (h1p + h2p + 360.0) / 2.0
		else:
			hp_mean = (h1p + h2p - 360.0) / 2.0
	var t: float = 1.0 - 0.17 * cos(deg_to_rad(hp_mean - 30.0)) \
		+ 0.24 * cos(deg_to_rad(2.0 * hp_mean)) \
		+ 0.32 * cos(deg_to_rad(3.0 * hp_mean + 6.0)) \
		- 0.20 * cos(deg_to_rad(4.0 * hp_mean - 63.0))
	var d_theta: float = 30.0 * exp(-pow((hp_mean - 275.0) / 25.0, 2.0))
	var cp_mean7: float = pow(cp_mean, 7.0)
	var rc: float = 2.0 * sqrt(cp_mean7 / (cp_mean7 + pow(25.0, 7.0)))
	var l50: float = (l_mean - 50.0) * (l_mean - 50.0)
	var sl: float = 1.0 + 0.015 * l50 / sqrt(20.0 + l50)
	var sc: float = 1.0 + 0.045 * cp_mean
	var sh: float = 1.0 + 0.015 * cp_mean * t
	var rt: float = -sin(deg_to_rad(2.0 * d_theta)) * rc
	var tl: float = dl / sl
	var tc: float = dc / sc
	var th: float = dh_big / sh
	return sqrt(tl * tl + tc * tc + th * th + rt * tc * th)


static func _hue(b: float, a: float) -> float:
	if a == 0.0 and b == 0.0:
		return 0.0
	var h: float = rad_to_deg(atan2(b, a))
	return h + 360.0 if h < 0.0 else h


## sRGB (display values) to linear RGB.
static func _linear(c: Color) -> Vector3:
	return Vector3(_channel(c.r), _channel(c.g), _channel(c.b))


static func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _simulate(rgb: Vector3, matrix: Array[Vector3]) -> Vector3:
	return Vector3(
		clampf(matrix[0].dot(rgb), 0.0, 1.0),
		clampf(matrix[1].dot(rgb), 0.0, 1.0),
		clampf(matrix[2].dot(rgb), 0.0, 1.0))


static func _luminance(rgb: Vector3) -> float:
	return 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z


## Linear sRGB (D65) to CIELAB.
static func _lab(rgb: Vector3) -> Vector3:
	var x: float = 0.4124564 * rgb.x + 0.3575761 * rgb.y + 0.1804375 * rgb.z
	var y: float = 0.2126729 * rgb.x + 0.7151522 * rgb.y + 0.0721750 * rgb.z
	var z: float = 0.0193339 * rgb.x + 0.1191920 * rgb.y + 0.9503041 * rgb.z
	var fx: float = _lab_f(x / WHITE.x)
	var fy: float = _lab_f(y / WHITE.y)
	var fz: float = _lab_f(z / WHITE.z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lab_f(t: float) -> float:
	const EPSILON: float = 216.0 / 24389.0
	const KAPPA: float = 24389.0 / 27.0
	return pow(t, 1.0 / 3.0) if t > EPSILON else (KAPPA * t + 16.0) / 116.0
