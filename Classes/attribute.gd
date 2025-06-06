class_name Attribute
extends Resource

@export var base_value: int = 0
@export var modifiers: Array = []

func get_value() -> int:
	var final_value = base_value
	for modifier in modifiers:
		final_value += modifier
	return final_value

func set_default_value(value: int) -> void:
	base_value = value

func add_modifier(modifier: int) -> void:
	modifiers.append(modifier)

func remove_modifier(modifier: int) -> void:
	modifiers.erase(modifier)

func to_dict() -> Dictionary:
	return {
		"base_value": base_value,
		"modifiers": modifiers.duplicate()
	}

func from_dict(dict: Dictionary) -> void:
	base_value = dict.get("base_value", base_value)
	modifiers = dict.get("modifiers",[]).duplicate() 
