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
			var final_color: Color
			
			# Se for baixo, é Mar
			if elevation <= 0.05: 
				final_color = color_agua
			else:
				# Se for Terra, pedimos os dados de Bioma (Temp + Umidade)
				var biome = planet_data.get_biome_data(pointOnUnitSphere, elevation)
				var temp = biome.temperature # 0.0 (Polo) a 1.0 (Equador)
				var moist = biome.moisture   # -1.0 (Seco) a 1.0 (Úmido)
				
				# Regras de Pintura (Do Frio para o Quente)
				
				# ALTITUDE EXTREMA (Picos de Montanhas viram rocha/neve independente da latitude)
				if elevation > planet_data.height_map.max_height * 0.8:
					final_color = color_rocha
				
				# ZONA POLAR (Frio Extremo)
				elif temp < 0.2:
					final_color = color_neve
					
				# ZONA SUB-POLAR (Frio)
				elif temp < 0.4:
					final_color = color_tundra
					
				# ZONA TEMPERADA (Médio)
				elif temp < 0.7:
					if moist < -0.2: # Temperado Seco
						final_color = color_tundra # Ou uma cor de estepe
					else:
						final_color = color_taiga # Floresta de Coníferas
						
				# ZONA TROPICAL (Quente)
				else:
					if moist < -0.4: # Muito Seco
						final_color = color_deserto
					elif moist < 0.2: # Meio Seco
						final_color = color_savana
					else: # Úmido
						final_color = color_floresta
			
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
