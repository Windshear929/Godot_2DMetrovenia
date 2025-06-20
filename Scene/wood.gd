extends World

@onready var target_cam_pos: Marker2D = $TargetCamPos
@onready var plantform: TileMapLayer = $Cave/Plantform
@onready var door: CharacterBody2D = $Cave/Door
@onready var door_player: AnimationPlayer = $DoorPlayer
@onready var detect_area: Area2D = $DetectArea
@onready var wild_boar: CharacterBody2D = $WildBoar


func _ready() -> void:
	super()
	
	door_player.play("idle_close")
	
	wild_boar.boss_dead.connect(after_boss_dead)
	holding_camera.connect(wild_boar.boss_health_bar.show_boss_health) # 这样调取函数都可以

func _process(delta: float) -> void:
	var boss_exist :=  get_tree().get_nodes_in_group("boss")
	if not boss_exist:
		door_player.play("idle_open")
		detect_area.monitoring = false


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
