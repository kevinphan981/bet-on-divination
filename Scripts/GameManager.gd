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
@onready var hit_button = $"../CanvasLayer/MainUI/HitButton"
@onready var stand_button = $"../CanvasLayer/MainUI/StandButton"
@onready var result_label = $"../CanvasLayer/MainUI/ResultLabel"
@onready var wager_label = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/WagerAmtLabel"
@onready var player_score_label = $"../CanvasLayer/MainUI/ScoreContainer/PlayerScoreLabel"
@onready var dealer_score_label = $"../CanvasLayer/MainUI/ScoreContainer/DealerScoreLabel"

# buttons and wager increment
@onready var wager_up_button = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/WagerUpButton"
@onready var wager_down_button = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/WagerDownButton"
@onready var deal_button = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/DealButton"

const WAGER_INCREMENT: int = 5  # adjust to taste

# too many things overlay each other, temporary fix until I can get some blur animation
func hide_UI(condition: bool):
	hit_button.visible = condition
	stand_button.visible = condition
	player_score_label.visible = condition 
	dealer_score_label.visible = condition


func disable_UI(condition: bool):
	hit_button.disabled = condition 
	stand_button.disabled = condition 

func _ready():
	#state = GameState.PLAYING
	# disable all buttons until the player bets
	disable_UI(true)
	hide_UI(false)
	result_label.text = "Awaiting player wager..."
	wager_up_button.pressed.connect(_on_wager_up_button_pressed)
	wager_down_button.pressed.connect(_on_wager_down_button_pressed)
	#deal_button.pressed.connect(_on_deal_button_pressed)
	update_wager_display()
	

func _on_wager_up_button_pressed() -> void:
	if state != GameState.BETTING:
		return
	# can't wager more than you have
	current_wager = min(current_wager + WAGER_INCREMENT, player_years)
	update_wager_display()


func _on_wager_down_button_pressed() -> void:
	if state != GameState.BETTING:
		return
		# can't wager below 0
	current_wager = max(current_wager - WAGER_INCREMENT, 0)
	update_wager_display()

func _on_deal_button_pressed() -> void:
	if state != GameState.BETTING:
		return
	if current_wager <= 0:
		result_label.text = "You must wager at least 1 year."
		return
	place_wager(current_wager)
	player_score_label.visible = true
	dealer_score_label.visible = true
	result_label.visible = true


func start_round():
	state = GameState.PLAYING
	hide_UI(true)
	hit_button.disabled = false
	stand_button.disabled = false
	deal_button.disabled = true
	wager_up_button.disabled = true
	wager_down_button.disabled = true
	result_label.text = ""
	update_wager_display()
	deck_reference.deal_initial_hand()

func end_round(result: String):
	state = GameState.ROUND_OVER
	match result:
		"player_wins":
			player_years += current_wager
			show_result("You gain %d years. Total: %d" % [current_wager, player_years])
		"dealer_wins":
			player_years -= current_wager
			show_result("You lose %d years. Total: %d" % [current_wager, player_years])
		"push":
			show_result("Push! Your %d years are returned." % current_wager)
	check_game_over()
	hide_UI(false)


func next_round():
	pass

func check_game_over():
	if player_years <= 0:
		state = GameState.GAME_OVER
		show_result("You have no years left. You are dead.")
		hit_button.disabled = true
		stand_button.disabled = true
		deal_button.disabled = true
		wager_up_button.disabled = true
		wager_down_button.disabled = true 
		
		# you die and get sent to the main menu after a bit
		await get_tree().create_timer(3.5).timeout
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

	elif player_years >= IMMORTALITY_THRESHOLD:
		state = GameState.GAME_OVER
		show_result("You have transcended mortaliy. You win.")
		hit_button.disabled = true
		stand_button.disabled = true 
		deal_button.disabled = true
		wager_up_button.disabled = true
		wager_down_button.disabled = true
	else:
		# we get ready for next round.
		#current_round += 1
		#state = GameState.BETTING
		hit_button.disabled = true
		stand_button.disabled = true
		deal_button.disabled = false
		wager_up_button.disabled = false
		wager_down_button.disabled = false
		
		# we wait for 1.5 seconds for the next round
		await get_tree().create_timer(1.5).timeout
		advance_to_next_round()

func advance_to_next_round():
	deck_reference.clear_table()
	current_round += 1
	current_wager = 0
	state = GameState.BETTING
	hit_button.disabled = true
	stand_button.disabled = true
	deal_button.disabled = false
	wager_up_button.disabled = false
	wager_down_button.disabled = false
	result_label.text = ""
	update_wager_display()

func restart():
	player_years = STARTING_YEARS
	current_wager = 0
	current_round = 1
	state = GameState.BETTING
	#disable_UI(true)
	update_wager_display()

# wager
func place_wager(amount: int):
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
