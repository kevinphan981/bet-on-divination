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

func determine_winner():
	var player_score = calculate_score(player_hand_reference.hand)
	var dealer_score = calculate_score(deck_reference.dealer_hand)
	
	if dealer_score > 21:
		game_manager_reference.end_round("player_wins")
	elif player_score > dealer_score:
		game_manager_reference.end_round("player_wins")
	elif dealer_score > player_score:
		game_manager_reference.end_round("dealer_wins")
	else:
		game_manager_reference.end_round("push")


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
	
func update_score_display():
	print("--- update_score_display called ---")
	print("player_hand_reference: ", player_hand_reference)
	print("deck_reference: ", deck_reference)
	var player_score = calculate_score(player_hand_reference.hand)
	player_score_label.text = "Player: %d" % player_score
	var dealer_score = calculate_score(deck_reference.dealer_hand)
	dealer_score_label.text = "Dealer: %d" % dealer_score

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
	# We cap at 10 iterations to avoid an infinite loop if scoring breaks.
	var max_attempts := 10
	var attempts := 0
	while calculate_score(deck_reference.dealer_hand) <= 21 and attempts < max_attempts:
		deck_reference.draw_card_to_dealer(false)
		attempts += 1
	print("dealer_bust: dealer score is now ", calculate_score(deck_reference.dealer_hand))
	determine_winner()
