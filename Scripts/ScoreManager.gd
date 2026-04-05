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
@onready var result_label = $"../CanvasLayer/ResultLabel"
@onready var player_score_label = $"../CanvasLayer/ScoreContainer/PlayerScoreLabel"
@onready var dealer_score_label = $"../CanvasLayer/ScoreContainer/DealerScoreLabel"
@onready var hit_button = $"../CanvasLayer/HitButton"
@onready var stand_button = $"../CanvasLayer/StandButton"

func determine_winner():
	var player_score = calculate_score(player_hand_reference.hand)
	var dealer_score = calculate_score(deck_reference.dealer_hand)
	
	if dealer_score > 21:
		game_manager_reference.end_game("Player wins! Dealer busted.")
	elif player_score > dealer_score:
		game_manager_reference.end_game("Player wins!")
	elif dealer_score > player_score:
		game_manager_reference.end_game("Dealer wins!")
	else:
		game_manager_reference.end_game("Push! It's a tie.")


	
func restart():
	pass

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
		game_manager_reference.end_game("Dealer Wins! Player busted.")
