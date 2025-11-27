@tool
extends MeshInstance3D
class_name PlanetMeshFace

# --- CONFIGURAÇÃO DE VISUALIZAÇÃO ---
enum ViewMode { SOLID, WIREFRAME, HYBRID }
const CURRENT_MODE : ViewMode = ViewMode.SOLID

# DEFINIÇÃO DOS CANAIS (Pesos Puros)
# R = Areia
# G = Grama
# B = Rocha
# A = Neve
var WEIGHT_SAND  = Color(1, 0, 0, 0)
var WEIGHT_GRASS = Color(0, 1, 0, 0)
var WEIGHT_ROCK  = Color(0, 0, 1, 0)
var WEIGHT_SNOW  = Color(0, 0, 0, 1)

# Material com o Shader de Texturas (Arraste aqui no Inspector ou carregue via código)
# Certifique-se que o caminho "uid://..." está correto ou arraste manualmente
#@export var materialMesh : Material 
const materialMesh : Material  = preload("res://systems/planet_generator/materials/planet.tres")

## Direção da face do cubo
@export var normal : Vector3 

# Variáveis do Quadtree (LOD)
var chunk_origin : Vector2 = Vector2(0, 0) 
var chunk_size : float = 1.0                

# Variável técnica para corrigir a tremedeira da física (Local Vertex Space)
var mesh_offset : Vector3 = Vector3.ZERO

func regenerate_mesh(planet_data : Resource):
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var resolution : int = planet_data.resolution
	var num_vertices : int = resolution * resolution
	var num_indices : int = (resolution-1) * (resolution-1) * 6
	
	var vertex_array := PackedVector3Array()
	var normal_array := PackedVector3Array()
	var color_array := PackedColorArray()
	var uv_array := PackedVector2Array()
	var index_array := PackedInt32Array()
	
	vertex_array.resize(num_vertices)
	normal_array.resize(num_vertices)
	color_array.resize(num_vertices)
	uv_array.resize(num_vertices)
	index_array.resize(num_indices)
	
	var tri_index : int = 0
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	
	# --- PASSO 1: CALCULAR O CENTRO DO CHUNK (OFFSET) ---
	# Descobrimos onde é o centro deste pedaço e movemos o objeto para lá.
	var center_percent = chunk_origin + (Vector2(0.5, 0.5) * chunk_size)
	var center_cube = normal + (center_percent.x-0.5) * 2.0 * axisA + (center_percent.y-0.5) * 2.0 * axisB
	var center_sphere = center_cube.normalized()
	
	# Calcula a posição real do centro no mundo (Double Precision segura isso)
	mesh_offset = planet_data.point_on_planet(center_sphere)
	# ----------------------------------------------------
	
	for y in range(resolution):
		for x in range(resolution):
			var i : int = x + y * resolution
			
			# Lógica do Quadtree
			var percent_in_chunk := Vector2(x, y) / (resolution - 1)
			var percent := percent_in_chunk * chunk_size + chunk_origin
			
			var pointOnUnitCube : Vector3 = normal + (percent.x-0.5) * 2.0 * axisA + (percent.y-0.5) * 2.0 * axisB
			var pointOnUnitSphere := pointOnUnitCube.normalized() 
			
			# 3. GERAÇÃO DE TERRENO
			var world_point = planet_data.point_on_planet(pointOnUnitSphere)
			
			# --- CORREÇÃO DE TREMEDEIRA (GEOMETRIA) ---
			# Vértice relativo ao centro do chunk. Números pequenos para a GPU.
			vertex_array[i] = world_point - mesh_offset
			
			# --- CORREÇÃO DE TREMEDEIRA (TEXTURA - UV LOCAL) ---
			# Ignoramos o mundo. Usamos a geometria do cubo unitário (-1 a 1).
			var face_uv = Vector2(0,0)
			if abs(normal.y) > 0.5: # Cima/Baixo
				face_uv = Vector2(pointOnUnitCube.x, pointOnUnitCube.z)
			elif abs(normal.x) > 0.5: # Esquerda/Direita
				face_uv = Vector2(pointOnUnitCube.y, pointOnUnitCube.z)
			else: # Frente/Trás
				face_uv = Vector2(pointOnUnitCube.x, pointOnUnitCube.y)
			
			# Normaliza de [-1, 1] para [0, 1]
			face_uv = (face_uv + Vector2(1.0, 1.0)) * 0.5
			uv_array[i] = face_uv 
			# ---------------------------------------------------
			
			# 4. PINTURA DOS BIOMAS (Splatmap para o Shader)
			var elevation = world_point.length() - planet_data.radius
			var final_color: Color = Color(0, 0, 0, 0) # Começa invisível (Água)
			
			# 1. DADOS
			var biome = planet_data.get_biome_data(pointOnUnitSphere, elevation)
			var temp = biome.temperature
			var moist = biome.moisture
			var max_h = planet_data.height_map.max_height
			
			# 2. DECISÃO DE BIOMA (Hierarquia Rígida)
			
			# Nível do Mar
			if elevation <= 0.05:
				final_color = Color(0, 0, 0, 0) # Água (Azul no shader)
				
			# Montanhas Altas (Rocha)
			# Regra: Se for muito alto OU alto com ruído de detalhe
			elif elevation > max_h * 0.95:
				final_color = WEIGHT_ROCK
			elif elevation > max_h * 0.75 and abs(moist) > 0.4:
				final_color = WEIGHT_ROCK
				
			# Regiões Polares (Neve)
			elif temp < 0.25:
				final_color = WEIGHT_SNOW
				
			# Regiões Frias / Tundra
			elif temp < 0.45:
				# Aqui você escolhe: Ou é Neve ou é Grama. Nada de mistura.
				if moist > 0.0:
					final_color = WEIGHT_SNOW
				else:
					final_color = WEIGHT_GRASS # Tundra seca é grama/musgo
			
			# Regiões Temperadas e Tropicais
			else:
				# A Umidade define estritamente se é Deserto ou Floresta
				if moist < -0.3:
					final_color = WEIGHT_SAND # Deserto Puro
				elif moist < 0.1:
					final_color = WEIGHT_GRASS # Savana (Agora usamos textura de grama pura, talvez uma grama seca se tiver outra textura)
				else:
					final_color = WEIGHT_GRASS # Floresta
			
			# Aplica a cor pura
			color_array[i] = final_color
			
			# 5. Construção dos Triângulos
			if x != resolution-1 and y != resolution-1:
				index_array[tri_index+2] = i
				index_array[tri_index+1] = i+resolution+1
				index_array[tri_index] = i+resolution
				index_array[tri_index+5] = i
				index_array[tri_index+4] = i+1
				index_array[tri_index+3] = i+resolution+1
				tri_index += 6

	# 6. Cálculo das Normais
	for a in range(0, index_array.size(), 3):
		var b : int = a + 1
		var c : int = a + 2
		var ab : Vector3 = vertex_array[index_array[b]] - vertex_array[index_array[a]]
		var bc : Vector3 = vertex_array[index_array[c]] - vertex_array[index_array[b]]
		var ca : Vector3 = vertex_array[index_array[a]] - vertex_array[index_array[c]]
		var cross_prod : Vector3 = ab.cross(bc) * -1.0 
		normal_array[index_array[a]] += cross_prod
		normal_array[index_array[b]] += cross_prod
		normal_array[index_array[c]] += cross_prod

	for k in range(normal_array.size()):
		normal_array[k] = normal_array[k].normalized()

	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_COLOR] = color_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	# Importante: Usar call_deferred para não travar a thread principal
	call_deferred("_update_mesh", arrays)

func _update_mesh(arrays : Array):
	var _mesh := ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = _mesh
	
	# --- MOVIMENTO DO MESH PARA O LOCAL CERTO ---
	# Aqui a mágica da Double Precision funciona
	self.position = mesh_offset
	
	# --- SISTEMA DE MATERIAIS ---
	var wire_mat = ShaderMaterial.new()
	wire_mat.shader = Shader.new()
	wire_mat.shader.code = """
	shader_type spatial;
	render_mode wireframe, cull_back, unshaded;
	uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	void fragment() { ALBEDO = line_color.rgb; }
	"""
	
	match CURRENT_MODE:
		ViewMode.SOLID:
			if materialMesh:
				self.material_override = materialMesh
		ViewMode.WIREFRAME:
			self.material_override = wire_mat
		ViewMode.HYBRID:
			self.material_override = wire_mat # Simplificado para debug

	# --- SISTEMA DE COLISÃO OTIMIZADO ---
	# Só cria colisão se o chunk for PEQUENO (detalhado)
	if chunk_size < 0.1: 
		
		# 1. Tenta achar o StaticBody
		var static_body = find_child("GeneratedStaticBody", false, false)
		
		# Se não existe, CRIAMOS UM DO ZERO
		if not static_body:
			static_body = StaticBody3D.new()
			static_body.name = "GeneratedStaticBody"
			add_child(static_body)
		
		# 2. Tenta achar o CollisionShape
		var col_shape = static_body.find_child("GeneratedShape", false, false)
		
		if not col_shape:
			col_shape = CollisionShape3D.new()
			col_shape.name = "GeneratedShape"
			static_body.add_child(col_shape)
			
		# 3. GERA A FORMA (SHAPE)
		var trimesh_shape = _mesh.create_trimesh_shape()
		col_shape.shape = trimesh_shape

	else:
		# LÓGICA DE LIMPEZA
		# Se estamos longe, deleta a colisão para economizar memória
		var existing_body = find_child("GeneratedStaticBody", false, false)
		if existing_body:
			existing_body.queue_free()
