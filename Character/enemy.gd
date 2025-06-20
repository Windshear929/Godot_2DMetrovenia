class_name Enemy
extends CharacterBody2D

enum Direction {
	LEFT = -1,
	RIGHT = 1,
}

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = -direction

@export var max_speed: float = 180
@export var acceleration: float = 2000

@export var drop_item_chance: float = 0.0
@export var drop_item_data1: Item_data = null
@export var drop_item_data2: Item_data = null


var frozen_speed: float = max_speed * 0.6
var current_speed: float = max_speed

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var pending_damage: Damage # 待处理的伤害

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = $Stats
@onready var sprite_2d: Sprite2D = $Graphics/Sprite2D

const SILVER = preload("res://Artwork/UI/Fort/Silver.ttf")
const ITEM_OBJECT = preload("res://Objects/item_object.tscn")

@warning_ignore("unused_signal")
signal boss_dead

func _ready() -> void:
	stats.frozen.connect(_on_frozen)

func _on_frozen() -> void:
	current_speed = frozen_speed
	animation_player.speed_scale = 0.6
	await stats.element_fx_timer.timeout
	current_speed = max_speed
	animation_player.speed_scale = 1

func turn_around():
	if direction == Direction.LEFT:
		direction = Direction.RIGHT
	else:
		direction = Direction.LEFT

func move(speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, speed * direction, acceleration * delta)
	velocity.y += default_gravity * delta
	
	move_and_slide()

func on_take_damage(attacker_stats: Stats, attacker_hitbox: Hitbox) -> void:
	attacker_stats.do_damage(stats)
	attacker_stats.do_magic_damage(stats)
	if attacker_stats.total_damage > 0 or attacker_stats.total_m_damage > 0:
		pending_damage = Damage.new()
		pending_damage.amount = attacker_stats.total_damage + attacker_stats.total_m_damage
		pending_damage.source = attacker_hitbox.owner
		if attacker_stats.total_damage > 0 and attacker_stats.total_m_damage <= 0:
			show_battle_info(attacker_stats.total_damage, global_position, attacker_stats)
		elif attacker_stats.total_damage > 0 and attacker_stats.total_m_damage > 0:
			show_battle_info(attacker_stats.total_damage + attacker_stats.total_m_damage, global_position, attacker_stats)
		attacker_stats.total_damage = 0
		attacker_stats.total_m_damage = 0
		stats.health -= pending_damage.amount
		print("%s受到了%s的伤害" % [stats.owner.name, pending_damage.amount])
		
		attacker_stats.energy += attacker_stats.attack_energy_regenerate.get_value()

func boss_hurt_effect() -> void:
	var shader_material := sprite_2d.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("quantity", 1.0)
		var tween = create_tween()
		tween.tween_property(shader_material, "shader_parameter/quantity", 0.0, 0.3)

func show_battle_info(value: int, pos: Vector2, _attacker_stats: Stats):
	pos.y -= sprite_2d.texture.get_height()
	
	var label = Label.new()
	
	label.text = str(value)
	label.position = pos
	label.add_theme_font_override("Font", SILVER)
	
	if _attacker_stats.is_critical_attack:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.DARK_ORANGE)
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color.FIREBRICK)
	else:
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color.WHITE)
	
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y - 30.0, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func die():
	stats.is_element_affect = false
	queue_free()


func can_drop_item() -> bool:
	# TODO: 关于luck属性影响道具掉落的数值还要设法优化
	var total_chance = drop_item_chance + Game.player_stats.luck.get_value() * 0.01
	print("该角色道具掉落的概率为：", total_chance * 100, "%")
	var percentage = randf()
	print("本次道具掉率计算结果为：", snapped(percentage, 0.01) * 100, "%")
	if percentage < total_chance:
		return true
	return false


func drop_item() -> void:
	var _drop_item = ITEM_OBJECT.instantiate()
	_drop_item.position = self.global_position - Vector2(0, 5)
	_drop_item.linear_velocity = Vector2(randf_range(50.0, -50.0), -300.0)
	get_parent().add_child(_drop_item)
	var item_data: Item_data = null
	if drop_item_data2 != null:
		var pecentage = randf()
		if pecentage < 0.7:
			item_data = drop_item_data1
		else:
			item_data = drop_item_data2
	_drop_item.texture_rect.texture = item_data.item_icon
	_drop_item.object_file = item_data
