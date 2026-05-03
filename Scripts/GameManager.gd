extends Node

# core stats
var player_years: int = 100
var current_wager: int = 0
const IMMORTALITY_THRESHOLD: int = 1000
const STARTING_YEARS: int = 100
# round counter, as is
var round_counter: int = 1

# round state (for state machine)
enum GameState { BETTING, PLAYING, ROUND_OVER, GAME_OVER }
var state: GameState = GameState.BETTING
var current_round: int = 1

# references...
@onready var deck_reference = $"../Deck"
@onready var player_hand_reference = $"../PlayerHand"
@onready var score_manager_reference = $"../ScoreManager"

# will change because of my UI fixes

# the entire sidepanel
@onready var side_panel = $"../CanvasLayer/MainUI/SidePanel"
@onready var hit_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/HitButton"
@onready var stand_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/StandButton"
@onready var result_label = $"../CanvasLayer/MainUI/ResultLabel"
@onready var wager_label = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/WagerAmtLabel"
@onready var player_score_label = $"../CanvasLayer/MainUI/ScoreContainer/PlayerScoreLabel"
@onready var dealer_score_label = $"../CanvasLayer/MainUI/ScoreContainer/DealerScoreLabel"
@onready var round_label = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/RoundLabel"
# buttons and wager increment
@onready var wager_up_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/WagerUpButton"
@onready var wager_down_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/WagerDownButton"
@onready var deal_button = $"../CanvasLayer/MainUI/SidePanel/MarginContainer/VBoxContainer/DealButton"

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

'''
	single function that owns the UI states, call in every function
'''
func _apply_ui_for_state() -> void:
	match state:
		GameState.BETTING:
			hit_button.visible   = false
			stand_button.visible = false
			player_score_label.visible = false
			dealer_score_label.visible = false
			result_label.text    = "Awaiting player wager..."
			deal_button.disabled        = false
			wager_up_button.disabled    = false
			wager_down_button.disabled  = false
			hit_button.disabled         = true
			stand_button.disabled       = true

		GameState.PLAYING:
			hit_button.visible   = true
			stand_button.visible = true
			player_score_label.visible = true
			dealer_score_label.visible = true
			deal_button.disabled        = true
			wager_up_button.disabled    = true
			wager_down_button.disabled  = true
			hit_button.disabled         = false
			stand_button.disabled       = false

		GameState.ROUND_OVER:
			# Scores stay visible so the highlight color is readable.
			hit_button.visible   = false
			stand_button.visible = false
			player_score_label.visible = false
			dealer_score_label.visible = false
			deal_button.disabled        = true
			wager_up_button.disabled    = true
			wager_down_button.disabled  = true
			hit_button.disabled         = true
			stand_button.disabled       = true
			
		GameState.GAME_OVER:
			hit_button.visible   = false
			stand_button.visible = false
			deal_button.disabled        = true
			wager_up_button.disabled    = true
			wager_down_button.disabled  = true
			hit_button.disabled         = true
			stand_button.disabled       = true
			player_score_label.visible = false
			dealer_score_label.visible = false

func _ready():
	wager_up_button.pressed.connect(_on_wager_up_button_pressed)
	wager_down_button.pressed.connect(_on_wager_down_button_pressed)
	state = GameState.BETTING
	_apply_ui_for_state()
	update_wager_display()
	GameLog.add("Game started — you have %d years." % player_years)



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
	result_label.text = "Awaiting player wager..."
	update_wager_display()
	deck_reference.deal_initial_hand()
	
	# round label
	print("Round is: ", round_counter)
	round_label.text = "Round: %d" % [round_counter]


# will have to adjust for tarot logic
func end_round(result: String):
	if state == GameState.ROUND_OVER or state == GameState.GAME_OVER:
		return  # guard against duplicate calls

	# ── Apply tarot modifiers ─────────────────────────────────────────────
	var effective_result := result
	if inverted_scoring and result != "push":
		effective_result = "dealer_wins" if result == "player_wins" else "player_wins"

	match effective_result:
		"player_wins":
			player_years += current_wager
			result_label.text = "You gain %d years! Total: %d" % [current_wager, player_years]
		"dealer_wins":
			if skip_next_bust:
				skip_next_bust = false
				result_label.text = "The Fool protects you! Total: %d" % player_years
			elif half_loss_on_bust:
				AudioController.play_damage()
				var loss := current_wager / 2
				player_years -= loss
				half_loss_on_bust = false
				result_label.text = "Temperance softens the blow — lose %d years. Total: %d" % [loss, player_years]
			elif restore_on_loss:
				restore_on_loss = false
				player_years = _years_at_round_start
				result_label.text = "Judgement restores your years. Total: %d" % player_years
			else:
				player_years -= current_wager
				AudioController.play_damage()
				result_label.text = "You lose %d years. Total: %d" % [current_wager, player_years]
		"push":
			result_label.text = "Push! Your %d years are returned." % current_wager

	if player_years <= 0 and is_protected_from_death:
		AudioController.play_damage()
		is_protected_from_death = false
		player_years = 1
		result_label.text = "Debt Forgiveness saves you! You survive with 1 year."

	# Reset per-round tarot flags
	dealer_frozen = false
	inverted_scoring = false

	state = GameState.ROUND_OVER
	GameLog.add(result_label.text)  # logs whatever the outcome message was
	_apply_ui_for_state()  # scores visible, buttons hidden
	update_wager_display()
	print(result_label.text)

	# Wait here so the player can read the highlighted scores + result
	await get_tree().create_timer(2.5).timeout
	_finish_round()

 

func check_game_over():
	if player_years <= 0:
		state = GameState.GAME_OVER
		show_result("You have no years left. You are dead.")
		
		# you die and get sent to the main menu after a bit
		await get_tree().create_timer(3.5).timeout
		#get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") # no work
		Engine.get_main_loop().change_scene_to_file("res://Scenes/MainMenu.tscn")

	elif player_years >= IMMORTALITY_THRESHOLD:
		state = GameState.GAME_OVER
		show_result("You have transcended mortaliy. You win.")

	else:
		state = GameState.BETTING
		
		# we wait for 1.5 seconds for the next round
		await get_tree().create_timer(3.5).timeout
		advance_to_next_round()

func advance_to_next_round():
	score_manager_reference.reset_score_colors()
	deck_reference.clear_table()
	current_round += 1
	current_wager = 0
	state = GameState.BETTING
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
	if amount <= 0 or amount > player_years:
		return
	current_wager = amount
	_years_at_round_start = player_years
	state = GameState.PLAYING
	round_label.text = "Round: %d" % current_round
	_apply_ui_for_state()
	GameLog.divider("Round %d" % current_round)
	update_wager_display()
	deck_reference.deal_initial_hand()
	
func _finish_round():
	if player_years <= 0:
		state = GameState.GAME_OVER
		_apply_ui_for_state()
		result_label.text = "You have no years left. You are dead."
		await get_tree().create_timer(3.5).timeout
		Engine.get_main_loop().change_scene_to_file("res://Scenes/MainMenu.tscn")

	elif player_years >= IMMORTALITY_THRESHOLD:
		state = GameState.GAME_OVER
		_apply_ui_for_state()
		result_label.text = "You have transcended mortality. You win."

	else:
		# Clean up and go back to betting
		score_manager_reference.reset_score_colors()
		deck_reference.clear_table()
		current_round += 1
		current_wager = 0
		state = GameState.BETTING
		_apply_ui_for_state()
		update_wager_display()

#--------------- Helpers ---------------------------------
func update_wager_display():
	wager_label.text = "Years: %d | Wager: %d" % [player_years, current_wager]

func show_result(message: String):
	result_label.text = message
	print(message)
