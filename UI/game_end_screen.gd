extends Control

const LINES := [
	"传说之路走到了终点",
	"勇者终于兑现了人民的期待",
	"世界恢复了往日的协和与宁静",
	"然而",
	"只有勇者知道",
	"一切的真相就这样放入了潘多拉魔盒",
	"完",
]

var current_line := -1
var tween: Tween

@onready var label: Label = $Label

func _ready() -> void:
	show_line(0)

func _input(event: InputEvent) -> void:
	if tween.is_running():
		return
	
	if (event is InputEventKey or 
		event is InputEventMouseButton or 
		event is InputEventJoypadButton
		):
		if event.is_pressed() and not event.is_echo(): # echo为回显事件，即长按按键后不断发送按键信息的事件
			if current_line + 1 < LINES.size():
				show_line(current_line + 1)
			else:
				Game.back_to_title()

func show_line(line: int) -> void:
	current_line = line
	
	tween = create_tween()
	# 先设置缓动类型为淡入淡出，再设置过度曲线为sin曲线
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	if line > 0:
		tween.tween_property(label, "modulate:a", 0, 1)
	else:
		label.modulate.a = 0
	
	tween.tween_callback(label.set_text.bind(LINES[line]))
	tween.tween_property(label, "modulate:a", 1, 1)
