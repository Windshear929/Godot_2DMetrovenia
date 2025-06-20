extends Node
class_name C_Inventory

var inventory: Array[Item_data] = []

## 添加道具
func add_item(new_item: Item_data) -> void:
	var item_copy = new_item.duplicate()
	_add_item_internal(item_copy)


func _add_item_internal(item: Item_data) -> void:
	if item.quantity <= 0:
		return
	
	for existing_item in inventory:
		if _can_stack(existing_item, item):
			_stack_item(existing_item, item)
			return
	
	if item.quantity > 0:
		inventory.append(item)


## 检查物品是否可以堆叠
func _can_stack(item_a: Item_data, item_b: Item_data) -> bool:
	return (
		item_a.item_id == item_b.item_id and
		item_a.quantity < item_a.max_stack
	)


## 推叠物品并处理溢出
func _stack_item(target: Item_data, source: Item_data) -> void:
	var space_left = target.max_stack - target.quantity
	var amount_to_add =  min(source.quantity, space_left)
	
	target.quantity += amount_to_add
	source.quantity -= amount_to_add
	
	if source.quantity > 0:
		_add_item_internal(source)


## 背包整理
func sort_inventory() -> void:
	inventory.sort_custom(_compare_items)

## 排序规则
func _compare_items(a: Item_data, b: Item_data) -> bool:
	if a.item_type != b.item_type:
		return a.item_type < b.item_type
	return a.item_id < b.item_id
