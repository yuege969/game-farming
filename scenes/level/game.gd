extends Node2D

const PlantScene := preload("res://scenes/level/plant.tscn")

@onready var _layers: Node2D = $Layers
@onready var _grass_layer: TileMapLayer = $Layers/GrassLayer
@onready var _soil_layer: TileMapLayer = $Layers/SoilLayer
@onready var _water_layer: TileMapLayer = $Layers/WaterLayer
@onready var _soil_water_layer: TileMapLayer = $Layers/SoilWaterLayer
@onready var _objects: Node2D = $Objects
@onready var _player: CharacterBody2D = $Objects/Player

func _ready() -> void:
	_player.tool_action.connect(_on_tool_action)
	_player.plant_action.connect(_on_plant_action)

func _on_tool_action(tool_name: String, target_world_pos: Vector2) -> void:
	match tool_name:
		"axe":
			_handle_axe(target_world_pos)
		"hoe":
			_handle_hoe(target_world_pos)
		"water":
			_handle_water(target_world_pos)

func _on_plant_action(seed_name: String, target_world_pos: Vector2) -> void:
	_handle_plant(seed_name, target_world_pos)

func _handle_plant(seed_name: String, target_world_pos: Vector2) -> void:
	var coords := _world_to_tile(target_world_pos)

	# Only plant on soil tiles
	if _soil_layer.get_cell_source_id(coords) == -1:
		return

	# Don't plant if a Plant already exists at this tile
	if _plant_at_tile(coords) != null:
		return

	var plant: StaticBody2D = PlantScene.instantiate()
	plant.setup(seed_name)
	plant.position = _tile_to_world(coords)
	_objects.add_child(plant)

func _handle_axe(target_world_pos: Vector2) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = target_world_pos
	query.collision_mask = 1  # Tree is on default collision layer 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results := space_state.intersect_point(query)
	for result in results:
		var body: Node2D = result.collider
		if body.is_in_group("Trees"):
			body.flash()
			break

func _handle_hoe(target_world_pos: Vector2) -> void:
	var coords := _world_to_tile(target_world_pos)

	# Only till if grass exists at the target tile
	if _grass_layer.get_cell_tile_data(coords) == null:
		return

	# Don't double-till — soil already present
	if _soil_layer.get_cell_source_id(coords) != -1:
		return

	# Don't till tiles that intersect with water
	if _water_layer.get_cell_source_id(coords) != -1:
		return

	# Place soil tile with terrain auto-connect (terrain_set=0, terrain=0)
	_soil_layer.set_cells_terrain_connect([coords], 0, 0)

func _handle_water(target_world_pos: Vector2) -> void:
	var coords := _world_to_tile(target_world_pos)

	# Only water if soil exists at the target tile
	if _soil_layer.get_cell_source_id(coords) == -1:
		return

	# Don't double-water — soil_water already present
	if _soil_water_layer.get_cell_source_id(coords) != -1:
		return

	# Erase the soil tile and replace with soil_water
	_soil_layer.erase_cell(coords)

	# Random atlas x (0, 1, or 2) for visual variety
	var atlas_x := randi() % 3
	_soil_water_layer.set_cell(coords, 0, Vector2i(atlas_x, 0))

	# Trigger plant growth if a plant exists at this tile
	var plant := _plant_at_tile(coords)
	if plant != null:
		plant.water()

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	var local_pos := _soil_layer.to_local(world_pos)
	return _soil_layer.local_to_map(local_pos)


func _tile_to_world(coords: Vector2i) -> Vector2:
	var local_pos := _soil_layer.map_to_local(coords)
	return _soil_layer.to_global(local_pos)


func _plant_at_tile(coords: Vector2i) -> Node:
	for child in _objects.get_children():
		if child.has_method("setup") and child.has_method("water"):
			var child_coords := _world_to_tile(child.global_position)
			if child_coords == coords:
				return child
	return null
