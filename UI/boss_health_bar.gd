extends Control

@export var stats: Stats

@onready var boss_health_bar: TextureProgressBar = $VBoxContainer/BossHealthBar
@onready var eased_boss_health_bar: TextureProgressBar = $VBoxContainer/BossHealthBar/EasedBossHealthBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if not stats:
		push_error("未发现可用的Stats节点")
	hide()
	
	stats.health_change.connect(update_health)
	update_health(true)

func update_health(skip_anim := false) -> void:
	var percentage := stats.health / float(stats.get_max_health())
	boss_health_bar.value = percentage
	
	if skip_anim:
		eased_boss_health_bar.value = percentage
	else:
		create_tween().tween_property(eased_boss_health_bar, "value", percentage, 0.3)

func show_boss_health() -> void:
	show()
	animation_player.play("enter")
