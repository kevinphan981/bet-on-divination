extends Control


func _on_start_pressed() -> void:
	print("Pressed Start.")
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_options_pressed() -> void:
	print("Pressed Options.")


func _on_exit_pressed() -> void:
	print("Pressed Exit.")
