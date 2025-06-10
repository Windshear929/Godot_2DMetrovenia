class_name EntryPoint
extends Marker2D

@export var direction := Player.Direction.RIGHT

func _ready() -> void:
	add_to_group("entry_points")
	#print_group_members("entry_points")

func print_group_members(group_name: String):
	var menbers = get_tree().get_nodes_in_group(group_name)
	print("组 '%s' 的成员: " % group_name)
	for node in menbers:
		print("- ", node.name, " (", node.get_path(), ")")
