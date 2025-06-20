extends RigidBody2D

var object_file: Item_data = null

@onready var texture_rect: TextureRect = $TextureRect
@onready var player_check: Area2D = $PlayerCheck
@onready var floor_check: RayCast2D = $FloorCheck


func _ready() -> void:
	player_check.monitoring = false


func _process(delta: float) -> void:
	if rotation != 0:
		rotation = 0
		
	if floor_check.is_colliding():
		player_check.monitoring = true


func _on_player_check_area_entered(area: Area2D) -> void:
	if area != null:
		Game.c_inventory.add_item(object_file)
		print("玩家大人把我捡走啦！")
		queue_free()
