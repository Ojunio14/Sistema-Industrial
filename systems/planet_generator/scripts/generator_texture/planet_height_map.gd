@tool
extends Resource
class_name PlanetHeightMap

@export var min_height : float = 0.0
@export var max_height : float = 10.0

# Sua imagem panorâmica (Equirretangular)
@export var panorama : Texture2D 

var _image : Image
var _width : int
var _height : int

func prepare_data():
	if panorama: 
		_image = panorama.get_image()
		_width = _image.get_width()
		_height = _image.get_height()

# --- A MÁGICA DA SUAVIZAÇÃO (Bilinear Filtering) ---
# Em vez de pegar 1 pixel, pegamos 4 e misturamos.
func get_height_at_uv(u: float, v: float) -> float:
	if not _image: return 0.0
	
	# Coordenada exata (com vírgula) na imagem
	var x_float = u * (_width - 1)
	var y_float = v * (_height - 1)
	
	# WRAP HORIZONTAL (Para não ter costura lateral)
	x_float = fmod(x_float, float(_width - 1))
	if x_float < 0: x_float += (_width - 1)
	
	# CLAMP VERTICAL (Para não dar a volta nos polos)
	y_float = clamp(y_float, 0.0, float(_height - 1))
	
	# Acha os 4 pixels vizinhos
	var x0 = int(floor(x_float))
	var y0 = int(floor(y_float))
	var x1 = (x0 + 1) % _width # Wrap no X+1 também
	var y1 = min(y0 + 1, _height - 1)
	
	# Pesos da mistura (O quanto estamos perto de cada um)
	var w_x = x_float - x0
	var w_y = y_float - y0
	
	# Pega as cores (Altura)
	var h00 = _image.get_pixel(x0, y0).r # Top Left
	var h10 = _image.get_pixel(x1, y0).r # Top Right
	var h01 = _image.get_pixel(x0, y1).r # Bottom Left
	var h11 = _image.get_pixel(x1, y1).r # Bottom Right
	
	# Mistura (Lerp)
	var top_mix = lerp(h00, h10, w_x)
	var bot_mix = lerp(h01, h11, w_x)
	var final_height = lerp(top_mix, bot_mix, w_y)
	
	return final_height
