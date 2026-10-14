extends Node3D
class_name SpriteMotion

var sprite: AnimatedSprite3D
var current_state := "idle"
var frozen := false
var profile: Dictionary = {}
var _attack_move := ""
var _attack_elapsed := 0.0
var _attack_duration := 0.0
var _base_position := Vector3.ZERO
var _base_scale := Vector3.ONE
var _facing := 1.0

func bind(animated_sprite: AnimatedSprite3D, animation_profile: Dictionary = {}) -> void:
	sprite = animated_sprite
	profile = animation_profile.duplicate(true)
	_base_position = sprite.position
	_base_scale = sprite.scale


func start_attack(move_id: String, duration: float) -> void:
	if not profile.get("moves", {}).has(move_id): return
	_attack_move = move_id
	_attack_elapsed = 0.0
	_attack_duration = maxf(duration, 0.001)


func clear_attack() -> void:
	_attack_move = ""
	_attack_elapsed = 0.0
	_attack_duration = 0.0
	_restore_base_transform()


func _process(delta: float) -> void:
	if frozen or sprite == null or _attack_move.is_empty(): return
	_attack_elapsed = minf(_attack_duration, _attack_elapsed + maxf(delta, 0.0))
	var amount: Dictionary = profile.moves[_attack_move]
	var phase := clampf(_attack_elapsed / _attack_duration, 0.0, 1.0)
	var strike := sin(PI * phase)
	var extension := sin(PI * minf(phase / 0.68, 1.0))
	var recoil_phase := clampf((phase - 0.62) / 0.38, 0.0, 1.0)
	var recoil := sin(PI * recoil_phase)
	sprite.position = _base_position + Vector3(_facing * (float(amount.drive) * extension - float(amount.recoil) * recoil), float(amount.lift) * strike, 0.0)
	sprite.rotation.z = deg_to_rad(float(amount.tilt_deg)) * strike * _facing
	sprite.scale = Vector3(_base_scale.x * (1.0 + float(amount.squash) * strike), _base_scale.y * (1.0 - float(amount.squash) * 0.5 * strike), _base_scale.z)
	if _attack_elapsed >= _attack_duration: clear_attack()


func _restore_base_transform() -> void:
	if sprite == null: return
	sprite.position = _base_position
	sprite.rotation.z = 0.0
	sprite.scale = _base_scale

func play_state(state: String, restart: bool = false, target_duration: float = 0.0) -> void:
	if sprite == null or not sprite.sprite_frames.has_animation(state): return
	if restart or current_state != state:
		sprite.play(state)
		current_state = state
	if target_duration > 0.0:
		var count := maxi(1, sprite.sprite_frames.get_frame_count(state))
		var source_duration := count / maxf(0.1, sprite.sprite_frames.get_animation_speed(state))
		sprite.speed_scale = clampf(source_duration / target_duration, 0.35, 3.5)
	else: sprite.speed_scale = 1.0
	if frozen: sprite.pause()

func set_facing(direction: float) -> void:
	_facing = -1.0 if direction < 0.0 else 1.0
	if sprite != null: sprite.flip_h = direction < 0.0

func freeze_motion(value: bool) -> void:
	frozen = value
	if sprite == null: return
	if frozen: sprite.pause()
	else: sprite.play()
