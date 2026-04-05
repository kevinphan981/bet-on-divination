extends Control

func _ready():
	visible = false
	$AnimationPlayer.play("RESET")

func resume():
	get_tree().paused = false
	print("Playing blur")
	$AnimationPlayer.play_backwards("Blur")
	print("finished blur, returning.")
	visible = false # Usually you'll want to hide the menu too!

func pause():
	#visible = true # do I need this? or too much?
	get_tree().paused = true
	visible = true
	print("Playing blur")
	$AnimationPlayer.play("Blur")
	

func testEsc():
	if Input.is_action_just_pressed("esc") and get_tree().paused == false:
		print("Escape key pushed")
		pause()
	elif Input.is_action_just_pressed("esc") and get_tree().paused == true:
		print("Escape key pushed")
		resume()
		

func _on_resume_pressed() -> void:
	resume()

# this works
func _on_restart_pressed() -> void:
	resume() #technically doesn't make sense
	get_tree().reload_current_scene()

# this works because of how direct it is
func _on_quit_pressed() -> void:
	get_tree().quit
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _process(delta):
	testEsc()
	
