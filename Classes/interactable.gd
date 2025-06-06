class_name Interactable
extends Area2D

signal interacted


func _init() -> void:
	# 重置碰撞的层级和对象
	collision_layer = 0
	collision_mask = 0
	
	# 设置可碰撞对象为Player
	set_collision_mask_value(2, true)
	
	# 此处两个Area2D信号用于判断物理对象和TileSet物理层的碰撞关系
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func interact() -> void:
	#print("[Interact] ", name)
	interacted.emit()

func _on_body_entered(player: Player) -> void:
	# 玩家进入碰撞区域是可互动对象为类本体
	player.add_interactable_obj(self)

func _on_body_exited(player: Player) -> void:
	player.subtract_interactable_obj(self)
