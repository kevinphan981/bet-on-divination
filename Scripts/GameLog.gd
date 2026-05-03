# GameLog.gd (autoload as "GameLog")
extends Node

const MAX_LINES = 20
var lines: Array = []

signal log_updated

func add(message: String) -> void:
	lines.append("[color=#aaaaaa]>[/color] " + message)
	if lines.size() > MAX_LINES:
		lines.pop_front()
	emit_signal("log_updated")

func get_display_text() -> String:
	# Most recent at the bottom
	return "\n".join(lines)
	
#func round_start(round_number: int) -> void:
	#lines.append("")
	#lines.append("[center][color=#556677]—————— Round %d ——————[/color][/center]" % round_number)
	#if lines.size() > MAX_LINES:
		#lines.pop_front()
	#emit_signal("log_updated")
	
func divider(label: String) -> void:
	lines.append("")
	lines.append("[color=#7aaabb]◆ %s[/color]" % label.to_upper())
	lines.append("")
	_trim_and_notify()

func _trim_and_notify() -> void:
	while lines.size() > MAX_LINES:
		lines.pop_front()
	emit_signal("log_updated")

	
func round_over() -> void:
	lines.append("[center][color=#445566]———————————————[/color][/center]")
	lines.append("")
	if lines.size() > MAX_LINES:
		lines.pop_front()
	emit_signal("log_updated")
