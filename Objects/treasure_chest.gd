extends Interactable

const EQUIPMENT_OBJECT = preload("res://Objects/equipment_object.tscn")

@export var chest_item: Item_data = null

@onready var opened: Sprite2D = $Opened

var chest_opened: bool = false

func _ready() -> void:
	if chest_opened:
		opened.visible = true
		monitoring = false


func interact() -> void:
	super()
	
	opened.visible = true
	chest_opened = true
	monitoring = false
	
	var drop_item = EQUIPMENT_OBJECT.instantiate()
	drop_item.z_index = 1
	drop_item.position = self.global_position - Vector2(0, 20)
	get_parent().add_child(drop_item)
	drop_item.texture_rect.texture = chest_item.item_icon
	drop_item.object_file = chest_item
	drop_item.timer.start()


func get_state() -> Dictionary:
	return {
		"is_opened" = chest_opened,
	}

func set_state(data: Dictionary) -> void:
	if data.has("is_opened"):
		chest_opened = data["is_opened"]
