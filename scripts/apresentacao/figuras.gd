extends RefCounted
## Modelos 3D cartunescos TEMPORÁRIOS, montados com formas simples.
## Proposta visual (não é regra): proporções "chibi" com cabeça grande, base redonda
## e cores e elmo tirados da ilustração aprovada de cada Cavaleiro
## (dados/paletas_cavaleiros.json). Serão trocados por modelos definitivos.


static func _material(cor: Color, metal: float = 0.0, aspereza: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = aspereza
	return m


static func _peca(pai: Node3D, malha: Mesh, cor: Color, posicao: Vector3, rotacao: Vector3 = Vector3.ZERO, metal: float = 0.0) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.mesh = malha
	no.material_override = _material(cor, metal)
	no.position = posicao
	no.rotation_degrees = rotacao
	pai.add_child(no)
	return no


static func _esfera(raio: float, altura: float = -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = altura if altura > 0 else raio * 2
	return m


static func _capsula(raio: float, altura: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = raio
	m.height = altura
	return m


static func _cilindro(topo: float, base: float, altura: float, lados: int = 24) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = topo
	m.bottom_radius = base
	m.height = altura
	m.radial_segments = lados
	return m


static func _caixa(tamanho: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = tamanho
	return m


static func cor(paleta: Dictionary, campo: String, padrao: Color) -> Color:
	return Color.html(paleta[campo]) if paleta.has(campo) else padrao


## Cavaleiro: base, corpo (animável, nó "Corpo"), elmo temático, escudo e espada.
static func cavaleiro(paleta: Dictionary, cor_base: Color) -> Node3D:
	var armadura := cor(paleta, "armadura", cor_base)
	var detalhe := cor(paleta, "detalhe", cor_base.darkened(0.3))
	var elmo := cor(paleta, "elmo", armadura.lightened(0.1))
	var largo: bool = paleta.get("porte", "") == "largo"
	var raiz := Node3D.new()
	_peca(raiz, _cilindro(0.44, 0.48, 0.08), Color(0.32, 0.26, 0.2), Vector3(0, 0.04, 0))
	_peca(raiz, _cilindro(0.4, 0.4, 0.085), cor_base, Vector3(0, 0.045, 0))
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	raiz.add_child(corpo)
	var l := 1.3 if largo else 1.0
	# Pernas e tronco
	for x in [-0.1, 0.1]:
		_peca(corpo, _capsula(0.085, 0.32), armadura.darkened(0.35), Vector3(x * l, 0.25, 0))
	_peca(corpo, _capsula(0.2 * l, 0.5), armadura, Vector3(0, 0.56, 0), Vector3.ZERO, 0.35)
	_peca(corpo, _cilindro(0.205 * l, 0.205 * l, 0.06), detalhe, Vector3(0, 0.46, 0))
	# Braços
	for lado in [-1, 1]:
		_peca(corpo, _capsula(0.07 * l, 0.3), armadura.darkened(0.15), Vector3(0.25 * l * lado, 0.6, 0.02), Vector3(0, 0, 20 * lado))
	# Cabeça grande com elmo temático
	var cabeca := Node3D.new()
	cabeca.position = Vector3(0, 1.0, 0)
	corpo.add_child(cabeca)
	_elmo(cabeca, paleta.get("elmo_forma", "redondo"), elmo, detalhe)
	# Escudo e espada (ou luvas de boxe)
	if paleta.get("extra", "") == "luvas":
		for lado in [-1, 1]:
			_peca(corpo, _esfera(0.13), detalhe if lado < 0 else elmo, Vector3(0.3 * lado, 0.48, 0.12))
	else:
		_peca(corpo, _cilindro(0.17, 0.17, 0.045), detalhe, Vector3(-0.3 * l, 0.58, 0.08), Vector3(90, 0, 12), 0.2)
		_peca(corpo, _caixa(Vector3(0.05, 0.52, 0.025)), Color(0.86, 0.88, 0.92), Vector3(0.3 * l, 0.74, 0.1), Vector3(0, 0, -12), 0.85)
		_peca(corpo, _caixa(Vector3(0.18, 0.04, 0.04)), detalhe.darkened(0.2), Vector3(0.28 * l, 0.5, 0.1), Vector3(0, 0, -12))
	if paleta.get("extra", "") == "capa":
		_peca(corpo, _caixa(Vector3(0.42 * l, 0.6, 0.03)), detalhe.darkened(0.35), Vector3(0, 0.55, -0.2), Vector3(-8, 0, 0))
	if paleta.get("extra", "") == "pluma":
		_peca(cabeca, _capsula(0.05, 0.3), detalhe, Vector3(0, 0.3, -0.05), Vector3(-30, 0, 0))
	return raiz


static func _elmo(cabeca: Node3D, forma: String, elmo: Color, detalhe: Color) -> void:
	var escuro := Color(0.05, 0.05, 0.07)
	match forma:
		"fatia":  # fatia de pizza: prisma triangular com bolinhas de pepperoni
			_peca(cabeca, _cilindro(0.3, 0.3, 0.42, 3), elmo, Vector3(0, 0.02, 0), Vector3(0, 30, 0))
			_peca(cabeca, _caixa(Vector3(0.3, 0.05, 0.04)), escuro, Vector3(0, -0.02, 0.17))
			for p in [Vector3(-0.1, 0.12, 0.13), Vector3(0.09, 0.15, 0.1), Vector3(0, -0.14, 0.12)]:
				_peca(cabeca, _esfera(0.045), detalhe, p)
		"banana":  # elmo comprido e curvo de banana, com os olhos na fenda
			_peca(cabeca, _capsula(0.16, 0.7), elmo, Vector3(0, 0.12, 0), Vector3(0, 0, -18))
			_peca(cabeca, _cilindro(0.03, 0.05, 0.12), Color(0.35, 0.25, 0.1), Vector3(0.14, 0.48, 0), Vector3(0, 0, -30))
			_peca(cabeca, _caixa(Vector3(0.22, 0.07, 0.04)), escuro, Vector3(-0.02, -0.02, 0.15))
		"torrada":  # fatia de pão de forma
			_peca(cabeca, _caixa(Vector3(0.44, 0.42, 0.3)), elmo, Vector3.ZERO)
			_peca(cabeca, _esfera(0.24, 0.3), elmo.lightened(0.15), Vector3(0, 0.2, 0))
			_peca(cabeca, _caixa(Vector3(0.36, 0.3, 0.02)), Color(0.92, 0.9, 0.85), Vector3(0, -0.02, 0.155))
			_peca(cabeca, _caixa(Vector3(0.28, 0.05, 0.03)), escuro, Vector3(0, 0.02, 0.17))
		"rosquinha":  # anel de rosquinha com cobertura em volta do elmo
			_peca(cabeca, _esfera(0.23), elmo, Vector3.ZERO, Vector3.ZERO, 0.2)
			var anel := TorusMesh.new()
			anel.inner_radius = 0.18
			anel.outer_radius = 0.32
			_peca(cabeca, anel, detalhe, Vector3(0, 0.05, 0), Vector3(90, 0, 0))
			_peca(cabeca, _caixa(Vector3(0.26, 0.05, 0.04)), escuro, Vector3(0, -0.02, 0.21))
		"chifres":
			_peca(cabeca, _esfera(0.24), elmo, Vector3.ZERO, Vector3.ZERO, 0.3)
			for lado in [-1, 1]:
				_peca(cabeca, _cilindro(0.0, 0.06, 0.24), detalhe, Vector3(0.15 * lado, 0.22, 0), Vector3(0, 0, -25 * lado))
			_peca(cabeca, _caixa(Vector3(0.3, 0.05, 0.05)), escuro, Vector3(0, -0.01, 0.21))
		"orelhas":
			_peca(cabeca, _esfera(0.24), elmo, Vector3.ZERO, Vector3.ZERO, 0.2)
			for lado in [-1, 1]:
				_peca(cabeca, _esfera(0.08), detalhe, Vector3(0.16 * lado, 0.2, 0))
				_peca(cabeca, _caixa(Vector3(0.04, 0.18, 0.02)), detalhe, Vector3(0.11 * lado, 0.04, 0.2))
			_peca(cabeca, _caixa(Vector3(0.3, 0.05, 0.05)), escuro, Vector3(0, -0.01, 0.21))
		"aranha":
			_peca(cabeca, _esfera(0.24), elmo, Vector3.ZERO)
			for lado in [-1, 1]:
				_peca(cabeca, _esfera(0.075, 0.05), Color(0.95, 0.95, 0.9), Vector3(0.09 * lado, 0.0, 0.2), Vector3(70, 0, 25 * lado))
		_:
			_peca(cabeca, _esfera(0.24), elmo, Vector3.ZERO, Vector3.ZERO, 0.35)
			_peca(cabeca, _caixa(Vector3(0.3, 0.05, 0.06)), escuro, Vector3(0, -0.01, 0.21))
			_peca(cabeca, _capsula(0.045, 0.22), detalhe, Vector3(0, 0.26, -0.05), Vector3(-25, 0, 0))


## Inimigo: criatura cartunesca com olhos grandes. Chefes são maiores e têm coroa.
static func inimigo(id: String, chefe: bool) -> Node3D:
	var cores := {
		"barao_do_pantano": Color(0.32, 0.5, 0.25), "lobo_mal": Color(0.45, 0.45, 0.5),
		"porquinhos_viloes": Color(0.95, 0.6, 0.65), "ratos_mafiosos": Color(0.5, 0.45, 0.42),
		"xerife_do_mal": Color(0.55, 0.35, 0.2), "mercenario_do_deserto": Color(0.8, 0.65, 0.4),
		"guerreiro_beduino": Color(0.75, 0.55, 0.35),
	}
	var corpo_cor: Color = cores.get(id, Color(0.6, 0.25, 0.25))
	var raiz := Node3D.new()
	_peca(raiz, _cilindro(0.5, 0.55, 0.08), Color(0.25, 0.1, 0.08), Vector3(0, 0.04, 0))
	_peca(raiz, _cilindro(0.46, 0.46, 0.085), Color(0.8, 0.2, 0.15), Vector3(0, 0.045, 0))
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	raiz.add_child(corpo)
	_peca(corpo, _esfera(0.42, 0.7), corpo_cor, Vector3(0, 0.45, 0))
	_peca(corpo, _esfera(0.3), corpo_cor.lightened(0.08), Vector3(0, 0.95, 0.04))
	for lado in [-1, 1]:
		_peca(corpo, _esfera(0.085), Color.WHITE, Vector3(0.11 * lado, 1.0, 0.27))
		_peca(corpo, _esfera(0.04), Color.BLACK, Vector3(0.11 * lado, 0.99, 0.35))
		_peca(corpo, _caixa(Vector3(0.14, 0.03, 0.03)), Color.BLACK, Vector3(0.11 * lado, 1.1, 0.3), Vector3(0, 0, 18 * lado))
		_peca(corpo, _capsula(0.08, 0.36), corpo_cor.darkened(0.15), Vector3(0.42 * lado, 0.5, 0.05), Vector3(0, 0, 35 * lado))
	if chefe:
		_peca(corpo, _cilindro(0.17, 0.2, 0.14, 8), Color(0.98, 0.8, 0.3), Vector3(0, 1.26, 0), Vector3.ZERO, 0.8)
	return raiz


## Cenário acolhedor de pântano em volta do tabuleiro (proposta de ambientação).
static func pantano(pai: Node3D) -> void:
	var agua := Color(0.24, 0.45, 0.42)
	_peca(pai, _caixa(Vector3(40, 0.1, 30)), Color(0.36, 0.48, 0.28), Vector3(0, -0.2, -6))
	for p in [Vector3(-7.5, -0.14, -3), Vector3(8, -0.14, -2.5), Vector3(-3, -0.14, -6.5), Vector3(5, -0.14, -7)]:
		var poca := _peca(pai, _cilindro(2.4, 2.4, 0.04, 32), agua, p, Vector3.ZERO, 0.3)
		poca.scale = Vector3(1.4, 1, 0.8)
	for p in [Vector3(-7, -0.1, -2.6), Vector3(-6.4, -0.1, -3.4), Vector3(8.4, -0.1, -2.2), Vector3(4.6, -0.1, -6.6)]:
		_peca(pai, _cilindro(0.35, 0.35, 0.02, 16), Color(0.3, 0.6, 0.25), p)
	var arvores := [Vector3(-9, 0, -5), Vector3(-6, 0, -8), Vector3(9.5, 0, -5.5), Vector3(7, 0, -9), Vector3(-1, 0, -10), Vector3(2.5, 0, -9.5), Vector3(-9.5, 0, 1.5), Vector3(10, 0, 1)]
	for p in arvores:
		_peca(pai, _cilindro(0.15, 0.25, 1.6), Color(0.38, 0.27, 0.18), p + Vector3(0, 0.6, 0))
		_peca(pai, _esfera(1.0, 1.4), Color(0.25, 0.42, 0.22), p + Vector3(0, 1.8, 0))
		_peca(pai, _esfera(0.7, 1.0), Color(0.3, 0.5, 0.26), p + Vector3(0.5, 2.3, 0.2))
	for p in [Vector3(-7.8, 0, -1.2), Vector3(-7.2, 0, -0.9), Vector3(7.6, 0, -1.4), Vector3(8.2, 0, -1.0), Vector3(-4.5, 0, -5.4)]:
		for k in 3:
			_peca(pai, _capsula(0.025, 0.7), Color(0.45, 0.55, 0.25), p + Vector3(k * 0.12, 0.25, 0), Vector3(0, 0, -8 + k * 8))
	for t in [[Vector3(-8.5, 0, -7.5), Color(0.85, 0.4, 0.25)], [Vector3(9, 0, -8.5), Color(0.35, 0.45, 0.75)]]:
		var p: Vector3 = t[0]
		_peca(pai, _cilindro(0.75, 0.85, 2.6, 12), Color(0.78, 0.74, 0.66), p + Vector3(0, 1.2, 0))
		_peca(pai, _cilindro(0.0, 1.05, 1.3, 12), t[1], p + Vector3(0, 3.15, 0))
		_peca(pai, _caixa(Vector3(0.3, 0.45, 0.1)), Color(0.98, 0.82, 0.45), p + Vector3(0, 1.6, 0.8))
