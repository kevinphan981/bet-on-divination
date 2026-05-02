extends Node

# References to other managers to modify game state
@onready var game_manager = $"../GameManager"
@onready var deck = $"../Deck"
@onready var score_manager = $"../ScoreManager"
@onready var player_hand = $"../PlayerHand"
@onready var tarot_desc_label = $"../CanvasLayer/MainUI/InfoPanel/TarotDescription"
func _ready():
	# We will connect signals here or via the CardManager
	pass

# This function is triggered by the tarot_activated signal from Card.gd
func execute_power(card):
	var power = card.card_data.get("power", "")
	print("Activating Tarot Power: ", power)
	
	# removes card from playerhand array so it doesn't break calcuation/positioning
	if player_hand.hand.has(card):
		AudioController.play_special_card_activate()
		player_hand.remove_card_from_hand(card)
		
	# update visuals/logic now card is gone
	player_hand.update_hand_positions()
	score_manager.update_score_display()
	
	match power:
		"skip_bust": 
			# Implementation requires a 'protected' flag in GameManager
			game_manager.set("skip_next_bust", true)
		"peek_dealer": 
			deck.reveal_dealer_hand()
		"freeze_dealer":
			game_manager.set("dealer_frozen", true)
		"heal_years":
			game_manager.player_years += 10
		"double_wager":
			game_manager.current_wager *= 2
		"peek_deck":
			# Log top 3 cards to console or a UI list
			for i in range(min(3, CardDatabase.draw_pile.size())):
				print("Top ", i+1, ": ", CardDatabase.draw_pile[-(i+1)].name)
				#game_manager.show_result("Top ", i+1, ": ", CardDatabase.draw_pile[-(i+1)].name)

		"exchange":
			player_hand.remove_card_from_hand(card)
			deck.draw_card_to_player()
		"extra_hit":
			deck.draw_card_to_player() # Ignores MAX_HAND_SIZE if logic is added to Deck
		"ace_toggle":
			# Logic to find an Ace in player_hand and flip its value
			pass 
		"remove_card":
			if player_hand.hand.is_empty():
				print("remove_card: no cards in hand to remove.")
			else:
				print("remove_card: awaiting player selection…")
				_await_card_removal()
			# Early return — card.queue_free() is handled at the bottom,
			# but we must NOT free the selected card until the player picks.
			game_manager.update_wager_display()
			card.queue_free()
			return  # skip the queue_free at the end; tarot card was already removed above
		"randomize_wager":
			game_manager.current_wager = int(game_manager.current_wager * randf_range(1.0, 5.0))
		"push_force":
			game_manager.end_round("push")
		"invert_score":
			game_manager.set("inverted_scoring", true)
		"clear_hand":
			deck.clear_table()
			deck.deal_initial_hand()
		"halve_bust":
			game_manager.set("half_loss_on_bust", true)
		"steal_years":
			game_manager.player_years += 5
		"dealer_bust":
			score_manager._force_dealer_bust() # While loop in Deck handles this [cite: 46]
		"restore_years":
			game_manager.set("restore_on_loss", true)
		"debt_forgiveness":
			game_manager.set("is_protected_from_death", true)
		"win_force":
			if score_manager.calculate_score(player_hand.hand) >= 15:
				game_manager.end_round("player_wins")
		"reveal_all":
			deck.reveal_dealer_hand()

	game_manager.update_wager_display()
	# Most tarot cards should be destroyed after one use
	card.queue_free()
	
'''
	Helper: put the game into card-removal selection mode.
	Connect each card's input event to _on_removal_card_selected while active.
'''

var _awaiting_removal: bool = false

func _await_card_removal():
	_awaiting_removal = true
	# Connect a one-shot listener to every card currently in hand.
	for hand_card in player_hand.hand:
		if not hand_card.is_connected("card_selected", _on_removal_card_selected):
			hand_card.card_selected.connect(_on_removal_card_selected)
 
func _on_removal_card_selected(selected_card) -> void:
	if not _awaiting_removal:
		return
	_awaiting_removal = false
	
	# Disconnect all listeners
	for hand_card in player_hand.hand:
		if hand_card.is_connected("card_selected", _on_removal_card_selected):
			hand_card.card_selected.disconnect(_on_removal_card_selected)
			
	# Remove and destroy the chosen card
	player_hand.remove_card_from_hand(selected_card)
	player_hand.update_hand_positions()
	score_manager.update_score_display()
	selected_card.queue_free()
	game_manager.update_wager_display()
	print("remove_card: player removed ", selected_card.card_data.get("name", "a card"))
