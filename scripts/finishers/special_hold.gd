extends RefCounted

var active := false
var elapsed := 0.0
var threshold := 0.55

func update(delta: float, pressed: bool, released: bool, eligible: bool) -> String:
	if active and not eligible:
		cancel()
		return "none"
	if pressed:
		cancel()
		if not eligible:
			return "special"
		active = true
	if not active:
		return "none"
	if not pressed:
		elapsed += maxf(delta, 0.0)
	if elapsed >= threshold:
		cancel()
		return "finisher"
	if released:
		cancel()
		return "special"
	return "none"

func cancel() -> void:
	active = false
	elapsed = 0.0
