extends MarginContainer

var c_inventory: C_Inventory = null

func _ready() -> void:
	pass


func initialize() -> void:
	c_inventory.inventory_changed.connect(inventory_update)


func inventory_update() -> void:
	print("inventory_update, ", c_inventory.items)
