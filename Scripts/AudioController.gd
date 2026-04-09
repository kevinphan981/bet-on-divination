extends Node2D

@export var mute: bool = false

func _ready():
	if not mute:
		play_music()

func play_music():
	if not mute:
		$Song1.play()
