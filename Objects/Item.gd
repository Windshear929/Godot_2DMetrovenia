class_name Item
extends Resource

## 所有的道具都是一个抽象的自定义数据，这是所有道具的基类

## 道具类型
enum Item_Type {
	## 未知
	NONE,
	## 消耗品
	CONSUMABLE,
	## 装备
	EQUIPMENT,
	## 材料
	MATERIAL,
}

## 道具名称
@export var name: String = "Name"
## 道具描述
@export var description: String = "Description"
## 道具图标
@export var icon: Texture = null
## 道具类型
@export var item_type: Item_Type = Item_Type.NONE
## 道具最大堆叠数量
@export var max_stack := 1
## 道具当前堆叠数量
@export var quantity := 1 :
	set(value):
		quantity_changed.emit(value)
		quantity = value
## 道具提供的属性（如果需要）
@export var attributes: Dictionary = {
	
}

## 道具数量发生改变时发出信号
signal quantity_changed(value: int)
