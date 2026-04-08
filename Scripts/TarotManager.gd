extends Node

# References to other managers to modify game state
@onready var game_manager = $"../GameManager"
@onready var deck = $"../Deck"
@onready var score_manager = $"../ScoreManager"
@onready var player_hand = $"../PlayerHand"

func _ready():
	# We will connect signals here or via the CardManager
	pass

# This function is triggered by the tarot_activated signal from Card.gd
func execute_power(card):
	var power = card.card_data.get("power", "")
	print("Activating Tarot Power: ", power)
	
	# removes card from playerhand array so it doesn't break calcuation/positioning
	if player_hand.hand.has(card):
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
		"exchange":
			player_hand.remove_card_from_hand(card)
			deck.draw_card_to_player()
		"extra_hit":
			deck.draw_card_to_player() # Ignores MAX_HAND_SIZE if logic is added to Deck
		"ace_toggle":
			# Logic to find an Ace in player_hand and flip its value
			pass 
		"remove_card":
			# Requires a selection state to pick a card to delete
			pass
		"randomize_wager":
			game_manager.current_wager = int(game_manager.current_wager * randf_range(0.5, 2.0))
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
			deck.run_dealer_logic() # While loop in Deck handles this [cite: 46]
		"restore_years":
			game_manager.set("restore_on_loss", true)
		"hide_score":
			game_manager.set("scores_hidden", true)
		"win_force":
			if score_manager.calculate_score(player_hand.hand) >= 15:
				game_manager.end_round("player_wins")
		"reveal_all":
			deck.reveal_dealer_hand()

	game_manager.update_wager_display()
	# Most tarot cards should be destroyed after one use
	card.queue_free()
