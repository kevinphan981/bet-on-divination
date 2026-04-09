extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_DECK = 8 # yes
var card_manager_reference
var deck_reference
@onready var tarot_manager_reference = $"../TarotManager"

func _ready() -> void:
	card_manager_reference = $"../CardManager"
	deck_reference = $"../Deck"
	

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			emit_signal("left_mouse_button_clicked")
			raycast_at_cursor()
		else:
			emit_signal("left_mouse_button_released")
			pass
			
func raycast_at_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	var result = space_state.intersect_point(parameters)
	
	print("=== RAYCAST at position: ", parameters.position, " ===")
	print("Total hits: ", result.size())
	
	if result.size() > 0:
		var result_collision_mask = result[0].collider.collision_mask
		print("Checking first hit — collision_mask value: ", result_collision_mask)

		if result_collision_mask == COLLISION_MASK_CARD:
			# CARD CLICKED
			print("Card detected")
			var card_found = result[0].collider.get_parent()
			if card_found:
				if card_found.card_data.get("is_tarot", false):
					# If it's tarot, we click it to activate
					card_found.on_clicked()
				elif tarot_manager_reference._awaiting_removal:
					# Removal mode active — route click to on_clicked() so
					# card_selected fires and TarotManager can handle it
					card_found.on_clicked()
					
				else:
					# normal card, just start dragging.
					card_manager_reference.start_drag(card_found)
		#elif result_collision_mask == COLLISION_MASK_DECK:
			#print("Deck detected — calling draw_card()")
			# DECK CLICKED, we remove this feature
			#deck_reference.draw_card()
			
				
