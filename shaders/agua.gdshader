// Água cartunesca do pântano: rasa na margem, funda no meio, espuma na borda
// e reflexos animados. A malha leva em COLOR.r a "profundidade" (0 na margem, 1 no centro).
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform vec4 cor_rasa : source_color = vec4(0.42, 0.66, 0.55, 1.0);
uniform vec4 cor_funda : source_color = vec4(0.10, 0.27, 0.30, 1.0);
uniform vec4 cor_espuma : source_color = vec4(0.88, 0.95, 0.85, 1.0);
uniform vec4 cor_brilho : source_color = vec4(0.75, 0.92, 0.88, 1.0);

varying vec3 mundo;
varying float profundidade;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	profundidade = COLOR.r;
	VERTEX.y += sin(TIME * 1.4 + mundo.x * 1.7 + mundo.z * 1.3) * 0.012 * profundidade;
}

void fragment() {
	float d = smoothstep(0.0, 0.85, profundidade);
	vec3 cor = mix(cor_rasa.rgb, cor_funda.rgb, d);
	// Faixas de luz que se movem devagar, como reflexos pintados.
	float onda = sin(mundo.x * 3.1 + TIME * 1.1 + sin(mundo.z * 2.3 + TIME * 0.7) * 1.6);
	float brilho = smoothstep(0.86, 0.97, onda) * (0.35 + 0.65 * d);
	cor = mix(cor, cor_brilho.rgb, brilho * 0.55);
	// Espuma ondulante junto à margem.
	float limite = 0.13 + 0.035 * sin(mundo.x * 7.0 + mundo.z * 5.0 + TIME * 2.0);
	float espuma = 1.0 - smoothstep(limite - 0.03, limite, profundidade);
	cor = mix(cor, cor_espuma.rgb, espuma * 0.9);
	ALBEDO = cor;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
