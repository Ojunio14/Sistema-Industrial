extends Node
class_name FloatingOrigin

# Distância limite antes de recentralizar o mundo
const THRESHOLD : float = 5000.0 

@onready var player_node : Node3D = get_parent()

func _physics_process(delta):
	if not player_node: return

	# Verifica a distância do jogador até o centro absoluto (0,0,0)
	var distance_from_center = player_node.global_position.length()
	
	if distance_from_center > THRESHOLD:
		shift_world_origin(player_node.global_position)

func shift_world_origin(offset : Vector3):
	#print(">>> Origem Flutuante Ativada! Offset: ", offset)
	
	var scene_root = get_tree().current_scene
	
	# Mover a PRÓPRIA RAIZ da cena move tudo junto (Planeta, Player, etc)
	# Isso garante que a distância Player <-> Planeta continue correta para o Quadtree.
	if scene_root is Node3D:
		scene_root.global_position -= offset
	
	# Fallback de segurança (caso a raiz não seja Node3D)
	else:
		for node in scene_root.get_children():
			if node is Node3D:
				node.global_position -= offset
