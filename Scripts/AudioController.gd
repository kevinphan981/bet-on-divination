extends Node2D

@export var mute: bool = false

func _ready():
	if not mute:
		play_music()

func play_music():
	if not mute:
		$Song1.play()

func play_card_draw():
	if not mute:
		$CardDraw.play()
		
func play_special_card_draw():
	if not mute:
		$SpecialCardDraw.play()

func play_special_card_activate():
	if not mute:
		$SpecialCardActivate.play()

func play_card_shuffle():
	if not mute:
		$CardShuffle.play()
