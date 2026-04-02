extends Node

const CARD_DATA = {
	"Ace": 11,
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6,
	"7": 7, "8": 8, "9": 9, "10": 10,
	"Jack": 10, "Queen": 10, "King": 10
}

# Maps card name to its file number
const CARD_NUMBER = {
	"Ace": "01",
	"2": "02", "3": "03", "4": "04", "5": "05", "6": "06",
	"7": "07", "8": "08", "9": "09", "10": "10",
	"Jack": "11", "Queen": "12", "King": "13"
}
const SUIT_PREFIX = {
	"Cups": "Cups",
	"Pentacles": "Pentacles",
	"Wands": "Wands",
	"Swords": "Swords"
}

const SUITS = ["Cups", "Pentacles", "Wands", "Swords"]

# Full deck of 52 cards as [ {name, suit, value} ]
var full_deck = []
var draw_pile = []

func _ready():
	build_deck()
	shuffle_deck()  # add this

func build_deck():
	full_deck.clear()
	for suit in SUITS:
		for card_name in CARD_DATA.keys():
			full_deck.append({
				"name": card_name,
				"suit": suit,
				"value": CARD_DATA[card_name],
				"texture_path": "res://Assets/Cards/%s%s.png" % [SUIT_PREFIX[suit], CARD_NUMBER[card_name]]
			})

func shuffle_deck():
	draw_pile = full_deck.duplicate()
	draw_pile.shuffle()

func draw_card_db() -> Dictionary:
	if draw_pile.is_empty():
		print("Deck is empty! Reshuffling...")
		shuffle_deck()
	return draw_pile.pop_back()
