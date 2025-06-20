extends Resource
class_name Item_data

enum Item_Type {
	MATERIAL,
	EQUIPMENT,
	CONSUMABLE,
}

@export var item_id: String = ""
@export var item_name: String = "Name"
@export var description: String = "Description"
@export var item_type: Item_Type = Item_Type.MATERIAL
@export var item_icon: Texture2D = null
@export var max_stack: int = 1
@export var quantity: int = 1
