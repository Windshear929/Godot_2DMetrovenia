extends Enemy

enum State {
	IDLE,
	WALK,
	RUN,
	WAIT,
	ATTACK,
	DIE,
}

@export var detect_area: Area2D
@export var battle_start_position: Marker2D

@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var attack_fx: AnimatedSprite2D = $Graphics/AttackFX
@onready var attackbox: Hitbox = $Graphics/AttackFX/Attackbox
@onready var boss_health_bar: Control = $CanvasLayer/BossHealthBar
@onready var wait_for_battle_start: Timer = $WaitForBattleStart

var target_player : Player = null
var hit_wall_counter : int = 0
var should_move_to_position: bool = false


func _ready() -> void:
	super()
	detect_area.body_entered.connect(on_player_detected)
	detect_area.body_exited.connect(on_player_lost)
	boss_dead.connect(end_attack_frame)
	attack_fx.visible = false
	attackbox.monitoring = false

func on_player_detected(body: Node2D):
	if body is Player:
		target_player = body
	
	should_move_to_position = true
	wait_for_battle_start.start()

func on_player_lost(body: Node2D):
	if body == target_player:
		target_player = null

func on_attack_frame() -> void:
	attack_fx.visible = true
	attack_fx.play("default")
	attackbox.monitoring = true

func end_attack_frame() -> void:
	attack_fx.visible = false
	attack_fx.stop()
	attackbox.monitoring = false

func tick_physics(state: State, delta: float) -> void: # 状态下持续干什么
	if should_move_to_position:
		animation_player.play("run")
	
	match state:
		State.IDLE:
			if should_move_to_position and battle_start_position:
				var direction_to_pos = global_position.direction_to(battle_start_position.global_position)
				if direction_to_pos.x > 0:
					direction = Direction.RIGHT
				else:
					direction = Direction.LEFT
				
				move(current_speed / 2, delta)
				
				if global_position.distance_to(battle_start_position.global_position) < 5.0:
					should_move_to_position = false
					animation_player.play("idle")
					var dir = target_player.global_position.direction_to(global_position)
					if dir.x > 0:
						direction = Direction.LEFT
					else:
						direction = Direction.RIGHT
			else:
				move(0.0, delta)
		
		State.WALK:
			move(current_speed / 4, delta)
		
		State.RUN:
			move(current_speed, delta)
		
		State.WAIT:
			move(0.0, delta)
		
		State.ATTACK:
			move(0.0, delta)

func get_next_state(state: State) -> int: # 什么情况下改变状态
	if stats.health <= 0:
		return StateMachine.KEEP_CURRENT if state == State.DIE else State.DIE
	
	match state:
		State.IDLE:
			if target_player and not should_move_to_position and wait_for_battle_start.time_left <= 0:
				return State.RUN
			if state_machine.state_time > 4.0:
				return State.WALK
		
		State.WALK:
			if target_player:
				return State.IDLE
			if wall_checker.is_colliding():
				turn_around()
			elif state_machine.state_time > randf_range(2.0, 4.0):
				return State.IDLE
		
		State.RUN:
			if wall_checker.is_colliding():
				turn_around()
				hit_wall_counter += 1
			if hit_wall_counter >= 3:
				return State.WAIT
		
		State.WAIT:
			if state_machine.state_time > 2.0:
				return State.ATTACK
		
		State.ATTACK:
			if not animation_player.is_playing():
				return State.RUN
		
	return StateMachine.KEEP_CURRENT

func transition_state(from: State, to: State) -> void: # 刚进入状态需要执行什么
	#print("[%s] %s => %s" % [
		#Engine.get_physics_frames(),
		#State.keys()[from] if from != -1 else "<START>",
		#State.keys()[to]
	#])
	
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.WALK:
			animation_player.play("walk")
		
		State.RUN:
			animation_player.play("run")
		
		State.WAIT:
			hit_wall_counter = 0
			animation_player.play("idle")
		
		State.ATTACK:
			animation_player.play("attack")
		
		State.DIE:
			animation_player.play("die") # 动画中包含方法调用，调用了die()函数
			
			# TODO: 封装
			detect_area.monitoring = false
			var hitbox := get_node("Graphics/Hitbox") as Hitbox
			hitbox.monitoring = false
			var hurtbox := get_node("Graphics/Hurtbox") as Hurtbox
			hurtbox.monitorable = false
			var tween := create_tween()
			tween.tween_property(boss_health_bar, "self_modulate:a", 0.0, 0.5)
			await tween.finished
			boss_health_bar.visible = false


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	var attacker_stats := Game.player_stats as Stats
	
	if attacker_stats:
		on_take_damage(attacker_stats, hitbox)
		if pending_damage and pending_damage.amount > 0:
			boss_hurt_effect()
			SoundManager.play_sfx("BodyHurtSFX")

func die():
	boss_dead.emit()
	
	super()
