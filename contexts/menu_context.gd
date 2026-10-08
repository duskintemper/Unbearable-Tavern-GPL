class_name MenuContext
extends Node2D

@export_file("*.tscn", "*.scn") var game_scene_path: String
@export var credits_scene : PackedScene
@onready var play_button : Button = %PlayButton
@onready var info_button : Button = %InfoButton
@onready var credits_button : Button = %CreditsButton
@onready var exit_button : Button = %ExitButton
@onready var back_button : Button = %BackButton
@onready var easy_button : Button = %EasyButton
@onready var normal_button : Button = %NormalButton
@onready var hard_button : Button = %HardButton
@onready var menu_panel : Control = %MenuButtons
@onready var diff_panel : Control = %DiffButtons
@onready var highscore_label : Label = %HighscoreText
@onready var info_board : Control = %InfoBoard
@onready var info_collapse_button : Button = %InfoCollpaseButton
@onready var music_player : AudioStreamPlayer = %MusicPlayer
@onready var ui_button_player : AudioStreamPlayer = %UIButtonPlayer
@export var player : Node2D
@export var player_sprite : AnimatedSprite2D
@export var move_destinations : Array[Node2D]
@export var hiding_interface_list : Array[Control]

var wander_queue : Array[int]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	diff_panel.hide()
	info_board.hide()

	get_tree().paused = false
	load_high_score()

	play_button.pressed.connect(
		func() -> void:
			menu_panel.hide()
			diff_panel.show()
	)
	exit_button.pressed.connect(get_tree().quit)
	back_button.pressed.connect(
		func() -> void:
			menu_panel.show()
			diff_panel.hide()
	)

	easy_button.pressed.connect(launch_game.bind(GameConstants.Difficulty.EASY))
	normal_button.pressed.connect(launch_game.bind(GameConstants.Difficulty.NORMAL))
	hard_button.pressed.connect(launch_game.bind(GameConstants.Difficulty.HARD))
	info_button.pressed.connect(toggle_info.bind(true))
	info_collapse_button.pressed.connect(toggle_info.bind(false))
	credits_button.pressed.connect(toggle_credits.bind(true))
	
	for button : Button in get_tree().get_nodes_in_group("ui_buttons"):
		button.pressed.connect(play_ui_sound)

	activate_wandering_player()
	

func launch_game(difficulty : GameConstants.Difficulty) -> void:

	GameConstants.current_difficulty = difficulty
	diff_panel.hide()
	EasyTransition.default_transition(game_scene_path)


func toggle_info(activate : bool) -> void:

	if activate:
		for control : Control in hiding_interface_list:
			control.hide()
		info_board.show()
		get_tree().paused = true
	
	else:
		for control : Control in hiding_interface_list:
			control.show()
		info_board.hide()
		get_tree().paused = false		


func toggle_credits(activate : bool) -> void:

	if activate:
		for control : Control in hiding_interface_list:
			control.hide()
		get_tree().paused = true
		var scene := credits_scene.instantiate() as QuickLicenses
		add_child(scene)
		scene.position = Vector2(20.0, 13.5)
		music_player.volume_db = -7.5
		
		scene.close_requested.connect(
			func() -> void:
				toggle_credits(false)
				music_player.volume_db = 0.0
				scene.queue_free()
		)

	else:
		for control : Control in hiding_interface_list:
			control.show()
		get_tree().paused = false	


func load_high_score() -> void:

	if not FileAccess.file_exists("user://data.save"): 
		print("Save file not found") 
		return
	var save_file := FileAccess.open("user://data.save", FileAccess.READ)
	var json_string := save_file.get_line()
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if not parse_result == OK:
		print("Save file reading has produced an error.")
		return
	var save_data : Dictionary = json.data
	GameConstants.high_score = save_data["highscore"]
	highscore_label.text = "{0} G".format([GameConstants.high_score])


func activate_wandering_player() -> void:

	if wander_queue.size() <= 0:
		wander_queue.clear()
		for i in range(move_destinations.size()):
			wander_queue.append(i % move_destinations.size())
		wander_queue.shuffle()

	var point := move_destinations[wander_queue.pop_back()].global_position
	var origin : Vector2 = player.global_position
	var distance := origin.distance_to(point)

	player_sprite.flip_h = true if point.x < player.global_position.x else false
	player_sprite.speed_scale = 0.5
	player_sprite.play("move")

	var tween := create_tween()
	tween.tween_property(player, "global_position", point, distance / 160.0)
	tween.tween_callback(player_sprite.play.bind("idle"))
	tween.tween_callback(func() -> void: player_sprite.speed_scale = 1.0)
	tween.tween_callback(func() -> void: player_sprite.flip_h = false)
	tween.tween_callback(activate_wandering_player).set_delay(randf_range(3.0, 10.0))


func play_ui_sound() -> void:
	ui_button_player.pitch_scale = randf_range(0.9, 1.1)
	ui_button_player.play()