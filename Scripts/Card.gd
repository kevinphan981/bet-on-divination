extends Node2D

signal hovered
signal hovered_off
signal tarot_activated(card)
signal card_selected(card)  # fired when a non-tarot card is clicked (used by remove_card power)

var position_in_hand
var card_data = {}
var is_face_down = false

func _ready() -> void:
	get_parent().connect_card_signals(self)
	print(get_tree().get_nodes_in_group(""))  # temp
	for child in get_children():
		print("Child: ", child.name, " | Type: ", child.get_class())


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)

# Called by InputManager on left click
func on_clicked() -> void:
	if card_data.get("is_tarot", false):
		await play_tarot_activation()
		emit_signal("tarot_activated", self)
	else:
		emit_signal("card_selected", self)


# ─────────────────────────────────────────────────────────────────────────────
# Tarot activation animation
#
# Three overlapping phases:
#   1. Gold shimmer    — sprite flashes gold then white-hot
#   2. Ripple ring     — expanding golden ring drawn with a Line2D
#   3. Ascend & fade   — card scales up, rotates slightly, then dissolves
# ─────────────────────────────────────────────────────────────────────────────
func play_tarot_activation() -> void:
	var sprite: Sprite2D = get_node("Sprite2D")

	# ── Phase 1: shimmer gold flash ──────────────────────────────────────────
	var shimmer = create_tween()
	shimmer.set_parallel(true)
	# Tint goes: normal → deep gold → white-hot
	shimmer.tween_property(sprite, "modulate",
		Color(1.6, 1.3, 0.2, 1.0), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shimmer.chain().tween_property(sprite, "modulate",
		Color(2.0, 1.8, 0.8, 1.0), 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Slight scale pop
	shimmer.tween_property(self, "scale",
		Vector2(1.18, 1.18), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await shimmer.finished

	# ── Phase 2: spawn three ripple rings ───────────────────────────────────
	_spawn_ripple_ring(0.0,  Color(1.0, 0.85, 0.1, 0.85), 1.0)   # bright gold
	_spawn_ripple_ring(0.08, Color(1.0, 0.55, 0.0, 0.60), 1.3)   # amber, slightly delayed
	_spawn_ripple_ring(0.18, Color(1.0, 1.0,  0.6, 0.40), 1.6)   # pale gold shimmer

	# ── Phase 3: ascend, spin, dissolve ─────────────────────────────────────
	var dissolve = create_tween()
	dissolve.set_parallel(true)
	dissolve.tween_property(self, "scale",
		Vector2(1.4, 1.4), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dissolve.tween_property(self, "rotation_degrees",
		12.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dissolve.tween_property(sprite, "modulate",
		Color(2.0, 1.8, 0.5, 0.0), 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dissolve.finished

	# Reset visual state so the card doesn't leave a ghost if something
	# goes wrong with queue_free() timing
	sprite.modulate = Color(1, 1, 1, 1)
	self.scale      = Vector2(1, 1)
	self.rotation_degrees = 0.0


# Spawns a single expanding ring that fades out.
# delay_sec lets you stagger multiple rings without awaiting each one.
func _spawn_ripple_ring(delay_sec: float, color: Color, scale_end: float) -> void:
	# Build the ring as a Line2D circle approximation
	var ring := Line2D.new()
	ring.default_color  = color
	ring.width          = 5.0
	ring.joint_mode     = Line2D.LINE_JOINT_ROUND
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode   = Line2D.LINE_CAP_ROUND
	ring.z_index        = 20

	# Circle made of 32 points
	const SEGMENTS := 32
	const RADIUS   := 70.0
	for i in range(SEGMENTS + 1):
		var angle := (float(i) / SEGMENTS) * TAU
		ring.add_point(Vector2(cos(angle), sin(angle)) * RADIUS)

	add_child(ring)
	ring.scale    = Vector2(0.4, 0.4)
	ring.modulate = Color(color.r, color.g, color.b, 0.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_interval(delay_sec)  # stagger start
	t.tween_property(ring, "scale",
		Vector2(scale_end, scale_end), 0.55)\
		.set_delay(delay_sec)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.9, 0.12)\
		.set_delay(delay_sec)\
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(ring, "modulate:a", 0.0, 0.42)\
		.set_delay(delay_sec + 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Clean up once done; use a one-shot timer so we don't block the caller
	get_tree().create_timer(delay_sec + 0.60).timeout.connect(ring.queue_free)


# ─────────────────────────────────────────────────────────────────────────────
# Card flip feature
# Uses "squish and reveal" tweens, then shows the face-up card.
# ─────────────────────────────────────────────────────────────────────────────
func flip_face_up() -> void:
	if not is_face_down:
		return

	var sprite = get_node("Sprite2D")
	var face_texture = load(card_data.texture_path)

	# Phase 1: squish to zero on x-axis (fold inward)
	var tween = create_tween()
	tween.tween_property(sprite, "scale:x", 0.0, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	# Swap at midpoint
	sprite.texture = face_texture
	is_face_down = false

	# Phase 2: expand back out
	var tween2 = create_tween()
	tween2.tween_property(sprite, "scale:x", .45, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween2.finished


# ─────────────────────────────────────────────────────────────────────────────
# Floating value pop (Balatro-style)
# Spawns a +n label that floats up and fades out above the card.
# ─────────────────────────────────────────────────────────────────────────────
func show_value_popup(value: int) -> void:
	if value <= 0:
		return  # don't show anything for tarot cards

	var label = Label.new()
	label.text    = "+%d" % value
	label.z_index = 10

	var font_size = 56
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color",         Color(1.0, 0.5, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	label.add_theme_constant_override("outline_size", 4)

	label.position = Vector2(-20, -80)
	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 2.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 2.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	label.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# Score breakdown popup (stand reveal style)
# popup_direction: -1 = above card (player), +1 = below card (dealer)
# ─────────────────────────────────────────────────────────────────────────────
func show_score_breakdown(value: int, running_total: int, delay: float = 0.0, popup_direction: int = -1) -> void:
	if value <= 0:
		return  # skip tarot cards

	await get_tree().create_timer(delay).timeout

	var sprite = get_node("Sprite2D")
	var card_half_height = sprite.texture.get_height() * sprite.scale.y * 0.5
	var base_y = card_half_height * popup_direction

	var value_label = Label.new()
	value_label.text = "+%d" % value
	value_label.z_index = 15
	value_label.add_theme_font_size_override("font_size", 52)
	value_label.add_theme_color_override("font_color",         Color(1.0, 0.85, 0.3))
	value_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	value_label.add_theme_constant_override("outline_size", 5)
	value_label.position = Vector2(-24, base_y)
	add_child(value_label)

	var float_distance = 55 * popup_direction

	var t1 = create_tween()
	t1.set_parallel(true)
	t1.tween_property(value_label, "position:y", value_label.position.y + float_distance, 2.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t1.tween_property(value_label, "modulate:a", 0.0, 2.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await t1.finished
	value_label.queue_free()
