extends Interactable

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func interact() -> void:
	super()
	
	animation_player.play("actived")
	#Game.player_stats.health = Game.player_stats.max_health.get_value()
	Game.save_game()
