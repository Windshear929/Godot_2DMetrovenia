extends Node2D

var object_file: Item_data = null

@onready var texture_rect: TextureRect = $TextureRect
@onready var player_check: Area2D = $PlayerCheck
@onready var timer: Timer = $Timer


func _ready() -> void:
	player_check.monitoring = false

func _process(delta: float) -> void:
	if timer.time_left > 0:
		player_check.monitoring = false
	player_check.monitoring = true


func _on_player_check_area_entered(area: Area2D) -> void:
	if area != null:
		Game.c_inventory.add_item(object_file)
		print("玩家大人把我捡走啦！")
		queue_free()
