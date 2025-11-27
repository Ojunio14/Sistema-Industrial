shader_type spatial;

// IMPORTANTE: REMOVEMOS O 'render_mode world_vertex_coords'.
// Agora o VERTEX é local (pequeno) e seguro.

// --- TEXTURAS ---
uniform sampler2D texture_sand : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_grass : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_rock : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_snow : source_color, filter_linear_mipmap_anisotropic;

// --- ESCALA ---
uniform float scale_micro = 1.0; 

// --- DADOS DO SCRIPT (Juan's Method) ---
uniform vec3 chunk_offset;

// --- VARIÁVEIS PARA O FRAGMENT ---
varying vec3 v_stable_pos; 
varying vec3 v_world_normal;

void vertex() {
	// 1. POSIÇÃO ESTÁVEL (RTE)
	// VERTEX = Posição local do vértice (Pequeno, vem do script)
	// chunk_offset = Resto da divisão da posição do mundo (Pequeno, vem do script)
	// Resultado: Uma posição perfeita para texturizar, sem números gigantes.
	v_stable_pos = VERTEX + chunk_offset;
	
	// 2. NORMAL DO MUNDO (MANUAL)
	// Como desligamos o world_vertex_coords, o NORMAL é local.
	// Precisamos rodar ele para alinhar com o planeta, mas SEM somar a posição gigante.
	// Usamos (NORMAL, 0.0) para aplicar apenas a Rotação da Model Matrix.
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 get_triplanar_sample(sampler2D p_sampler, vec3 p_weights, vec3 p_pos, float p_scale) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_pos.xz * p_scale) * p_weights.y; // Topo
	samp += texture(p_sampler, p_pos.xy * p_scale) * p_weights.z; // Frente
	samp += texture(p_sampler, p_pos.zy * p_scale) * p_weights.x; // Lado
	return samp;
}

void fragment() {
	// --- BLENDING COM NORMAL CORRIGIDA ---
	vec3 blending = abs(v_world_normal);
	blending = normalize(max(blending, 0.00001));
	
	// Nitidez na curva (opcional, mantenha se gostou do resultado anterior)
	blending = pow(blending, vec3(4.0));
	
	float b = (blending.x + blending.y + blending.z);
	blending /= vec3(b, b, b);

	// --- LEITURA DAS TEXTURAS ---
	// Usamos a v_stable_pos que é livre de tremedeira
	vec3 sand_mic = get_triplanar_sample(texture_sand, blending, v_stable_pos, scale_micro).rgb;
	vec3 grass_mic = get_triplanar_sample(texture_grass, blending, v_stable_pos, scale_micro).rgb;
	vec3 rock_mic = get_triplanar_sample(texture_rock, blending, v_stable_pos, scale_micro).rgb;
	vec3 snow_mic = get_triplanar_sample(texture_snow, blending, v_stable_pos, scale_micro).rgb;

	// --- MISTURA SPLATMAP ---
	vec3 final_albedo = vec3(0.0);
	final_albedo += sand_mic * COLOR.r;
	final_albedo += grass_mic * COLOR.g;
	final_albedo += rock_mic * COLOR.b;
	final_albedo += snow_mic * COLOR.a;
	
	// Água
	float total_weight = COLOR.r + COLOR.g + COLOR.b + COLOR.a;
	if (total_weight < 0.1) {
		final_albedo = vec3(0.0, 0.2, 0.5); 
		ROUGHNESS = 0.1;
		METALLIC = 0.5;
	} else {
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	}

	ALBEDO = final_albedo;
}