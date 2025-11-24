extends Camera3D

# Configurações de Sensibilidade e Velocidade
@export_group("Controles da Câmera")
@export var mouse_sensitivity : float = 0.002
@export var base_speed : float = 10.0
@export var boost_multiplier : float = 5.0  # Multiplicador ao segurar Shift
@export var max_speed_scale : float = 100.0 # Para viajar rápido pelo planeta

# Variáveis internas
var current_speed_scale : float = 1.0

func _ready():
	# Captura o mouse para ele não sair da tela
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# 1. Rotação da Câmera (Mouse)
	if event is InputEventMouseMotion:
		# Rotação horizontal (Y) - Gira o corpo no eixo global Y ou local
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotação vertical (X) - Gira a câmera localmente
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		
		# Previne que a câmera gire demais (looping) corrigindo o eixo Z (roll)
		# Mantém o horizonte estável se desejar, ou remova para liberdade total (6DoF)
		rotation.z = 0 

	# 2. Controle de Velocidade (Scroll do Mouse)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_speed_scale = min(current_speed_scale * 1.1, max_speed_scale)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_speed_scale = max(current_speed_scale * 0.9, 0.1)
	
	# 3. Sair do modo captura (Tecla ESC)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	# Se o mouse não estiver capturado, não move (para poder editar menus, etc)
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	# Define a velocidade atual
	var speed = base_speed * current_speed_scale
	if Input.is_key_pressed(KEY_SHIFT): # Ou use Input.is_action_pressed("speed_boost")
		speed *= boost_multiplier

	# Vetor de movimento local
	var velocity = Vector3.ZERO

	# Movimentação WASD (Local)
	# Nota: Use os nomes das suas Actions ou KEY_W, KEY_S hardcoded se preferir
	if Input.is_key_pressed(KEY_W): velocity += Vector3.FORWARD
	if Input.is_key_pressed(KEY_S): velocity += Vector3.BACK
	if Input.is_key_pressed(KEY_A): velocity += Vector3.LEFT
	if Input.is_key_pressed(KEY_D): velocity += Vector3.RIGHT
	
	# Movimentação Vertical (Q/E ou Espaço/Ctrl) - Relativo à câmera
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE): 
		velocity += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL): 
		velocity += Vector3.DOWN

	# Normaliza para não andar mais rápido na diagonal
	velocity = velocity.normalized()

	# A MÁGICA ACONTECE AQUI:
	# Traduzimos o vetor de movimento local para o espaço global usando a "Basis" da câmera.
	# transform.basis * vector transforma "Frente local" em "Frente global"
	var global_velocity = transform.basis * (velocity * speed * delta)
	
	position += global_velocity
