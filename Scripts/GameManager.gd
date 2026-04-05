extends Node

# core stats
var player_years: int = 100
var current_wager: int = 0
const IMMORTALITY_THRESHOLD: int = 100000
const STARTING_YEARS: int = 100

# round state (for state machine)

enum GameState { BETTING, PLAYING, ROUND_OVER, GAME_OVER }
var state: GameState = GameState.BETTING
var current_round: int = 1

# references...
@onready var deck_reference = $"../Deck"
@onready var player_hand_reference = $"../PlayerHand"
@onready var score_manager_reference = $"../ScoreManager"
@onready var hit_button = $"../CanvasLayer/HitButton"
@onready var stand_button = $"../CanvasLayer/StandButton"
@onready var result_label = $"../CanvasLayer/ResultLabel"
@onready var wager_label = $"../CanvasLayer/WagerAmtLabel"
@onready var player_score_label = $"../CanvasLayer/ScoreContainer/PlayerScoreLabel"
@onready var dealer_score_label = $"../CanvasLayer/ScoreContainer/DealerScoreLabel"


func _ready():
	# disable all buttons until the player bets
	hit_button.disabled = true 
	stand_button.disabled = true  
	update_wager_display()
	
#func current_round():
	#pass
	
#func player_chips():
	#pass
#
#func current_wager():
	#pass

# we need a state machine here
#BETTING → PLAYING → RESOLVING → NEXT_ROUND

func start_round():
	state = GameState.PLAYING
	hit_button.disabled = false
	stand_button.disabled = false
	result_label.text = ""
	update_wager_display()
	deck_reference.deal_initial_hand()

func end_round(result: String):
	state = GameState.ROUND_OVER
	match result:
		"player wins":
			player_years += current_wager
			show_result("You gain %d years. Total: %d" % [current_wager, player_years])
		"dealer_wins":
			player_years -= current_wager
			show_result("You lose %d years. Total: %d" % [current_wager, player_years])
		"push":
			show_result("Push! Your %d years are returned." % current_wager)
#
#func next_round():
	#pass

func check_game_over():
	if player_years <= 0:
		state = GameState.GAME_OVER
		show_result("You have no years left. You are dead.")
		hit_button.disabled = true
		stand_button.disabled = true 
	elif player_years >= IMMORTALITY_THRESHOLD:
		state = GameState.GAME_OVER
		show_result("You have transcended mortaliy. You win.")
		hit_button.disabled = true
		stand_button.disabled = true 
	else:
		# we get ready for next round.
		current_round += 1
		state = GameState.BETTING
		hit_button.disabled = true
		stand_button.disabled = true 



func end_game(message: String):
	print(message)
	result_label.text = message
	player_score_label.visible = false
	dealer_score_label.visible = false
	hit_button.disabled = true
	stand_button.disabled = true

func restart():
	player_years = STARTING_YEARS
	current_wager = 0
	current_round = 1
	state = GameState.BETTING
	hit_button.disabled = true
	stand_button.disabled = true
	update_wager_display()

# wager

func place_waver(amount: int):
	if state != GameState.BETTING:
		return
	if amount <= 0 or amount > player_years:
		print("Invalid wager")
		return
	current_wager = amount
	print("Wager placed: %d years" % current_wager)
	start_round()

func update_wager_display():
	wager_label.text = "Years: %d | Wager: %d" % [player_years, current_wager]


# helper show result

func show_result(message: String):
	result_label.text = message
	print(message)
