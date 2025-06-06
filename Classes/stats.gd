class_name Stats
extends Node

signal health_change
signal energy_change
signal target_dodge

@export_category("主要属性")
@export var strength: Attribute = Attribute.new() ## 每点属性值直接影响角色的攻击力，0.5倍影响角色的暴击伤害
## 敏捷属性分阶段影响回避率
## 属性值(1-10): evasion = 0.5 * agility;
## 属性值(11-30): evasion = 4 + (agility - 10) * 1.25;
## 属性值(>31): evasion = 30 + (agility -30) * 0.2;
@export var agility: Attribute = Attribute.new()
@export var intelligence: Attribute = Attribute.new() ## 每点属性直接影响魔法伤害
@export var vitality: Attribute = Attribute.new() ## 每点属性增加5点最大生命值上限
@export var luck: Attribute = Attribute.new() ## 暴击率 = 50% * (1- e^(-k * luck):luck属性影响暴击率上限不会超过50%

@export_category("进攻属性")
@export var damage: Attribute = Attribute.new()
@export var crit_chance: Attribute = Attribute.new()
@export var crit_power: Attribute = Attribute.new()

@export_category("防守属性")
@export var max_health: Attribute = Attribute.new()
@export var armor: Attribute = Attribute.new()
@export var evasion: Attribute = Attribute.new()
@export var magic_resist: Attribute = Attribute.new()

@export_category("能量属性")
@export var max_energy: Attribute = Attribute.new()
@export var energy_regenerate: Attribute = Attribute.new()
@export var attack_energy_regenerate: Attribute = Attribute.new()

@export_category("魔法属性")
@export var fire_damage: Attribute = Attribute.new()
@export var ice_damage: Attribute = Attribute.new()
@export var thunder_damage: Attribute = Attribute.new()

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
var is_magic_damage: bool = false

func _init() -> void:
	crit_power.set_default_value(150)

func _ready() -> void:
	print("%s初始生命为： %s" % [owner.name, health])

func _process(delta: float) -> void:
	energy += energy_regenerate.get_value() * delta

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
	
	total_damage = check_target_armor(_target_stats, total_damage)


func do_magic_damage(_target_stats: Stats) -> void:
	# TODO: 考虑将属性防御分解成3个属性，并一一对应属性攻击，并将抗性设置为百分比，超过百分比回血等设计
	var _fire_damage = fire_damage.get_value()
	var _ice_damage = ice_damage.get_value()
	var _thunder_damage = thunder_damage.get_value()
	
	is_magic_damage = true
	
	total_m_damage = _fire_damage + _ice_damage + _thunder_damage + intelligence.get_value()
	
	total_m_damage = check_target_resist(_target_stats, total_m_damage)


func target_can_avoid_attack(_target_stats: Stats) -> bool:
	var target_base_evasion = _target_stats.evasion.get_value()
	var agility = _target_stats.agility.get_value()
	var agility_evasion: float
	
	if agility <= 10:
		agility_evasion = 0.5 * agility
	elif agility <= 30:
		agility_evasion = 4 + (agility -10) * 1.25
	else:
		agility_evasion = 30 + (agility - 30) * 0.2
	
	var total_evasion = target_base_evasion + agility_evasion
	total_evasion = clamp(total_evasion, 0.0, 80.0)
	print("当前回避率：", total_evasion, "%")
	
	if randf_range(0.0, 100.0) < total_evasion:
		return true
	return false

func can_crit() -> bool:
	var base_crit_chance = crit_chance.get_value()
	var luck_crit_chance = roundi(0.5 * (1 - exp(-0.03 * luck.get_value())) * 100)
	var total_chance = min(base_crit_chance + luck_crit_chance, 100.0)
	print("暴击率： ", total_chance, "%")
	return randf_range(0.0, 100.0) <= total_chance

func calculate_critical_damage(_damage: int) -> int:
	var total_critical_power: float = (crit_power.get_value() + roundi(strength.get_value() * 0.5)) * 0.01
	var crit_damage = _damage * total_critical_power
	return roundi(crit_damage)

func check_target_armor(_target_stats: Stats, _damage: int) -> int:
	_damage -= _target_stats.armor.get_value()
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
		"armor": armor.to_dict(),
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
	armor.from_dict(dict.get("armor", []))
	evasion.from_dict(dict.get("evasion", []))
	magic_resist.from_dict((dict.get("magic_resist", [])))

	max_energy.from_dict(dict.get("max_energy", []))
	energy_regenerate.from_dict(dict.get("energy_regenerate", {}))
	attack_energy_regenerate.from_dict(dict.get("attack_energy_regenerate", {}))
	
	health = dict.get("health", max_health.get_value())
