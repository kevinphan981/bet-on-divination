extends Node2D

signal hovered
signal hovered_off

var position_in_hand
var card_data = {}
var is_face_down = false

#func setup(data: Dictionary):
	#card_data = data
	#print("Loading texture: ", card_data.texture_path)
	#$"Sprite2Dimage".texture = load(card_data.texture_path)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# when card instantiates, it must be child of cardmanager
	get_parent().connect_card_signals(self)
	
	# testing
	print(get_tree().get_nodes_in_group(""))  # temp
	for child in get_children():
		print("Child: ", child.name, " | Type: ", child.get_class())


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)
	


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
	
