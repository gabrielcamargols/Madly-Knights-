extends RefCounted
## Cenário 3D cartunesco do Pântano Maluco e o tablado onde a partida acontece.
## Tudo é montado em código, com sombreamento em degraus (toon) e contorno escuro
## para o acabamento de desenho animado. Os elementos de cenário são proposta de
## ambientação; não alteram regras.

const AGUA = preload("res://shaders/agua.gdshader")
const CONTORNO := Color(0.13, 0.08, 0.05)


static func mat(cor: Color, contorno: float = 0.022, cores_vertice: bool = false, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.85
	m.metallic = metal
	m.vertex_color_use_as_albedo = cores_vertice
	if contorno > 0.0:
		var c := StandardMaterial3D.new()
		c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.albedo_color = CONTORNO
		c.cull_mode = BaseMaterial3D.CULL_FRONT
		c.grow = true
		c.grow_amount = contorno
		m.next_pass = c
	return m


static func peca(pai: Node3D, malha: Mesh, material: Material, posicao: Vector3, rotacao: Vector3 = Vector3.ZERO, escala: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.mesh = malha
	no.material_override = material
	no.position = posicao
	no.rotation_degrees = rotacao
	no.scale = escala
	pai.add_child(no)
	return no


static func esfera(raio: float, lados: int = 12, aneis: int = 7) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2
	m.radial_segments = lados
	m.rings = aneis
	return m


static func cilindro(topo: float, base: float, altura: float, lados: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = topo
	m.bottom_radius = base
	m.height = altura
	m.radial_segments = lados
	m.rings = 1
	return m


static func caixa(tamanho: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = tamanho
	return m


static func capsula(raio: float, altura: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = raio
	m.height = altura
	m.radial_segments = 8
	m.rings = 3
	return m


# --- Terreno e água -------------------------------------------------------------

## Normal da face apontando para cima (as malhas do chão são vistas de cima).
static func normal_para_cima(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a).normalized()
	return -n if n.y < 0.0 else n

## Chão em facetas, com variação de cor entre grama, musgo e lama.
static func terreno(pai: Node3D) -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = 11
	ruido.frequency = 0.09
	var manchas := FastNoiseLite.new()
	manchas.seed = 5
	manchas.frequency = 0.05
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passo := 0.7
	var x0 := -20.0
	var z0 := -16.0
	var nx := 58
	var nz := 34
	var altura := func(x: float, z: float) -> float:
		return -0.16 + ruido.get_noise_2d(x, z) * 0.22
	var cor_em := func(x: float, z: float) -> Color:
		var m: float = manchas.get_noise_2d(x, z)
		var n: float = ruido.get_noise_2d(x * 2.0, z * 2.0)
		var grama := Color(0.45, 0.6, 0.29).lerp(Color(0.34, 0.5, 0.25), n * 0.5 + 0.5)
		if m > 0.25:
			return grama.lerp(Color(0.46, 0.38, 0.24), clampf((m - 0.25) * 3.0, 0.0, 1.0))
		return grama
	for iz in nz:
		for ix in nx:
			var xa := x0 + ix * passo
			var za := z0 + iz * passo
			var p := [Vector3(xa, 0, za), Vector3(xa + passo, 0, za), Vector3(xa + passo, 0, za + passo), Vector3(xa, 0, za + passo)]
			for k in 4:
				p[k].y = altura.call(p[k].x, p[k].z)
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var centro: Vector3 = (p[tri[0]] + p[tri[1]] + p[tri[2]]) / 3.0
				st.set_color(cor_em.call(centro.x, centro.z))
				st.set_normal(normal_para_cima(p[tri[0]], p[tri[1]], p[tri[2]]))
				for k in tri:
					st.add_vertex(p[k])
	var chao := mat(Color.WHITE, 0.0, true)
	chao.cull_mode = BaseMaterial3D.CULL_DISABLED
	peca(pai, st.commit(), chao, Vector3.ZERO)


## Poça de água com margem irregular de lama e espuma na borda.
static func poca(pai: Node3D, centro: Vector3, raio: float, semente: int, alongar: Vector2 = Vector2(1.3, 0.85)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var f := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var forma := func(a: float) -> float:
		return raio * (1.0 + 0.17 * sin(3.0 * a + f[0]) + 0.1 * sin(5.0 * a + f[1]) + 0.05 * sin(9.0 * a + f[2]))
	var lados := 48
	var ponto := func(a: float, fator: float, y: float) -> Vector3:
		var r: float = forma.call(a) * fator
		return centro + Vector3(cos(a) * r * alongar.x, y, sin(a) * r * alongar.y)
	# Margem de lama, um pouco elevada, descendo até o chão.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var q := [ponto.call(a0, 0.97, 0.02), ponto.call(a1, 0.97, 0.02), ponto.call(a1, 1.28, -0.14), ponto.call(a0, 1.28, -0.14)]
		var lama := Color(0.43, 0.33, 0.21).lerp(Color(0.52, 0.42, 0.27), rng.randf())
		for tri in [[0, 2, 1], [0, 3, 2]]:
			st.set_color(lama)
			st.set_normal(normal_para_cima(q[tri[0]], q[tri[1]], q[tri[2]]))
			for k in tri:
				st.add_vertex(q[k])
	var margem := mat(Color.WHITE, 0.0, true)
	margem.cull_mode = BaseMaterial3D.CULL_DISABLED
	peca(pai, st.commit(), margem, Vector3.ZERO)
	# Água em anéis: a profundidade vai em COLOR.r (0 na margem, 1 no meio).
	var aneis := [[1.0, 0.0], [0.78, 0.35], [0.5, 0.7], [0.22, 0.92], [0.0, 1.0]]
	var agua := SurfaceTool.new()
	agua.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		for k in aneis.size() - 1:
			var fora: Array = aneis[k]
			var dentro: Array = aneis[k + 1]
			var v := [ponto.call(a0, fora[0], 0.0), ponto.call(a1, fora[0], 0.0), ponto.call(a1, dentro[0], 0.0), ponto.call(a0, dentro[0], 0.0)]
			var prof := [fora[1], fora[1], dentro[1], dentro[1]]
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for idx in tri:
					agua.set_color(Color(prof[idx], 0, 0))
					agua.set_normal(Vector3.UP)
					agua.add_vertex(v[idx])
	var material := ShaderMaterial.new()
	material.shader = AGUA
	peca(pai, agua.commit(), material, Vector3.ZERO)


# --- Vegetação, pedras e madeira -----------------------------------------------

static func arvore(pai: Node3D, pos: Vector3, escala: float, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var raiz := Node3D.new()
	raiz.position = pos
	raiz.scale = Vector3.ONE * escala
	raiz.rotation_degrees.y = rng.randf_range(0, 360)
	pai.add_child(raiz)
	var casca := mat(Color(0.4, 0.27, 0.17), 0.03)
	peca(raiz, cilindro(0.17, 0.3, 1.9, 9), casca, Vector3(0, 0.9, 0), Vector3(0, 0, rng.randf_range(-6, 6)))
	for k in 4:
		var ang := k * 90.0 + rng.randf_range(-20, 20)
		peca(raiz, capsula(0.08, 0.8), casca, Vector3(cos(deg_to_rad(ang)) * 0.32, 0.12, sin(deg_to_rad(ang)) * 0.32), Vector3(0, -ang, 55))
	var verdes := [Color(0.27, 0.45, 0.22), Color(0.33, 0.52, 0.25), Color(0.4, 0.6, 0.29), Color(0.3, 0.48, 0.3)]
	var copas := [Vector3(0, 2.1, 0), Vector3(0.65, 1.85, 0.2), Vector3(-0.6, 1.9, -0.15), Vector3(0.1, 2.5, -0.3), Vector3(-0.2, 1.75, 0.55)]
	for p in copas:
		var r := rng.randf_range(0.65, 0.95)
		peca(raiz, esfera(r, 10, 6), mat(verdes[rng.randi_range(0, verdes.size() - 1)], 0.035), p, Vector3.ZERO, Vector3(1.0, 0.82, 1.0))
	# Barba-de-velho pendurada.
	for k in 4:
		peca(raiz, capsula(0.03, rng.randf_range(0.45, 0.8)), mat(Color(0.55, 0.65, 0.4), 0.0), Vector3(rng.randf_range(-0.7, 0.7), 1.35, rng.randf_range(-0.4, 0.6)))


static func arbusto(pai: Node3D, pos: Vector3, escala: float, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	for k in 4:
		var p := pos + Vector3(rng.randf_range(-0.35, 0.35), 0.22, rng.randf_range(-0.25, 0.25)) * escala
		peca(pai, esfera(rng.randf_range(0.28, 0.42) * escala, 9, 5), mat(Color(0.3, 0.5, 0.24).lightened(rng.randf_range(0, 0.15)), 0.025), p)
	for k in 3:
		peca(pai, esfera(0.05 * escala, 6, 4), mat(Color(0.85, 0.2, 0.2), 0.0), pos + Vector3(rng.randf_range(-0.35, 0.35), 0.45, rng.randf_range(0.0, 0.3)) * escala)


static func pedra(pai: Node3D, pos: Vector3, tamanho: float, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var cinza := Color(0.58, 0.57, 0.55).lerp(Color(0.48, 0.5, 0.52), rng.randf())
	peca(pai, esfera(tamanho, 7, 4), mat(cinza, 0.025), pos, Vector3(rng.randf_range(0, 20), rng.randf_range(0, 360), 0), Vector3(1.25, 0.7, 1.0))
	if rng.randf() < 0.6:
		peca(pai, esfera(tamanho * 0.75, 6, 3), mat(Color(0.38, 0.52, 0.27), 0.0), pos + Vector3(0, tamanho * 0.42, 0), Vector3.ZERO, Vector3(1.2, 0.35, 1.0))


static func tronco(pai: Node3D, pos: Vector3, comprimento: float, giro: float) -> void:
	var raiz := Node3D.new()
	raiz.position = pos
	raiz.rotation_degrees.y = giro
	pai.add_child(raiz)
	peca(raiz, cilindro(0.22, 0.24, comprimento, 10), mat(Color(0.43, 0.29, 0.18), 0.03), Vector3(0, 0.2, 0), Vector3(0, 0, 90))
	for lado in [-1, 1]:
		peca(raiz, cilindro(0.2, 0.2, 0.03, 10), mat(Color(0.86, 0.7, 0.46), 0.0), Vector3(lado * comprimento / 2, 0.2, 0), Vector3(0, 0, 90))
	peca(raiz, esfera(0.2, 8, 4), mat(Color(0.38, 0.55, 0.27), 0.0), Vector3(0.2, 0.4, 0), Vector3.ZERO, Vector3(2.2, 0.4, 1.0))
	peca(raiz, cilindro(0.06, 0.08, 0.35, 6), mat(Color(0.43, 0.29, 0.18), 0.02), Vector3(-0.3, 0.45, 0.1), Vector3(0, 0, -30))


static func juncos(pai: Node3D, pos: Vector3, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	for k in 6:
		var altura := rng.randf_range(0.6, 1.1)
		var p := pos + Vector3(rng.randf_range(-0.3, 0.3), altura / 2 - 0.05, rng.randf_range(-0.2, 0.2))
		var inclinacao := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		peca(pai, capsula(0.025, altura), mat(Color(0.45, 0.6, 0.26), 0.012), p, inclinacao)
		if k % 2 == 0:
			peca(pai, capsula(0.05, 0.22), mat(Color(0.45, 0.28, 0.16), 0.015), p + Vector3(inclinacao.z * -0.006, altura / 2, inclinacao.x * 0.006))


static func vitoria_regia(pai: Node3D, pos: Vector3, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	peca(pai, cilindro(0.3, 0.3, 0.02, 14), mat(Color(0.36, 0.6, 0.27), 0.012), pos, Vector3(0, rng.randf_range(0, 360), 0))
	if rng.randf() < 0.5:
		for k in 5:
			var a := TAU * k / 5
			peca(pai, esfera(0.06, 6, 4), mat(Color(0.98, 0.65, 0.78), 0.0), pos + Vector3(cos(a) * 0.06, 0.06, sin(a) * 0.06), Vector3.ZERO, Vector3(1, 0.6, 1.6))
		peca(pai, esfera(0.04, 6, 4), mat(Color(1, 0.88, 0.35), 0.0), pos + Vector3(0, 0.09, 0))


static func cogumelo(pai: Node3D, pos: Vector3, escala: float) -> void:
	peca(pai, cilindro(0.05, 0.07, 0.26, 8), mat(Color(0.95, 0.9, 0.78), 0.012), pos + Vector3(0, 0.13, 0) * escala, Vector3.ZERO, Vector3.ONE * escala)
	peca(pai, esfera(0.17, 10, 5), mat(Color(0.86, 0.22, 0.18), 0.018), pos + Vector3(0, 0.27, 0) * escala, Vector3.ZERO, Vector3(1, 0.6, 1) * escala)
	for p in [Vector3(0.07, 0.36, 0.06), Vector3(-0.08, 0.34, 0.03), Vector3(0.0, 0.38, -0.07)]:
		peca(pai, esfera(0.025, 6, 3), mat(Color.WHITE, 0.0), pos + p * escala)


## Torre de pedra com ameias, telhado cônico, janelas acesas e bandeira.
static func torre(pai: Node3D, pos: Vector3, cor_telhado: Color, escala: float) -> void:
	var raiz := Node3D.new()
	raiz.position = pos
	raiz.scale = Vector3.ONE * escala
	pai.add_child(raiz)
	var pedra_m := mat(Color(0.8, 0.76, 0.68), 0.04)
	peca(raiz, cilindro(0.8, 0.95, 2.8, 12), pedra_m, Vector3(0, 1.4, 0))
	for k in 8:
		var a := TAU * k / 8
		peca(raiz, caixa(Vector3(0.32, 0.3, 0.3)), pedra_m, Vector3(cos(a) * 0.82, 2.95, sin(a) * 0.82), Vector3(0, -rad_to_deg(a), 0))
	peca(raiz, cilindro(0.0, 1.08, 1.5, 12), mat(cor_telhado, 0.04), Vector3(0, 3.85, 0))
	for y in [1.1, 2.1]:
		peca(raiz, caixa(Vector3(0.24, 0.38, 0.1)), mat(Color(1.0, 0.82, 0.42), 0.0), Vector3(0, y, 0.86))
	peca(raiz, cilindro(0.025, 0.025, 0.8, 6), mat(Color(0.35, 0.25, 0.15), 0.0), Vector3(0, 4.9, 0))
	peca(raiz, caixa(Vector3(0.5, 0.3, 0.02)), mat(cor_telhado.lightened(0.2), 0.012), Vector3(0.26, 5.12, 0))


## Placa de madeira cravada no chão com o nome do reino.
static func placa(pai: Node3D, pos: Vector3, texto: String) -> void:
	var madeira := mat(Color(0.52, 0.35, 0.2), 0.03)
	peca(pai, cilindro(0.06, 0.07, 1.2, 8), madeira, pos + Vector3(0, 0.6, 0))
	peca(pai, caixa(Vector3(1.6, 0.42, 0.08)), madeira, pos + Vector3(0, 1.05, 0.04), Vector3(0, 0, -3))
	var r := Label3D.new()
	r.text = texto
	r.font = load("res://fontes/Lora-Variable.ttf")
	r.font_size = 64
	r.pixel_size = 0.0035
	r.modulate = Color(1.0, 0.92, 0.7)
	r.outline_size = 10
	r.outline_modulate = Color(0.2, 0.12, 0.06)
	r.position = pos + Vector3(0, 1.05, 0.1)
	r.rotation_degrees.z = -3
	pai.add_child(r)


## Píer de tábuas avançando sobre a água.
static func pier(pai: Node3D, pos: Vector3, giro: float) -> void:
	var raiz := Node3D.new()
	raiz.position = pos
	raiz.rotation_degrees.y = giro
	pai.add_child(raiz)
	for k in 6:
		peca(raiz, caixa(Vector3(1.1, 0.07, 0.24)), mat(Color(0.62, 0.45, 0.27).darkened((k % 2) * 0.08), 0.015), Vector3(0, 0.06, k * 0.27))
	for x in [-0.5, 0.5]:
		for z in [0.0, 1.35]:
			peca(raiz, cilindro(0.06, 0.07, 0.6, 7), mat(Color(0.42, 0.28, 0.17), 0.02), Vector3(x, 0.0, z))


## Pântano completo em volta do tablado.
static func pantano(pai: Node3D) -> Array:
	terreno(pai)
	poca(pai, Vector3(-8.6, -0.05, -3.0), 2.3, 1, Vector2(1.4, 0.9))
	poca(pai, Vector3(8.8, -0.05, -2.2), 2.1, 2, Vector2(1.3, 1.0))
	poca(pai, Vector3(-2.5, -0.05, -7.4), 2.6, 3, Vector2(1.6, 0.7))
	poca(pai, Vector3(5.2, -0.05, -8.0), 2.0, 4)
	for p in [[Vector3(-8.0, -0.03, -3.4), 7], [Vector3(-9.3, -0.03, -2.4), 8], [Vector3(9.3, -0.03, -2.6), 9], [Vector3(-1.9, -0.03, -7.2), 10], [Vector3(-3.4, -0.03, -7.6), 11], [Vector3(5.6, -0.03, -7.7), 12]]:
		vitoria_regia(pai, p[0], p[1])
	var arvores := [[Vector3(-11, 0, -5.5), 1.15], [Vector3(-7.4, 0, -8.6), 1.0], [Vector3(11.2, 0, -5.2), 1.2], [Vector3(8.2, 0, -10.0), 1.05], [Vector3(-0.5, 0, -11.0), 1.1], [Vector3(2.8, 0, -10.5), 0.9], [Vector3(-11.5, 0, 0.8), 1.05], [Vector3(11.6, 0, 1.4), 1.1], [Vector3(-12.5, 0, -9.0), 1.3], [Vector3(12.8, 0, -9.5), 1.25]]
	var semente := 20
	for a in arvores:
		arvore(pai, a[0], a[1], semente)
		semente += 1
	for p in [Vector3(-6.4, 0, -4.9), Vector3(6.4, 0, -5.0), Vector3(-6.6, 0, 1.6), Vector3(6.8, 0, 2.0), Vector3(-4.2, 0, -5.8), Vector3(3.6, 0, -6.2)]:
		arbusto(pai, p, 1.0, semente)
		semente += 1
	for p in [[Vector3(-6.2, 0, -2.2), 0.45], [Vector3(6.3, 0, -1.6), 0.5], [Vector3(-6.0, 0, 0.9), 0.35], [Vector3(6.1, 0, 0.6), 0.4], [Vector3(-5.2, 0, -5.2), 0.55], [Vector3(4.8, 0, -5.6), 0.4], [Vector3(-10.4, 0, -1.2), 0.5], [Vector3(10.6, 0, -0.4), 0.45]]:
		pedra(pai, p[0], p[1], semente)
		semente += 1
	tronco(pai, Vector3(-6.7, 0, -0.6), 2.0, 70)
	tronco(pai, Vector3(7.0, 0, -4.0), 1.7, -40)
	for p in [Vector3(-7.0, 0, -2.0), Vector3(-10.4, 0, -4.4), Vector3(7.6, 0, -1.0), Vector3(10.3, 0, -3.3), Vector3(-4.0, 0, -6.6), Vector3(-0.9, 0, -6.9), Vector3(4.1, 0, -7.1), Vector3(6.3, 0, -8.4)]:
		juncos(pai, p, semente)
		semente += 1
	for p in [[Vector3(-6.4, 0, 2.5), 1.0], [Vector3(-6.0, 0, 2.8), 0.7], [Vector3(6.7, 0, -3.1), 0.9], [Vector3(-5.6, 0, -4.4), 0.8]]:
		cogumelo(pai, p[0], p[1])
	torre(pai, Vector3(-10.0, 0, -11.5), Color(0.82, 0.36, 0.24), 1.15)
	torre(pai, Vector3(10.5, 0, -12.0), Color(0.3, 0.42, 0.72), 1.0)
	pier(pai, Vector3(7.6, 0, -2.6), -70)
	placa(pai, Vector3(-6.4, 0, 3.0), "Pântano Maluco")
	# Vaga-lumes que flutuam devagar (animados pela mesa).
	var vaga_lumes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var luz := StandardMaterial3D.new()
	luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luz.albedo_color = Color(1.0, 0.95, 0.5)
	for k in 14:
		var v := peca(pai, esfera(0.045, 6, 3), luz, Vector3(rng.randf_range(-11, 11), rng.randf_range(0.6, 2.2), rng.randf_range(-10, 1)))
		v.set_meta("base", v.position)
		v.set_meta("fase", rng.randf() * TAU)
		vaga_lumes.append(v)
	return vaga_lumes


# --- Tablado -----------------------------------------------------------------------

## Tablado de madeira sobre base de pedra, com a arena do inimigo e as vagas da fila.
## Devolve as vagas para a mesa atualizar seus estados.
static func tablado(pai: Node3D, posicoes_vagas: Array, pos_arena: Vector3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var largura := 10.6
	var z_ini := -3.55
	var z_fim := 1.75
	# Tábuas
	var z := z_ini
	var k := 0
	var tons := [Color(0.66, 0.48, 0.29), Color(0.6, 0.43, 0.26), Color(0.7, 0.52, 0.31)]
	while z < z_fim:
		peca(pai, caixa(Vector3(largura, 0.14, 0.48)), mat(tons[k % 3], 0.0), Vector3(0, -0.02, z + 0.24))
		for x in [-largura / 2 + 0.25, largura / 2 - 0.25]:
			peca(pai, esfera(0.035, 6, 3), mat(Color(0.3, 0.3, 0.32), 0.0, false, 0.6), Vector3(x, 0.06, z + 0.24))
		z += 0.52
		k += 1
	# Base de pedra em volta (blocos de alturas variadas).
	var pedra_m := [mat(Color(0.5, 0.49, 0.46), 0.025), mat(Color(0.44, 0.44, 0.43), 0.025), mat(Color(0.56, 0.53, 0.48), 0.025)]
	var borda := []
	var x := -largura / 2 - 0.3
	while x <= largura / 2 + 0.3:
		borda.append(Vector3(x, 0, z_ini - 0.3))
		borda.append(Vector3(x, 0, z_fim + 0.25))
		x += 0.62
	z = z_ini
	while z <= z_fim:
		borda.append(Vector3(-largura / 2 - 0.3, 0, z))
		borda.append(Vector3(largura / 2 + 0.3, 0, z))
		z += 0.62
	for p in borda:
		var alto := rng.randf_range(0.2, 0.3)
		peca(pai, caixa(Vector3(0.56, alto, 0.5)), pedra_m[rng.randi_range(0, 2)], p + Vector3(0, alto / 2 - 0.1, 0), Vector3(0, rng.randf_range(-6, 6), 0))
	# Arena do inimigo: círculo pintado em vermelho com aro de latão.
	peca(pai, cilindro(1.42, 1.42, 0.03, 32), mat(Color(0.86, 0.66, 0.28), 0.0), pos_arena + Vector3(0, 0.055, 0))
	peca(pai, cilindro(1.3, 1.3, 0.035, 32), mat(Color(0.4, 0.17, 0.13), 0.0), pos_arena + Vector3(0, 0.06, 0))
	peca(pai, cilindro(1.0, 1.0, 0.036, 32), mat(Color(0.47, 0.21, 0.15), 0.0), pos_arena + Vector3(0, 0.061, 0))
	for kk in 8:
		var a := TAU * kk / 8
		peca(pai, esfera(0.06, 6, 3), mat(Color(0.86, 0.66, 0.28), 0.0, false, 0.5), pos_arena + Vector3(cos(a) * 1.36, 0.08, sin(a) * 1.36))
	# Faixa de latão separando a arena da fila.
	peca(pai, caixa(Vector3(largura - 0.6, 0.02, 0.07)), mat(Color(0.86, 0.66, 0.28), 0.0, false, 0.4), Vector3(0, 0.06, -0.55))
	# Vagas: escudos redondos de madeira com aro de ferro e número pintado.
	var vagas: Array = []
	for i in posicoes_vagas.size():
		var p: Vector3 = posicoes_vagas[i]
		var aro_m := mat(Color(0.42, 0.42, 0.45), 0.0, false, 0.5)
		aro_m.emission_enabled = true
		aro_m.emission = Color.BLACK
		peca(pai, cilindro(0.56, 0.56, 0.05, 28), aro_m, p + Vector3(0, 0.055, 0))
		peca(pai, cilindro(0.49, 0.49, 0.06, 28), mat(Color(0.5, 0.33, 0.19), 0.0), p + Vector3(0, 0.065, 0))
		peca(pai, cilindro(0.36, 0.36, 0.062, 28), mat(Color(0.56, 0.38, 0.22), 0.0), p + Vector3(0, 0.066, 0))
		var numero := Label3D.new()
		numero.text = str(i + 1)
		numero.font = Tema.fonte_titulo()
		numero.font_size = 120
		numero.pixel_size = 0.004
		numero.rotation_degrees.x = -90
		numero.modulate = Color(0.95, 0.85, 0.6)
		numero.outline_size = 14
		numero.outline_modulate = Color(0.25, 0.15, 0.08)
		numero.position = p + Vector3(0, 0.1, 0)
		pai.add_child(numero)
		# Ordem de ataque pintada na frente da vaga (fica visível mesmo ocupada).
		var ordem := Label3D.new()
		ordem.text = "%dº — ATACA" % (i + 1) if i == 0 else "%dº" % (i + 1)
		ordem.font = Tema.fonte_titulo()
		ordem.font_size = 54
		ordem.pixel_size = 0.0045
		ordem.rotation_degrees.x = -90
		ordem.modulate = Color(1.0, 0.85, 0.45) if i == 0 else Color(0.97, 0.9, 0.75)
		ordem.outline_size = 12
		ordem.outline_modulate = Color(0.2, 0.12, 0.06)
		ordem.position = p + Vector3(0, 0.08, 0.72)
		pai.add_child(ordem)
		vagas.append({"aro": aro_m, "numero": numero})
	# Setas pintadas da 1ª vaga até a arena: a ordem de ataque segue para o inimigo.
	var inicio: Vector3 = posicoes_vagas[0] + Vector3(0.35, 0.07, -0.55)
	for kk in 4:
		var t := (kk + 1) / 5.0
		var ponto := inicio.lerp(pos_arena + Vector3(-1.1, 0.07, 0.45), t)
		var direcao := (pos_arena - inicio)
		var giro := rad_to_deg(atan2(direcao.x, -direcao.z))
		peca(pai, cilindro(0.16, 0.16, 0.02, 3), mat(Color(0.95, 0.75, 0.3), 0.0), ponto, Vector3(0, -giro, 0), Vector3(0.8, 1, 1.3))
	return vagas


const Tema = preload("res://scripts/apresentacao/tema.gd")
