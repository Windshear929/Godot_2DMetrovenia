class_name C_Inventory
extends Node

@export var item_slot_count: int = 20

var items: Array[Item] = []

signal inventory_changed

func _ready() -> void:
	items.resize(item_slot_count) # 给背包添加20个空槽位

## 添加道具
func add_item(item: Item):
	var empty_slot: int = get_empty_item_slot_index()
	if empty_slot == -1: return
	items[empty_slot] = item
	inventory_changed.emit()

## 获取当前空的背包槽
func get_empty_item_slot_index() -> int:
	var index: int = 0
	for slot in items:
		if slot == null:
			return index
		index += 1 
	return -1
