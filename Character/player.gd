class_name Player
extends CharacterBody2D

enum Direction {
	LEFT = -1,
	RIGHT = 1,
}

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	PEAK,
	LANDING,
	WALL_SLIDE,
	WALL_JUMP,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	HURT,
	DIE,
	SLIDE_START,
	SLIDE_LOOP,
	SLIDE_END,
}

@export var can_combo := false
@export var direction := Direction.RIGHT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = direction

const GROUND_STATES := [
	State.IDLE, State.RUN, State.LANDING,
	State.ATTACK1, State.ATTACK2, State.ATTACK3,
	]
const RUN_SPEED := 160.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.125
const AIR_ACCELERATION := RUN_SPEED / 0.1
const JUMP_VELOCITY := -340.0
const WALL_JUMP_VELOCITY := Vector2(420, -390)
const KNOCKBACK_POWER := 300.0
const SLIDE_DURATION := 0.1
const SLIDE_SPEED := 250.0
const SLIDE_ENERGY := 35
const LANDING_HEIGHT := 100.0
const SILVER = preload("res://Artwork/UI/Fort/Silver.ttf")

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false # 判断当前是否在某状态的第一帧
var is_combo_requested := false
var pending_damage: Damage
var current_attack_modifier: float = 0.0
var fall_from_height : float
var interactable_object : Array[Interactable] = []
var steps_on_wood_sound: Array[AudioStream] = [
	preload("res://SFX/PlayerSFX/run_on_wood_1.ogg"),
	preload("res://SFX/PlayerSFX/run_on_wood_2.ogg"),
	preload("res://SFX/PlayerSFX/run_on_wood_3.ogg"),
	preload("res://SFX/PlayerSFX/run_on_wood_4.ogg"),
]

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactive_icon: AnimatedSprite2D = $InteractiveIcon
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var slide_request_timer: Timer = $SlideRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = Game.player_stats
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var run_sfx: AudioStreamPlayer = $RunSFX

func _ready() -> void:
	stand(default_gravity, 0.01)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true
	
	if event.is_action_pressed("slide"):
		slide_request_timer.start()
	
	if event.is_action_pressed("interact") and interactable_object:
		interactable_object.back().interact()


func tick_physics(state: State, delta: float) -> void: # 在状态中持续做什么
	interactive_icon.visible = not interactable_object.is_empty() # 可交互UI可见性和是否存在可交互对象关联
	
	if invincible_timer.time_left > 0:
		graphics.modulate.a = sin(Time.get_ticks_msec() / 35.0) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
	match state:
		State.IDLE:
			move(default_gravity, delta)
		
		State.RUN:
			move(default_gravity, delta)
		
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		
		State.FALL:
			move(default_gravity, delta)
		
		State.PEAK:
			velocity.y += default_gravity * delta
			move_and_slide()
		
		State.LANDING:
			stand(default_gravity, delta)
		
		State.WALL_SLIDE:
			move(default_gravity / 5, delta)
			direction = Direction.LEFT if  get_wall_normal().x < 0 else Direction.RIGHT
		
		State.WALL_JUMP:
			if state_machine.state_time < 0.2:
				stand(0.0 if is_first_tick else default_gravity, delta)
				direction = Direction.LEFT if  get_wall_normal().x < 0 else Direction.RIGHT
			else:
				move(default_gravity, delta)
		
		State.ATTACK1, State.ATTACK2, State.ATTACK3:
			stand(default_gravity, delta)
		
		State.HURT, State.DIE:
			stand(default_gravity, delta)
		
		State.SLIDE_END:
			stand(default_gravity, delta)
		
		State.SLIDE_START, State.SLIDE_LOOP:
			slide(delta)
	
	is_first_tick = false

#region BEHAVIOR
func move(gravity: float, delta: float) -> void:
	var movement := 0.0
	if state_machine.current_state != State.PEAK:
		movement = Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, movement * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	
	if not is_zero_approx(movement) and state_machine.current_state != State.PEAK:
		direction = Direction.LEFT if movement < 0 else Direction.RIGHT
	
	move_and_slide()

func stand(gravity: float,delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()

func slide(delta: float) -> void:
	velocity.x = graphics.scale.x * SLIDE_SPEED
	velocity.y += default_gravity * delta
	
	move_and_slide()

func die():
	game_over_screen.show_game_over()

func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding() and velocity.y >= 0

func should_slide() -> bool:
	if slide_request_timer.is_stopped():
		return false
	if stats.energy < SLIDE_ENERGY:
		return false
	return not foot_checker.is_colliding()
#endregion

func add_interactable_obj(obj: Interactable) -> void:
	if state_machine.current_state == State.DIE:
		return
	
	if obj in interactable_object:
		return
	interactable_object.append(obj)

func subtract_interactable_obj(obj: Interactable) -> void:
	interactable_object.erase(obj)


func get_next_state(state: State) -> int: # 什么情况下转换状态
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DIE else State.DIE
	
	if pending_damage and pending_damage.amount > 0:
			return State.HURT
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var movement := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(movement) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK1
			if should_slide():
				return State.SLIDE_START
			if not is_still:
				return State.RUN
		
		State.RUN:
			if Input.is_action_just_pressed("attack"):
				run_sfx.stop()
				return State.ATTACK1
			if should_slide():
				run_sfx.stop()
				return State.SLIDE_START
			if is_still:
				run_sfx.stop()
				return State.IDLE
		
		State.JUMP:
			if can_wall_slide():
				return State.WALL_SLIDE
			if abs(velocity.y) < 80:
				return State.PEAK
		
		State.PEAK:
			if can_wall_slide():
				return State.WALL_SLIDE
			if velocity.y > 80:
				return State.FALL
			if is_on_floor():
				return State.IDLE
		
		State.FALL:
			if is_on_floor():
				var height := global_position.y - fall_from_height
				return State.LANDING if height >= LANDING_HEIGHT else State.RUN
			if can_wall_slide():
				return State.WALL_SLIDE
		
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDE:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDE
			if abs(velocity.y) < 80:
				return State.PEAK
		
		State.ATTACK1:
			if not animation_player.is_playing():
				return State.ATTACK2 if is_combo_requested else State.IDLE
			
		
		State.ATTACK2:
			if not animation_player.is_playing():
				if current_attack_modifier != 0:
					stats.damage.remove_modifier(roundi(current_attack_modifier))
					current_attack_modifier = 0
				return State.ATTACK3 if is_combo_requested else State.IDLE
		
		State.ATTACK3:
			if not animation_player.is_playing():
				if current_attack_modifier != 0:
					stats.damage.remove_modifier(roundi(current_attack_modifier))
					current_attack_modifier = 0
				return State.IDLE
		
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDE_START:
			if not animation_player.is_playing():
				return State.SLIDE_LOOP
		
		State.SLIDE_END:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDE_LOOP:
			if state_machine.state_time > SLIDE_DURATION or is_on_wall():
				return State.SLIDE_END
	
	return StateMachine.KEEP_CURRENT


func transition_state(from: State, to: State) -> void: # 刚进入某个状态的时候需要做什么
	#print("[%s] %s => %s" % [
		#Engine.get_physics_frames(),
		#State.keys()[from] if from != -1 else "<START>",
		#State.keys()[to]
	#])
	
	if from not in GROUND_STATES and to in GROUND_STATES:
		
		coyote_timer.stop()
	
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.RUN:
			animation_player.play("run")
		
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			SoundManager.play_sfx("PlayerJumpSFX")
		
		State.PEAK:
			animation_player.play("peak")
		
		State.FALL:
			fall_from_height = global_position.y
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
		
		State.LANDING:
			animation_player.play("landing")
			SoundManager.play_sfx("PlayerJumpLandSFX")
		
		State.WALL_SLIDE:
			animation_player.play("wall_slide")
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
			SoundManager.play_sfx("PlayerJumpSFX")
		
		State.ATTACK1:
			animation_player.play("attack1")
			is_combo_requested = false
			SoundManager.play_sfx("PlayerAttackSFX1")
			if current_attack_modifier != 0:
				stats.damage.remove_modifier(roundi(current_attack_modifier))
				current_attack_modifier = 0
		
		State.ATTACK2:
			animation_player.play("attack2")
			is_combo_requested = false
			SoundManager.play_sfx("PlayerAttackSFX2")
			if current_attack_modifier != 0:
				stats.damage.remove_modifier(roundi(current_attack_modifier))
			current_attack_modifier = stats.damage.get_value() * 0.05
			stats.damage.add_modifier(roundi(current_attack_modifier))
		
		State.ATTACK3:
			animation_player.play("attack3")
			is_combo_requested = false
			SoundManager.play_sfx("PlayerAttackSFX3")
			if current_attack_modifier != 0:
				stats.damage.remove_modifier(roundi(current_attack_modifier))
			current_attack_modifier = stats.damage.get_value() * 0.1
			stats.damage.add_modifier(roundi(current_attack_modifier))
		
		State.HURT:
			animation_player.play("hurt")
			SoundManager.play_sfx("PlayerHurtSFX")
			stats.health -= pending_damage.amount
			
			# 伤害来源的全局坐标指向自己的坐标作为被击退的方向
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_POWER
			
			pending_damage = null
			invincible_timer.start()
		
		State.DIE:
			animation_player.play("die")
			SoundManager.play_sfx("PlayerScreamSFX")
			invincible_timer.stop()
			interactable_object.clear()
		
		State.SLIDE_START:
			animation_player.play("slide_start")
			slide_request_timer.stop()
			stats.energy -= SLIDE_ENERGY
		
		State.SLIDE_LOOP:
			animation_player.play("slide_loop")
		
		State.SLIDE_END:
			animation_player.play("slide_end")
	
	is_first_tick = true

func show_dodge_info() -> void:
	#var sprite = graphics.find_child("Sprite2D") as Sprite2D
	#var height = sprite.texture.get_height()
	
	var label = Label.new()
	label.text = "闪！"
	label.global_position = global_position - Vector2(6, 46)
	label.add_theme_font_override("Font", SILVER)
	
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color.WHITE)
	
	get_tree().current_scene.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func play_random_sound():
	if steps_on_wood_sound.is_empty():
		return
	
	run_sfx.stream = steps_on_wood_sound.pick_random()
	run_sfx.play()


func _on_hurtbox_hurt(attacker: Hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
	
	var attacker_stats := attacker.owner.get_node("Stats") as Stats
	
	if attacker_stats:
		if not attacker_stats.target_dodge.is_connected(show_dodge_info):
			attacker_stats.target_dodge.connect(show_dodge_info)
		
		attacker_stats.do_damage(stats)
		if attacker_stats.total_damage > 0:
			pending_damage = Damage.new()
			pending_damage.amount = attacker_stats.total_damage
			attacker_stats.total_damage = 0
			pending_damage.source = attacker.owner
