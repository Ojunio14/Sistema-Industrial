@tool
extends Resource
class_name PlanetHeightMap

@export var min_height : float = 0.0
@export var max_height : float = 10.0

# Agora é apenas UMA imagem panorâmica (2:1 aspect ratio)
@export var panorama : Texture2D 

var _image : Image

func prepare_data():
	if panorama: 
		_image = panorama.get_image()

# Função simplificada (Lê apenas UV)
func get_height_at_uv(u: float, v: float) -> float:
	if not _image: return 0.0
	
	var w = _image.get_width()
	var h = _image.get_height()
	
	# Mapeia 0..1 para Pixels
	var x_float = u * (w - 1)
	var y_float = v * (h - 1)
	
	# --- SOLUÇÃO DA COSTURA (WRAP) ---
	# Aqui a mágica acontece. Se sair da borda, dá a volta.
	# Usamos fmod para garantir que 1.1 vire 0.1
	x_float = fmod(x_float, float(w - 1))
	if x_float < 0: x_float += (w - 1)
	
	# Clamp no Y (Não dá a volta nos polos, senão inverte o mundo)
	y_float = clamp(y_float, 0.0, h - 1.0)
	
	# Interpolação Simples (Nearest Neighbor) para teste
	# Se quiser suave, use a lógica bilinear que mandei antes adaptada aqui
	var x = int(x_float)
	var y = int(y_float)
	
	return _image.get_pixel(x, y).r
