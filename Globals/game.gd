extends Node

#signal game_start

const SAVE_PATH := "user://brave.sav"

# 场景的名称 => {
# 	enemies_alive => [ 敌人的路径 ]
# }
var world_states := {}
var player: Player = null

@onready var player_stats: Stats = $PlayerStats
@onready var color_rect: ColorRect = $ColorRect
@onready var default_player_stats := player_stats.to_dict()

func _ready() -> void:
	color_rect.color.a = 0

func register_player(p: Player) -> void:
	player = p

func change_scene(path: String, params := {}) -> void:
	var duration := params.get("duration", 0.2) as float
	
	var tree := get_tree()
	tree.paused = true
	
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 1, duration)
	await tween.finished
	
	# 切换场景前获取该场景的名称并赋值给old_scene,并根据该场景名记录场景状态
	if tree.current_scene is World:
		var old_scene := tree.current_scene.scene_file_path.get_file().get_basename()
		world_states[old_scene] = tree.current_scene.to_dict()
		#print("world_states 内容: ", world_states)
	
	tree.change_scene_to_file(path)
	if "init" in params:
		params.init.call()
	
	await tree.tree_changed # 等待节点树切换
	
	# 切换场景后获取新场景名称并赋值给new_scene,当该场景状态曾经被记录过时，才调取场景状态的数据
	if tree.current_scene is World:
		var new_scene := tree.current_scene.scene_file_path.get_file().get_basename()
		if new_scene in world_states:
			await tree.process_frame
			tree.current_scene.from_dict(world_states[new_scene])
		
		if "entry_point" in params:
			for node in tree.get_nodes_in_group("entry_points"):
				if node.name == params.entry_point:
					await tree.process_frame
					tree.current_scene.update_player(node.global_position, node.direction)
					break
		
		if "position" in params and "direction" in params:
			await tree.process_frame
			tree.current_scene.update_player(params.position, params.direction)
	
	tree.paused = false
	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 0, duration)


func new_game() -> void:
	change_scene("res://Scene/forest.tscn", {
		duration = 1,
		init = func ():
			world_states = {}
			player_stats.from_dict(default_player_stats)
	})


func save_game() -> void:
	var scene := get_tree().current_scene
	var scene_name := scene.scene_file_path.get_file().get_basename()
	world_states[scene_name] = scene.to_dict()
	
	var data := {
		world_states = world_states,
		stats = player_stats.to_dict(),
		scene = scene.scene_file_path,
		player = {
			direction = scene.player.direction,
			position = {
				x = scene.player.global_position.x,
				y = scene.player.global_position.y,
				},
		}
	}
	
	var json = JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(json)


func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := file.get_as_text()
	var data := JSON.parse_string(json) as Dictionary
	
	change_scene(data.scene, {
		direction = data.player.direction,
		position = Vector2(
			data.player.position.x,
			data.player.position.y,
		),
		init = func ():
			world_states = data.world_states
			player_stats.from_dict(data.stats)
	})


func back_to_title() -> void:
	change_scene("res://UI/title_screen.tscn", {
		duration = 1,
	})


func save_file_exist() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
