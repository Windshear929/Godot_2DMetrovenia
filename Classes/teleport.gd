class_name  Teleport
extends Interactable

@export_file("*.tscn") var path: String
@export var entry_point: String

func interact() -> void:
	super() # 调用父类中同名函数的功能
	Game.change_scene(path, { entry_point = entry_point })
