class_name CoreSystem
extends Node2D

signal interaction (success : bool)
signal request_generated (item_sprite : Sprite2D)
signal customer_arrived

enum ItemType {
	NONE,
	MEAT,
	POTION,
	BEER,
	FRUIT,
	SOUP,
}

@export_group("Child Nodes")
@export var interactable_points : Array[InteractablePoint]
@export var player : Node2D
@export var player_sprite : AnimatedSprite2D
@export var speech_bubble : Node2D
@export_group("Marker Positions")
@export var toss_item_marker : Node2D
@export var request_item_marker : Node2D
@export var arrival_marker : Node2D
@export var receive_marker : Node2D
@export var departure_marker : Node2D
@export var waiting_markers : Array[Node2D]
@export_group("Properties")
@export var texture_library : Dictionary[ItemType, Texture2D]
@export var customer_sprite_frames : Array[SpriteFrames]
@export var customer_move_speed := 320.0
@export var item_arrival_time := 0.5

var difficulty := GameConstants.Difficulty.EASY
var request_item_type := ItemType.NONE
var request_item_obj : Node2D
var player_tween : Tween
var request_queue : Array[int]
var standing_item_type := ItemType.NONE
var is_interacting := false
var customer_sprite_queue : Array[int]
var wait_customer_queue : Array[Customer]
var send_item_queue : Array[ItemType]
var send_customer_queue : Array[Customer]
var is_game_running := false


# Binding systems
func _ready() -> void:

	for point in interactable_points:
		point.interaction.connect(interact)
	player_sprite.animation_finished.connect(player_anim_transition)

	for i in range (5):
		interactable_points[i].visible = false
	
	for i in range (3):
		wait_customer_queue.append(instantiate_customer(waiting_markers[i].global_position))

	request_item_marker.hide()


## Launches the core system
func start_game(diff : GameConstants.Difficulty) -> void:

	difficulty = diff
	for i in range (5):
		if i < 3 + (diff as int):
			interactable_points[i].visible = true

	request_item_marker.show()

	is_game_running = true
	generate_request(false)


## Stops the core system and player interaction
func stop_game(success : bool) -> void:

	for point in interactable_points:
		point.visible = false
	if request_item_obj:
		request_item_obj.queue_free()
	request_item_marker.hide()
	is_game_running = false

	if success:
		for i in range(wait_customer_queue.size()):
			var customer := wait_customer_queue[i]
			if i <= 2:
				customer.drag_to_position(departure_marker.global_position, customer_move_speed)
			else:
				customer.drag_to_position(waiting_markers[2].global_position, customer_move_speed)
				customer.drag_to_position(departure_marker.global_position, customer_move_speed, true)

	else:
		if player_tween:
			player_tween.kill()
		player_sprite.play("faint")



## Player interacts with an appliance -- execution varies depedning on the success of fulfilling current item request.
func interact(point: Vector2, item_type: ItemType) -> void:
	
	# Block interactions when player is still in the middle of the movement animation
	if is_interacting:
		return

	# Checks if the interacted appliance fulfils the current request
	if check_request(item_type):
		
		is_interacting = true
		generate_request()

		# Only move the player sprite when they are not standing at the same appliance
		var movement_duration := 0.0
		
		if standing_item_type != item_type:
			standing_item_type = item_type

			player_sprite.flip_h = true if point.x < player.position.x else false
			player_sprite.play("move")
			movement_duration = 0.1
			
		# Play related tween when interaction is successful
		if player_tween:
			player_tween.kill()
		player_tween = create_tween()
		player_tween.tween_property(player, "global_position", point, movement_duration)
		player_tween.tween_callback(
			spawn_tossed_item.bind(item_type, self, point, toss_item_marker.global_position)
		)
		player_tween.tween_callback(func() -> void: is_interacting = false)
		player_tween.tween_callback(func() -> void: player_sprite.flip_h = false)
		player_tween.tween_callback(player_sprite.play.bind("toss"))

		interaction.emit(true)

	else:
		interaction.emit(false)


## Attach a basic item sprite to *target* object.
func create_item_sprite(item_type: ItemType, parent: Node2D, offset := Vector2.ZERO) -> Sprite2D:
	
	if item_type == ItemType.NONE : return

	var _item := Sprite2D.new()
	parent.add_child(_item)
	_item.position = offset
	_item.texture = texture_library[item_type]
	_item.z_index = 99
	_item.global_scale = Vector2.ONE

	return _item


## Generate / Replace current item request.
func generate_request(wait_for_customer := true) -> void:

	# Refresh new request queue when current queue is empty, total quantity is 4 x difficulty level
	if request_queue.size() <= 0:
		var request_quantity := 3 + difficulty as int
		request_queue.clear()
		for i in range(4 * request_quantity):
			request_queue.append(i % request_quantity + 1)
		request_queue.shuffle()

	# Pop final element as current item request
	var _item_type : int = request_queue.pop_back()
	request_item_type = _item_type as ItemType
	
	# Refresh item request sprite
	if request_item_obj:
		request_item_obj.queue_free()
	request_item_obj = create_item_sprite(_item_type, request_item_marker)

	if wait_for_customer:
		spawn_customer()
		await customer_arrived

	if is_game_running:
		request_generated.emit(request_item_obj as Sprite2D)


## Check item passed fulfils current item request.
func check_request(item_type: ItemType) -> bool:
	return item_type == request_item_type


## Contains all animation transitions for players
func player_anim_transition() -> void:
	if player_sprite.animation == "toss":
		player_sprite.play("idle")


## Spawn a temporary item and throw it at an arc with a specified destination
func spawn_tossed_item (item_type: ItemType, parent: Node2D, origin: Vector2, destination: Vector2) -> void:

	var item := create_item_sprite(item_type, parent)
	send_item_queue.append(item_type)

	item.global_position = origin

	var arc_height := -70.0
	var highest_y_point := origin.y + arc_height + (destination.x - origin.x) / 10.0

	var tween_x := item.create_tween()
	tween_x.tween_property(item, "position:x", destination.x, item_arrival_time)

	var tween_arc := item.create_tween().set_trans(Tween.TRANS_SINE)
	tween_arc.tween_property(item, "position:y", highest_y_point , item_arrival_time / 2.0).set_ease(Tween.EASE_OUT)
	tween_arc.tween_property(item, "position:y", destination.y, item_arrival_time / 2.0).set_ease(Tween.EASE_IN)
	tween_arc.tween_callback(send_customer)
	tween_arc.tween_callback(item.queue_free)


func spawn_customer() -> void:
	
	request_item_obj.hide()
	speech_bubble.scale = Vector2.ZERO

	var current_customer : Customer = wait_customer_queue.pop_front()
	if current_customer:
		send_customer_queue.append(current_customer)
		current_customer.drag_to_position(receive_marker.global_position, customer_move_speed)

	wait_customer_queue.append(instantiate_customer())

	for i in range(wait_customer_queue.size()):
		var customer := wait_customer_queue[i]
		var tween := create_tween()
		customer.drag_to_position(waiting_markers[i].global_position, customer_move_speed)
		tween.tween_subtween(customer.self_tween)
		if i == 0:
			tween.tween_property(speech_bubble, "scale", Vector2.ONE, 0.15)
			tween.tween_callback(request_item_obj.show)
			tween.tween_callback(customer_arrived.emit)


func spawn_rushed_customer() -> void:
	
	for i in range(3, 5):
		var customer := instantiate_customer()
		wait_customer_queue.append(customer)
		customer.drag_to_position(waiting_markers[i].global_position, customer_move_speed)


func instantiate_customer(_spawn_pos := arrival_marker.global_position) -> Customer:
	if customer_sprite_queue.size() <= 0:
		var sprite_quantity := customer_sprite_frames.size()
		customer_sprite_queue.clear()
		for i in range(sprite_quantity):
			customer_sprite_queue.append(i % sprite_quantity)
		customer_sprite_queue.shuffle()

	var customer := Customer.new()
	var frame_id : int = customer_sprite_queue.pop_back()
	customer.initialize(customer_sprite_frames[frame_id], self, _spawn_pos)
	return customer


func send_customer() -> void:

	var item_type : ItemType = send_item_queue.pop_front()
	var customer : Customer = send_customer_queue.pop_front()

	create_item_sprite(item_type, customer, Vector2(0.0, -10.0))
	var tween := create_tween()
	customer.drag_to_position(departure_marker.global_position, customer_move_speed)
	tween.tween_subtween(customer.self_tween)
	tween.tween_callback(customer.queue_free)



class Customer extends AnimatedSprite2D:
	
	var self_tween : Tween


	func initialize(_sprite_frames : SpriteFrames, parent : Node2D, spawn_pos : Vector2) -> void:

		parent.add_child(self)
		self.global_position = spawn_pos
		self.sprite_frames = _sprite_frames
		self.play("idle")
		self.scale = Vector2(1.25, 1.25)
		self.flip_h = true
		self.z_index = 15


	func drag_to_position(pos: Vector2, speed: float, continue_previous_movement := false) -> void:

		var origin : Vector2 = self.global_position
		var distance := origin.distance_to(pos)

		if not continue_previous_movement:
			if self_tween:
				self_tween.kill()
			self_tween = create_tween()
		
		self_tween.tween_callback(self.play.bind("move"))
		self_tween.tween_property(self, "global_position", pos, distance / speed)
		self_tween.tween_callback(self.play.bind("idle"))
