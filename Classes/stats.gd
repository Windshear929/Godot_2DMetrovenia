class_name Stats
extends Node

signal health_change
signal energy_change
signal target_dodge
signal frozen

@export var ignite_fx: AnimatedSprite2D
@export var freeze_fx: AnimatedSprite2D
@export var shock_fx: AnimatedSprite2D
@export var element_fx_timer: Timer

@export_category("主要属性")
@export var strength: Attribute = Attribute.new() ## 每点属性值直接影响角色的攻击力，0.5倍影响角色的暴击伤害
## 敏捷属性分阶段影响回避率
## 属性值(1-10): evasion = 0.5 * agility;
## 属性值(11-30): evasion = 4 + (agility - 10) * 1.25;
## 属性值(>31): evasion = 30 + (agility -30) * 0.2;
@export var agility: Attribute = Attribute.new()
@export var intelligence: Attribute = Attribute.new() ## 每点属性直接影响魔法伤害
@export var vitality: Attribute = Attribute.new() ## 每点属性增加5点最大生命值上限，0.2倍影响角色的防御
@export var luck: Attribute = Attribute.new() ## 暴击率 = 50% * (1- e^(-k * luck):luck属性影响暴击率上限不会超过50%

@export_category("进攻属性")
@export var damage: Attribute = Attribute.new()
@export var crit_chance: Attribute = Attribute.new()
@export var crit_power: Attribute = Attribute.new()

@export_category("防守属性")
@export var max_health: Attribute = Attribute.new()
@export var armour: Attribute = Attribute.new()
@export var evasion: Attribute = Attribute.new()
@export var magic_resist: Attribute = Attribute.new()

@export_category("能量属性")
@export var max_energy: Attribute = Attribute.new()
@export var energy_regenerate: Attribute = Attribute.new()
@export var attack_energy_regenerate: Attribute = Attribute.new()

@export_category("魔法属性")
@export var fire_damage: Attribute = Attribute.new() ## 攻击让角色进入点燃状态，持续损失生命值
@export var ice_damage: Attribute = Attribute.new() ## 攻击有50%概率让角色冰冻，降低行为速度
@export var thunder_damage: Attribute = Attribute.new() ## 攻击让角色进入震颤状态，防御值和抵抗值无效

# @export初始化顺序高于@onready，借此让用户在检查器修改max_health后也可以有效的更新health的值，以免导入默认max_health的值
@onready var health: int = get_max_health():
	set(v):
		v = clampi(v, 0, get_max_health())
		if health == v:
			return
		health = v
		health_change.emit()

@onready var energy: float = max_energy.get_value():
	set(v):
		v = clampf(v, 0, max_energy.get_value())
		if energy == v:
			return
		energy = v
		energy_change.emit()

var total_damage: int = 0
var total_m_damage: int = 0
var is_dodge_attack: bool = false
var is_critical_attack: bool = false
var is_element_affect: bool = false
var ignite_damage_timer: Timer
var is_shock: bool = false

func _init() -> void:
	crit_power.set_default_value(150)

func _ready() -> void:
	print("%s初始生命为： %s" % [owner.name, health])
	
	## 点燃状态自动扣血
	ignite_damage_timer = Timer.new()
	add_child(ignite_damage_timer)
	ignite_damage_timer.wait_time = 0.3
	ignite_damage_timer.timeout.connect(_on_ignited_damage)

func _process(delta: float) -> void:
	energy += energy_regenerate.get_value() * delta

func _on_ignited_damage() -> void:
	health -= roundi(get_max_health() * 0.01)

func get_max_health() -> int:
	return max_health.get_value() + vitality.get_value() * 5

func do_damage(_target_stats: Stats) -> void:
	is_dodge_attack = target_can_avoid_attack(_target_stats)
	if is_dodge_attack:
		target_dodge.emit()
		return
	
	total_damage = damage.get_value() + strength.get_value()
	is_critical_attack = can_crit()
	
	if is_critical_attack:
		total_damage = calculate_critical_damage(total_damage)
	
	if is_shock: return
	total_damage = check_target_armour(_target_stats, total_damage)


func do_magic_damage(_target_stats: Stats) -> void:
	# TODO: 考虑将属性防御分解成3个属性，并一一对应属性攻击，并将抗性设置为百分比，超过百分比回血等设计
	var _fire_damage = fire_damage.get_value()
	var _ice_damage = ice_damage.get_value()
	var _thunder_damage = thunder_damage.get_value()
	
	if _target_stats.health <= 0:
		_target_stats.is_element_affect = false
	
	if _fire_damage == 0 and _ice_damage == 0 and _thunder_damage == 0:
		return
	# 设置元素伤害判断条件
	var can_ignite_damage: bool = _fire_damage > _ice_damage and _fire_damage > _thunder_damage
	var can_freeze_damage: bool = _ice_damage > _fire_damage and _ice_damage > _thunder_damage
	var can_shock_damage: bool = _thunder_damage > _fire_damage and _thunder_damage > _ice_damage
	
	if can_ignite_damage:
		print("Ignited! Fire Damage: ", _fire_damage)
	if can_freeze_damage:
		print("Freeze! Ice Damage: ", _ice_damage)
	if can_shock_damage:
		print("Shock! Thunder Damage: ", _thunder_damage)
	
	if not can_ignite_damage and not can_freeze_damage and not can_shock_damage:
		return
		
	element_effect(_target_stats, can_ignite_damage, can_freeze_damage, can_shock_damage)
	
	total_m_damage = _fire_damage + _ice_damage + _thunder_damage + intelligence.get_value()
	
	if is_shock: return
	total_m_damage = check_target_resist(_target_stats, total_m_damage)

func element_effect(target: Stats, can_ignite: bool, can_freeze: bool, can_shock: bool) -> void:
	# 这里要用一个值去确认角色的状态是否已经是在异常状态中，在状态中则中断函数
	if target.is_element_affect:
		return
	
	target.is_element_affect = true
	if can_ignite:
		target.ignite_damage_timer.start()
		show_effects(target, target.ignite_fx, "ignite", Color.ORANGE)
	if can_freeze:
		if randf() < 0.5:
			target.frozen.emit()
			show_effects(target, target.freeze_fx, "freeze", Color.DODGER_BLUE)
		else: target.is_element_affect = false
	if can_shock:
		is_shock = true
		show_effects(target, target.shock_fx, "shock", Color.GOLD)

func show_effects(target: Stats, anim: AnimatedSprite2D, anim_name: String, color: Color) -> void:
	if target.get_parent().is_in_group("boss"):
		var material := target.get_parent().find_child("Sprite2D", true, false).material as ShaderMaterial
		material.set_shader_parameter("effect_tint", 1.0)
		anim.visible = true
		anim.play(anim_name)
		material.set_shader_parameter("target_color", color)
		target.element_fx_timer.start()
		await anim.animation_finished
		anim.visible = false
		await target.element_fx_timer.timeout
		material.set_shader_parameter("target_color", Color.WHITE)
		target.ignite_damage_timer.stop()
		is_shock = false
		target.is_element_affect = false
	else:
		var node
		if target.name == "PlayerStats":
			node = Game.player.find_child("Graphics")
		else:
			node = target.get_parent().find_child("Graphics") as Node2D
		
		anim.visible = true
		anim.play(anim_name)
		node.modulate = color
		target.element_fx_timer.start()
		await anim.animation_finished
		anim.visible = false
		await target.element_fx_timer.timeout
		node.modulate = Color.WHITE
		target.ignite_damage_timer.stop()
		is_shock = false
		target.is_element_affect = false


func target_can_avoid_attack(_target_stats: Stats) -> bool:
	var target_base_evasion = _target_stats.evasion.get_value()
	var agility_v = _target_stats.agility.get_value()
	var agility_evasion: float
	
	if agility_v <= 10:
		agility_evasion = 0.5 * agility_v
	elif agility_v <= 30:
		agility_evasion = 4 + (agility_v -10) * 1.25
	else:
		agility_evasion = 30 + (agility_v - 30) * 0.2
	
	var total_evasion = target_base_evasion + agility_evasion
	total_evasion = clamp(total_evasion, 0.0, 80.0)
	if _target_stats.name == "PlayerStats":
		print("%s当前回避率：%s%%" % ["Player", total_evasion])
	else:
		print("%s当前回避率：%s%%" % [_target_stats.get_parent().name, total_evasion])
	
	if randf_range(0.0, 100.0) < total_evasion:
		return true
	return false

func can_crit() -> bool:
	var base_crit_chance = crit_chance.get_value()
	var luck_crit_chance = roundi(0.5 * (1 - exp(-0.03 * luck.get_value())) * 100)
	var total_chance = min(base_crit_chance + luck_crit_chance, 100.0)
	if self.name == "PlayerStats":
		print("%s暴击率：%s%%" % ["Player", total_chance])
	else:
		print("%s暴击率：%s%%" % [self.get_parent().name, total_chance])
	return randf_range(0.0, 100.0) <= total_chance

func calculate_critical_damage(_damage: int) -> int:
	var total_critical_power: float = (crit_power.get_value() + roundi(strength.get_value() * 0.5)) * 0.01
	var crit_damage = _damage * total_critical_power
	return roundi(crit_damage)

func check_target_armour(_target_stats: Stats, _damage: int) -> int:
	var total_armour = _target_stats.armour.get_value() + roundi(_target_stats.vitality.get_value() * 0.2)
	_damage -= total_armour
	_damage = clamp(_damage, 1, 9999) # 防御抵消攻击最低也会造成1点伤害，且伤害的上限不会超过9999
	return _damage

func check_target_resist(_target_stats: Stats, magic_damge: int) -> int:
	magic_damge -= _target_stats.magic_resist.get_value() + _target_stats.intelligence.get_value()
	magic_damge = clamp(magic_damge, 1, 9999) # 魔防抵消魔攻最低也会造成1点伤害，且伤害的上限不会超过9999
	return magic_damge

func to_dict() -> Dictionary:
	return {
		"strength": strength.to_dict(),
		"agility": agility.to_dict(),
		"intelligence": intelligence.to_dict(),
		"vitality": vitality.to_dict(),
		"luck": luck.to_dict(),
		
		"damage": damage.to_dict(),
		"crit_chance": crit_chance.to_dict(),
		"crit_power": crit_power.to_dict(),
		
		"max_health": max_health.to_dict(),
		"armour": armour.to_dict(),
		"evasion": evasion.to_dict(),
		"magic_resist": magic_resist.to_dict(),
		
		"max_energy": max_energy.to_dict(),
		"energy_regenerate": energy_regenerate.to_dict(),
		"attack_energy_regenerate": attack_energy_regenerate.to_dict(),
		
		"health": health,
	}

func from_dict(dict: Dictionary) -> void:
	strength.from_dict(dict.get("strength", []))
	agility.from_dict(dict.get("agility", []))
	intelligence.from_dict(dict.get("intelligence", []))
	vitality.from_dict(dict.get("vitality", []))
	luck.from_dict(dict.get("luck", []))
	
	damage.from_dict(dict.get("damage", []))
	crit_chance.from_dict(dict.get("crit_chance", []))
	crit_power.from_dict(dict.get("crit_power", []))
	
	max_health.from_dict(dict.get("max_health", []))
	armour.from_dict(dict.get("armour", []))
	evasion.from_dict(dict.get("evasion", []))
	magic_resist.from_dict((dict.get("magic_resist", [])))

	max_energy.from_dict(dict.get("max_energy", []))
	energy_regenerate.from_dict(dict.get("energy_regenerate", {}))
	attack_energy_regenerate.from_dict(dict.get("attack_energy_regenerate", {}))
	
	health = dict.get("health", max_health.get_value())
