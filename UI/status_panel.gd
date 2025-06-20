extends HBoxContainer

@export var stats: Stats

@onready var health_bar: TextureProgressBar = $V/HealthBarFrame/HealthBar
@onready var eased_health_bar: TextureProgressBar = $V/HealthBarFrame/HealthBar/EasedHealthBar
@onready var avatar_box: PanelContainer = $AvatarBox
@onready var enegy_bar: TextureProgressBar = $V/EnegyBar

func _ready() -> void:
	if not stats:
		stats = Game.player_stats
	
	stats.health_change.connect(update_health)
	update_health(true)
	
	stats.energy_change.connect(update_energy)
	update_energy()
	
	if owner is Player:
		avatar_box.show()
		enegy_bar.show()
	elif owner is Enemy:
		avatar_box.hide()
		enegy_bar.hide()
	
	tree_exited.connect(func ():
		stats.health_change.disconnect(update_health)
		stats.energy_change.disconnect(update_energy)
		)

func update_health(skip_anim := false) -> void:
	var percentage := stats.health / float(stats.get_max_health())
	health_bar.value = percentage
	
	if skip_anim:
		eased_health_bar.value = percentage
	else:
		create_tween().tween_property(eased_health_bar, "value", percentage, 0.3)

func update_energy() -> void:
	var percentage : = stats.energy / stats.max_energy.get_value()
	enegy_bar.value = percentage
