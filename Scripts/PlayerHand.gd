extends Node2D

const CARD_SCENE_PATH = 'res://Scenes/Card.tscn'
const CARD_WIDTH = 250 #literally play with this to see what fits
const HAND_Y_POSITION = 900
#const DEALER_Y_POSITION = 200
var hand = []
var center_screen_x

# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	center_screen_x = get_viewport().size.x/2 # get the center of the screen


func add_card_to_hand(card):
	if card not in hand:
		hand.insert(0, card)
		update_hand_positions() 
	else: #move the card back to hand position
		animate_card_to_position(card, card.position_in_hand)

# setting the position of the card in the loop based on its index
func update_hand_positions():
	for i in range(hand.size()):
		# for new card's position based on index
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = hand[i]
		card.position_in_hand = new_position
		animate_card_to_position(card, new_position)
	
'''
total_width now correctly multiplies by CARD_WIDTH (you had a - instead of *, so it was subtracting instead of scaling)
start_x is the left edge of the entire hand — it shifts left from center by half the total spread
x_offset then steps each card rightward by CARD_WIDTH from that starting point
'''

const CARD_OVERLAP_RATIO = 0.6  #"tuning knob". 0.7 = slight overlap, 1.0 = no overlap

func get_card_step() -> float:
	if hand.is_empty():
		return 0.0
	var card = hand[0]
	var texture = card.get_node("Sprite2D").texture  # adjust node name if yours differs
	print("Player card width: ", texture.get_width())
	return texture.get_width() * card.scale.x * CARD_OVERLAP_RATIO
	
	

func calculate_card_position(index):
	#var total_width = (hand.size() - 1) * CARD_WIDTH
	#var start_x = center_screen_x - total_width/2
	#var x_offset = start_x + index * CARD_WIDTH 
	#return x_offset
	var center = get_viewport().size.x / 2  # calculate live instead of relying on _ready()
	var step = get_card_step()
	var total_width = (hand.size() - 1) * step
	print("center: ", center)
	print("total_width: ", total_width)
	print("hand.size(): ", hand.size())
	print("CARD_WIDTH: ", CARD_WIDTH)
	var start_x = center - total_width / 2
	var x_offset = start_x + index * step
	return x_offset

# animating the code moving
func animate_card_to_position(card, new_position):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, 0.1)

func remove_card_from_hand(card):
	if card in hand:
		hand.erase(card)
		update_hand_positions()

## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
