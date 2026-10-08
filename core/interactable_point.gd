class_name InteractablePoint
extends Area2D

signal interaction (point: Vector2, item: CoreSystem.ItemType)

@export_group("Child Nodes")
@export var move_destination : Node2D
@export var station_sprite : AnimatedSprite2D
@export var indicator_sprite : Sprite2D
@export_group("Properties")
@export var item_to_create : CoreSystem.ItemType
@export var outline_material : Material


func _ready() -> void:
	hidden.connect(on_hidden)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var current_event := event as InputEventMouseButton
		if current_event.button_index == MOUSE_BUTTON_LEFT and current_event.pressed:
			interaction.emit(move_destination.global_position, item_to_create)


func _mouse_enter() -> void:

	if station_sprite:
		station_sprite.material = outline_material

	if indicator_sprite:
		indicator_sprite.material = outline_material


func _mouse_exit() -> void:

	if station_sprite:
		station_sprite.material = null

	if indicator_sprite:
		indicator_sprite.material = null


func on_hidden() -> void:

	if station_sprite:
		station_sprite.material = null

	if indicator_sprite:
		indicator_sprite.material = null
