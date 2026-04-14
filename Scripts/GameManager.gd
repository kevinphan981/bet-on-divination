extends Node

# core stats
var player_years: int = 100
var current_wager: int = 0
const IMMORTALITY_THRESHOLD: int = 1000
const STARTING_YEARS: int = 100

# round state (for state machine)
enum GameState { BETTING, PLAYING, ROUND_OVER, GAME_OVER }
var state: GameState = GameState.BETTING
var current_round: int = 1

# references...
@onready var deck_reference = $"../Deck"
@onready var player_hand_reference = $"../PlayerHand"
@onready var score_manager_reference = $"../ScoreManager"
@onready var hit_button = $"../CanvasLayer/MainUI/GameplayPanel/GameButtons/HitButton"
@onready var stand_button = $"../CanvasLayer/MainUI/GameplayPanel/GameButtons/StandButton"
@onready var result_label = $"../CanvasLayer/MainUI/ResultLabel"
@onready var wager_label = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/WagerAmtLabel"
@onready var player_score_label = $"../CanvasLayer/MainUI/ScoreContainer/PlayerScoreLabel"
@onready var dealer_score_label = $"../CanvasLayer/MainUI/ScoreContainer/DealerScoreLabel"

# buttons and wager increment
@onready var wager_up_button = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/WagerUpButton"
@onready var wager_down_button = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/WagerDownButton"
@onready var deal_button = $"../CanvasLayer/MainUI/WagerPanel/WagerBoxContainer/DealButton"

const WAGER_INCREMENT: int = 5  # adjust to taste

# Tarot Power Flags
var skip_next_bust: bool = false           # The Fool: ignore the next bust loss
var dealer_frozen: bool = false            # The Hermit: dealer cannot draw extra cards
var inverted_scoring: bool = false         # The World: lower score wins this round
var half_loss_on_bust: bool = false        # Temperance: bust only costs half the wager
var restore_on_loss: bool = false          # Judgement: restore years to pre-round total on loss
var is_protected_from_death: bool = false  # Debt Forgiveness: survive one zero-year moment
 
# Snapshot of player_years taken at the start of each round for restore_on_loss
var _years_at_round_start: int = 0


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
		result_label.text = "You must wager at least %d years." % [WAGER_INCREMENT] #adjust depending on wage increment
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
	result_label.text = "Awaiting player wager..."
	update_wager_display()
	deck_reference.deal_initial_hand()

# will have to adjust for tarot logic
func end_round(result: String):
	if state == GameState.ROUND_OVER or state == GameState.GAME_OVER:
		return  # already resolved, ignore duplicate calls
	
		# --- Tarot: inverted_scoring flips winner/loser (push is unaffected) ---
	var effective_result := result
	if inverted_scoring and result != "push":
		effective_result = "dealer_wins" if result == "player_wins" else "player_wins"
		print("Inverted scoring active — result flipped to: ", effective_result)
 
	match effective_result:
		"player_wins":
			player_years += current_wager*(1.5)
			show_result("You gain %d years. Total: %d" % [current_wager, player_years])
 
		"dealer_wins":
			# Tarot: skip_next_bust — bust loss ignored entirely
			if skip_next_bust:
				skip_next_bust = false
				show_result("The Fool protects you — bust ignored! Total: %d" % player_years)
 
			# Tarot: half_loss_on_bust — only half the wager is lost on a bust
			elif half_loss_on_bust:
				var loss := current_wager / 2
				player_years -= loss
				half_loss_on_bust = false
				show_result("Temperance softens the blow — you lose only %d years. Total: %d" % [loss, player_years])
 
			# Tarot: restore_on_loss — years snap back to what they were at round start
			# this doesn't work for some reason..?
			elif restore_on_loss:
				restore_on_loss = false
				player_years = _years_at_round_start
				show_result("Judgement restores your years. Total: %d" % player_years)
 
			else:
				player_years -= current_wager
				show_result("You lose %d years. Total: %d" % [current_wager, player_years])
 
		"push":
			show_result("Push! Your %d years are returned." % current_wager)
 
	# Tarot: is_protected_from_death — survive falling to 0 once
	if player_years <= 0 and is_protected_from_death:
		is_protected_from_death = false
		player_years = 1
		show_result("Debt Forgiveness saves you from death! You survive with 1 year.")
 	# Reset per-round tarot flags
	dealer_frozen = false
	inverted_scoring = false
	hide_UI(false)
	
	check_game_over()
 



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
		#get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") # no work
		Engine.get_main_loop().change_scene_to_file("res://Scenes/MainMenu.tscn")

	elif player_years >= IMMORTALITY_THRESHOLD:
		state = GameState.GAME_OVER
		show_result("You have transcended mortaliy. You win.")
		hit_button.disabled = true
		stand_button.disabled = true 
		deal_button.disabled = true
		wager_up_button.disabled = true
		wager_down_button.disabled = true
	else:
		#state = GameState.BETTING
		hit_button.disabled = true
		stand_button.disabled = true
		deal_button.disabled = false
		wager_up_button.disabled = false
		wager_down_button.disabled = false
		
		# we wait for 1.5 seconds for the next round
		await get_tree().create_timer(3.5).timeout
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
	result_label.text = "Awaiting player wager..."
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
