#@tool
class_name Planet
extends Node3D

# --- Configurações Principais ---
@export var player : Node3D # Arraste o Player ou a Camera3D aqui
@export var radius : float = 100.0:
	set(value):
		radius = value
		if planet_data: planet_data.radius = value
		on_data_changed() # Reconstrói se mudar o raio no editor

@export var resolution : int = 16:
	set(value):
		resolution = value
		if planet_data: planet_data.resolution = value
		on_data_changed()

# --- Resource de Dados (Com Setter Inteligente do Script B) ---
@export var planet_data : PlanetDataTexture:
	set(value):
		# Desconecta o sinal do resource antigo se existir
		if planet_data and planet_data.is_connected("changed", Callable(self, "on_data_changed")):
			planet_data.disconnect("changed", Callable(self, "on_data_changed"))
		
		planet_data = value
		
		# Conecta o sinal no novo resource
		if planet_data:
			if not planet_data.is_connected("changed", Callable(self, "on_data_changed")):
				planet_data.connect("changed", Callable(self, "on_data_changed"))
			# Sincroniza os valores iniciais
			planet_data.radius = radius
			planet_data.resolution = resolution
		
		on_data_changed()

# --- Variáveis Internas ---
var player_cam : Camera3D

func _ready():
	# Se não tiver dados, cria um novo para evitar crash
	if not planet_data:
		planet_data = PlanetDataTexture.new()
		planet_data.radius = radius
		planet_data.resolution = resolution
	
	# Configuração da Câmera (Só funciona DENTRO do jogo, não no editor)
	if not Engine.is_editor_hint():
		setup_camera()
	
	on_data_changed()

func setup_camera():
	if player:
		# Tenta encontrar a câmera de várias formas
		if player is Camera3D:
			player_cam = player
		elif player.has_node("Camera3D"): # Godot 4 padrão
			player_cam = player.get_node("Camera3D")
		elif player.has_node("Camera"):   # Seu nome customizado
			player_cam = player.get_node("Camera")
			
	if not player_cam:
		push_warning("Planet: Nenhuma câmera encontrada no Player!")

func on_data_changed():
	# IMPORTANTE: Quadtree precisa destruir tudo e recomeçar se os dados base mudarem
	# Limpa os filhos antigos (Faces antigas)
	for child in get_children():
		child.queue_free()
	
	# Só gera a Quadtree se estiver no jogo OU se você quiser ver no editor (cuidado com performance)
	# Aqui vou permitir gerar no editor para você ver a esfera base
	spawn_quadtree_faces()

func spawn_quadtree_faces():
	# Se estivermos no editor e sem câmera, o QuadtreeNode precisa saber lidar com isso
	# (Geralmente ele mostra LOD 0 se a câmera for null)
	
	var directions = [
		Vector3.UP, Vector3.DOWN, 
		Vector3.LEFT, Vector3.RIGHT, 
		Vector3.FORWARD, Vector3.BACK
	]
	
	for dir in directions:
		# Cria o nó raiz para cada face
		var face_node = QuadtreeNode.new() # Certifique-se que QuadtreeNode tem class_name
		face_node.name = "Face_" + str(dir)
		add_child(face_node)
		
		# Em editor, player_cam será null, o QuadtreeNode deve lidar com isso exibindo resolução baixa
		face_node.initialize(planet_data, dir, Vector2(0,0), 1.0, 0, self, player_cam)
