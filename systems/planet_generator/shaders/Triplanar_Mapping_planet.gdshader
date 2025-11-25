shader_type spatial;

// Input das Texturas (Arraste as imagens aqui no Inspector)
uniform sampler2D texture_sand : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_grass : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_rock : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D texture_snow : source_color, filter_linear_mipmap_anisotropic;

// Tamanho das texturas (Quanto maior, mais elas se repetem)
uniform float uv_scale = 0.5;

// Função Mágica: Triplanar Mapping
// Ela projeta a textura de 3 lados (X, Y, Z) e mistura
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy * uv_scale) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz * uv_scale) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * uv_scale) * p_weights.x;
	return samp;
}

void fragment() {
	// 1. Calcular pesos Triplanares (Baseado na Normal do terreno)
	// Isso evita que a textura estique em paredes verticais
	vec3 blending = abs(NORMAL);
	blending = normalize(max(blending, 0.00001));
	float b = (blending.x + blending.y + blending.z);
	blending /= vec3(b, b, b);

	// 2. Ler as 4 texturas usando Triplanar
	// VERTEX é a posição do ponto no mundo
	vec4 col_sand = triplanar_texture(texture_sand, blending, VERTEX);
	vec4 col_grass = triplanar_texture(texture_grass, blending, VERTEX);
	vec4 col_rock = triplanar_texture(texture_rock, blending, VERTEX);
	vec4 col_snow = triplanar_texture(texture_snow, blending, VERTEX);

	// 3. Misturar baseado na COR DO VÉRTICE (COLOR)
	// COLOR.r = Peso da Areia
	// COLOR.g = Peso da Grama
	// COLOR.b = Peso da Rocha
	// COLOR.a = Peso da Neve
	
	vec3 final_albedo = vec3(0.0);
	
	// Soma as texturas multiplicadas pelo peso que definimos no script
	final_albedo += col_sand.rgb * COLOR.r;
	final_albedo += col_grass.rgb * COLOR.g;
	final_albedo += col_rock.rgb * COLOR.b;
	final_albedo += col_snow.rgb * COLOR.a;
	
	// Adiciona uma cor azul base onde não tem textura (Água)
	// Se a soma dos pesos for baixa, assumimos que é água
	float total_weight = COLOR.r + COLOR.g + COLOR.b + COLOR.a;
	if (total_weight < 0.1) {
		final_albedo = vec3(0.0, 0.2, 0.5); // Azul simples pra água
		ROUGHNESS = 0.1;
		METALLIC = 0.1;
	} else {
		ROUGHNESS = 0.9; // Terra é fosca
	}

	ALBEDO = final_albedo;
}