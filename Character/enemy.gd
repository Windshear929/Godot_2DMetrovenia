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

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var pending_damage: Damage # 待处理的伤害

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = $Stats
@onready var sprite_2d: Sprite2D = $Graphics/Sprite2D

const SILVER = preload("res://Artwork/UI/Fort/Silver.ttf")

signal boss_dead

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
	if attacker_stats.total_damage > 0:
		pending_damage = Damage.new()
		pending_damage.amount = attacker_stats.total_damage
		pending_damage.source = attacker_hitbox.owner
		show_battle_info(attacker_stats.total_damage, global_position, attacker_stats)
		attacker_stats.total_damage = 0
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
	boss_dead.emit()
	queue_free()
