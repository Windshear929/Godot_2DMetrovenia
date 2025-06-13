class_name ItemData
extends Resource

enum ItemType {
	MATERIAL,
	EQUIPMENT,
}

@export var item_type: ItemType = ItemType.MATERIAL
@export var item_name: String = ""
@export var item_icon: Texture2D
@export var item_id: String = ""
@export_range(0.0, 100.0) var drop_chance: float = 0.0

func get_description() -> String:
	return ""
