class_name GameController
extends Node2D

signal timer_updated (current_time : int)
signal SAT_updated (current_value : float, max_value : float)
signal rush_mode_entered ()
signal game_ended (success: bool)

enum GameState {
	DEFAULT,
	START,
	RUSH,
	END,
}

@export_group("Child Nodes")
@export var second_timer : Timer
@export var core_system : CoreSystem
@export var game_ui : GameUI
@export var order_display_sys : OrderDisplay
@export var score_sys : ScoreSystem
@export var camera_sys : MainCamera
@export var music_player : AudioStreamPlayer
@export_group("Properties")
@export_file("*.tscn", "*.scn") var menu_scene_path: String
@export var difficulty := GameConstants.Difficulty.EASY
@export var game_time : int = 50
@export var rush_time : int = 20
@export var SAT_decay_rate : float = 5.0
@export var SAT_refund : float = 7.5
@export var rush_SAT_refund : float = 12.0
@export var SAT_punish : float = 20.0
@export_group("Music")
@export var music_playlist : Dictionary[GameConstants.Difficulty, AudioStream]
@export var win_music : AudioStream
@onready var ui_button_player : AudioStreamPlayer = %UIButtonPlayer
@onready var coin_player : AudioStreamPlayer = %CoinPlayer
@onready var hurt_player : AudioStreamPlayer = %HurtPlayer
@onready var lose_player : AudioStreamPlayer = %LosePlayer
@onready var warn_player : AudioStreamPlayer = %WarnPlayer

var current_time : int = 0
var current_SAT : float = 0.0
var max_SAT : float = 100.0
var game_state := GameState.DEFAULT


func _ready() -> void:

	bind_system()

	current_time = game_time
	timer_updated.emit(current_time)

	current_SAT = max_SAT
	SAT_updated.emit(current_SAT, max_SAT)

	difficulty = GameConstants.current_difficulty

	for button : Button in get_tree().get_nodes_in_group("ui_buttons"):
		button.pressed.connect(play_ui_sound)


	await get_tree().create_timer(1.0).timeout

	order_display_sys.initialize(difficulty)
	score_sys.initialize(difficulty)
	core_system.start_game(difficulty)
	second_timer.start()

	var music_tag := (
		"Easy" if difficulty == GameConstants.Difficulty.EASY else
		"Normal" if difficulty == GameConstants.Difficulty.NORMAL else 
		"Hard" if difficulty == GameConstants.Difficulty.HARD else ""
	)
	music_player.set("parameters/switch_to_clip", music_tag)
	music_player.play()

	game_state = GameState.START


func _process(delta: float) -> void:

	match game_state:
		GameState.START:
			SAT_decay_tick(SAT_decay_rate * delta * ((difficulty as int) + 1))
		GameState.RUSH:
			SAT_decay_tick(SAT_decay_rate * delta * ((difficulty as int) + 1) * 2.0)
		

func bind_system() -> void:

	# Bindings: Self
	second_timer.timeout.connect(on_second_tick)

	# Bindings: Game UI
	timer_updated.connect(game_ui.update_timer)
	SAT_updated.connect(game_ui.update_SAT_bar)
	rush_mode_entered.connect(game_ui.swap_SAT_bar.bind(true))

	# Bindings: Core System
	core_system.interaction.connect(
		func(success : bool) -> void:
			if success: 
				SAT_refil()
				coin_player.pitch_scale = randf_range(0.9, 1.0)
				coin_player.play()
			else : 
				SAT_decay_tick(SAT_punish)
				game_ui.warn_SAT_bar()
				camera_sys.apply_shake()
				hurt_player.pitch_scale = randf_range(0.95, 1.05)
				hurt_player.play()

	)
	rush_mode_entered.connect(core_system.spawn_rushed_customer)
	game_ended.connect(core_system.stop_game)
	game_ui.game_paused.connect(pause_game)
	game_ui.menu_pressed.connect(go_to_menu)

	# Bindings: Other
	core_system.request_generated.connect(order_display_sys.display_item)
	core_system.interaction.connect(
		func(success : bool) -> void:
			score_sys.on_interacted(success)
			if success:
				game_ui.update_base_score(score_sys.display_base_score(), true)
	)
	rush_mode_entered.connect(
		func() -> void:
			warn_player.play()
			game_ui.display_warn_text()
	)
	game_ended.connect(order_display_sys.clear_display.unbind(1))
	game_ended.connect(
		func(success : bool) -> void:
			if success:
				score_sys.calculate_final(current_SAT)
				game_ui.display_final_score(score_sys.query_individual_scores())
				save_high_score()
			else:
				game_ui.update_base_score(0, false)
				game_ui.toggle_fail_hint()
	)
	game_ended.connect(game_ui.hide_game_uis.unbind(1))


func end_game(success: bool) -> void:

	game_state = GameState.END
	camera_sys.reset_camera()
	second_timer.stop()
	game_ended.emit(success)

	if not success:
		music_player.set("parameters/switch_to_clip", "Failure")
		hurt_player.play()
		lose_player.play()
		await get_tree().create_timer(5.0).timeout
		EasyTransition.default_transition(menu_scene_path)

	else:
		music_player.set("parameters/switch_to_clip", "Victory")


func pause_game (activate: bool) -> void:
	get_tree().paused = activate

	if activate:
		camera_sys.reset_camera()


func go_to_menu () -> void:
	EasyTransition.default_transition(menu_scene_path)


func save_high_score() -> void:

	if score_sys.total_score <= GameConstants.high_score: return
	
	GameConstants.high_score = score_sys.total_score
	var save_file := FileAccess.open("user://data.save", FileAccess.WRITE)
	var json_string := JSON.stringify({"highscore" : GameConstants.high_score})
	save_file.store_line(json_string)


func on_second_tick() -> void:

	current_time -= 1
	if current_time <= 0:
		end_game(true)
	elif current_time <= rush_time and game_state != GameState.RUSH:
		game_state = GameState.RUSH
		rush_mode_entered.emit()
	timer_updated.emit(current_time)


func SAT_decay_tick(decay_rate : float) -> void:

	current_SAT = clamp (current_SAT - decay_rate, 0.0, max_SAT)
	if (current_SAT <= 0.0):
		end_game(false)
	SAT_updated.emit(current_SAT, max_SAT)


func SAT_refil() -> void:

	current_SAT =  clamp (current_SAT + (
		SAT_refund * ((difficulty as int) + 1) / 1.5 if game_state == GameState.START 
		else rush_SAT_refund * ((difficulty as int) + 1) / 1.5 if game_state == GameState.RUSH
		else 0.0
	), 0.0, max_SAT)


func play_ui_sound() -> void:
	ui_button_player.pitch_scale = randf_range(0.9, 1.1)
	ui_button_player.play()
