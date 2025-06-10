extends Enemy

enum State {
	IDLE,
	WALK,
	RUN,
	HURT,
	DIE,
}

const KNOCKBACK_POWER := 300.0



@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var calm_down_timer: Timer = $CalmDownTimer
@onready var status_panel: HBoxContainer = $StatusPanel
@onready var boar_hurt_sfx: AudioStreamPlayer = $BoarHurtSFX

func _ready() -> void:
	status_panel.modulate.a = 0.0

func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player

func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE,State.HURT, State.DIE:
			move(0.0, delta)
		
		State.WALK:
			move(max_speed / 4, delta)
		
		State.RUN:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				turn_around()
			move(max_speed, delta)
			if can_see_player():
				calm_down_timer.start()


func get_next_state(state: State) -> int:
	if stats.health <= 0:
		return StateMachine.KEEP_CURRENT if state == State.DIE else State.DIE
	
	if pending_damage and pending_damage.amount > 0:
		return State.HURT
	
	match state:
		State.IDLE:
			if can_see_player():
				return State.RUN
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			if can_see_player():
				return State.RUN
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		
		State.RUN:
			if not can_see_player() and calm_down_timer.is_stopped():
				return State.WALK
		
		State.HURT:
			if not animation_player.is_playing():
				return State.RUN
		
	return StateMachine.KEEP_CURRENT


func transition_state(from: State, to: State) -> void:
	#print("[%s] %s => %s" % [
		#Engine.get_physics_frames(),
		#State.keys()[from] if from != -1 else "<START>",
		#State.keys()[to]
	#])
	
	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				turn_around()
		
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				turn_around()
				floor_checker.force_raycast_update()
		
		State.RUN:
			animation_player.play("run")
		
		State.HURT:
			animation_player.play("hurt")
			SoundManager.play_sfx("BodyHurtSFX")
			boar_hurt_sfx.play()
			
			# 伤害来源的全局坐标指向自己的坐标作为被击退的方向
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_POWER
			
			if dir.x > 0:
				direction = Direction.LEFT
			else:
				direction = Direction.RIGHT
			
			pending_damage = null
		
		State.DIE:
			animation_player.play("die") # 动画中包含方法调用，调用了die()函数
			var hitbox := get_node("Graphics/Hitbox") as Hitbox
			hitbox.monitoring = false


func _on_hurtbox_hurt(hitbox: Hitbox) -> void: # 该方法为节点连接hurtbox信号时自动生成
	var owner_stats := Game.player_stats as Stats
	
	if owner_stats:
		on_take_damage(owner_stats, hitbox)
		
		if pending_damage and pending_damage.amount > 0:
			var tween = create_tween()
			tween.tween_property(status_panel, "modulate:a", 1.0, 0.2)
			var timer = get_tree().create_timer(3.0)
			timer.timeout.connect(hide_health_bar)

func hide_health_bar() -> void:
	var tween = create_tween()
	tween.tween_property(status_panel, "modulate:a", 0.0, 0.2)

func die():
	var tween = create_tween()
	tween.tween_property(graphics, "modulate:a", 0.0, 0.2)
	await tween.finished
	super()
