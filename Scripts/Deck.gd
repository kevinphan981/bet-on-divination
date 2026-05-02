extends Node2D
const CARD_BACK_PATH = "res://Assets/Cards/test.png"
const CARD_SCENE_PATH = 'res://Scenes/Card.tscn'
var card_database_reference
var dealer_hand = []
var dealer_hidden_card = null #tracks face down cards
var score_manager_reference  # new because of ScoreManager
@onready var hit_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/HitButton"
@onready var stand_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/StandButton"
@onready var result_label = $"../CanvasLayer/MainUI/ResultLabel"
const MAX_HAND_SIZE = 5 # subject to change, 7 based on google search
const DEALER_Y_POSITION = 200
const PLAYER_Y_POSITION = 900

#const CardScript = preload("res://Scripts/Card.gd")  # adjust path as needed


# Delay between each dealer card flip during the reveal (seconds)
const FLIP_DELAY = 0.45
const DEAL_DELAY = 0.35  # tune this to match your flip speed



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
	result_label.text = ''
	draw_card_to_dealer(false)
	await get_tree().create_timer(DEAL_DELAY).timeout
	await draw_card_to_player()
	await get_tree().create_timer(DEAL_DELAY).timeout
	draw_card_to_dealer(true)
	await get_tree().create_timer(DEAL_DELAY).timeout
	await draw_card_to_player()
	


	
'''
	Contemplate doing a singular function that 
	just takes different arguments for the player or dealer
'''

func draw_card_to_player():
	## wait a moment
	#await get_tree().create_timer(DEAL_DELAY).timeout
	
	print("score_manager_reference: ", score_manager_reference)
	if $"../PlayerHand".hand.size() >= MAX_HAND_SIZE:
		return
	#var card_data = CardDatabase.draw_card_db()
	var card_data = CardDatabase.draw_card_for_player()
	print("Deck received data: ", card_data) # [cite: 43]
	
	if card_data.is_empty():
		print("ERROR: card_data is empty!")
		return
	
	var new_card = create_card(card_data, PLAYER_Y_POSITION)
	
	# we draw the card physically
	$"../PlayerHand".add_card_to_hand(new_card)
	new_card.call("show_value_popup", card_data.get("value", 0))
	AudioController.play_card_draw()
	
	await get_tree().create_timer(DEAL_DELAY).timeout  # ← wait after dealing
	
	score_manager_reference.update_score_display()
	score_manager_reference.check_bust()
	# Only bust-check on non-tarot draws (tarot value is 0)
	if not card_data.get("is_tarot", false):
		score_manager_reference.check_bust()
		
	
	


func draw_card_to_dealer(face_down: bool):

	var card_data = CardDatabase.draw_card_db()
	var new_card = create_card(card_data, DEALER_Y_POSITION)
	AudioController.play_card_draw()
	if face_down:
		new_card.get_node("Sprite2D").texture = load(CARD_BACK_PATH)
		new_card.is_face_down = true # actually excludes it from the score
		dealer_hidden_card = new_card
	dealer_hand.append(new_card)
	update_dealer_positions()
	
	if not face_down:
		new_card.call("show_value_popup", card_data.get("value", 0))
	await get_tree().create_timer(DEAL_DELAY).timeout  # ← wait after dealing
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

func create_card(card_data, dest_y: float) -> Node:
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	$"../CardManager".add_child(new_card)
	new_card.card_data = card_data

	if card_data.get("is_tarot", false):
		new_card.connect("tarot_activated", $"../TarotManager".execute_power)

	new_card.name = "Card"
	new_card.get_node("Sprite2D").texture = load(card_data.texture_path)

	# Start above the destination and slide down to it
	var center_x = get_viewport().size.x / 2
	new_card.position = Vector2(center_x, dest_y - 300)
	var tween = get_tree().create_tween()
	tween.tween_property(new_card, "position:y", dest_y, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	#draw_card_to_dealer(true)

'''
	reveal_dealer_hand():
	shows the hand of the dealer when the player stands or busts
	
	4/14 - now adds individual card flips, also async so dealer logic doesn't call ahead
'''
func reveal_dealer_hand():
	# flip all dealer cards face up (call this when player stands)
	for card in dealer_hand:
		print("Card: ", card.card_data.get("name", "?"), " | is_face_down: ", card.is_face_down)
		if card.is_face_down:
			await card.flip_face_up()
			card.show_value_popup(card.card_data.get("value", 0))
			# Brief pause before flipping the next card
			await get_tree().create_timer(FLIP_DELAY).timeout
	score_manager_reference.update_score_display()



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
	await reveal_dealer_hand()
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
