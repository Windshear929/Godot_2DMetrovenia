class_name World
extends Node2D

@export var geometry: TileMapLayer
@export var bgm : AudioStream
@export var boss_battle : AudioStream

@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var player: Player = $Player
@onready var w_inventory: MarginContainer = %W_Inventory

var boss_was_dead: float = false

signal holding_camera

func _ready() -> void:
	_player_get_effects()
	var used := geometry.get_used_rect().grow(-1) # 获取关卡矩形尺寸中非空的图块左上和右下的坐标
	var tile_size := geometry.tile_set.tile_size # 获取瓦片地图的图块单位尺寸
	
	# 这里的position是关卡矩形左上角的点；end是关卡矩形右小角的点。这里理解get_used_rect()只是获取了坐标，但是没有图块的尺寸
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.reset_smoothing()
	
	if bgm:
		SoundManager.play_bgm(bgm)
	
	w_inventory.c_inventory = player.get_node("C_Inventory")

func _player_get_effects() -> void:
	Game.player_stats.ignite_fx = player.find_child("IgniteEffects", true, false)
	Game.player_stats.freeze_fx = player.find_child("FreezeEffects", true, false)
	Game.player_stats.shock_fx = player.find_child("ShockEffects", true, false)
	Game.player_stats.element_fx_timer = player.find_child("ElementTimer", true, false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.back_to_title()


func update_player(pos: Vector2, direction: Player.Direction) -> void:
	player.global_position = pos
	player.fall_from_height = pos.y
	player.direction = direction
	camera_2d.reset_smoothing()
	camera_2d.force_update_scroll()


func hold_camera(target_mark: Marker2D) -> void:
	var camera_pos = camera_2d.global_position
	player.remove_child(camera_2d)
	add_child(camera_2d)
	camera_2d.global_position = camera_pos
	camera_2d.reset_smoothing()
	
	var tween = create_tween()
	tween.tween_property(camera_2d, "global_position", target_mark.global_position, 0.2)
	await  tween.finished
	holding_camera.emit()


func move_camera(original_mark: Marker2D) -> void:
	remove_child(camera_2d)
	player.add_child(camera_2d)
	camera_2d.global_position = original_mark.global_position
	camera_2d.reset_smoothing()
	
	var tween = create_tween()
	tween.tween_property(camera_2d, "global_position", player.global_position, 0.2)


func to_dict() -> Dictionary:
	var boss_alive = []
	for node in get_tree().get_nodes_in_group("boss"):
		var path := get_path_to(node) as String
		boss_alive.append(path)
	
	#print("Enemies alive paths: ", boss_alive)
	#for i in boss_alive.size():
		#print("Enemy %d: %s" % [i, boss_alive[i]])
	
	return {
		boss_alive = boss_alive,
	}


func from_dict(dict: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group("boss"):
		var path := get_path_to(node) as String
		if path not in dict.boss_alive:
			node.queue_free()
