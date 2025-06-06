extends World

@onready var target_cam_pos: Marker2D = $TargetCamPos
@onready var plantform: TileMapLayer = $Cave/Plantform
@onready var door: CharacterBody2D = $Cave/Door
@onready var door_player: AnimationPlayer = $DoorPlayer
@onready var detect_area: Area2D = $DetectArea
@onready var wild_boar: CharacterBody2D = $WildBoar


func _ready() -> void:
	var combined_used := get_combine_used_rect()
	var used := combined_used.grow(-1) # 获取关卡矩形尺寸中非空的图块左上和右下的坐标
	var tile_size := geometry.tile_set.tile_size # 获取瓦片地图的图块单位尺寸
	
	# 这里的position是关卡矩形左上角的点；end是关卡矩形右小角的点。这里理解get_used_rect()只是获取了坐标，但是没有图块的尺寸
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.reset_smoothing()
	
	door_player.play("idle_close")
	
	wild_boar.boss_dead.connect(after_boss_dead)
	holding_camera.connect(wild_boar.boss_health_bar.show_boss_health) # 这样调取函数都可以
	#print("信号连接状态: ", $WildBoar.boss_dead.is_connected(after_boss_dead))

func _process(delta: float) -> void:
	var boss_exist :=  get_tree().get_nodes_in_group("boss")
	if not boss_exist:
		door_player.play("idle_open")
		detect_area.monitoring = false

func get_combine_used_rect() -> Rect2i:
	var rect1 := geometry.get_used_rect()
	var rect2 := plantform.get_used_rect()
	
	return rect1.merge(rect2)


func _on_detect_area_body_entered(body: Node2D) -> void:
	hold_camera(target_cam_pos)
	if boss_battle:
		SoundManager.play_bgm(boss_battle)
	else:
		print("boss_battle为null")

func after_boss_dead() -> void:
	boss_was_dead = true
	door_player.play("open")
	
	SoundManager.play_bgm(bgm)
	move_camera(target_cam_pos)


func _on_wild_boar_boss_dead() -> void:
	await get_tree().create_timer(1).timeout
	Game.change_scene("res://UI/game_end_screen.tscn", {
		duration = 1,
	})
