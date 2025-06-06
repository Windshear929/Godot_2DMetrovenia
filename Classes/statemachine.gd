class_name StateMachine
extends Node

const KEEP_CURRENT := -1

var current_state: int = -1: # 因为ready函数给current_state赋值为0，状态转换函数将0转换为0，所以这里给v赋值-1
	set(v): # 给current_state一个setter为v
		owner.transition_state(current_state, v) # 先转换状态从current_state到v
		current_state = v # 完成转换后，将v赋值给当前状态
		state_time = 0

var state_time: float

func _ready() -> void:
	await owner.ready # godot先激活子节点，再激活根节点，这里要等待根节点ready
	current_state = 0

func _physics_process(delta: float) -> void:
	while true: # 无限循环写法，必须有break条件。这里作用是持续检查当前状态是否需要切换，直到状态稳定
		var next := owner.get_next_state(current_state) as int
		if next == KEEP_CURRENT:
			break
		current_state = next
	
	owner.tick_physics(current_state, delta)
	state_time += delta
