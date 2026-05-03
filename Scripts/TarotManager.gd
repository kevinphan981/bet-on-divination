extends Node

# References to other managers to modify game state
@onready var game_manager = $"../GameManager"
@onready var deck = $"../Deck"
@onready var score_manager = $"../ScoreManager"
@onready var player_hand = $"../PlayerHand"
@onready var tarot_desc_label = $"../CanvasLayer/MainUI/InfoPanel/TarotDescription"

var _awaiting_removal: bool = false


# This function is triggered by the tarot_activated signal from Card.gd
func execute_power(card):
	var power = card.card_data.get("power", "")
	print("Activating Tarot Power: ", power)
	AudioController.play_special_card_activate()

	# Remove tarot card from hand before resolving its effect
	if player_hand.hand.has(card):
		player_hand.remove_card_from_hand(card)
	player_hand.update_hand_positions()
	score_manager.update_score_display()

	match power:

		# ── Already working — flags read by end_round ────────────────────
		"skip_bust":
			game_manager.skip_next_bust = true
			GameLog.add("The Fool: your next bust is ignored.")

		"halve_bust":
			game_manager.half_loss_on_bust = true
			GameLog.add("Temperance: if you bust, lose only half your wager.")

		"restore_years":
			game_manager.restore_on_loss = true
			GameLog.add("The Star: if you lose, your years are restored.")

		"debt_forgiveness":
			game_manager.is_protected_from_death = true
			GameLog.add("The Moon: you are protected from death once.")

		# ── Direct effect — no flag needed ───────────────────────────────
		"heal_years":
			game_manager.player_years += 10
			game_manager.update_wager_display()
			GameLog.add("The Empress: +10 years granted.")

		"steal_years":
			game_manager.player_years += 5
			game_manager.update_wager_display()
			GameLog.add("The Devil: you steal 5 years.")

		"double_wager":
			game_manager.current_wager = min(
				game_manager.current_wager * 2,
				game_manager.player_years  # cap at what player actually has
			)
			game_manager.update_wager_display()
			GameLog.add("The Emperor: your wager is doubled!")

		"randomize_wager":
			var multiplier = randf_range(1.0, 5.0)
			game_manager.current_wager = min(
				int(game_manager.current_wager * multiplier),
				game_manager.player_years
			)
			game_manager.update_wager_display()
			GameLog.add("Wheel of Fortune: your wager is now %d years." % game_manager.current_wager)

		"push_force":
			GameLog.add("Justice: the round is forced to a push.")
			game_manager.end_round("push")
			card.queue_free()
			return

		"win_force":
			var score = score_manager.calculate_score(player_hand.hand)
			if score >= 15:
				GameLog.add("The Sun: victory forced at %d!" % score)
				game_manager.end_round("player_wins")
				card.queue_free()
				return
			else:
				GameLog.add("The Sun: score too low (%d), no effect." % score)

		# ── Needs flag read in Deck.run_dealer_logic ─────────────────────
		"freeze_dealer":
			game_manager.dealer_frozen = true
			GameLog.add("The High Priestess: dealer must skip their next draw.")

		# ── Needs flag read in ScoreManager.determine_winner ─────────────
		"invert_score":
			game_manager.inverted_scoring = true
			GameLog.add("The Hanged Man: scores are inverted — lower wins this round.")

		# ── Draw / hand manipulation ──────────────────────────────────────
		"peek_dealer":
			await deck.reveal_dealer_hand()
			GameLog.add("The Magician: the dealer's hand is revealed.")

		"reveal_all":
			await deck.reveal_dealer_hand()
			GameLog.add("Judgement: all dealer cards revealed.")

		"extra_hit":
			# Bypasses MAX_HAND_SIZE intentionally
			var card_data = CardDatabase.draw_card_for_player()
			var new_card = deck.create_card(card_data, deck.PLAYER_Y_POSITION)
			player_hand.add_card_to_hand(new_card)
			new_card.show_value_popup(card_data.get("value", 0))
			score_manager.update_score_display()
			score_manager.check_bust()
			GameLog.add("The Chariot: one extra card drawn!")

		"exchange":
			# Hand already has the tarot removed — just draw a replacement
			await deck.draw_card_to_player()
			GameLog.add("The Lovers: a card was exchanged for a fresh draw.")

		"peek_deck":
			var top_cards = []
			for i in range(min(3, CardDatabase.draw_pile.size())):
				top_cards.append(CardDatabase.draw_pile[-(i + 1)].get("name", "?"))
			GameLog.add("The Hierophant: next cards are %s." % ", ".join(top_cards))

		"clear_hand":
			# Clear player hand and redeal fresh
			for c in player_hand.hand.duplicate():
				player_hand.remove_card_from_hand(c)
				c.queue_free()
			player_hand.update_hand_positions()
			await deck.draw_card_to_player()
			await deck.draw_card_to_player()
			score_manager.update_score_display()
			GameLog.add("Death: your hand is redrawn.")

		"ace_toggle":
			# Find the first Ace and flip its effective value between 11 and 1
			var toggled = false
			for c in player_hand.hand:
				if c.card_data.get("name", "") == "Ace":
					if c.card_data["value"] == 11:
						c.card_data["value"] = 1
					else:
						c.card_data["value"] = 11
					toggled = true
					break
			score_manager.update_score_display()
			if toggled:
				GameLog.add("Strength: Ace toggled.")
			else:
				GameLog.add("Strength: no Ace in hand.")

		"remove_card":
			if player_hand.hand.is_empty():
				GameLog.add("The Hermit: no cards to remove.")
			else:
				GameLog.add("The Hermit: click a card to remove it.")
				_await_card_removal()
			card.queue_free()
			return

		"dealer_bust":
			score_manager._force_dealer_bust()

	game_manager.update_wager_display()
	card.queue_free()
	
'''
	Helper: put the game into card-removal selection mode.
	Connect each card's input event to _on_removal_card_selected while active.
'''

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
	GameLog.add("The Hermit: card removed.")

	print("remove_card: player removed ", selected_card.card_data.get("name", "a card"))
