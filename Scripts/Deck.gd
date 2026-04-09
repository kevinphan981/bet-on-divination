extends Node2D
const CARD_BACK_PATH = "res://Assets/Cards/test.png"
const CARD_SCENE_PATH = 'res://Scenes/Card.tscn'
var card_database_reference
var dealer_hand = []
var dealer_hidden_card = null #tracks face down cards
var score_manager_reference  # new because of ScoreManager
@onready var hit_button = $"../CanvasLayer/MainUI/GameplayPanel/GameButtons/HitButton"
@onready var stand_button = $"../CanvasLayer/MainUI/GameplayPanel/GameButtons/StandButton"
@onready var result_label = $"../CanvasLayer/MainUI/ResultLabel"
const MAX_HAND_SIZE = 7 # subject to change, 7 based on google search
const DEALER_Y_POSITION = 200


#signal hit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#print($Area2D.collision_mask)
	# meant to connect the signal to the actual function
	hit_button.pressed.connect(on_hit_button_pressed)
	stand_button.pressed.connect(on_stand_button_pressed)
	score_manager_reference = $"../ScoreManager"  # ← new
	card_database_reference = preload('res://Scripts/CardDatabase.gd')
	#deal_initial_hand()
	#print(get_parent().get_children())  # see what nodes are actually at that level
   

	#pass # Replace with function body.

func deal_initial_hand():
	print("Initial hands dealt")
	draw_card_to_dealer(false)
	draw_card_to_player()
	draw_card_to_dealer(true)
	draw_card_to_player()
	result_label.text = ''


	
'''
	Contemplate doing a singular function that 
	just takes different arguments for the player or dealer
'''

func draw_card_to_player():
	print("score_manager_reference: ", score_manager_reference)
	if $"../PlayerHand".hand.size() >= MAX_HAND_SIZE:
		return
	#var card_data = CardDatabase.draw_card_db()
	var card_data = CardDatabase.draw_card_for_player()
	print("Deck received data: ", card_data) # [cite: 43]
	
	if card_data.is_empty():
		print("ERROR: card_data is empty!")
		return
		
		
	var new_card = create_card(card_data)
	$"../PlayerHand".add_card_to_hand(new_card)
	score_manager_reference.update_score_display()
	score_manager_reference.check_bust()
	# Only bust-check on non-tarot draws (tarot value is 0)
	if not card_data.get("is_tarot", false):
		score_manager_reference.check_bust()

func draw_card_to_dealer(face_down: bool):
	var card_data = CardDatabase.draw_card_db()
	var new_card = create_card(card_data)
	if face_down:
		new_card.get_node("Sprite2D").texture = load(CARD_BACK_PATH)
		new_card.is_face_down = true # actually excludes it from the score
		dealer_hidden_card = new_card
	dealer_hand.append(new_card)
	update_dealer_positions()
	score_manager_reference.update_score_display()

'''
	draw_card()
	was the manual way to click on a card and draw it from the deck.
'''
#func draw_card():
	#if $"../PlayerHand".hand.size() >= MAX_HAND_SIZE:
		#print("Hand is full!")
		#return
	#
	#var card_scene = preload(CARD_SCENE_PATH)
	#var card_data = CardDatabase.draw_card_db()
	#print("Drew: ", card_data)
#
	#var new_card = card_scene.instantiate()
	#$"../CardManager".add_child(new_card)
	#new_card.name = "Card"
	#
	##get texture directly
	#var texture = load(card_data.texture_path)
	#print("Texture loaded: ", texture)  # will print 'null' if path is wrong
#
	#new_card.get_node("Sprite2D").texture = texture
	#$"../PlayerHand".add_card_to_hand(new_card)

# func create to actually make the card
func create_card(card_data) -> Node:
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	$"../CardManager".add_child(new_card)
	new_card.card_data = card_data         # set AFTER add_child, not before
	
	# new logic for tarot cards
	if card_data.get("is_tarot", false):
		new_card.connect("tarot_activated", $"../TarotManager".execute_power)
		
	new_card.name = "Card"
	new_card.get_node("Sprite2D").texture = load(card_data.texture_path)
	return new_card

''' 
	DealerHand in itself seems too much for this, just use some things here to make the dealer
'''

const CARD_OVERLAP_RATIO = 0.6  #"tuning knob". 0.7 = slight overlap, 1.0 = no overlap

func get_dealer_card_step() -> float:
	if dealer_hand.is_empty():
		return 0.0
	var card = dealer_hand[0]
	var texture = card.get_node("Sprite2D").texture  # adjust node name if yours differs
	print("Dealer card width: ", texture.get_width())
	return texture.get_width() * card.scale.x * CARD_OVERLAP_RATIO
	
	
func update_dealer_positions():
	var center = get_viewport().size.x / 2
	var step = get_dealer_card_step()
	var total_width = (dealer_hand.size() - 1) * step
	var start_x = center - total_width / 2
	for i in range(dealer_hand.size()):
		var pos = Vector2(start_x + i * step, DEALER_Y_POSITION)
		var tween = get_tree().create_tween()  
		tween.tween_property(dealer_hand[i], "position", pos, 0.1)
		


'''
	hit logic, gets another card for dealer and player, but face down for the dealer
'''
func on_hit_button_pressed():
	$"../Deck".hit()

func hit():
	if $"../PlayerHand".hand.size() >= MAX_HAND_SIZE:
		return
	draw_card_to_player()
	# dealer also draws a face-down card on each player hit
	draw_card_to_dealer(true)

'''
	reveal_dealer_hand():
	shows the hand of the dealer when the player stands or busts
'''
func reveal_dealer_hand():
	# flip all dealer cards face up (call this when player stands)
	for card in dealer_hand:
		card.get_node("Sprite2D").texture = load(card.card_data.texture_path)
		card.is_face_down = false



'''
	stand()
	-reveals the dealer's hand and stops play
	
	run_dealer_logic():
	-rules:
		1. when dealer must draw until they hit 17
		there will be more...		
'''
func on_stand_button_pressed():
	$"../Deck".stand()
	
func stand():
	print("Player stands.")
	reveal_dealer_hand()
	score_manager_reference.update_score_display()
	run_dealer_logic()
	
func run_dealer_logic():
	while score_manager_reference.calculate_score(dealer_hand) < 17:
		draw_card_to_dealer(false) #face up
	score_manager_reference.update_score_display()
	score_manager_reference.determine_winner()
	
# clear table is the next state when we finish a round
func clear_table():
	# clear player hand
	for card in $"../PlayerHand".hand:
		card.queue_free()
	$"../PlayerHand".hand.clear()
	
	# clear dealer hand
	for card in dealer_hand:
		card.queue_free()
	dealer_hand.clear()
	dealer_hidden_card = null
	
	# reshuffle if needed
	CardDatabase.shuffle_deck()
