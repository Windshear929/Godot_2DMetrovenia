extends Control

@export var bgm : AudioStream

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	hide()
	set_process_input(false) # 通知引擎不要处理该脚本中的_input函数


func _input(event: InputEvent) -> void:
	get_window().set_input_as_handled()
	
	if animation_player.is_playing():
		return
	
	if (
		event is InputEventKey or 
		event is InputEventMouseButton or 
		event is InputEventJoypadButton
		):
		if event.is_pressed() and not event.is_echo(): # echo为回显事件，即长按按键后不断发送按键信息的事件
			if Game.save_file_exist():
				Game.load_game()
			else:
				Game.back_to_title()


func show_game_over() -> void:
	show()
	set_process_input(true)
	animation_player.play("enter")
	SoundManager.play_bgm(bgm)
