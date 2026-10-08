class_name ScoreSystem
extends Node2D

@export var base_order_score : Dictionary[GameConstants.Difficulty, int]
@export var consecutive_bonus : int
@export var SAT_rate_bonus : int
@export var perfect_bonus : Dictionary[GameConstants.Difficulty, int]

var current_difficulty : GameConstants.Difficulty
var current_consecutive := 0
var order_complete := 0
var consecutive_complete := 0
var SAT := 0
var is_perfect := true

var final_order_score := 0
var final_consecutive_score := 0
var final_SAT_score := 0
var final_perfect_score := 0
var total_score := 0


func initialize(diff: GameConstants.Difficulty) -> void:
	current_difficulty = diff


func on_interacted(success : bool) -> void:

	if success:
		order_complete += 1
		current_consecutive += 1
		consecutive_complete = current_consecutive if current_consecutive >= consecutive_complete else consecutive_complete
	else:
		current_consecutive = 0
		is_perfect = false


func display_base_score() -> int:
	return base_order_score[current_difficulty] * order_complete


func calculate_final(current_SAT : float) -> void:
	SAT = floori(current_SAT)

	final_order_score = (base_order_score[current_difficulty] * order_complete)
	final_consecutive_score = consecutive_bonus * consecutive_complete
	final_SAT_score = SAT * SAT_rate_bonus
	final_perfect_score = perfect_bonus[current_difficulty] if is_perfect else 0

	total_score = (
		final_order_score + final_consecutive_score + final_SAT_score + final_perfect_score
	)


## Pass in the individual score value as the following order:
## 0: Order Score, 1: Consecutive Score, 2: SAT Score, 3: Perfect Score, 
## 4: Order Quantity, 5: Consecutive Quantity, 6: SAT Quantity, 7: Total Score
func query_individual_scores() -> Array[int]:
	return [final_order_score, final_consecutive_score, final_SAT_score, final_perfect_score,
	order_complete, consecutive_complete, SAT, total_score]
