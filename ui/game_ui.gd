class_name GameUI
extends Control

signal game_paused (pause_mode : bool)
signal menu_pressed ()

@export_group("Child Nodes")
@export var scoreboard_rows : Array[Control]
@export var score_labels : Array[Label]
@export var sub_description_labels : Array[Label]
@export var controls_to_hide : Array[Control]
@export_group("Properties")
@export var default_theme : Theme
@export var warn_theme : Theme
@export var default_SAT_texture : Texture2D
@export var warn_SAT_texture : Texture2D

@onready var timer_label : Label = %TimerText
@onready var SAT_progress_bar : TextureProgressBar = %SatisfactionBar
@onready var base_score_label : Label = %BaseScoreText
@onready var scoreboard : Control = %Scoreboard
@onready var gold_icon : TextureRect = %GoldIcon
@onready var pause_button : Button = %PauseButton
@onready var pause_menu : Control = %PauseMenu
@onready var continue_button : Button = %ContinueButton
@onready var menu_button : Button = %MenuButton
@onready var failure_textbox : Control = %FailureTextbox
@onready var end_menu_button : Button = %EndMenuButton
@onready var warn_text_box : Control = %WarnTextbox


func _ready() -> void:

	pause_button.pressed.connect(toggle_pause_menu.bind(true))
	continue_button.pressed.connect(toggle_pause_menu.bind(false))
	menu_button.pressed.connect(
		func() -> void:
			pause_menu.hide()
			menu_pressed.emit()
	)
	end_menu_button.pressed.connect(
		func() -> void:
			end_menu_button.hide()
			menu_pressed.emit()
	)

	scoreboard.hide()
	for control : Control in scoreboard_rows:
		control.hide()
	for control : Control in score_labels:
		control.hide()
	swap_SAT_bar (false)
	update_base_score(0, false)
	pause_button.disabled = true
	pause_menu.hide()
	end_menu_button.hide()

	await get_tree().create_timer(1.0).timeout
	pause_button.disabled = false


func update_timer (number : int) -> void:
	timer_label.text = str(number)


func update_SAT_bar (new_value : float, max_value : float) -> void:
	SAT_progress_bar.value = new_value / max_value * SAT_progress_bar.max_value


func swap_SAT_bar (warn_mode : bool) -> void:
	if warn_mode:
		SAT_progress_bar.texture_progress = warn_SAT_texture
	else:
		SAT_progress_bar.texture_progress = default_SAT_texture


func warn_SAT_bar () -> void:
	var tween := create_tween()
	tween.tween_property(SAT_progress_bar, "tint_progress", Color.html("ff0000"), 0.15)
	tween.tween_property(SAT_progress_bar, "tint_progress", Color.html("ffffff"), 1.0)
	

func update_base_score (number: int, has_jump_anim : bool) -> void:
	base_score_label.text = "{0} G".format([number])

	if has_jump_anim:
		(gold_icon.get_child(0) as AnimationPlayer).stop()
		(gold_icon.get_child(0) as AnimationPlayer).play("jump")


func hide_game_uis () -> void:
	for _control: Control in controls_to_hide:
		_control.hide() 


func toggle_pause_menu (activate : bool) -> void:

	if activate:
		pause_button.disabled = true
		pause_menu.show()
	else:
		pause_button.disabled = false
		pause_menu.hide()

	game_paused.emit(activate)


func toggle_fail_hint() -> void:

	if not failure_textbox: return
	var tween := failure_textbox.create_tween()
	tween.tween_property(failure_textbox, "offset_transform_position:y", 0.0, 0.5).set_delay(1.0)


func toggle_success_hint() -> void:

	if not end_menu_button: return
	end_menu_button.show()
	var tween := end_menu_button.create_tween()
	tween.tween_property(end_menu_button, "offset_transform_position:x", 0.0, 0.5).set_delay(1.0)


func display_warn_text() -> void:

	if not warn_text_box: return
	var tween := warn_text_box.create_tween()
	tween.tween_property(warn_text_box, "offset_transform_position:y", 0.0, 0.5)
	tween.tween_property(warn_text_box, "offset_transform_position:y", 40.0, 0.5).set_delay(3.0)




## Pass in the individual score value as the following order:
## 0: Order Score, 1: Consecutive Score, 2: SAT Score, 3: Perfect Score, 
## 4: Order Quantity, 5: Consecutive Quantity, 6: SAT Quantity, 7: Total Score.
func display_final_score (values: Array[int]) -> void:
	
	if values.size() != 8 :
		return
	
	for i in range(8):
		if i <= 3:
			score_labels[i].text = "{0} G".format([values[i]])
		elif i <= 5:
			sub_description_labels[i - 4].text = "(x{0})".format([values[i]])
		elif i <= 6:
			sub_description_labels[i - 4].text = "({0}%)".format([values[i]])
		else:
			score_labels[4].text = "{0} G".format([values[i]])
	
	scoreboard.show()
	var tween := create_tween()
	for score_row_id in range(5):

		if score_row_id == 4:
			tween.tween_callback(scoreboard_rows[score_row_id].show).set_delay(1.0)
			tween.tween_callback(score_labels[score_row_id].show).set_delay(1.0)
			tween.tween_method(set_score_text.bind(score_labels[score_row_id]), 0, values[7], 2.0)
			continue
		
		if score_row_id == 3 and values[3] == 0:
			continue

		tween.tween_callback(scoreboard_rows[score_row_id].show).set_delay(0.5)
		tween.tween_callback(score_labels[score_row_id].show).set_delay(0.5)
		tween.tween_method(set_score_text.bind(score_labels[score_row_id]), 0, values[score_row_id], 1.0)
	tween.tween_callback(toggle_success_hint).set_delay(1.0)


func set_score_text(value: int, text_label : Label) -> void:
	text_label.text = "{0} G".format([value])