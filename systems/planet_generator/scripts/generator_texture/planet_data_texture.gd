@tool
extends Resource
class_name PlanetDataTexture


@export var radius : float = 600000.0 :
	set(value):
		radius = value
		emit_signal("changed")

@export var resolution : int = 100 :
	set(value):
		resolution = value
		emit_signal("changed")

# --- O SEGREDO DA SUAVIZAÇÃO ---
# Esta curva vai controlar o perfil do terreno.
# Eixo X (0 a 1) = Valor da cor na Imagem.
# Eixo Y (0 a 1) = Altura real do terreno.
@export var height_curve : Curve 
# -------------------------------

@export var height_map : PlanetHeightMap :
	set(value):
		height_map = value
		if height_map:
			height_map.prepare_data()
			if not height_map.is_connected("changed", Callable(self, "on_data_changed")):
				height_map.changed.connect(Callable(self, "on_data_changed"))
		emit_signal("changed")

# Configurações de Biomas (Latitude/Umidade)
@export_group("Biome Settings")
@export var moisture_noise : FastNoiseLite 
@export var temperature_noise : FastNoiseLite 
@export var biome_frequency : float = 1.0 

func on_data_changed():
	if height_map: height_map.prepare_data()
	emit_signal("changed")

func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	var elevation : float = 0.0
	
	if height_map:
		# 1. Lógica Equirretangular (Latitude/Longitude)
		var longitude = atan2(point_on_sphere.x, point_on_sphere.z)
		var u = (longitude / (2.0 * PI)) + 0.5
		var latitude = asin(point_on_sphere.y)
		var v = (latitude / PI) + 0.5
		v = 1.0 - v 
		
		# 2. Ler valor bruto da imagem (0 a 1)
		var raw_height = height_map.get_height_at_uv(u, v)
		
		# 3. APLICAR A CURVA (O Blend da Costa)
		var final_height_percent = raw_height
		
		if height_curve:
			# Aqui a mágica acontece. A curva transforma o valor.
			# Se raw_height for 0.1 (costa abrupta), a curva pode baixar para 0.01 (praia rasa).
			final_height_percent = height_curve.sample(raw_height)
		
		# 4. Calcular altura final
		var min_h = height_map.min_height
		var max_h = height_map.max_height
		elevation = min_h + (final_height_percent * (max_h - min_h))

	return point_on_sphere * (radius + elevation)

# ... (Mantenha sua função get_biome_data aqui igual estava antes) ...
func get_biome_data(point_on_sphere: Vector3, elevation_above_sea: float) -> Dictionary:
	var latitude = abs(point_on_sphere.y)
	var base_temp = 1.0 - latitude
	if temperature_noise:
		var noise_val = temperature_noise.get_noise_3dv(point_on_sphere * biome_frequency)
		base_temp += noise_val * 0.2 
	if height_map:
		var height_factor = elevation_above_sea / height_map.max_height
		base_temp -= height_factor * 0.5 
	base_temp = clamp(base_temp, 0.0, 1.0)
	var moisture = 0.0
	if moisture_noise:
		moisture = moisture_noise.get_noise_3dv(point_on_sphere * biome_frequency)
	return { "temperature": base_temp, "moisture": moisture }
