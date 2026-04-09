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

const TAROT_DATA = [{ "name": "The Fool",        "power": "skip_bust",     "desc": "Your next bust is ignored." },
	{ "name": "The Magician",    "power": "peek_dealer",   "desc": "Reveal the dealer's hidden card." },
	{ "name": "The High Priestess","power":"freeze_dealer","desc": "Dealer must skip their next draw." },
	{ "name": "The Empress",     "power": "heal_years",    "desc": "Gain 10 years regardless of outcome." },
	{ "name": "The Emperor",     "power": "double_wager",  "desc": "Your wager pays double this round." },
	{ "name": "The Hierophant",  "power": "peek_deck",     "desc": "See the top 3 cards of the deck." },
	{ "name": "The Lovers",      "power": "exchange",      "desc": "Swap one of your cards for a fresh draw." },
	{ "name": "The Chariot",     "power": "extra_hit",     "desc": "Draw one extra card beyond the hand limit." },
	{ "name": "Strength",        "power": "ace_toggle",    "desc": "Toggle one Ace between 11 and 1." },
	{ "name": "The Hermit",      "power": "remove_card",   "desc": "Remove any one card from your hand." },
	{ "name": "Wheel Of Fortune","power": "randomize_wager","desc":"Your wager is randomized up to 5×." },
	{ "name": "Justice",         "power": "push_force",    "desc": "Force a push — reclaim your wager." },
	{ "name": "The Hanged Man",  "power": "invert_score",  "desc": "Your score counts down from 21 this turn." },
	{ "name": "Death",           "power": "clear_hand",    "desc": "Discard your hand and redraw fresh." },
	{ "name": "Temperance",      "power": "halve_bust",    "desc": "If you bust, lose only half the wager." },
	{ "name": "The Devil",       "power": "steal_years",   "desc": "Steal 5 years directly from the dealer pool." },
	{ "name": "The Tower",       "power": "dealer_bust",   "desc": "Force the dealer to draw until they bust or hit 21." },
	{ "name": "The Star",        "power": "restore_years", "desc": "Restore years to your round-start amount if you lose." },
	{ "name": "The Moon",        "power": "debt_forgiveness",    "desc": "If player loses everything, they are revived with 1 year." },
	{ "name": "The Sun",         "power": "win_force",     "desc": "Force a win if your score is 15 or higher." },
	{ "name": "Judgement",       "power": "reveal_all",    "desc": "Reveal all dealer cards immediately." },
]

const TAROT_DRAW_CHANCE = 0.25 #change depending on game play

# Full deck of 52 cards as [ {name, suit, value} ]
var full_deck = []
var draw_pile = []
var tarot_pile = []  # separate, reshuffles independently

func _ready():
	build_deck()
	shuffle_deck()
	build_tarot_pile()


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


func build_tarot_pile():
	tarot_pile.clear()
	# We use a loop with an index (i) to generate the numbers 00, 01, 02...
	for i in range(TAROT_DATA.size()):
		var entry = TAROT_DATA[i]
		
		# Format the index as a two-digit string (e.g., 0 becomes "00", 1 becomes "01")
		var number_prefix = "%02d" % i
		# Remove spaces from the name (e.g., "The Fool" becomes "TheFool")
		var formatted_name = entry.name.replace(" ", "")

		tarot_pile.append({
			"name" : entry.name,
			"suit" : "tarot",
			"value": 0,
			"is_tarot": true,
			"power": entry.power,
			"desc": entry.desc,
			# Adjust path to wherever your tarot art lives
			"texture_path": "res://Assets/Cards/%s-%s.png" % [number_prefix, formatted_name]
		})
	tarot_pile.shuffle()

# still useful but more for the dealer now
func draw_card_db() -> Dictionary:
	if draw_pile.is_empty():
		print("Deck is empty! Reshuffling...")
		shuffle_deck()
	return draw_pile.pop_back()

# Player-specific draw — has a chance to give a tarot card instead
func draw_card_for_player() -> Dictionary:
	var roll = randf()
	print("Drawing for player: Roll was ", roll, " | Chance: ", TAROT_DRAW_CHANCE)
	
	if roll < TAROT_DRAW_CHANCE and not tarot_pile.is_empty():
		var card = tarot_pile.pop_back()
		print("Drawing Tarot: ", card.name) 
		return card
		
	var card = draw_card_db()
	print("Drawing Standard: ", card.name)# [cite: 4]
	return card

# gets rid of the hand
func clear_table():
	for card in $"../PlayerHand".hand:
		card.queue_free()
	$"../PlayerHand".hand.clear()

	CardDatabase.shuffle_deck()
	CardDatabase.build_tarot_pile()  # ← NEW: reshuffle tarot between rounds
