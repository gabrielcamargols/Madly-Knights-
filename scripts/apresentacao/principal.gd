extends Node3D
## Mesa jogável do playtest no Pântano Maluco, no estilo dos jogos de cartas digitais.
## Só lê o estado da partida e mostra os resultados que a lógica devolveu;
## não decide regras nem rola dados. A arte das cartas é provisória.
##
## Direção visual (docs/DIRECAO_VISUAL.md): personagens e cenário em 3D cartunesco,
## cartas 2D ilustradas na interface. No tabuleiro, cada Cavaleiro é uma figura 3D
## temporária com uma plaquinha (nome, Armadura, Força); o inimigo também. Baralho do
## reino e Cemitério ficam à esquerda como cartas.
## Mão (2D) embaixo; arraste uma carta para a mesa para jogá-la.
## Escolhas aparecem no centro da tela com as cartas grandes. Ações ficam à direita.

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")
const DecisorInterface = preload("res://scripts/apresentacao/decisor_interface.gd")
const Sessao = preload("res://scripts/apresentacao/sessao.gd")
const Regras = preload("res://scripts/core/regras.gd")
const Figuras = preload("res://scripts/apresentacao/figuras.gd")
const Sons = preload("res://scripts/apresentacao/sons.gd")
const Visual = preload("res://scripts/apresentacao/visual.gd")
const Tema = preload("res://scripts/apresentacao/tema.gd")
const FASES := ["Preparação", "Exploração", "Resolução", "Reposição", "Avanço"]

# Mesa (unidades do mundo)
const TAM_CARTA_3D := Vector2(1.0, 1.86)  # mesma proporção das cartas 2D
const ESPACO_VAGA := 1.3
const VAGAS := 6
const POS_FILA_Z := 0.35
const POS_ENCONTRO := Vector3(0.0, 0.0, -1.55)
const ESCALA_ENCONTRO := 1.15
const POS_REINO := Vector3(-4.75, 0.0, -2.35)
const POS_CEMITERIO := Vector3(-4.75, 0.0, -0.05)
const POS_ENTRADA := Vector3(0.0, 0.0, 3.6)
const PIXELS_CARTA := Vector2i(280, 521)  # textura de cada carta da mesa

# Cartas 2D (pixels da tela-base de 1280×720)
const TAM_MAO := Vector2(118, 0)  # altura vem da proporção da carta
const TAM_ESCOLHA := Vector2(166, 0)
const PROPORCAO_ARTE := 0.8  # 4:5, igual às ilustrações aprovadas
const ALTURA_POR_LARGURA := 1.86

const COR_OURO := Color(0.98, 0.8, 0.3)
const COR_FORCA := Color(0.78, 0.16, 0.12)
const COR_ARMADURA := Color(0.16, 0.36, 0.78)

var cat
var partida
var jogador  # jogador mostrado na mesa
var indice_preparo := 0
var indice_turno := 0

# Modo: "iniciais", "reerguer", "preparacao", "ataque" ou "" (aguardando a lógica).
var modo := ""
var pendentes: Array = []  # Cavaleiros arrastados para a mesa na colocação inicial
var decisor_atual = null
var opcoes_ataque: Array = []
var atacante_escolhido = null
var selecionados: Array = []
var armaduras_vistas: Dictionary = {}
var carta_revelada := ""
var paletas: Dictionary = {}
var figura_inimigo: Node3D = null
var tempo := 0.0

var camera: Camera3D
var cartas_3d: Dictionary = {}  # "jogador/id_instancia" -> Node3D
var objetos_3d: Dictionary = {}
var carta_encontro: Node3D
var pilha_reino: Node3D
var pilha_cemiterio: Node3D

var rotulo_status: Label
var rotulo_dica: Label
var mao_2d: HBoxContainer
var acoes: VBoxContainer
var painel_registro: PanelContainer
var registro: RichTextLabel
var zona_mesa: Control
var camada_escolha: Control
var escolha: PanelContainer
var titulo_escolha: Label
var cartas_escolha: HFlowContainer
var botoes_escolha: HFlowContainer
var camada_detalhes: Control
var texto_detalhes: RichTextLabel
var carta_detalhes: CenterContainer
var rotulo_dado: Label
# Janela do dado
var camada_dado: Control
var titulo_dado: Label
var area_dado: Control
var dado_visual: Control
var resultado_dado: Label
var botao_jogar: Button
var dado_aguardando := false
var girando := false
var face_pendente := 0
var arrastando_dado := false
# Narração dos momentos
var sons
var momento_ativo := false
var pulando := false
var vitrine: Control
var titulo_vitrine: Label
var lugar_vitrine: CenterContainer
var faixa: Label
var legenda: Label
var rotulos_fase: Array = []
# Mesa e interface
var vagas_3d: Array = []
var vaga_lumes: Array = []
var arrastando := false
var carta_arrastada: Control = null
var chips: Dictionary = {}
var painel_dica: PanelContainer


func _ready() -> void:
	sons = Sons.new()
	add_child(sons)
	_criar_ambiente()
	_criar_interface()
	get_viewport().size_changed.connect(_ajustar_camera)
	_ajustar_camera()
	cat = Catalogo.new()
	if not cat.carregar():
		rotulo_dica.text = "Erro ao carregar os dados do jogo."
		return
	var dados_paletas = Catalogo.ler_json("res://dados/paletas_cavaleiros.json")
	if dados_paletas != null:
		paletas = dados_paletas["paletas"]
	carta_encontro = _criar_carta_3d()
	carta_encontro.position = POS_ENCONTRO
	carta_encontro.scale = Vector3(ESCALA_ENCONTRO, 1.0, ESCALA_ENCONTRO)
	pilha_reino = _criar_carta_3d()
	pilha_reino.position = POS_REINO
	pilha_cemiterio = _criar_carta_3d()
	pilha_cemiterio.position = POS_CEMITERIO
	nova_partida()


func nova_partida() -> void:
	for no in cartas_3d.values():
		no.queue_free()
	cartas_3d.clear()
	objetos_3d.clear()
	armaduras_vistas.clear()
	registro.clear()
	carta_revelada = ""
	_fechar_escolha()
	partida = Partida.new(cat, Dado.new(), Embaralhador.new())
	partida.registrou.connect(_ao_registrar)
	partida.revelou.connect(_ao_revelar)
	partida.com_pausas = true
	partida.passo_de_combate.connect(_ritmo_do_combate)
	partida.dado.rolou.connect(_ao_rolar)
	partida.dado_mostrado.connect(_ao_dado_mostrado)
	partida.momento.connect(_ao_momento)
	partida.fase.connect(_ao_mudar_fase)
	partida.montar_mesa()
	for k in clampi(Sessao.jogadores, 1, 4):
		var decisor = DecisorInterface.new()
		decisor.pedido.connect(_ao_pedido.bind(decisor))
		partida.adicionar_jogador("j%d" % (k + 1), [], decisor)
	indice_preparo = 0
	indice_turno = 0
	_preparar_proximo_jogador()


func _nome(j) -> String:
	return "Jogador %s" % j.id.substr(1)


func _vez(j) -> String:
	return "" if partida.jogadores.size() == 1 else "%s: " % _nome(j)


# --- Cena 3D --------------------------------------------------------------------

func _criar_ambiente() -> void:
	camera = Camera3D.new()
	add_child(camera)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-52, 28, 0)
	luz.light_color = Color(1.0, 0.92, 0.78)
	luz.light_energy = 1.15
	luz.shadow_enabled = true
	luz.directional_shadow_max_distance = 32.0
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	var ceu := Sky.new()
	var ceu_material := ProceduralSkyMaterial.new()
	ceu_material.sky_top_color = Color(0.4, 0.6, 0.76)
	ceu_material.sky_horizon_color = Color(0.93, 0.85, 0.7)
	ceu_material.ground_horizon_color = Color(0.62, 0.64, 0.5)
	ceu_material.ground_bottom_color = Color(0.3, 0.36, 0.25)
	ceu.sky_material = ceu_material
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.68, 0.66)
	env.ambient_light_energy = 0.85
	ambiente.environment = env
	add_child(ambiente)
	# Pântano em volta e tablado de madeira e pedra com a arena e as vagas.
	vaga_lumes = Visual.pantano(self)
	var posicoes: Array = []
	for i in VAGAS:
		posicoes.append(_pos_vaga(i))
	vagas_3d = Visual.tablado(self, posicoes, POS_ENCONTRO)



func _plano(tamanho: Vector2, posicao: Vector3, cor: Color) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = tamanho
	no.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	no.material_override = material
	no.position = posicao
	add_child(no)
	return no


func _pos_vaga(i: int) -> Vector3:
	return Vector3((i - (VAGAS - 1) / 2.0) * ESPACO_VAGA, 0.0, POS_FILA_Z)


## Na horizontal a altura da mesa cabe na tela; na vertical, a largura.
func _ajustar_camera() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	if tamanho.x >= tamanho.y:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 40
		camera.look_at_from_position(Vector3(0, 6.6, 5.0), Vector3(0, 0, -0.85))
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 70
		camera.look_at_from_position(Vector3(0, 8.0, 7.0), Vector3(0, 0, 0.6))


## Carta da mesa: um quadro deitado com a textura de uma carta 2D desenhada num SubViewport.
func _criar_carta_3d() -> Node3D:
	var raiz := Node3D.new()
	var vp := SubViewport.new()
	vp.name = "VP"
	vp.size = PIXELS_CARTA
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	raiz.add_child(vp)
	var malha := MeshInstance3D.new()
	malha.name = "Malha"
	var quadro := QuadMesh.new()
	quadro.size = TAM_CARTA_3D
	malha.mesh = quadro
	malha.rotation_degrees.x = -90
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_texture = vp.get_texture()
	malha.material_override = material
	raiz.add_child(malha)
	add_child(raiz)
	return raiz


func _desenhar(no: Node3D, face: Control) -> void:
	var vp: SubViewport = no.get_node("VP")
	for filho in vp.get_children():
		vp.remove_child(filho)
		filho.queue_free()
	face.custom_minimum_size = Vector2(vp.size)
	face.size = Vector2(vp.size)
	vp.add_child(face)


## Figura 3D com uma plaquinha flutuante (nome, barra de Armadura e atributos).
func _criar_figura(figura: Node3D, altura_placa: float) -> Node3D:
	var raiz := Node3D.new()
	figura.name = "Figura"
	raiz.add_child(figura)
	var vp := SubViewport.new()
	vp.name = "VP"
	vp.size = Vector2i(260, 92)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	raiz.add_child(vp)
	var placa := Sprite3D.new()
	placa.name = "Placa"
	placa.texture = vp.get_texture()
	placa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	placa.pixel_size = 0.004
	placa.no_depth_test = true
	placa.render_priority = 10
	placa.position = Vector3(0, altura_placa, 0)
	raiz.add_child(placa)
	add_child(raiz)
	return raiz


func _face_placa(nome: String, armadura: int, maxima: int, forca: int, cor_barra: Color, borda: Color) -> PanelContainer:
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.06, 0.05, 0.05, 0.85), borda, 4, 14, 6))
	var coluna := _ignorar_mouse(VBoxContainer.new())
	coluna.add_theme_constant_override("separation", 2)
	painel.add_child(coluna)
	var linha := _ignorar_mouse(HBoxContainer.new())
	coluna.add_child(linha)
	linha.add_child(_medalhao(str(forca), COR_FORCA, 0.95))
	var rotulo := _texto(nome, 22, Color.WHITE, 5)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotulo.clip_text = true
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)
	linha.add_child(_medalhao(str(armadura), COR_ARMADURA, 0.95, Color(1, 0.55, 0.5) if armadura < maxima else Color.WHITE))
	var barra := ProgressBar.new()
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.max_value = maxi(1, maxima)
	barra.value = armadura
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 14)
	barra.add_theme_stylebox_override("background", _estilo(Color(0.1, 0.08, 0.08), Color.BLACK, 1, 6, 0))
	barra.add_theme_stylebox_override("fill", _estilo(cor_barra, cor_barra, 0, 6, 0))
	coluna.add_child(barra)
	return painel


func _paleta(c) -> Dictionary:
	return paletas.get(c.id_carta.split("__")[0], {})


func _tremer(no: Node3D) -> void:
	var figura := no.get_node_or_null("Figura") as Node3D
	if figura == null:
		return
	var tween := create_tween()
	for dx in [0.1, -0.1, 0.07, -0.05, 0.0]:
		tween.tween_property(figura, "position:x", dx, 0.05)


func _process(delta: float) -> void:
	tempo += delta
	for v in vaga_lumes:
		var base: Vector3 = v.get_meta("base")
		var fase_vl: float = v.get_meta("fase")
		v.position = base + Vector3(sin(tempo * 0.6 + fase_vl) * 0.4, sin(tempo * 1.3 + fase_vl) * 0.15, cos(tempo * 0.5 + fase_vl) * 0.3)
	_atualizar_vagas()
	if painel_dica != null:
		painel_dica.visible = rotulo_dica.text != "" and not camada_escolha.visible
	var k := 0
	for no in cartas_3d.values():
		var corpo := no.get_node_or_null("Figura/Corpo") as Node3D
		if corpo != null and no.visible:
			corpo.position.y = absf(sin(tempo * 2.6 + k * 1.3)) * 0.04
		k += 1
	if figura_inimigo != null:
		var corpo := figura_inimigo.get_node_or_null("Figura/Corpo") as Node3D
		if corpo != null and figura_inimigo.get_meta("vivo", true):
			corpo.scale = Vector3(1.0 + sin(tempo * 2.0) * 0.025, 1.0 - sin(tempo * 2.0) * 0.025, 1.0)


## Estado de cada vaga: livre, pode receber (pulsa em verde), ocupada (bronze)
## ou selecionada para atacar (dourada).
func _atualizar_vagas() -> void:
	if jogador == null or vagas_3d.is_empty():
		return
	var em_campo: Array = jogador.fila + pendentes
	var pode_receber := false
	if modo == "iniciais" or modo == "reerguer":
		pode_receber = pendentes.size() < 3
	elif modo == "preparacao":
		pode_receber = jogador.fila.size() < VAGAS and jogador.mao.any(func(c): return _pode_jogar(c))
	var selecionada := em_campo.find(atacante_escolhido) if modo == "ataque" else -1
	for i in vagas_3d.size():
		var aro: StandardMaterial3D = vagas_3d[i]["aro"]
		var cor := Color(0.42, 0.42, 0.45)
		var brilho := Color.BLACK
		if i < em_campo.size():
			cor = Color(0.78, 0.56, 0.26)
		if pode_receber and i == em_campo.size():
			var pulso := 0.5 + 0.5 * sin(tempo * 5.0)
			cor = Color(0.35, 0.9, 0.45)
			brilho = Color(0.15, 0.7, 0.25) * (0.4 + 0.5 * pulso) * (1.8 if arrastando else 1.0)
		if i == selecionada:
			cor = Color(1.0, 0.82, 0.3)
			brilho = Color(1.0, 0.7, 0.2) * (0.6 + 0.4 * sin(tempo * 6.0))
		aro.albedo_color = cor
		aro.emission = brilho
		var numero: Label3D = vagas_3d[i]["numero"]
		numero.visible = i >= em_campo.size()


func _chave(c) -> String:
	return "%s/%s" % [jogador.id, c.id_instancia]


func _atualizar(animar: bool) -> void:
	if jogador == null:
		return
	var em_campo: Array = jogador.fila + pendentes
	var destinos := {}
	for i in em_campo.size():
		var c = em_campo[i]
		var altura := 0.3 if (modo == "ataque" and c == atacante_escolhido) else 0.0
		destinos[c] = _pos_vaga(i) + Vector3(0, altura, 0)
	# Quem acabou de cair desliza para o Cemitério e some sob a pilha.
	for chave in cartas_3d.keys():
		var no: Node3D = cartas_3d[chave]
		var c = objetos_3d.get(chave)
		if no.visible and not destinos.has(c):
			if animar and c != null and jogador.cemiterio.has(c):
				var t := create_tween()
				t.tween_property(no, "position", POS_CEMITERIO + Vector3(0, 0.1, 0), 0.45)
				t.tween_callback(no.hide)
			else:
				no.visible = false
	for c in destinos:
		var chave := _chave(c)
		if not cartas_3d.has(chave):
			var nova := _criar_figura(Figuras.cavaleiro(_paleta(c), _cor_do_cavaleiro(c)), 1.85)
			nova.position = POS_ENTRADA
			cartas_3d[chave] = nova
		objetos_3d[chave] = c
		var carta: Node3D = cartas_3d[chave]
		if not carta.visible:
			carta.position = POS_ENTRADA
			carta.visible = true
		var borda := Color(0.55, 0.45, 0.25)
		if modo == "ataque" and opcoes_ataque.has(c):
			borda = Color(0.4, 1, 0.5) if c == atacante_escolhido else Color(0.4, 0.85, 1)
		_desenhar(carta, _face_placa(_nome_curto(c), c.armadura_atual, c.armadura_maxima(), c.forca_total(), Color(0.3, 0.6, 1.0), borda))
		if animar:
			var tween := create_tween()
			tween.tween_property(carta, "position", destinos[c], 0.4).set_trans(Tween.TRANS_CUBIC)
		else:
			carta.position = destinos[c]
	_desenhar(pilha_reino, _face_verso(jogador.reino_atual, "%d cartas" % partida.baralhos_reino[jogador.reino_atual].size(), Vector2(PIXELS_CARTA)))
	if jogador.cemiterio.is_empty():
		_desenhar(pilha_cemiterio, _face_verso("Cemitério", "vazio", Vector2(PIXELS_CARTA), true))
	else:
		_desenhar(pilha_cemiterio, _face_cavaleiro(jogador.cemiterio[-1], Vector2(PIXELS_CARTA), "caido"))
	_desenhar(carta_encontro, _face_encontro(Vector2(PIXELS_CARTA)))
	_atualizar_inimigo()
	_atualizar_mao()
	var itens := "nenhum"
	if not jogador.itens_mao.is_empty():
		itens = ", ".join(jogador.itens_mao.map(func(i): return i["nome"]))
	rotulo_status.text = _vez(jogador) + jogador.reino_atual
	chips["moedas"].text = "Moedas %d" % jogador.moedas
	chips["inimigos"].text = "Inimigos %d/4" % jogador.inimigos
	chips["eventos"].text = "Eventos %d/3" % jogador.eventos
	chips["itens"].text = "Itens %d" % jogador.itens_mao.size()
	chips["itens"].tooltip_text = itens


## Inimigo em combate vira figura 3D com plaquinha; Eventos e Mercador ficam como carta.
func _atualizar_inimigo() -> void:
	var ini = partida.inimigo_atual
	var em_combate: bool = ini != null and carta_revelada == ini.id
	carta_encontro.visible = not em_combate
	if not em_combate:
		if figura_inimigo != null:
			figura_inimigo.queue_free()
			figura_inimigo = null
		return
	if figura_inimigo == null:
		var escala := 1.75 if ini.eh_chefe() else 1.35
		figura_inimigo = _criar_figura(Figuras.inimigo(ini.id, ini.eh_chefe()), 1.6)
		figura_inimigo.position = POS_ENCONTRO
		var figura: Node3D = figura_inimigo.get_node("Figura")
		figura.scale = Vector3.ONE * escala
		figura_inimigo.get_node("Placa").position.y = 1.3 * escala
	_desenhar(figura_inimigo, _face_placa(ini.nome, ini.armadura_atual, ini.armadura_maxima, ini.forca_total(), Color(0.9, 0.2, 0.15), Color(0.9, 0.3, 0.2) if modo != "ataque" else Color(1, 0.85, 0.3)))
	if not ini.vivo() and figura_inimigo.get_meta("vivo", true):
		figura_inimigo.set_meta("vivo", false)
		var tween := create_tween()
		tween.tween_property(figura_inimigo.get_node("Figura"), "rotation_degrees:x", -85.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
		tween.parallel().tween_property(figura_inimigo.get_node("Placa"), "modulate:a", 0.0, 0.5)


func _ao_revelar(carta_id: String) -> void:
	carta_revelada = carta_id
	armaduras_vistas.clear()
	if figura_inimigo != null:
		figura_inimigo.queue_free()
		figura_inimigo = null
	_desenhar(carta_encontro, _face_encontro(Vector2(PIXELS_CARTA)))
	_atualizar_inimigo()
	var tween := create_tween()
	carta_encontro.scale = Vector3(0.2, 1, 0.2)
	tween.tween_property(carta_encontro, "scale", Vector3(ESCALA_ENCONTRO, 1, ESCALA_ENCONTRO), 0.35).set_trans(Tween.TRANS_BACK)


## Chamado pela lógica entre os golpes: mostra o dano e espera um pouco.
func _ritmo_do_combate() -> void:
	_mostrar_danos()
	_atualizar(true)
	await get_tree().create_timer(0.15).timeout
	partida.continuar.emit()


func _mostrar_danos() -> void:
	var ini = partida.inimigo_atual
	if ini != null:
		var antes: int = armaduras_vistas.get("inimigo", ini.armadura_atual)
		if ini.armadura_atual != antes:
			_numero_flutuante(POS_ENCONTRO + Vector3(0, 1.6, 0), ini.armadura_atual - antes)
			if figura_inimigo != null:
				_tremer(figura_inimigo)
		armaduras_vistas["inimigo"] = ini.armadura_atual
	for c in jogador.fila + jogador.cemiterio:
		var chave := _chave(c)
		var antes: int = armaduras_vistas.get(chave, c.armadura_atual)
		var agora: int = c.armadura_atual if jogador.fila.has(c) else 0
		if agora != antes and cartas_3d.has(chave):
			_numero_flutuante(cartas_3d[chave].position + Vector3(0, 1.3, 0), agora - antes)
			_tremer(cartas_3d[chave])
		armaduras_vistas[chave] = agora


func _numero_flutuante(posicao: Vector3, valor: int) -> void:
	var r := Label3D.new()
	r.text = ("%d" % valor) if valor < 0 else ("+%d" % valor)
	r.font_size = 120
	r.pixel_size = 0.006
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r.modulate = Color(1, 0.25, 0.2) if valor < 0 else Color(0.3, 1, 0.4)
	r.outline_size = 20
	r.no_depth_test = true
	r.position = posicao
	add_child(r)
	var tween := create_tween()
	tween.tween_property(r, "position", posicao + Vector3(0, 1.2, 0), 1.1)
	tween.parallel().tween_property(r, "modulate:a", 0.0, 1.1)
	tween.tween_callback(r.queue_free)


func _ao_rolar(motivo: String, face: int) -> void:
	if partida.rolando_em_janela:
		return  # esta rolagem aparece na janela do dado
	rotulo_dado.text = "%s\nD6: %d" % [_motivo_legivel(motivo), face]
	rotulo_dado.visible = true
	rotulo_dado.modulate.a = 1.0
	rotulo_dado.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(rotulo_dado, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.6)
	tween.tween_property(rotulo_dado, "modulate:a", 0.0, 0.3)


func _motivo_legivel(motivo: String) -> String:
	if motivo.begins_with("contra_ataque_"):
		var ini = partida.inimigo_atual
		return "Contra-ataque: %s" % (ini.nome if ini != null else motivo.substr(14).capitalize())
	if motivo.begins_with("ataque_"):
		return "Ataque: %s" % _nome_por_chave(motivo.substr(7))
	if motivo.begins_with("iniciativa_"):
		return "Iniciativa: Jogador %s" % motivo.substr(12)
	var nomes := {"ponte_": "Ponte Despencando", "areia_": "Areia Movediça", "gato_": "Gato de Botas", "furacao_": "Furacão Tubarão",
		"escorregao_tatico_": "Escorregão Tático", "passo_apressado_": "Botas do Corre-Corre", "nao_valeu_": "Não Valeu!",
		"honra_rival_": "Lute por Honra: rival", "honra_": "Lute por Honra", "calda_imperial": "Calda Imperial"}
	for prefixo in nomes:
		if motivo.begins_with(prefixo):
			return nomes[prefixo]
	return motivo.replace("_", " ").capitalize()


func _nome_por_chave(chave_curta: String) -> String:
	for c in jogador.fila + jogador.cemiterio + jogador.mao:
		if Regras.chave(c.id_instancia) == chave_curta:
			return _nome_curto(c)
	return chave_curta.capitalize()


func _ao_registrar(texto: String) -> void:
	if registro != null:
		registro.append_text(texto + "\n")


# --- Faces das cartas (usadas na mão, nas escolhas e na mesa) ------------------

func _cor_do_cavaleiro(c) -> Color:
	match c.cor:
		"Amarelo":
			return Color(0.95, 0.78, 0.3)
		"Vermelho":
			return Color(0.88, 0.36, 0.3)
	return Color(0.75, 0.75, 0.75)


func _nome_curto(c) -> String:
	return c.nome.replace("Cavaleiro ", "")


func _estilo(cor: Color, borda: Color, espessura: int = 3, raio: int = 12, margem: int = 8) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(espessura)
	estilo.set_corner_radius_all(raio)
	estilo.content_margin_left = margem
	estilo.content_margin_right = margem
	estilo.content_margin_top = margem
	estilo.content_margin_bottom = margem
	return estilo


func _texto(conteudo: String, tamanho: int, cor: Color = Color.WHITE, contorno: int = 0) -> Label:
	var r := Label.new()
	r.text = conteudo
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_color_override("font_color", cor)
	r.add_theme_font_size_override("font_size", maxi(8, tamanho))
	if contorno > 0:
		r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		r.add_theme_constant_override("outline_size", contorno)
	return r


func _ignorar_mouse(no: Control) -> Control:
	no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return no


## Medalhão redondo com um número, como os atributos dos jogos de cartas.
func _medalhao(valor: String, cor: Color, e: float, cor_texto: Color = Color.WHITE) -> PanelContainer:
	var m := PanelContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lado := 40.0 * e
	m.custom_minimum_size = Vector2(lado, lado)
	m.add_theme_stylebox_override("panel", _estilo(cor, Color(0.08, 0.06, 0.04), int(3 * e), 200, 0))
	var r := _texto(valor, int(24 * e), cor_texto, int(6 * e))
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(r)
	return m


## Quadro de "arte" provisório: cor da carta e a inicial em destaque.
func _arte(cor: Color, inicial: String, altura: float, e: float) -> PanelContainer:
	var a := PanelContainer.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.custom_minimum_size = Vector2(0, altura)
	a.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var estilo := _estilo(cor, cor.darkened(0.45), int(2 * e), int(8 * e), 0)
	estilo.bg_color = cor
	a.add_theme_stylebox_override("panel", estilo)
	var r := _texto(inicial, int(64 * e), cor.darkened(0.55))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.add_child(r)
	return a


func _moldura(cor_fundo: Color, borda: Color, tamanho: Vector2, espessura: int) -> PanelContainer:
	var e := tamanho.x / 140.0
	var painel := PanelContainer.new()
	painel.custom_minimum_size = tamanho
	painel.pivot_offset = tamanho / 2
	painel.add_theme_stylebox_override("panel", _estilo(cor_fundo, borda, espessura, int(14 * e), int(6 * e)))
	return painel


## Ilustração aprovada do Cavaleiro, se houver (arte/cavaleiros/<id>.jpg).
var _artes: Dictionary = {}


func _textura_arte(id_carta: String) -> Texture2D:
	var base: String = id_carta.split("__")[0]
	if not _artes.has(base):
		var caminho := "res://arte/cavaleiros/%s.jpg" % base
		_artes[base] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _artes[base]


## Ilustração cobrindo todo o quadro, recortada para caber.
func _ilustracao(textura: Texture2D, e: float) -> PanelContainer:
	var quadro := PanelContainer.new()
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quadro.clip_contents = true
	quadro.add_theme_stylebox_override("panel", _estilo(Color.BLACK, Color.BLACK, 0, int(10 * e), 0))
	var imagem := TextureRect.new()
	imagem.texture = textura
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quadro.add_child(imagem)
	return quadro


## Faixa escura semitransparente para o texto ficar legível sobre a arte.
func _faixa(e: float, opacidade: float = 0.62) -> PanelContainer:
	var faixa := PanelContainer.new()
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_theme_stylebox_override("panel", _estilo(Color(0, 0, 0, opacidade), Color(0, 0, 0, 0), 0, int(8 * e), int(3 * e)))
	return faixa


## Cavaleiro com arte de corpo inteiro; nome e atributos por cima.
## estado: "", "marcada", "destaque", "opcao", "apagada" ou "caido".
func _face_cavaleiro(c, tamanho: Vector2, estado: String = "") -> PanelContainer:
	var e := tamanho.x / 140.0
	var cor := _cor_do_cavaleiro(c)
	var borda := cor.darkened(0.15)
	var espessura := int(4 * e)
	match estado:
		"marcada":
			borda = Color(0.95, 0.25, 0.2)
			espessura = int(7 * e)
		"destaque":
			borda = Color(0.4, 1, 0.5)
			espessura = int(7 * e)
		"opcao":
			borda = Color(0.4, 0.85, 1)
			espessura = int(6 * e)
	var painel := _corpo_carta(tamanho, Color(0.2, 0.13, 0.08), borda, espessura)
	if estado == "apagada" or estado == "caido":
		painel.modulate = Color(0.55, 0.55, 0.55)
	var coluna: VBoxContainer = painel.get_child(0)
	coluna.add_child(_titulo_carta(str(c.custo()), Color(0.2, 0.42, 0.85), Color.WHITE, _nome_curto(c), e))
	var base_id: String = c.id_carta.split("__")[0]
	coluna.add_child(_janela_arte(_textura_arte(c.id_carta), "arte/cavaleiros/%s.jpg" % base_id, "", tamanho.x - 2 * (espessura + int(5 * e)), e))
	var hab := _texto(c.habilidade if c.habilidade != "" else " ", int(11 * e), Color(1, 0.88, 0.6))
	hab.autowrap_mode = TextServer.AUTOWRAP_OFF
	hab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(hab)
	var ferido: bool = c.armadura_atual < c.armadura_maxima()
	coluna.add_child(_linha_atributos(c.forca_total(), c.armadura_atual, "Honra %d" % c.honra(), Color(1, 0.6, 0.55) if ferido else Color.WHITE, e))
	if estado == "marcada":
		var selo := _texto("TROCAR", int(26 * e), Color(1, 0.3, 0.25), int(8 * e))
		selo.add_theme_font_override("font", Tema.fonte_titulo())
		selo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		selo.rotation_degrees = -14
		selo.pivot_offset = Vector2(tamanho.x * 0.5, tamanho.x * ALTURA_POR_LARGURA * 0.5)
		painel.add_child(selo)
	return painel


## Corpo da carta: moldura com proporção fixa e uma coluna para o conteúdo.
func _corpo_carta(tamanho: Vector2, fundo: Color, borda: Color, espessura: int) -> PanelContainer:
	var e := tamanho.x / 140.0
	var painel := PanelContainer.new()
	var altura := tamanho.x * ALTURA_POR_LARGURA
	painel.custom_minimum_size = Vector2(tamanho.x, altura)
	painel.pivot_offset = Vector2(tamanho.x / 2, altura)
	var caixa := Tema.caixa(fundo, borda, espessura, int(12 * e), int(5 * e), int(5 * e))
	caixa.content_margin_top = int(5 * e)
	caixa.content_margin_bottom = int(5 * e)
	painel.add_theme_stylebox_override("panel", caixa)
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_theme_constant_override("separation", int(3 * e))
	painel.add_child(coluna)
	return painel


## Faixa do título: medalhão (custo, preço ou Ameaça) e o nome.
func _titulo_carta(valor: String, cor_valor: Color, cor_texto_valor: Color, nome: String, e: float) -> HBoxContainer:
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_theme_constant_override("separation", int(4 * e))
	topo.custom_minimum_size = Vector2(0, 26 * e)
	if valor != "":
		topo.add_child(_medalhao(valor, cor_valor, e * 0.68, cor_texto_valor))
	var rotulo := _texto(nome, int((14 if nome.length() > 13 else 16) * e), Color(1, 0.95, 0.84), int(4 * e))
	rotulo.add_theme_font_override("font", Tema.fonte_titulo())
	rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(rotulo)
	return topo


## Janela de arte em 4:5, a proporção das ilustrações: mostra a imagem inteira, sem
## esticar nem recortar. Sem ilustração, mostra um aviso provisório com o arquivo que falta.
func _janela_arte(textura: Texture2D, arquivo_esperado: String, texto_extra: String, largura: float, e: float) -> AspectRatioContainer:
	var caixa := AspectRatioContainer.new()
	caixa.ratio = PROPORCAO_ARTE
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.custom_minimum_size = Vector2(largura, largura / PROPORCAO_ARTE)
	var quadro := PanelContainer.new()
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quadro.clip_contents = true
	caixa.add_child(quadro)
	if textura != null:
		quadro.add_theme_stylebox_override("panel", Tema.caixa(Color(0.1, 0.07, 0.04), Color(0.1, 0.07, 0.04), 0, int(6 * e), 0))
		var imagem := TextureRect.new()
		imagem.texture = textura
		imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quadro.add_child(imagem)
		return caixa
	# Recurso provisório, identificado como tal.
	quadro.add_theme_stylebox_override("panel", Tema.caixa(Tema.PERGAMINHO_ESCURO, Color(0.55, 0.42, 0.25), int(2 * e), int(6 * e), int(6 * e)))
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", int(3 * e))
	quadro.add_child(coluna)
	if texto_extra != "":
		var extra := _texto(texto_extra, int(10.5 * e), Tema.TINTA)
		extra.size_flags_vertical = Control.SIZE_EXPAND_FILL
		coluna.add_child(extra)
	var aviso := _texto("ILUSTRAÇÃO PENDENTE", int(10 * e), Color(0.5, 0.3, 0.15))
	aviso.add_theme_font_override("font", Tema.fonte_titulo())
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(aviso)
	if arquivo_esperado != "":
		var arquivo := _texto(arquivo_esperado.get_file(), int(8 * e), Color(0.45, 0.35, 0.25))
		arquivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coluna.add_child(arquivo)
	return caixa


## Linha de baixo: Força (vermelho), um texto no meio e Armadura (azul).
func _linha_atributos(forca: int, armadura: int, meio: String, cor_armadura: Color, e: float) -> HBoxContainer:
	var base := HBoxContainer.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(_medalhao(str(forca), COR_FORCA, e * 0.92))
	var rotulo := _texto(meio, int(11.5 * e), Color(0.95, 0.9, 0.8))
	rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base.add_child(rotulo)
	base.add_child(_medalhao(str(armadura), COR_ARMADURA, e * 0.92, cor_armadura))
	return base



func _face_item(item: Dictionary, tamanho: Vector2, estado: String = "") -> PanelContainer:
	var e := tamanho.x / 140.0
	var marcada := estado == "marcada"
	var espessura := int((7 if marcada else 4) * e)
	var painel := _corpo_carta(tamanho, Color(0.13, 0.13, 0.2), Color(0.4, 1, 0.5) if marcada else Color(0.5, 0.55, 0.8), espessura)
	if estado == "apagada":
		painel.modulate = Color(0.55, 0.55, 0.55)
	var coluna: VBoxContainer = painel.get_child(0)
	coluna.add_child(_titulo_carta(str(int(item["preco_mercador"])), COR_OURO.darkened(0.1), Color.BLACK, item["nome"], e))
	coluna.add_child(_janela_arte(null, "", item["efeito"], tamanho.x - 2 * (espessura + int(5 * e)), e))
	var categoria := _texto("%s • %s" % [item["categoria"], item["raridade"]], int(11 * e), Color(0.75, 0.8, 1))
	categoria.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(categoria)
	return painel



## Carta do topo: inimigo (com barra de Armadura), Evento, Mercador ou o próprio reino.
func _face_encontro(tamanho: Vector2) -> PanelContainer:
	var e := tamanho.x / 140.0
	var ini = partida.inimigo_atual if partida != null else null
	if ini != null and carta_revelada == ini.id:
		var painel := _moldura(Color(0.16, 0.06, 0.05), Color(0.85, 0.25, 0.18) if ini.vivo() else Color(0.35, 0.3, 0.3), tamanho, int(5 * e))
		if not ini.vivo():
			painel.modulate = Color(0.55, 0.55, 0.55)
		var coluna := _ignorar_mouse(VBoxContainer.new())
		coluna.add_theme_constant_override("separation", int(3 * e))
		painel.add_child(coluna)
		var topo := _ignorar_mouse(HBoxContainer.new())
		coluna.add_child(topo)
		topo.add_child(_medalhao(str(ini.ameaca), COR_OURO, e * 0.8, Color.BLACK))
		var nome := _texto(ini.nome, int(15 * e), Color.WHITE, int(4 * e))
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		topo.add_child(nome)
		coluna.add_child(_arte(Color(0.55, 0.2, 0.15), ini.nome.left(1), 62 * e, e))
		var barra := ProgressBar.new()
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.max_value = ini.armadura_maxima
		barra.value = ini.armadura_atual
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 12 * e)
		barra.add_theme_stylebox_override("background", _estilo(Color(0.08, 0.05, 0.05), Color.BLACK, 1, int(5 * e), 0))
		barra.add_theme_stylebox_override("fill", _estilo(Color(0.85, 0.18, 0.15), Color(0.85, 0.18, 0.15), 0, int(5 * e), 0))
		coluna.add_child(barra)
		var base := _ignorar_mouse(HBoxContainer.new())
		coluna.add_child(base)
		base.add_child(_medalhao(str(ini.forca_total()), COR_FORCA, e))
		var vida := _texto("%d/%d" % [ini.armadura_atual, ini.armadura_maxima], int(13 * e), Color(0.9, 0.9, 0.9))
		vida.autowrap_mode = TextServer.AUTOWRAP_OFF
		vida.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vida.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vida.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		base.add_child(vida)
		base.add_child(_medalhao(str(ini.armadura_atual), COR_ARMADURA, e))
		return painel
	var tipo: String = cat.tipo_de_carta(carta_revelada) if carta_revelada != "" else ""
	if tipo == "evento":
		var ev: Dictionary = cat.eventos[carta_revelada]
		return _face_texto(ev["nome"], "EVENTO", ev["efeito"], Color(0.12, 0.18, 0.32), Color(0.45, 0.65, 1), tamanho)
	if tipo == "mercador":
		return _face_texto("Mercador", "LOJA", "Revela cinco itens. Compre quantos quiser pelos preços impressos.", Color(0.25, 0.18, 0.06), COR_OURO, tamanho)
	var reino: String = jogador.reino_atual if jogador != null else "Pântano Maluco"
	return _face_texto(reino, "REINO", "Explore para revelar a próxima carta.", Color(0.1, 0.2, 0.13), Color(0.45, 0.75, 0.45), tamanho)


func _face_texto(titulo: String, selo: String, corpo: String, fundo: Color, borda: Color, tamanho: Vector2) -> PanelContainer:
	var e := tamanho.x / 140.0
	var painel := _corpo_carta(tamanho, fundo, borda, int(5 * e))
	var coluna: VBoxContainer = painel.get_child(0)
	coluna.add_child(_titulo_carta("", Color.BLACK, Color.BLACK, titulo, e))
	coluna.add_child(_janela_arte(null, "", corpo, tamanho.x - 2 * int(10 * e), e))
	var marca := _texto(selo, int(13 * e), borda)
	marca.add_theme_font_override("font", Tema.fonte_titulo())
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(marca)
	return painel



## Verso de baralho ou pilha.
func _face_verso(titulo: String, subtitulo: String, tamanho: Vector2, apagado: bool = false) -> PanelContainer:
	var e := tamanho.x / 140.0
	var fundo := Color(0.2, 0.18, 0.22) if apagado else Color(0.28, 0.14, 0.1)
	var painel := _moldura(fundo, COR_OURO.darkened(0.25), tamanho, int(5 * e))
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	painel.add_child(coluna)
	var marca := _texto("MK", int(48 * e), COR_OURO.darkened(0.1 if not apagado else 0.5), int(6 * e))
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(marca)
	var nome := _texto(titulo, int(15 * e), Color.WHITE, int(4 * e))
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(nome)
	var sub := _texto(subtitulo, int(13 * e), Color(0.85, 0.8, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(sub)
	return painel


## Liga um toque (soltar o dedo) a uma ação.
func _tocavel(painel: Control, acao: Callable) -> Control:
	if acao.is_valid():
		painel.gui_input.connect(_ao_toque_2d.bind(acao))
	return painel


func _ao_toque_2d(evento: InputEvent, acao: Callable) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
		acao.call()


# --- Mão ------------------------------------------------------------------------

func _atualizar_mao() -> void:
	for filho in mao_2d.get_children():
		mao_2d.remove_child(filho)
		filho.queue_free()
	var cartas: Array = jogador.mao.filter(func(c): return not pendentes.has(c))
	var total: int = cartas.size() + jogador.itens_mao.size()
	var i := 0
	for c in cartas:
		var estado := "destaque" if _pode_jogar(c) else ""
		if modo == "preparacao" and not _pode_jogar(c):
			estado = "apagada"
		var carta := _face_cavaleiro(c, TAM_MAO, estado)
		_tocavel(carta, _mostrar_detalhes_cavaleiro.bind(c, "Na mão"))
		carta.gui_input.connect(_pressao_na_mao.bind(carta))
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 3.0
		carta.set_drag_forwarding(_arrastar_da_mao.bind(c, carta), Callable(), Callable())
		mao_2d.add_child(carta)
		i += 1
	for item in jogador.itens_mao:
		var carta := _face_item(item, TAM_MAO)
		_tocavel(carta, _tocar_item.bind(item))
		carta.gui_input.connect(_pressao_na_mao.bind(carta))
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 3.0
		mao_2d.add_child(carta)
		i += 1


## Ao encostar o dedo, a carta cresce um pouco; ao soltar, volta.
func _pressao_na_mao(evento: InputEvent, carta: Control) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		var alvo := Vector2(1.08, 1.08) if evento.pressed else Vector2.ONE
		create_tween().tween_property(carta, "scale", alvo, 0.1)



func _tocar_item(item: Dictionary) -> void:
	if modo == "preparacao":
		_escolher_portador(item)
	else:
		_mostrar_detalhes("[b]%s[/b]  (%s, %s)\n\n%s" % [item["nome"], item["categoria"], item["raridade"], item["efeito"]])


func _arrastar_da_mao(_posicao: Vector2, c, origem: Control) -> Variant:
	if not _pode_jogar(c):
		return null
	var previa := _face_cavaleiro(c, TAM_MAO * 1.12, "destaque")
	previa.rotation_degrees = -5
	var suporte := Control.new()
	suporte.add_child(previa)
	previa.position = -Vector2(TAM_MAO.x * 1.12 / 2, TAM_MAO.x * 1.12 * ALTURA_POR_LARGURA * 0.6)
	mao_2d.set_drag_preview(suporte)
	carta_arrastada = origem
	origem.modulate.a = 0.3
	origem.scale = Vector2.ONE
	return {"cavaleiro": c}



func _pode_jogar(c) -> bool:
	match modo:
		"iniciais", "reerguer":
			return pendentes.size() < 3 and not pendentes.has(c)
		"preparacao":
			return jogador.fila.size() < VAGAS and jogador.moedas >= c.custo()
	return false


func _pode_soltar(_posicao: Vector2, dados) -> bool:
	return dados is Dictionary and dados.has("cavaleiro") and _pode_jogar(dados["cavaleiro"])


func _soltar(_posicao: Vector2, dados) -> void:
	jogar_em_campo(dados["cavaleiro"])


## Joga um Cavaleiro da mão na mesa (arrastar e soltar).
func jogar_em_campo(c) -> void:
	if not _pode_jogar(c):
		return
	match modo:
		"iniciais", "reerguer":
			pendentes.append(c)
			_atualizar(true)
			if pendentes.size() < mini(3, jogador.mao.size()):
				_dica_iniciais()
				return
			var escolhidos := pendentes.duplicate()
			pendentes.clear()
			if modo == "reerguer":
				modo = ""
				rotulo_dica.text = ""
				decisor_atual.responder(escolhidos)
			else:
				_concluir_iniciais(escolhidos)
		"preparacao":
			modo = ""
			await partida.recrutar_da_mao(jogador, c.id_instancia)
			_tela_preparacao()


func _notification(qual: int) -> void:
	if zona_mesa == null:
		return
	if qual == NOTIFICATION_DRAG_BEGIN:
		zona_mesa.visible = true
		arrastando = true
	elif qual == NOTIFICATION_DRAG_END:
		zona_mesa.visible = false
		arrastando = false
		if is_instance_valid(carta_arrastada):
			carta_arrastada.modulate.a = 1.0
		carta_arrastada = null



# --- Toques na mesa ------------------------------------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if camada_detalhes.visible or camada_escolha.visible or jogador == null:
		return
	if not (evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed):
		return
	var origem := camera.project_ray_origin(evento.position)
	var direcao := camera.project_ray_normal(evento.position)
	if absf(direcao.y) < 0.001:
		return
	var ponto := origem + direcao * (-origem.y / direcao.y)
	if carta_revelada != "" and _sob_ponto(ponto, POS_ENCONTRO, ESCALA_ENCONTRO):
		if modo == "ataque":
			atacar()
		else:
			_mostrar_detalhes(_detalhes_do_encontro())
		return
	if _sob(ponto, pilha_reino, 1.0):
		_mostrar_detalhes("[b]%s[/b]\n\n%d cartas no baralho do reino e %d no descarte." % [
			jogador.reino_atual, partida.baralhos_reino[jogador.reino_atual].size(), partida.descartes_reino[jogador.reino_atual].size()])
		return
	if _sob(ponto, pilha_cemiterio, 1.0):
		var nomes: Array = jogador.cemiterio.map(func(c): return _nome_curto(c))
		_mostrar_detalhes("[b]Cemitério[/b]\n\n%s" % (", ".join(nomes) if not nomes.is_empty() else "Vazio."))
		return
	for chave in cartas_3d:
		var no: Node3D = cartas_3d[chave]
		if no.visible and _sob(ponto, no, 1.0) and objetos_3d.has(chave):
			var c = objetos_3d[chave]
			if modo == "ataque" and opcoes_ataque.has(c):
				atacante_escolhido = c
				_dica_ataque()
				_atualizar(true)
				return
			var onde := "Na mesa"
			if jogador.fila.has(c):
				onde = "Em campo, posição %d da fila" % (jogador.fila.find(c) + 1)
			_mostrar_detalhes_cavaleiro(c, onde)
			return


func _sob_ponto(ponto: Vector3, centro: Vector3, escala: float) -> bool:
	return absf(ponto.x - centro.x) < TAM_CARTA_3D.x / 2 * escala and absf(ponto.z - centro.z) < TAM_CARTA_3D.y / 2 * escala


func _sob(ponto: Vector3, no: Node3D, escala: float) -> bool:
	return absf(ponto.x - no.position.x) < TAM_CARTA_3D.x / 2 * escala and absf(ponto.z - no.position.z) < TAM_CARTA_3D.y / 2 * escala


## Ataca o inimigo com o Cavaleiro escolhido (toque no inimigo durante o combate).
func atacar() -> void:
	if modo != "ataque" or decisor_atual == null:
		return
	modo = ""
	var quem = atacante_escolhido
	opcoes_ataque = []
	atacante_escolhido = null
	rotulo_dica.text = ""
	var no = cartas_3d.get(_chave(quem))
	if no != null:
		# Pulinho em direção ao inimigo e volta.
		var origem: Vector3 = no.position
		var alvo := origem.lerp(POS_ENCONTRO, 0.55) + Vector3(0, 0.5, 0)
		var tween := create_tween()
		tween.tween_property(no, "position", alvo, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(no, "position", Vector3(origem.x, 0, origem.z), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
	_atualizar(true)
	decisor_atual.responder(quem)


func _dica_ataque() -> void:
	var texto := "Toque no inimigo para atacar com %s." % _nome_curto(atacante_escolhido)
	if opcoes_ataque.size() > 1:
		texto += " Fila do Café: toque no Pão com Manteiga para ele atacar no lugar."
	rotulo_dica.text = _vez(jogador) + texto


func _mostrar_detalhes_cavaleiro(c, onde: String) -> void:
	var texto := "[b]%s[/b]  (%s)\n%s\n\nForça %d   Armadura %d/%d   Honra %d   Prestígio %d\nCusto para entrar em campo: %d" % [
		c.nome, c.cor, onde, c.forca_total(), c.armadura_atual, c.armadura_maxima(), c.honra(), c.prestigio(), c.custo()]
	if c.habilidade != "":
		texto += "\n\n[b]%s[/b]: %s" % [c.habilidade, c.habilidade_texto]
	if not c.equipamentos.is_empty():
		texto += "\n\n[b]Equipamentos[/b]"
		for item in c.equipamentos:
			texto += "\n• %s: %s" % [item["nome"], item["efeito"]]
	_mostrar_detalhes(texto, _face_cavaleiro(c, Vector2(200, 280)))


func _detalhes_do_encontro() -> String:
	if carta_revelada == "":
		return "[b]%s[/b]\n\nExplore o reino para revelar a primeira carta." % jogador.reino_atual
	var tipo: String = cat.tipo_de_carta(carta_revelada)
	if tipo == "mercador":
		return "[b]Mercador[/b]\n\nRevela cinco itens. Compre quantos quiser pelos preços impressos."
	if tipo == "evento":
		var ev: Dictionary = cat.eventos[carta_revelada]
		return "[b]%s[/b]  (Evento)\n\n%s" % [ev["nome"], ev["efeito"]]
	var dados: Dictionary = cat.inimigos[carta_revelada]
	var ini = partida.inimigo_atual
	var estado := ""
	if ini != null and ini.id == carta_revelada:
		estado = "\nForça %d   Armadura %d/%d   Ameaça %d%s" % [ini.forca_total(), ini.armadura_atual, ini.armadura_maxima, ini.ameaca, "" if ini.vivo() else "   (derrotado)"]
	return "[b]%s[/b]  (%s)%s\n\n[b]%s[/b]: %s" % [dados["nome"], dados["tipo"], estado, dados["habilidade"], dados["efeito"]]


func _mostrar_detalhes(texto: String, face: Control = null) -> void:
	texto_detalhes.text = texto
	for filho in carta_detalhes.get_children():
		carta_detalhes.remove_child(filho)
		filho.queue_free()
	carta_detalhes.visible = face != null
	if face != null:
		carta_detalhes.add_child(face)
	camada_detalhes.visible = true


func _fechar_detalhes() -> void:
	camada_detalhes.visible = false


func _alternar_registro() -> void:
	painel_registro.visible = not painel_registro.visible


# --- Interface 2D ---------------------------------------------------------------

func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = Tema.criar()
	camada.add_child(raiz)

	# Área de soltar: cobre a mesa e só aparece enquanto uma carta é arrastada.
	zona_mesa = Control.new()
	raiz.add_child(zona_mesa)
	zona_mesa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zona_mesa.visible = false
	zona_mesa.set_drag_forwarding(Callable(), _pode_soltar, _soltar)

	# Topo: barra de madeira com menu, registro, reino e contadores.
	var topo := PanelContainer.new()
	raiz.add_child(topo)
	topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var barra := Tema.madeira()
	barra.set_corner_radius_all(0)
	barra.content_margin_top = 5
	barra.content_margin_bottom = 7
	topo.add_theme_stylebox_override("panel", barra)
	var linha_topo := HBoxContainer.new()
	linha_topo.add_theme_constant_override("separation", 10)
	topo.add_child(linha_topo)
	for par in [["Menu", _ir_ao_menu], ["Registro", _alternar_registro]]:
		var b := Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(par[1])
		linha_topo.add_child(b)
	rotulo_status = Label.new()
	rotulo_status.add_theme_font_override("font", Tema.fonte_titulo())
	rotulo_status.add_theme_font_size_override("font_size", 24)
	rotulo_status.add_theme_color_override("font_color", Tema.LATAO.lightened(0.15))
	rotulo_status.add_theme_color_override("font_outline_color", Tema.MADEIRA_ESCURA)
	rotulo_status.add_theme_constant_override("outline_size", 6)
	rotulo_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha_topo.add_child(rotulo_status)
	for dados_chip in [["moedas", COR_OURO], ["inimigos", Color(0.8, 0.22, 0.18)], ["eventos", Color(0.3, 0.5, 0.9)], ["itens", Color(0.45, 0.65, 0.4)]]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Tema.caixa(Tema.PERGAMINHO, Tema.MADEIRA_ESCURA, 2, 16, 10))
		var linha_chip := HBoxContainer.new()
		linha_chip.add_theme_constant_override("separation", 6)
		chip.add_child(linha_chip)
		var icone := PanelContainer.new()
		icone.custom_minimum_size = Vector2(18, 18)
		icone.add_theme_stylebox_override("panel", Tema.caixa(dados_chip[1], dados_chip[1].darkened(0.45), 2, 9, 0))
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha_chip.add_child(icone)
		var valor := Label.new()
		valor.add_theme_font_override("font", Tema.fonte_forte())
		valor.add_theme_font_size_override("font_size", 17)
		linha_chip.add_child(valor)
		chips[dados_chip[0]] = valor
		linha_topo.add_child(chip)

	# Fases do turno: fita de pergaminho logo abaixo da barra.
	var fases := PanelContainer.new()
	raiz.add_child(fases)
	fases.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fases.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fases.offset_top = 56
	fases.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fases.add_theme_stylebox_override("panel", Tema.caixa(Tema.PERGAMINHO, Tema.MADEIRA, 3, 14, 12, 4))
	var linha_fases := HBoxContainer.new()
	linha_fases.add_theme_constant_override("separation", 8)
	fases.add_child(linha_fases)
	for i in FASES.size():
		if i > 0:
			linha_fases.add_child(_texto("›", 17, Color(0.55, 0.45, 0.3)))
		var r := _texto(FASES[i], 16, Color(0.55, 0.45, 0.3))
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		linha_fases.add_child(r)
		rotulos_fase.append(r)

	# Dica do momento: pergaminho pequeno, legível sem dominar a tela.
	painel_dica = PanelContainer.new()
	raiz.add_child(painel_dica)
	painel_dica.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	painel_dica.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel_dica.offset_top = 98
	painel_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_dica.add_theme_stylebox_override("panel", Tema.caixa(Color(0.98, 0.94, 0.82, 0.93), Color(0.62, 0.47, 0.27), 2, 10, 12))
	rotulo_dica = Label.new()
	rotulo_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo_dica.custom_minimum_size = Vector2(620, 0)
	rotulo_dica.add_theme_font_size_override("font_size", 17)
	painel_dica.add_child(rotulo_dica)

	# Narração: faixa grande e legenda no alto da mesa.
	faixa = _texto("", 58, COR_OURO, 16)
	faixa.add_theme_font_override("font", Tema.fonte_titulo())
	raiz.add_child(faixa)
	faixa.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	faixa.offset_top = 150
	faixa.offset_bottom = 230
	faixa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faixa.autowrap_mode = TextServer.AUTOWRAP_OFF
	faixa.pivot_offset = Vector2(640, 40)
	faixa.visible = false
	legenda = _texto("", 28, Color.WHITE, 12)
	legenda.add_theme_font_override("font", Tema.fonte_forte())
	raiz.add_child(legenda)
	legenda.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	legenda.offset_top = 232
	legenda.offset_bottom = 330
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legenda.visible = false

	# Vitrine: a carta revelada aparece grande no meio da tela.
	vitrine = Control.new()
	raiz.add_child(vitrine)
	vitrine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vitrine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo_vitrine := ColorRect.new()
	fundo_vitrine.color = Color(0, 0, 0, 0.45)
	fundo_vitrine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitrine.add_child(fundo_vitrine)
	fundo_vitrine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var coluna_vitrine := VBoxContainer.new()
	coluna_vitrine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna_vitrine.alignment = BoxContainer.ALIGNMENT_CENTER
	vitrine.add_child(coluna_vitrine)
	coluna_vitrine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo_vitrine = _texto("", 44, COR_OURO, 14)
	titulo_vitrine.add_theme_font_override("font", Tema.fonte_titulo())
	titulo_vitrine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna_vitrine.add_child(titulo_vitrine)
	lugar_vitrine = CenterContainer.new()
	lugar_vitrine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna_vitrine.add_child(lugar_vitrine)
	vitrine.visible = false

	# Mão: embaixo, no centro, saindo um pouco pela borda como nos jogos de cartas.
	mao_2d = HBoxContainer.new()
	raiz.add_child(mao_2d)
	mao_2d.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	mao_2d.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mao_2d.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mao_2d.offset_bottom = -6  # a mão inteira fica visível
	mao_2d.alignment = BoxContainer.ALIGNMENT_CENTER
	mao_2d.add_theme_constant_override("separation", -8)

	# Ações: à direita, como o botão de fim de turno.
	acoes = VBoxContainer.new()
	raiz.add_child(acoes)
	acoes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	acoes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	acoes.grow_vertical = Control.GROW_DIRECTION_BOTH
	acoes.offset_right = -16
	acoes.offset_left = -16
	acoes.offset_top = 60
	acoes.add_theme_constant_override("separation", 10)

	# Registro: painel à esquerda, aberto pelo botão do topo.
	painel_registro = PanelContainer.new()
	raiz.add_child(painel_registro)
	painel_registro.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	painel_registro.offset_top = 56
	painel_registro.offset_bottom = -10
	painel_registro.custom_minimum_size = Vector2(420, 0)
	painel_registro.add_theme_stylebox_override("panel", Tema.pergaminho(14))
	registro = RichTextLabel.new()
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 16)
	painel_registro.add_child(registro)
	painel_registro.visible = false

	# Escolhas: no centro da tela, com o fundo escurecido. O CenterContainer mantém
	# a janela centralizada qualquer que seja o tamanho do conteúdo.
	camada_escolha = _camada_central(raiz)
	escolha = PanelContainer.new()
	escolha.add_theme_stylebox_override("panel", Tema.pergaminho(20))
	camada_escolha.get_child(1).add_child(escolha)
	var coluna_escolha := VBoxContainer.new()
	coluna_escolha.add_theme_constant_override("separation", 14)
	escolha.add_child(coluna_escolha)
	titulo_escolha = Label.new()
	titulo_escolha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_escolha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_escolha.custom_minimum_size = Vector2(940, 0)
	titulo_escolha.add_theme_font_size_override("font_size", 21)
	coluna_escolha.add_child(titulo_escolha)
	cartas_escolha = HFlowContainer.new()
	cartas_escolha.alignment = FlowContainer.ALIGNMENT_CENTER
	cartas_escolha.add_theme_constant_override("h_separation", 14)
	cartas_escolha.add_theme_constant_override("v_separation", 14)
	coluna_escolha.add_child(cartas_escolha)
	botoes_escolha = HFlowContainer.new()
	botoes_escolha.alignment = FlowContainer.ALIGNMENT_CENTER
	botoes_escolha.add_theme_constant_override("h_separation", 12)
	coluna_escolha.add_child(botoes_escolha)
	_fechar_escolha()

	# Resultado do D6, grande no meio.
	rotulo_dado = Label.new()
	raiz.add_child(rotulo_dado)
	rotulo_dado.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rotulo_dado.offset_left = -300
	rotulo_dado.offset_right = 300
	rotulo_dado.offset_top = -120
	rotulo_dado.offset_bottom = 0
	rotulo_dado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_dado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo_dado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo_dado.add_theme_font_size_override("font_size", 44)
	rotulo_dado.add_theme_color_override("font_color", Color(1, 1, 1))
	rotulo_dado.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0))
	rotulo_dado.add_theme_constant_override("outline_size", 14)
	rotulo_dado.pivot_offset = Vector2(300, 60)
	rotulo_dado.visible = false

	# Janela do dado: o jogo entrega o dado e o jogador lança.
	camada_dado = _camada_central(raiz)
	var painel_dado := PanelContainer.new()
	painel_dado.add_theme_stylebox_override("panel", Tema.pergaminho(22))
	camada_dado.get_child(1).add_child(painel_dado)
	var coluna_dado := VBoxContainer.new()
	coluna_dado.add_theme_constant_override("separation", 10)
	painel_dado.add_child(coluna_dado)
	titulo_dado = Label.new()
	titulo_dado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_dado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_dado.custom_minimum_size = Vector2(460, 0)
	titulo_dado.add_theme_font_size_override("font_size", 26)
	titulo_dado.add_theme_font_override("font", Tema.fonte_titulo())
	coluna_dado.add_child(titulo_dado)
	area_dado = Control.new()
	area_dado.custom_minimum_size = Vector2(460, 230)
	coluna_dado.add_child(area_dado)
	dado_visual = Control.new()
	dado_visual.custom_minimum_size = Vector2(140, 140)
	dado_visual.size = Vector2(140, 140)
	dado_visual.pivot_offset = Vector2(70, 70)
	dado_visual.gui_input.connect(_ao_tocar_dado)
	area_dado.add_child(dado_visual)
	resultado_dado = Label.new()
	resultado_dado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resultado_dado.add_theme_font_size_override("font_size", 30)
	resultado_dado.add_theme_color_override("font_color", Color(0.6, 0.22, 0.08))
	resultado_dado.add_theme_font_override("font", Tema.fonte_titulo())
	coluna_dado.add_child(resultado_dado)
	botao_jogar = Button.new()
	botao_jogar.text = "Jogar!"
	botao_jogar.custom_minimum_size = Vector2(0, 70)
	botao_jogar.add_theme_font_size_override("font_size", 30)
	Tema.botao_principal(botao_jogar)
	botao_jogar.pressed.connect(_lancar_dado)
	coluna_dado.add_child(botao_jogar)
	camada_dado.visible = false

	# Detalhes de uma carta, também centralizados.
	camada_detalhes = _camada_central(raiz)
	var detalhes := PanelContainer.new()
	detalhes.add_theme_stylebox_override("panel", Tema.pergaminho(20))
	camada_detalhes.get_child(1).add_child(detalhes)
	var linha_detalhes := HBoxContainer.new()
	linha_detalhes.add_theme_constant_override("separation", 18)
	detalhes.add_child(linha_detalhes)
	carta_detalhes = CenterContainer.new()
	linha_detalhes.add_child(carta_detalhes)
	var coluna_detalhes := VBoxContainer.new()
	linha_detalhes.add_child(coluna_detalhes)
	texto_detalhes = RichTextLabel.new()
	texto_detalhes.bbcode_enabled = true
	texto_detalhes.fit_content = true
	texto_detalhes.custom_minimum_size = Vector2(520, 0)
	coluna_detalhes.add_child(texto_detalhes)
	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.custom_minimum_size = Vector2(0, 54)
	fechar.pressed.connect(_fechar_detalhes)
	coluna_detalhes.add_child(fechar)
	camada_detalhes.visible = false


## Camada de tela cheia com fundo escuro e um CenterContainer para o conteúdo.
func _camada_central(raiz: Control) -> Control:
	var camada := Control.new()
	raiz.add_child(camada)
	camada.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	camada.add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centro := CenterContainer.new()
	camada.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return camada


func _ir_ao_menu() -> void:
	get_tree().change_scene_to_file("res://cenas/menu.tscn")


func _abrir_escolha(titulo: String) -> void:
	if not titulo.is_empty():
		titulo = titulo[0].to_upper() + titulo.substr(1)
	titulo_escolha.text = titulo
	for recipiente in [cartas_escolha, botoes_escolha]:
		for filho in recipiente.get_children():
			recipiente.remove_child(filho)
			filho.queue_free()
	camada_escolha.visible = true


func _fechar_escolha() -> void:
	camada_escolha.visible = false


func _botao_escolha(texto: String, acao: Callable, ativo: bool = true) -> void:
	var b := Button.new()
	b.text = texto
	b.disabled = not ativo
	b.custom_minimum_size = Vector2(180, 60)
	b.pressed.connect(acao)
	botoes_escolha.add_child(b)


func _carta_na_escolha(face: Control, acao: Callable) -> void:
	cartas_escolha.add_child(_tocavel(face, acao))


## Responde ao decisor e fecha a janela de escolha.
func _responder(decisor, valor) -> void:
	_fechar_escolha()
	decisor.responder(valor)


func _limpar_acoes() -> void:
	for b in acoes.get_children():
		acoes.remove_child(b)
		b.queue_free()


func _acao(texto: String, acao: Callable, ativo: bool = true, principal: bool = false) -> void:
	var b := Button.new()
	b.text = texto
	b.disabled = not ativo
	b.custom_minimum_size = Vector2(220, 78 if principal else 52)
	if principal:
		b.add_theme_font_size_override("font_size", 26)
		Tema.botao_principal(b)
	else:
		b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(acao)
	acoes.add_child(b)


# --- Narração dos momentos -----------------------------------------------------
# A lógica emite um momento e espera; aqui ele é mostrado com faixa, legenda, sons e
# animação. Um toque na tela adianta a narração.

func _input(evento: InputEvent) -> void:
	if momento_ativo and evento is InputEventMouseButton and not evento.pressed:
		pulando = true


func _esperar(segundos: float) -> void:
	var fim := tempo + segundos
	while tempo < fim and not pulando:
		await get_tree().process_frame


func _ao_mudar_fase(nome: String) -> void:
	for r in rotulos_fase:
		var atual: bool = r.text == nome
		r.add_theme_color_override("font_color", Color(0.66, 0.2, 0.07) if atual else Color(0.55, 0.45, 0.3))
		r.add_theme_font_size_override("font_size", 19 if atual else 16)
		r.add_theme_font_override("font", Tema.fonte_titulo() if atual else Tema.fonte_texto())


func _ao_momento(m: Dictionary) -> void:
	momento_ativo = true
	pulando = false
	var vez := _vez(m.get("jogador", jogador))
	match m["tipo"]:
		"revelacao":
			await _mostrar_revelacao(m["carta"])
		"golpe":
			await _mostrar_golpe(m)
		"contra":
			await _mostrar_contra(m)
		"vitoria":
			_mostrar_danos()
			_atualizar(true)
			sons.tocar("vitoria")
			var por: String = _nome_curto(m["por"]) if m["por"] != null else "Sua equipe"
			_anunciar("VITÓRIA!", "%s%s derrota %s  •  +%d moedas" % [vez, por, m["inimigo"].nome, m["moedas"]], COR_OURO)
			await _esperar(0.5)
			sons.tocar("moeda")
			await _esperar(1.3)
		"derrota_total":
			sons.tocar("derrota")
			_anunciar("DERROTA TOTAL", "%sToda a equipe caiu diante de %s. De volta ao reino inicial." % [vez, m["inimigo"].nome], Color(1, 0.35, 0.3))
			await _esperar(2.2)
		"evento":
			var nome: String = cat.eventos[m["evento"]]["nome"]
			if m["sucesso"]:
				sons.tocar("vitoria")
				_anunciar("EVENTO SUPERADO!", "%s%s  •  +%d moedas, +1 Evento" % [vez, nome, m["moedas"]], Color(0.5, 1, 0.55))
			else:
				sons.tocar("erro")
				_anunciar("Não deu desta vez", "%s%s: sem progresso." % [vez, nome], Color(0.85, 0.85, 0.85))
			_atualizar(true)
			await _esperar(1.5)
		"reino_concluido":
			sons.tocar("vitoria")
			_anunciar("%s CONCLUÍDO!" % m["reino"].to_upper(), "%s%s" % [vez, _texto_avanco(m["por"]).capitalize()], COR_OURO)
			await _esperar(2.2)
		"aviso":
			_anunciar(m["titulo"], m["texto"], Color(0.6, 0.9, 1))
			_atualizar(true)
			await _esperar(1.6)
	_esconder_anuncio()
	momento_ativo = false
	partida.continuar.emit()


func _anunciar(titulo: String, texto: String, cor: Color) -> void:
	faixa.text = titulo
	faixa.add_theme_color_override("font_color", cor)
	faixa.visible = not titulo.is_empty()
	legenda.text = texto
	legenda.visible = not texto.is_empty()
	faixa.scale = Vector2(0.4, 0.4)
	faixa.modulate.a = 0.0
	legenda.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(faixa, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(faixa, "modulate:a", 1.0, 0.2)
	tween.tween_property(legenda, "modulate:a", 1.0, 0.3)


func _esconder_anuncio() -> void:
	faixa.visible = false
	legenda.visible = false


func _legenda(texto: String, cor: Color = Color.WHITE) -> void:
	faixa.visible = false
	legenda.text = texto
	legenda.add_theme_color_override("font_color", cor)
	legenda.visible = true
	legenda.modulate.a = 0.0
	create_tween().tween_property(legenda, "modulate:a", 1.0, 0.15)


func _tremer_camera(forca: float) -> void:
	var tween := create_tween()
	for k in 6:
		tween.tween_property(camera, "h_offset", randf_range(-forca, forca), 0.04)
		tween.parallel().tween_property(camera, "v_offset", randf_range(-forca, forca), 0.04)
	tween.tween_property(camera, "h_offset", 0.0, 0.05)
	tween.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


## A carta revelada aparece grande, com o que ela faz, antes de ir para a mesa.
func _mostrar_revelacao(id: String) -> void:
	sons.tocar("carta")
	for filho in lugar_vitrine.get_children():
		lugar_vitrine.remove_child(filho)
		filho.queue_free()
	var tamanho := Vector2(250, 350)
	var face: Control
	match cat.tipo_de_carta(id):
		"evento":
			titulo_vitrine.text = "Evento!"
			var ev: Dictionary = cat.eventos[id]
			face = _face_texto(ev["nome"], "EVENTO", ev["efeito"], Color(0.12, 0.18, 0.32), Color(0.45, 0.65, 1), tamanho)
		"mercador":
			titulo_vitrine.text = "Um Mercador!"
			face = _face_texto("Mercador", "LOJA", "Revela cinco itens. Compre quantos quiser pelos preços impressos.", Color(0.25, 0.18, 0.06), COR_OURO, tamanho)
		"chefe":
			titulo_vitrine.text = "O CHEFE APARECE!"
			face = _face_inimigo_dados(cat.inimigos[id], tamanho)
		_:
			titulo_vitrine.text = "Um inimigo aparece!"
			face = _face_inimigo_dados(cat.inimigos[id], tamanho)
	lugar_vitrine.add_child(face)
	vitrine.visible = true
	vitrine.modulate.a = 0.0
	face.scale = Vector2(0.3, 0.3)
	var tween := create_tween().set_parallel()
	tween.tween_property(vitrine, "modulate:a", 1.0, 0.2)
	tween.tween_property(face, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	await _esperar(2.2)
	var saida := create_tween()
	saida.tween_property(vitrine, "modulate:a", 0.0, 0.2)
	await saida.finished
	vitrine.visible = false


## Inimigo a partir dos dados do catálogo (antes de o combate começar), com o efeito.
func _face_inimigo_dados(dados: Dictionary, tamanho: Vector2) -> PanelContainer:
	var e := tamanho.x / 140.0
	var painel := _corpo_carta(tamanho, Color(0.2, 0.07, 0.05), Color(0.85, 0.25, 0.18), int(5 * e))
	var coluna: VBoxContainer = painel.get_child(0)
	coluna.add_child(_titulo_carta(str(int(dados["ameaca"])), COR_OURO, Color.BLACK, dados["nome"], e))
	var texto := "%s: %s" % [dados["habilidade"], dados["efeito"]]
	coluna.add_child(_janela_arte(null, "", texto, tamanho.x - 2 * int(10 * e), e))
	var tipo := _texto("Ameaça %d • %s" % [int(dados["ameaca"]), str(dados["tipo"]).capitalize()], int(11 * e), Color(1, 0.85, 0.6))
	tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(tipo)
	coluna.add_child(_linha_atributos(int(dados["forca"]), int(dados["armadura_maxima"]), "", Color.WHITE, e))
	return painel



func _mostrar_golpe(m: Dictionary) -> void:
	var c = m["de"]
	var dano: int = m["dano"]
	var face_dado: int = m["face"]
	_mostrar_danos()
	_atualizar(true)
	if dano <= 0:
		sons.tocar("erro")
		_legenda("%s errou o golpe!" % _nome_curto(c), Color(0.8, 0.8, 0.8))
	elif face_dado == 6:
		sons.tocar("critico")
		_tremer_camera(0.12)
		_anunciar("CRÍTICO!", "%s acerta %s: %d de dano!" % [_nome_curto(c), m["em"].nome, dano], Color(1, 0.55, 0.2))
	else:
		sons.tocar("golpe")
		_legenda("%s acerta %s: %d de dano!" % [_nome_curto(c), m["em"].nome, dano], Color(1, 0.95, 0.75))
	await _esperar(1.2)


func _mostrar_contra(m: Dictionary) -> void:
	var ini = m["de"]
	var alvo = m["em"]
	if m["falhou"]:
		sons.tocar("erro")
		_legenda("Escorregão Tático! %s erra o ataque." % ini.nome, Color(0.6, 1, 0.6))
		await _esperar(1.3)
		return
	# O inimigo avança sobre quem ele ataca.
	var no_alvo = cartas_3d.get(_chave(alvo))
	if figura_inimigo != null and no_alvo != null:
		var origem: Vector3 = figura_inimigo.position
		var destino: Vector3 = origem.lerp(no_alvo.position, 0.6) + Vector3(0, 0.3, 0)
		var tween := create_tween()
		tween.tween_property(figura_inimigo, "position", destino, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(figura_inimigo, "position", origem, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(0.2).timeout
	var dano: int = m["dano"]
	_mostrar_danos()
	_atualizar(true)
	var texto: String
	if m["roubo"]:
		sons.tocar("moeda")
		texto = "%s roubam até %d moedas!" % [ini.nome, dano]
	elif dano <= 0:
		sons.tocar("erro")
		texto = "%s ataca %s e erra!" % [ini.nome, _nome_curto(alvo)]
	else:
		sons.tocar("golpe")
		texto = "%s ataca %s: %d de dano!" % [ini.nome, _nome_curto(alvo), dano]
	if m["derrotado"]:
		sons.tocar("derrota")
		_anunciar("%s caiu!" % _nome_curto(alvo), texto, Color(1, 0.4, 0.35))
	else:
		_legenda(texto, Color(1, 0.75, 0.7))
	await _esperar(1.4 if m["derrotado"] else 1.2)


# --- Janela do dado ------------------------------------------------------------
# O jogo entrega o dado; o jogador arrasta e solta (ou toca em "Jogar!"). O valor
# é sorteado pela lógica no momento do lançamento e a janela só o mostra.

const PINTAS := {1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8]}


func _face_dado(n: int) -> PanelContainer:
	var face := PanelContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.custom_minimum_size = Vector2(140, 140)
	face.add_theme_stylebox_override("panel", _estilo(Color(0.98, 0.96, 0.9), Color(0.55, 0.45, 0.3), 5, 26, 16))
	var grade := GridContainer.new()
	grade.columns = 3
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	face.add_child(grade)
	for i in 9:
		var pinta := PanelContainer.new()
		pinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pinta.custom_minimum_size = Vector2(28, 28)
		var cor := Color(0.12, 0.1, 0.1) if PINTAS[n].has(i) else Color(0, 0, 0, 0)
		pinta.add_theme_stylebox_override("panel", _estilo(cor, cor, 0, 20, 0))
		grade.add_child(pinta)
	return face


func _desenhar_dado(n: int) -> void:
	for filho in dado_visual.get_children():
		dado_visual.remove_child(filho)
		filho.queue_free()
	dado_visual.add_child(_face_dado(n))


func _centro_dado() -> Vector2:
	return (area_dado.custom_minimum_size - dado_visual.size) / 2


func _abrir_dado(titulo: String, do_jogador: bool) -> void:
	titulo_dado.text = titulo
	resultado_dado.text = "Arraste e solte o dado, ou toque em Jogar!" if do_jogador else ""
	botao_jogar.visible = do_jogador
	botao_jogar.disabled = not do_jogador
	dado_visual.position = _centro_dado()
	dado_visual.rotation = 0
	dado_visual.scale = Vector2.ONE
	_desenhar_dado(randi_range(1, 6))
	camada_dado.visible = true


func _ao_tocar_dado(evento: InputEvent) -> void:
	if not dado_aguardando:
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		arrastando_dado = evento.pressed
		if not evento.pressed:
			_lancar_dado()
	elif evento is InputEventMouseMotion and arrastando_dado:
		dado_visual.position += evento.relative
		dado_visual.rotation += evento.relative.x * 0.01


## O jogador lança: o dado gira e a lógica sorteia o valor.
func _lancar_dado() -> void:
	if not dado_aguardando:
		return
	dado_aguardando = false
	arrastando_dado = false
	botao_jogar.disabled = true
	resultado_dado.text = ""
	var tween := create_tween()
	tween.tween_property(dado_visual, "position", _centro_dado(), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_iniciar_giro()
	sons.tocar("dado")
	decisor_atual.responder(null)


func _iniciar_giro() -> void:
	girando = true
	face_pendente = 0
	_girar()


func _girar() -> void:
	var inicio := tempo
	while face_pendente == 0 or tempo - inicio < 0.75:
		_desenhar_dado(randi_range(1, 6))
		dado_visual.rotation = randf_range(-0.6, 0.6)
		await get_tree().create_timer(0.06).timeout
	dado_visual.rotation = 0
	_desenhar_dado(face_pendente)
	dado_visual.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(dado_visual, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	girando = false


## A lógica sorteou: o dado para nesse número e a janela fecha.
func _ao_dado_mostrado(motivo: String, face: int, do_jogador: bool) -> void:
	if not do_jogador:
		_abrir_dado(_motivo_legivel(motivo), false)
		_iniciar_giro()
		sons.tocar("dado")
	elif not girando:
		_iniciar_giro()
	face_pendente = face
	while girando:
		await get_tree().process_frame
	resultado_dado.text = _significado_do_dado(motivo, face)
	await get_tree().create_timer(1.0 if do_jogador else 0.7).timeout
	camada_dado.visible = false
	partida.continuar.emit()


func _significado_do_dado(motivo: String, face: int) -> String:
	if motivo.begins_with("ataque_") or motivo.begins_with("contra_ataque_") or motivo.begins_with("ataque_rival_"):
		match face:
			1:
				return "1 — Errou o golpe!"
			2:
				return "2 — Golpe de raspão (1 de dano)"
			3:
				return "3 — Meio acerto (metade da Força)"
			4, 5:
				return "%d — Acerto completo!" % face
			6:
				return "6 — Acerto crítico! (dobro da Força)"
	return "Tirou %d" % face


# --- Preparação da partida (manual §4) -----------------------------------------
# Reino inicial, 6 moedas, 5 Cavaleiros, mulligan, 3 em campo de graça e fila por
# Honra (o dono decide empates). Com vários jogadores, o maior D6 começa.

func _preparar_proximo_jogador() -> void:
	if indice_preparo >= partida.jogadores.size():
		_tela_iniciativa()
		return
	jogador = partida.jogadores[indice_preparo]
	modo = ""
	pendentes.clear()
	selecionados.clear()
	_limpar_acoes()
	rotulo_dica.text = ""
	_atualizar(false)
	_abrir_escolha("%sescolha o reino inicial. Você começa com %d moedas." % [_vez(jogador), jogador.moedas])
	for r in cat.circuito:
		var tem_cartas: bool = not partida.baralhos_reino[r].is_empty()
		_botao_escolha(r if tem_cartas else "%s (em breve)" % r, _escolher_reino_inicial.bind(r), tem_cartas)


func _escolher_reino_inicial(reino: String) -> void:
	partida.definir_reino_inicial(jogador, reino)
	partida.comprar_mao_inicial(jogador)
	selecionados.clear()
	_tela_mulligan()


func _tela_mulligan() -> void:
	_atualizar(false)
	_abrir_escolha("%sSua mão inicial. Toque nas cartas que quer trocar (mulligan). Pode repetir quantas vezes quiser." % _vez(jogador))
	for c in jogador.mao:
		_carta_na_escolha(_face_cavaleiro(c, TAM_ESCOLHA, "marcada" if selecionados.has(c) else ""), _alternar_mulligan.bind(c))
	_botao_escolha("Trocar %d marcada%s" % [selecionados.size(), "" if selecionados.size() == 1 else "s"], _trocar_marcadas, not selecionados.is_empty())
	_botao_escolha("Manter mão", _tela_iniciais)


func _alternar_mulligan(c) -> void:
	if selecionados.has(c):
		selecionados.erase(c)
	else:
		selecionados.append(c)
	_tela_mulligan()


func _trocar_marcadas() -> void:
	partida.fazer_mulligan(jogador, selecionados.duplicate())
	selecionados.clear()
	_tela_mulligan()


func _tela_iniciais() -> void:
	_fechar_escolha()
	modo = "iniciais"
	pendentes.clear()
	_atualizar(true)
	_dica_iniciais()


func _dica_iniciais() -> void:
	var faltam := mini(3, jogador.mao.size()) - pendentes.size()
	var inicio := "Derrota total! " if modo == "reerguer" else ""
	rotulo_dica.text = "%s%sArraste %d Cavaleiro%s da mão para as vagas da mesa. Entram de graça." % [_vez(jogador), inicio, faltam, "" if faltam == 1 else "s"]


func _concluir_iniciais(escolhidos: Array) -> void:
	modo = ""
	rotulo_dica.text = ""
	await partida.colocar_iniciais(jogador, escolhidos)
	_atualizar(true)
	indice_preparo += 1
	_preparar_proximo_jogador()


func _tela_iniciativa() -> void:
	if partida.jogadores.size() == 1:
		_comecar_turno()
		return
	_abrir_escolha("Todos rolam o D6. O maior resultado começa; empates rolam de novo.")
	_botao_escolha("Rolar o D6", _rolar_iniciativa)


func _rolar_iniciativa() -> void:
	_fechar_escolha()
	await partida.definir_ordem_de_turno()
	var rolagens: Array = partida.dado.registro.filter(func(r): return r["motivo"].begins_with("iniciativa_"))
	var texto := ", ".join(rolagens.map(func(r): return "Jogador %s tirou %d" % [r["motivo"].substr(12), r["face"]]))
	_abrir_escolha("%s.\n%s começa!" % [texto, _nome(partida.jogadores[0])])
	_botao_escolha("Começar", _comecar_turno)


# --- Turno ------------------------------------------------------------------------

func _comecar_turno() -> void:
	_fechar_escolha()
	jogador = partida.jogadores[indice_turno]
	modo = ""
	_limpar_acoes()
	_atualizar(false)
	var avancou: bool = await partida.iniciar_turno(jogador)
	if avancou or partida.playtest_encerrado:
		_tela_final()
		return
	_tela_preparacao()


func _tela_preparacao() -> void:
	modo = "preparacao"
	_atualizar(true)
	rotulo_dica.text = "%sArraste Cavaleiros da mão para a mesa ou equipe itens. Quando estiver pronto, explore o reino." % _vez(jogador)
	_limpar_acoes()
	_acao("Explorar o reino", _explorar, true, true)
	_acao("Comprar Cavaleiro (1)", _comprar_cavaleiro, not jogador.comprou_cavaleiro_no_turno and jogador.moedas >= 1)
	var tem_itens: bool = not partida.baralho_itens.is_empty() or not partida.descarte_itens.is_empty()
	_acao("Compra às cegas (4)", _comprar_as_cegas, not jogador.comprou_as_cegas_no_turno and jogador.moedas >= 4 and tem_itens)


func _comprar_cavaleiro() -> void:
	partida.comprar_cavaleiro(jogador)
	_tela_preparacao()


func _comprar_as_cegas() -> void:
	partida.comprar_as_cegas(jogador)
	_tela_preparacao()


func _escolher_portador(item: Dictionary) -> void:
	_abrir_escolha("Quem vai equipar %s?\n%s: %s" % [item["nome"], item["categoria"], item["efeito"]])
	for c in jogador.fila + jogador.mao:
		_carta_na_escolha(_face_cavaleiro(c, TAM_ESCOLHA), _equipar.bind(c, item))
	_botao_escolha("Cancelar", _fechar_escolha)


func _equipar(c, item: Dictionary) -> void:
	_fechar_escolha()
	partida.equipar_item(jogador, c.id_instancia, item["id"])
	_tela_preparacao()


func _explorar() -> void:
	modo = ""
	_limpar_acoes()
	rotulo_dica.text = ""
	_atualizar(false)
	var moedas_antes: int = jogador.moedas
	await partida.explorar_e_resolver(jogador)
	_fechar_escolha()
	modo = ""
	_atualizar(true)
	if partida.playtest_encerrado:
		_tela_final()
		return
	var saldo: int = jogador.moedas - moedas_antes
	rotulo_dica.text = "%sFim do turno: %s%d moedas. Toque nas cartas para ver detalhes." % [_vez(jogador), "+" if saldo >= 0 else "", saldo]
	_limpar_acoes()
	if partida.jogadores.size() == 1:
		_acao("Próximo turno", _proximo_turno, true, true)
	else:
		var proximo = partida.jogadores[(indice_turno + 1) % partida.jogadores.size()]
		_acao("Passar para %s" % _nome(proximo), _proximo_turno, true, true)


func _proximo_turno() -> void:
	indice_turno = (indice_turno + 1) % partida.jogadores.size()
	_comecar_turno()


func _tela_final() -> void:
	modo = ""
	_limpar_acoes()
	rotulo_dica.text = ""
	var r: Dictionary = partida.relatorio
	_abrir_escolha("Playtest concluído! %sconcluiu %s (%s) e chegou a %s com %d moedas." % [
		_vez(jogador), r.get("reino_concluido", "o Pântano"), _texto_avanco(r.get("avanco_por", "")), jogador.reino_atual, jogador.moedas])
	_botao_escolha("Jogar de novo", nova_partida)
	_botao_escolha("Menu", _ir_ao_menu)


func _texto_avanco(por: String) -> String:
	match por:
		"quatro_inimigos":
			return "4 inimigos derrotados"
		"tres_eventos":
			return "3 Eventos superados"
		"chefe_derrotado":
			return "chefe derrotado"
	return por


# --- Perguntas durante a resolução ---------------------------------------------
# A opção mais segura de cada janela é sempre o último botão.

func _ao_pedido(tipo: String, dados: Dictionary, decisor) -> void:
	var quem = dados["jogador"]
	var vez := _vez(quem)
	decisor_atual = decisor
	modo = ""
	_atualizar(true)
	match tipo:
		"lancar_dado":
			dado_aguardando = true
			_abrir_dado("%sSua vez de jogar o dado!\n%s" % [vez, _motivo_legivel(dados["motivo"])], true)
		"ataque":
			modo = "ataque"
			opcoes_ataque = dados["opcoes"]
			atacante_escolhido = opcoes_ataque[0]
			_dica_ataque()
			_atualizar(true)
		"iniciais":
			modo = "reerguer"
			pendentes.clear()
			_atualizar(true)
			_dica_iniciais()
		"mercador":
			selecionados.clear()
			_tela_mercador(decisor, quem, dados["oferta"])
		"reposicao":
			_abrir_escolha("%sReposição: escolha quem entra em campo pagando o custo. A outra carta vai ao Cemitério. Você tem %d moedas." % [vez, quem.moedas])
			for c in dados["reveladas"]:
				var pode: bool = dados["pagaveis"].has(c)
				var acao: Callable = _responder.bind(decisor, c) if pode else Callable()
				_carta_na_escolha(_face_cavaleiro(c, TAM_ESCOLHA, "" if pode else "apagada"), acao)
		"cavaleiro_evento":
			var ev: Dictionary = cat.eventos[dados["evento"]]
			_abrir_escolha("%s%s\n%s\n\nEscolha o Cavaleiro." % [vez, ev["nome"], ev["efeito"]])
			for c in quem.fila:
				_carta_na_escolha(_face_cavaleiro(c, TAM_ESCOLHA), _responder.bind(decisor, c.id_instancia))
		"descarte":
			var ev: Dictionary = cat.eventos[dados["evento"]]
			_abrir_escolha(vez + dados.get("texto", "%s\n%s\n\nToque numa carta da mão para descartá-la." % [ev["nome"], ev["efeito"]]))
			for c in quem.mao:
				_carta_na_escolha(_face_cavaleiro(c, TAM_ESCOLHA), _responder.bind(decisor, c.id_instancia))
			for item in quem.itens_mao:
				_carta_na_escolha(_face_item(item, TAM_ESCOLHA), _responder.bind(decisor, item["id"]))
			_botao_escolha(dados["recusa"], _responder.bind(decisor, null))
		"empate":
			_tela_empate(decisor, quem, dados["grupo"], [])
		"conversao":
			_abrir_escolha("%sReino concluído! Converta o Prestígio dos Cavaleiros em campo." % vez)
			_botao_escolha("Status permanente", _responder.bind(decisor, "status"))
			_botao_escolha("Moedas (+%d)" % dados["total"], _responder.bind(decisor, "moedas"))
		"status":
			var c = dados["cavaleiro"]
			var p: int = c.prestigio()
			_abrir_escolha("%s%s tem %d de Prestígio. Onde aplicar os pontos?" % [vez, c.nome, p])
			_botao_escolha("+%d Armadura máxima" % p, _responder.bind(decisor, {"forca": 0, "armadura": p, "honra": 0}))
			_botao_escolha("+%d Honra" % p, _responder.bind(decisor, {"forca": 0, "armadura": 0, "honra": p}))
			_botao_escolha("+%d Força" % p, _responder.bind(decisor, {"forca": p, "armadura": 0, "honra": 0}))
		"reino":
			_abrir_escolha("%sChefe derrotado! Escolha o próximo reino." % vez)
			for r in dados["permitidos"]:
				_botao_escolha(r, _responder.bind(decisor, r))
		_:
			decisor.responder(null)


## Empate de Honra: o dono toca os Cavaleiros na ordem em que quer que fiquem.
func _tela_empate(decisor, quem, grupo: Array, escolhidos: Array) -> void:
	if escolhidos.size() == grupo.size():
		_responder(decisor, escolhidos)
		return
	var texto := "%sEmpate de Honra (%d). Toque os Cavaleiros na ordem em que devem ficar na fila." % [_vez(quem), grupo[0].honra()]
	if not escolhidos.is_empty():
		texto += "\nOrdem até agora: %s." % ", ".join(escolhidos.map(func(c): return _nome_curto(c)))
	_abrir_escolha(texto)
	for c in grupo:
		if not escolhidos.has(c):
			_carta_na_escolha(_face_cavaleiro(c, TAM_ESCOLHA), _tela_empate.bind(decisor, quem, grupo, escolhidos + [c]))
	if escolhidos.is_empty():
		_botao_escolha("Manter ordem atual", _responder.bind(decisor, grupo))


func _tela_mercador(decisor, quem, oferta: Array) -> void:
	var total := 0
	for item in selecionados:
		total += int(item["preco_mercador"])
	_abrir_escolha("%sMercador! Toque nos itens que quer comprar. Você tem %d moedas." % [_vez(quem), quem.moedas])
	for item in oferta:
		_carta_na_escolha(_face_item(item, TAM_ESCOLHA, "marcada" if selecionados.has(item) else ""), _alternar_item.bind(decisor, quem, oferta, item))
	_botao_escolha("Comprar (%d moedas)" % total, _confirmar_mercador.bind(decisor), not selecionados.is_empty() and total <= quem.moedas)
	_botao_escolha("Não comprar nada", _responder.bind(decisor, []))


func _alternar_item(decisor, quem, oferta: Array, item: Dictionary) -> void:
	if selecionados.has(item):
		selecionados.erase(item)
	else:
		selecionados.append(item)
	_tela_mercador(decisor, quem, oferta)


func _confirmar_mercador(decisor) -> void:
	var ids: Array = selecionados.map(func(i): return i["id"])
	selecionados.clear()
	_responder(decisor, ids)
