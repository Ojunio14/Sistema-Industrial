@tool
extends Resource
class_name PlanetDataTexture

#signal changed

@export var radius : float = 50.0 :
	set(value):
		radius = value
		emit_signal("changed")

@export var resolution : int = 100 :
	set(value):
		resolution = value
		emit_signal("changed")

@export var height_map : PlanetHeightMap :
	set(value):
		height_map = value
		if height_map:
			height_map.prepare_data()
			if not height_map.is_connected("changed", Callable(self, "on_data_changed")):
				height_map.changed.connect(Callable(self, "on_data_changed"))
		emit_signal("changed")

func on_data_changed():
	if height_map: height_map.prepare_data()
	emit_signal("changed")


# ... (suas variáveis de height_map, radius, etc) ...

@export_group("Biome Settings")
@export var moisture_noise : FastNoiseLite # Arraste um Noise aqui no Inspector!
@export var temperature_noise : FastNoiseLite # Opcional: Para variar um pouco o calor
@export var biome_frequency : float = 1.0 # Frequência dos biomas


func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	var elevation : float = 0.0
	
	if height_map:
		# LÓGICA EQUIRETANGULAR
		# O vetor point_on_sphere já é normalizado (-1 a 1)
		
		# 1. Calcular Longitude (U) - Eixo X/Z
		# atan2 retorna entre -PI e PI.
		var longitude = atan2(point_on_sphere.x, point_on_sphere.z)
		# Converter para 0 a 1
		var u = (longitude / (2.0 * PI)) + 0.5
		
		# 2. Calcular Latitude (V) - Eixo Y
		# asin retorna entre -PI/2 e PI/2
		var latitude = asin(point_on_sphere.y)
		# Converter para 0 a 1
		var v = (latitude / PI) + 0.5
		
		# Correção: Texturas geralmente leem de cima para baixo (0 no topo, 1 em baixo)
		# Então talvez precise inverter o V:
		v = 1.0 - v 
		
		# Ler altura
		var height_percent = height_map.get_height_at_uv(u, v)
		
		# Aplicar escala
		var min_h = height_map.min_height
		var max_h = height_map.max_height
		elevation = min_h + (height_percent * (max_h - min_h))

	return point_on_sphere * (radius + elevation)


# Retorna um Dicionário com { "temp": 0.0 a 1.0, "moist": -1.0 a 1.0 }
func get_biome_data(point_on_sphere: Vector3, elevation_above_sea: float) -> Dictionary:
	
	# 1. TEMPERATURA BASEADA NA LATITUDE (LINHAS DO EQUADOR)
	# point_on_sphere.y vai de -1 (Polo Sul) a 1 (Polo Norte).
	# abs(y) faz com que os dois polos sejam 1 e o equador seja 0.
	var latitude = abs(point_on_sphere.y)
	
	# Invertemos: 1.0 = Equador (Quente), 0.0 = Polos (Frio)
	var base_temp = 1.0 - latitude
	
	# 2. VARIAÇÃO (Ruído)
	# Adicionamos um pouco de ruído para a borda do gelo não ser uma linha reta perfeita
	if temperature_noise:
		var noise_val = temperature_noise.get_noise_3dv(point_on_sphere * biome_frequency)
		base_temp += noise_val * 0.2 # 20% de variação
	
	# 3. ALTITUDE (Lapse Rate)
	# Quanto mais alto, mais frio.
	# Vamos dizer que a cada 1000m (assumindo que max_height é grande), esfria 10%
	if height_map:
		var height_factor = elevation_above_sea / height_map.max_height
		base_temp -= height_factor * 0.5 # Ajuste esse 0.5 para esfriar mais ou menos nas montanhas
		
	# Clampa para não quebrar a lógica (ficar entre 0 e 1)
	base_temp = clamp(base_temp, 0.0, 1.0)
	
	# 4. UMIDADE (Ruído Puro)
	var moisture = 0.0
	if moisture_noise:
		moisture = moisture_noise.get_noise_3dv(point_on_sphere * biome_frequency)
		
	return { "temperature": base_temp, "moisture": moisture }
