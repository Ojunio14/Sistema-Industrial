@tool
extends MeshInstance3D
class_name PlanetMeshFace

@export var normal : Vector3 

# --- PALETA DE CORES DOS BIOMAS ---
var color_agua = Color("4682B4")      # Azul Real
var color_neve = Color("FFFFFF")      # Branco Absoluto
var color_tundra = Color("B0C4DE")    # Azul Acinzentado (LightSteelBlue)
var color_taiga = Color("2E8B57")     # Verde Pinho (SeaGreen)
var color_floresta = Color("228B22")  # Verde Floresta
var color_savana = Color("9ACD32")    # Verde Amarelo (YellowGreen)
var color_deserto = Color("F4A460")   # Laranja Areia (SandyBrown)
var color_rocha = Color("696969")     # Cinza Escuro (DimGray)

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
	
	for y in range(resolution):
		for x in range(resolution):
			var i : int = x + y * resolution
			var percent := Vector2(x,y) / (resolution-1)
			
			# 1. Posição Esférica
			var pointOnUnitCube : Vector3 = normal + (percent.x-0.5) * 2.0 * axisA + (percent.y-0.5) * 2.0 * axisB
			var pointOnUnitSphere := pointOnUnitCube.normalized()
			
			# 2. Altura (Vem da IMAGEM agora)
			var pointOnPlanet = planet_data.point_on_planet(pointOnUnitSphere)
			vertex_array[i] = pointOnPlanet
			
			# Calculamos a altura real acima do raio base para saber se é mar ou montanha
			var elevation = pointOnPlanet.length() - planet_data.radius
			
			# 3. LÓGICA DE CORES (BIOMAS)
# ... (código anterior de pointOnPlanet e elevation) ...

			var final_color: Color = Color(0, 0, 0, 0) # Começa transparente
			
			# 1. RECUPERA DADOS DO BIOMA
			var biome = planet_data.get_biome_data(pointOnUnitSphere, elevation)
			var temp = biome.temperature
			var moist = biome.moisture
			
			# 2. CALCULA SE É ROCHA (A parte que faltava)
			var is_rock = false
			var max_h = planet_data.height_map.max_height
			#b56214   17a335
			# Regra: Se for muito alto (95%) ou alto com ruído (75%)
			if elevation > max_h * 0.95:
				is_rock = true
			elif elevation > max_h * 0.75:
				if abs(moist) > 0.4: # Ruído nas bordas da montanha
					is_rock = true

			# 3. DEFINE OS PESOS DAS TEXTURAS (R, G, B, A)
			# R = Areia | G = Grama | B = Pedra | A = Neve
			
			# É Água?
			if elevation <= 0.05:
				final_color = Color(0, 0, 0, 0) # Tudo zero (o shader vai pintar de azul)
				
			# É Rocha?
			elif is_rock: 
				final_color = Color(0, 0, 1, 0) # 100% Azul (Pedra)
				
			# É Gelo? (Polo)
			elif temp < 0.25:
				final_color = Color(0, 0, 0, 1) # 100% Alpha (Neve)
				
			# É Tundra? (Mistura)
			elif temp < 0.45:
				final_color = Color(0, 0.5, 0, 0.5) # Grama + Neve
				
			# É Floresta/Savana?
			elif temp < 0.25:
				if moist < -0.3: 
					final_color = Color(0.5, 0.5, 0, 0) # Savana (Areia + Grama)
				else:
					final_color = Color(0, 1, 0, 0) # Floresta (Grama)
					
			# É Deserto/Equador?
			else:
				if moist < -0.4:
					final_color = Color(1, 0, 0, 0) # Deserto (Areia)
				elif moist < 0.2:
					final_color = Color(0.5, 0.5, 0, 0) # Savana
				else:
					final_color = Color(0, 1, 0, 0) # Selva (Grama)

			color_array[i] = final_color

			# Triângulos
			if x != resolution-1 and y != resolution-1:
				index_array[tri_index+2] = i
				index_array[tri_index+1] = i+resolution+1
				index_array[tri_index] = i+resolution
				
				index_array[tri_index+5] = i
				index_array[tri_index+4] = i+1
				index_array[tri_index+3] = i+resolution+1
				tri_index += 6

	# Normais
	for a in range(0, index_array.size(), 3):
		var b : int = a + 1
		var c : int = a + 2
		var ab : Vector3 = vertex_array[index_array[b]] - vertex_array[index_array[a]]
		var bc : Vector3 = vertex_array[index_array[c]] - vertex_array[index_array[b]]
		var ca : Vector3 = vertex_array[index_array[a]] - vertex_array[index_array[c]]
		var normal_tri = ab.cross(bc) * -1.0
		normal_array[index_array[a]] += normal_tri
		normal_array[index_array[b]] += normal_tri
		normal_array[index_array[c]] += normal_tri
	
	for i in range(normal_array.size()):
		normal_array[i] = normal_array[i].normalized()

	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_COLOR] = color_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	call_deferred("_update_mesh", arrays)

func _update_mesh(arrays : Array):
	var _mesh := ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = _mesh
