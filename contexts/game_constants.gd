class_name GameConstants

enum Difficulty {
	EASY,
	NORMAL,
	HARD,
}

static var current_difficulty := Difficulty.EASY
static var high_score := 0