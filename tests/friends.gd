extends Node
func _ready():
	print("FRIENDS=", Net.online_friends().size())
	get_tree().quit()
