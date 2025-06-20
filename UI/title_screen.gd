extends Control

@export var bgm : AudioStream

@onready var v: VBoxContainer = $V
@onready var new_game: Button = $V/NewGame
@onready var load_game: Button = $V/LoadGame


func _ready() -> void:
	load_game.disabled = not Game.save_file_exist()
	
	new_game.grab_focus()
	
	for button: Button in v.get_children():
		button.mouse_entered.connect(button.grab_focus)
	
	if bgm:
		SoundManager.play_bgm(bgm)
	SoundManager.setup_ui_sounds(self)


func _on_new_game_pressed() -> void:
	Game.new_game()


func _on_load_game_pressed() -> void:
	Game.load_game()


func _on_exit_game_pressed() -> void:
	get_tree().quit()
