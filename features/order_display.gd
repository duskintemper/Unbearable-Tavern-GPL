class_name OrderDisplay
extends Node2D

enum Display{
    FULL_FADE,
    COLOR_FADE,
    SCREEN_UP,
    SCREEN_DOWN,
    SLOW_UP,
    SLOW_DOWN,
}

@export_group("Properties")
@export var mask_texture : Texture2D
@export var initial_color_fade : Color
@export var screen_color : Color
var display_tween_1 : Tween
var display_tween_2 : Tween
var current_difficulty : GameConstants.Difficulty
var display_queue : Array[int]
## random queue for display should follow request generation queue logic from before


func initialize(diff: GameConstants.Difficulty) -> void:
    current_difficulty = diff


func display_item(item_sprite : Sprite2D, display_id := 1) -> void:
    
    if not item_sprite : return

	# Refresh new display queue when current queue is empty, total quantity is 2 x difficulty level
    if display_queue.size() <= 0:
        var display_quantity := 2 * (1 + current_difficulty as int)
        display_queue.clear()
        for i in range(2 * display_quantity):
            display_queue.append(i % display_quantity)
        display_queue.shuffle()

    # Pop final element as current display request
    var target_tween := display_tween_2 if display_id == 2 else display_tween_1
    var selection : int = display_queue.pop_back()
    var display_type :=  selection as Display

    if target_tween:
        target_tween.kill()
    target_tween = create_tween()
    
    match display_type:
        Display.FULL_FADE:
            item_sprite.self_modulate.a = 0.0
            target_tween.tween_property(item_sprite, "self_modulate:a", 1.0, 0.25) 

        Display.COLOR_FADE:
            item_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
            var grey_mask := Sprite2D.new()
            grey_mask.texture = mask_texture
            grey_mask.self_modulate = initial_color_fade
            item_sprite.add_child(grey_mask)
            item_sprite.self_modulate.a = 0.0
            target_tween.tween_property(item_sprite, "self_modulate:a", 1.0, 2.0)
            target_tween.tween_property(grey_mask, "self_modulate:a", 0.0, 2.0)
            target_tween.tween_callback(grey_mask.queue_free)

        Display.SCREEN_UP, Display.SLOW_UP:
            var screen_speed := 2.0 if display_type == Display.SCREEN_UP else 4.0
            item_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
            var screen_mask := Sprite2D.new()
            screen_mask .texture = mask_texture
            screen_mask .self_modulate = screen_color
            item_sprite.add_child(screen_mask)
            target_tween.set_parallel()
            target_tween.tween_property(screen_mask, "scale:y", 0.01, screen_speed)
            target_tween.tween_property(screen_mask, "position:y", 8.0, screen_speed)
            target_tween.set_parallel(false)
            target_tween.tween_callback(screen_mask.queue_free)

        Display.SCREEN_DOWN, Display.SLOW_DOWN:
            var screen_speed := 2.0 if display_type == Display.SCREEN_DOWN else 4.0
            item_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
            var screen_mask := Sprite2D.new()
            screen_mask .texture = mask_texture
            screen_mask .self_modulate = screen_color
            item_sprite.add_child(screen_mask)
            target_tween.set_parallel()
            target_tween.tween_property(screen_mask, "scale:y", 0.01, screen_speed)
            target_tween.tween_property(screen_mask, "position:y", -8.0, screen_speed)
            target_tween.set_parallel(false)
            target_tween.tween_callback(screen_mask.queue_free)


func clear_display() -> void:
    if display_tween_1:
        display_tween_1.kill()
    if display_tween_2:
        display_tween_2.kill()
