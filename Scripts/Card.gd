extends Node2D

signal hovered
signal hovered_off
signal tarot_activated(card)  # NEW
signal card_selected(card)  # fired when a non-tarot card is clicked (used by remove_card power)


var position_in_hand
var card_data = {}
var is_face_down = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# when card instantiates, it must be child of cardmanager
	get_parent().connect_card_signals(self)
	
	# testing
	print(get_tree().get_nodes_in_group(""))  # temp
	for child in get_children():
		print("Child: ", child.name, " | Type: ", child.get_class())


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)
	


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
	
# NEW — called by InputManager on left click
func on_clicked() -> void:
	if card_data.get("is_tarot", false):
		emit_signal("tarot_activated", self)
	else:
		emit_signal("card_selected", self)
		
		
'''
	Card flip feature
	Uses "squish and reveal" tweens, then shows the face up card.
'''

func flip_face_up() -> void:
	if not is_face_down:
		return
		
	var sprite = get_node("Sprite2D")
	var face_texture = load(card_data.texture_path)
	
	# phase 1: squish to zero on x-axis (fold inward)
	var tween = create_tween()
	tween.tween_property(sprite, "scale:x", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	
	# swap at midpoint
	sprite.texture = face_texture
	is_face_down = false
	
	# phase 2: expand when back out
	var tween2 = create_tween()
	tween2.tween_property(sprite, "scale:x", .45, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween2.finished
	
'''
	Floating value pop (balatro style)
	spawns a +n label that floats up and fades out above the card
'''
func show_value_popup(value: int) -> void:
	if value <= 0:
		return #don't show anything for tarot cards
		
	var label = Label.new()
	label.text = "+%d" % value
	label.z_index = 10 #highest to show up
	
	#style
	var font_size = 56
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))       # warm gold
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0)) # dark outline
	label.add_theme_constant_override("outline_size", 4)
	
	# Start just above the card center, SUBJECT TO CHANGE
	label.position = Vector2(-20, -80)
	add_child(label)
	
	# animation: float up 60px and fade out over 2.5s (prev. was 0.9s)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	label.queue_free()
	
