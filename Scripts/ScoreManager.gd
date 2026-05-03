extends Node

@onready var game_manager_reference = $"../GameManager"

# more or less moving a bunch of things, with new references

#var deck_reference
#var player_hand_reference
#var result_label
#var player_score_label
#var dealer_score_label
#var hit_button
#var stand_button

func _ready() -> void:
	print("ScoreManager ready, PlayerHand: ", $"../PlayerHand")

@onready var deck_reference = $"../Deck"
@onready var player_hand_reference = $"../PlayerHand"
@onready var result_label = $"../CanvasLayer/MainUI/ResultLabel"
@onready var player_score_label = $"../CanvasLayer/MainUI/ScoreContainer/PlayerScoreLabel"
@onready var dealer_score_label = $"../CanvasLayer/MainUI/ScoreContainer/DealerScoreLabel"
@onready var hit_button = $"../CanvasLayer/MainUI/GameplayPanel/GameButtons/HitButton"
@onready var stand_button = $"../CanvasLayer/MainUI/GameplayPanel/GameButtons/StandButton"

var player_display : int = 0
var dealer_display : int = 0
# Tracks whether we've already fired the 21 animation this round
# so it only plays once per hand, not on every subsequent score update.
# Prevents the animation firing more than once per hand
var _player_21_celebrated := false
var _dealer_21_celebrated := false
 
# Holds the active orbiting node so it can be killed on reset
var _player_orbit_node: Node = null
var _dealer_orbit_node:  Node = null
 
# Rune/glyph pool — mix of Elder Futhark, alchemical, and arcane unicode
const GLYPHS := [
	"ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ",
	"ᛁ", "ᛃ", "ᛇ", "ᛈ", "ᛉ", "ᛊ", "ᛏ", "ᛟ",
	"☽", "☾", "⊕", "✦", "⟁", "⌖", "⍟", "⎊",
]


func determine_winner():
	var player_score = calculate_score(player_hand_reference.hand)
	var dealer_score = calculate_score(deck_reference.dealer_hand)
	
	# When inverted, lower raw score wins — so flip the comparison values.
	# Dealer bust still counts as a player win regardless of inversion.
	var p_cmp = (21 - player_score) if game_manager_reference.inverted_scoring else player_score
	var d_cmp = (21 - dealer_score) if game_manager_reference.inverted_scoring else dealer_score

	if dealer_score > 21:
		_highlight_winner("player")
		game_manager_reference.end_round("player_wins")
	elif p_cmp > d_cmp:
		_highlight_winner("player")
		game_manager_reference.end_round("player_wins")
	elif d_cmp > p_cmp:
		_highlight_winner("dealer")
		game_manager_reference.end_round("dealer_wins")
	else:
		_highlight_winner("push")
		game_manager_reference.end_round("push")

		
	reset_score_colors()
 
func _highlight_winner(winner: String) -> void:
	match winner:
		"player":
			_tint_hand(player_hand_reference.hand, Color(0.3, 1.0, 0.45))
		"dealer":
			_tint_hand(deck_reference.dealer_hand, Color(0.3, 1.0, 0.45))
		"push":
			_tint_hand(player_hand_reference.hand, Color(0.9, 0.75, 0.3))
			_tint_hand(deck_reference.dealer_hand, Color(0.9, 0.75, 0.3))
 
 
# Pulses each card sprite in the hand to the target color with a staggered fade-in.
func _tint_hand(hand: Array, color: Color) -> void:
	for i in range(hand.size()):
		var card: Node2D = hand[i]
		var sprite: Sprite2D = card.get_node("Sprite2D")
		var delay := i * 0.03
		var t: Tween = sprite.create_tween()
		t.set_parallel(true)
		# Flash bright first then settle on the tint color
		t.tween_property(sprite, "modulate", Color(color.r * 1.6, color.g * 1.6, color.b * 1.6), 0.12)\
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "modulate", color, 0.25)\
			.set_delay(delay + 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 
 
func reset_score_colors() -> void:
	player_score_label.modulate = Color(1, 1, 1, 1)
	dealer_score_label.modulate = Color(1, 1, 1, 1)
	_player_21_celebrated = false
	_dealer_21_celebrated = false
	# Kill any still-running orbit nodes from a previous round
	if is_instance_valid(_player_orbit_node):
		_player_orbit_node.queue_free()
	if is_instance_valid(_dealer_orbit_node):
		_dealer_orbit_node.queue_free()
	_player_orbit_node = null
	_dealer_orbit_node  = null
	
func calculate_score(hand: Array) -> int:
	var score = 0
	var aces = 0
		
	for card in hand:
		if card.is_face_down:
			continue
		score += card.card_data.value
		if card.card_data["name"] == "Ace":
			aces += 1
	
	#downgrade aces from 11 to 1 if busting
	while score > 21 and aces > 0:
		score -= 10
		aces -= 1
	
	#returns final score
	return score

'''
	check_bust()
	-literally checks for a bust

	utilizes the end_game() method which actually outputs the message
'''

func check_bust():
	var player_score = calculate_score(player_hand_reference.hand)
	if player_score > 21:
		print("Player Bust")
		game_manager_reference.end_round("dealer_wins")
		
		
# ---------------------------------------------------------------------------
# Helper: force the dealer's hand score above 21 by adding high-value cards.
# Directly manipulates the dealer hand; adjust field names to match your Deck.
# ---------------------------------------------------------------------------
func _force_dealer_bust():
	# Keep drawing until the dealer hand is over 21.
	# We cap at 5 iterations to avoid an infinite loop if scoring breaks.
	var max_attempts := 5
	var attempts := 0
	while calculate_score(deck_reference.dealer_hand) <= 21 and attempts < max_attempts:
		deck_reference.draw_card_to_dealer(false)
		determine_winner()
		print("dealer_bust: dealer score is now ", calculate_score(deck_reference.dealer_hand))
		attempts += 1

#---------------------------------------------------
# update_score_display()
# updates the score, will change when someone hits 21
#---------------------------------------------------

func update_score_display():
	print("--- update_score_display called ---")
	var player_score = calculate_score(player_hand_reference.hand)
	var dealer_score = calculate_score(deck_reference.dealer_hand)
	player_score_label.text = "Player: %d" % player_score
	dealer_score_label.text = "Dealer: %d" % dealer_score
	
	var inverted: bool = game_manager_reference.inverted_scoring

	# ── Display values — when inverted, show 21-score so player sees
	#    what they're actually competing on (lower raw = higher inverted)
	player_display = (21 - player_score) if inverted else player_score
	dealer_display = (21 - dealer_score) if inverted else dealer_score
 

	if inverted:
		player_score_label.text = "Player: ~%d" % player_display
		dealer_score_label.text = "Dealer: ~%d" % dealer_display
		# Tint both labels a sickly moon-purple to signal the inversion
		player_score_label.modulate = Color(0.85, 0.5, 1.0)
		dealer_score_label.modulate = Color(0.85, 0.5, 1.0)
	else:
		player_score_label.text = "Player: %d" % player_score
		dealer_score_label.text = "Dealer: %d" % dealer_score
	if player_score == 21 and not _player_21_celebrated:
		_player_21_celebrated = true
		_play_21_mystical(player_score_label, true)
 
	if dealer_score == 21 and not _dealer_21_celebrated:
		_dealer_21_celebrated = true
		_play_21_mystical(dealer_score_label, false)
 
 
# =============================================================================
#  _play_21_mystical
#
#  Four simultaneous effects, all parented to `label` so they follow it:
#
#  1. Label flash      — text pulses gold briefly
#  2. Sigil ring       — a rotating heptagram that fades out over ~2s
#  3. Orbiting runes   — 6 glyphs orbit at increasing radii, drifting outward
#  4. Inscribing arc   — a Line2D circle that draws itself around the label
#
#  is_player sets the accent color so player (teal) and dealer (amber) differ.
# =============================================================================
func _play_21_mystical(label: Label, is_player: bool) -> void:
	var accent  := Color(0.35, 1.0,  0.9)  if is_player else Color(1.0, 0.6,  0.15)
	var accent2 := Color(0.1,  0.8,  0.6)  if is_player else Color(0.9, 0.35, 0.05)
	const GOLD  := Color(1.0, 0.88, 0.25)
 
	# ── 1. Label flash ────────────────────────────────────────────────────
	var flash := label.create_tween()
	flash.tween_property(label, "modulate", GOLD,                0.10).set_trans(Tween.TRANS_SINE)
	flash.tween_property(label, "modulate", Color(1.8, 1.6, 0.6), 0.08)
	flash.tween_property(label, "modulate", accent,              0.25).set_trans(Tween.TRANS_SINE)
 
	# ── 2. Sigil ring ─────────────────────────────────────────────────────
	_spawn_sigil_ring(label, accent, accent2)
 
	# ── 3. Orbiting runes ─────────────────────────────────────────────────
	var chosen: Array = GLYPHS.duplicate()
	chosen.shuffle()
	const RUNE_COUNT := 6
	for i in range(RUNE_COUNT):
		var angle_offset := (TAU / RUNE_COUNT) * i
		var base_radius  := randf_range(52.0, 72.0)
		var glyph        : String = chosen[i % chosen.size()]
		var orbit_speed  := randf_range(0.9, 1.6) * (1.0 if i % 2 == 0 else -1.0)
		var drift        := randf_range(28.0, 55.0)
		var delay        := i * 0.07
		var color        := accent if i % 2 == 0 else GOLD
		_spawn_orbiting_rune(label, glyph, angle_offset, base_radius,
							 orbit_speed, drift, color, delay)
 
	# ── 4. Self-inscribing arc ────────────────────────────────────────────
	_spawn_inscribing_arc(label, accent2)
 
 
# -----------------------------------------------------------------------------
# Rotating heptagram (7-point polygon + inner star) that fades out over ~2.5s
# -----------------------------------------------------------------------------
func _spawn_sigil_ring(anchor: Label, color_a: Color, color_b: Color) -> void:
	const POINTS  := 7
	const RADIUS  := 48.0
 
	# Outer heptagon ring
	var ring := Line2D.new()
	ring.default_color  = color_a
	ring.width          = 1.8
	ring.joint_mode     = Line2D.LINE_JOINT_ROUND
	ring.z_index        = 25
	for i in range(POINTS + 1):
		var a := (float(i) / POINTS) * TAU
		ring.add_point(Vector2(cos(a), sin(a)) * RADIUS)
	anchor.add_child(ring)
 
	# Inner heptagram (skip-3 gives a {7/3} star polygon)
	var star := Line2D.new()
	star.default_color = color_b
	star.width         = 1.2
	star.z_index       = 25
	var idx := 0
	for _i in range(POINTS + 1):
		var a := (float(idx) / POINTS) * TAU
		star.add_point(Vector2(cos(a), sin(a)) * (RADIUS * 0.62))
		idx = (idx + 3) % POINTS
	anchor.add_child(star)
 
	# Fade in then out — unrolled so GDScript can type each call correctly
	var t_ring: Tween = ring.create_tween()
	t_ring.set_parallel(true)
	t_ring.tween_property(ring, "modulate:a", 0.0,  0.0)
	t_ring.tween_property(ring, "modulate:a", 0.85, 0.20)
	t_ring.tween_property(ring, "modulate:a", 0.0,  1.80).set_delay(0.8)
	var t_star: Tween = star.create_tween()
	t_star.set_parallel(true)
	t_star.tween_property(star, "modulate:a", 0.0,  0.0)
	t_star.tween_property(star, "modulate:a", 0.85, 0.20)
	t_star.tween_property(star, "modulate:a", 0.0,  1.80).set_delay(0.8)
 
	# Continuous rotation via a linear tween over the full lifetime
	_attach_rotator(ring,  0.6,  2.5)
	_attach_rotator(star, -0.9,  2.5)
 
	anchor.get_tree().create_timer(2.6).timeout.connect(ring.queue_free)
	anchor.get_tree().create_timer(2.6).timeout.connect(star.queue_free)
 
 
func _attach_rotator(node: Node2D, rad_per_sec: float, duration: float) -> void:
	var t := node.create_tween()
	t.tween_property(node, "rotation_degrees",
		node.rotation_degrees + rad_to_deg(rad_per_sec) * duration, duration)\
		.set_trans(Tween.TRANS_LINEAR)
 
 
# -----------------------------------------------------------------------------
# One rune label that orbits anchor, drifts outward, then fades.
# Driven each frame by an inner-class _process node (tweens can't do circles).
# -----------------------------------------------------------------------------
func _spawn_orbiting_rune(
		anchor:      Label,
		glyph:       String,
		start_angle: float,
		base_radius: float,
		orbit_speed: float,
		drift:       float,
		color:       Color,
		delay:       float) -> void:
 
	var rune := Label.new()
	rune.text = glyph
	rune.z_index = 28
	rune.add_theme_font_size_override("font_size", int(randf_range(13.0, 22.0)))
	rune.add_theme_color_override("font_color",         color)
	rune.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.1, 0.8))
	rune.add_theme_constant_override("outline_size", 2)
	rune.modulate.a = 0.0
	anchor.add_child(rune)
 
	var driver := _RuneOrbitDriver.new()
	driver.setup(rune, start_angle, base_radius, orbit_speed * TAU, drift, delay)
	anchor.add_child(driver)
 
 
# -----------------------------------------------------------------------------
# Line2D arc that draws itself incrementally — like a ritual circle being
# traced from a single point all the way around.
# -----------------------------------------------------------------------------
func _spawn_inscribing_arc(anchor: Label, color: Color) -> void:
	const RADIUS   := 62.0
	const SEGMENTS := 64
	const DURATION := 1.1
	const LINGER   := 0.5
 
	var arc := Line2D.new()
	arc.default_color  = color
	arc.width          = 2.2
	arc.joint_mode     = Line2D.LINE_JOINT_ROUND
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode   = Line2D.LINE_CAP_ROUND
	arc.z_index        = 22
	arc.modulate.a     = 0.0
	anchor.add_child(arc)
 
	var driver := _ArcInscribeDriver.new()
	driver.setup(arc, RADIUS, SEGMENTS, DURATION, LINGER)
	anchor.add_child(driver)
 
 
# =============================================================================
#  Inner driver classes — attached as child nodes so _process runs automatically
# =============================================================================
 
class _RuneOrbitDriver extends Node:
	var rune:        Label
	var angle:       float
	var base_radius: float
	var speed:       float   # rad/sec
	var drift:       float   # total outward px over lifetime
	var delay:       float
	const LIFETIME := 2.8
	var elapsed := 0.0
 
	func setup(r, a, br, sp, dr, dl):
		rune = r;  angle = a;  base_radius = br
		speed = sp;  drift = dr;  delay = dl
 
	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed < delay:
			return
		var t := (elapsed - delay) / LIFETIME
		if t > 1.0:
			if is_instance_valid(rune):
				rune.queue_free()
			queue_free()
			return
 
		# Alpha envelope: fade in 0→0.15, hold 0.15→0.70, fade out 0.70→1.0
		var alpha: float
		if   t < 0.15: alpha = t / 0.15
		elif t > 0.70: alpha = 1.0 - (t - 0.70) / 0.30
		else:          alpha = 1.0
		rune.modulate.a = alpha
 
		angle += speed * delta
		var radius := base_radius + drift * t
		rune.position = Vector2(cos(angle), sin(angle)) * radius
		rune.rotation += delta * 0.8   # glyph slowly spins on its own axis
 
 
class _ArcInscribeDriver extends Node:
	var arc:      Line2D
	var radius:   float
	var segments: int
	var duration: float
	var linger:   float
	var elapsed   := 0.0
	var phase     := "draw"   # "draw" → "linger" → "fade"
 
	func setup(a, r, s, dur, ling):
		arc = a;  radius = r;  segments = s;  duration = dur;  linger = ling
 
	func _process(delta: float) -> void:
		elapsed += delta
		match phase:
			"draw":
				var t   : float = clamp(elapsed / duration, 0.0, 1.0)
				var pts := int(t * segments)
				arc.clear_points()
				arc.modulate.a = min(t * 3.0, 1.0)
				for i in range(pts + 1):
					var a := (float(i) / segments) * TAU - PI * 0.5
					arc.add_point(Vector2(cos(a), sin(a)) * radius)
				if t >= 1.0:
					phase = "linger";  elapsed = 0.0
			"linger":
				if elapsed >= linger:
					phase = "fade";  elapsed = 0.0
			"fade":
				var t : float = clamp(elapsed / 0.55, 0.0, 1.0)
				arc.modulate.a = 1.0 - t
				if t >= 1.0:
					queue_free()
