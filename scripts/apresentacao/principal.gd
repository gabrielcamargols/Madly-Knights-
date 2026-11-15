extends Node3D
## Mesa jogável do playtest no Pântano Maluco, no estilo dos jogos de cartas digitais.
## Só lê o estado da partida e mostra os resultados que a lógica devolveu;
## não decide regras nem rola dados. A arte das cartas é provisória.
##
## Mesa (3D, em perspectiva): o encontro no topo, as 6 vagas da sua fila embaixo dele,
## baralho do reino e Cemitério à esquerda. As cartas da mesa são as mesmas cartas
## desenhadas da mão, renderizadas sobre o tabuleiro.
## Mão (2D) embaixo; arraste uma carta para a mesa para jogá-la.
## Escolhas aparecem no centro da tela com as cartas grandes. Ações ficam à direita.

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")
const DecisorInterface = preload("res://scripts/apresentacao/decisor_interface.gd")
const Sessao = preload("res://scripts/apresentacao/sessao.gd")
const Regras = preload("res://scripts/core/regras.gd")

# Mesa (unidades do mundo)
const TAM_CARTA_3D := Vector2(1.1, 1.54)
const ESPACO_VAGA := 1.3
const VAGAS := 6
const POS_FILA_Z := 0.35
const POS_ENCONTRO := Vector3(0.0, 0.0, -1.85)
const ESCALA_ENCONTRO := 1.45
const POS_REINO := Vector3(-5.0, 0.0, -1.7)
const POS_CEMITERIO := Vector3(-5.0, 0.0, 0.35)
const POS_ENTRADA := Vector3(0.0, 0.0, 3.6)
const PIXELS_CARTA := Vector2i(280, 392)  # textura de cada carta da mesa

# Cartas 2D (pixels da tela-base de 1280×720)
const TAM_MAO := Vector2(124, 174)
const TAM_ESCOLHA := Vector2(170, 238)

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
var rotulo_dado: Label


func _ready() -> void:
	_criar_ambiente()
	_criar_interface()
	get_viewport().size_changed.connect(_ajustar_camera)
	_ajustar_camera()
	cat = Catalogo.new()
	if not cat.carregar():
		rotulo_dica.text = "Erro ao carregar os dados do jogo."
		return
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
	luz.rotation_degrees = Vector3(-60, 30, 0)
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	ambiente.environment = env
	add_child(ambiente)
	# Tabuleiro: madeira com um feltro verde de pântano no centro.
	_plano(Vector2(15, 10), Vector3(0, -0.06, -0.4), Color(0.3, 0.2, 0.12))
	_plano(Vector2(9.0, 6.4), Vector3(0.6, -0.05, -0.75), Color(0.16, 0.26, 0.18))
	_plano(Vector2(9.0, 0.06), Vector3(0.6, -0.04, -0.62), COR_OURO.darkened(0.3))
	# Vagas da fila.
	for i in VAGAS:
		var vaga := _plano(TAM_CARTA_3D * 1.06, _pos_vaga(i) + Vector3(0, 0.01, 0), Color(0.09, 0.14, 0.1))
		vaga.name = "Vaga%d" % i
	var marca := Label3D.new()
	marca.text = "ataca primeiro"
	marca.font_size = 34
	marca.pixel_size = 0.005
	marca.rotation_degrees.x = -90
	marca.modulate = COR_OURO
	marca.position = _pos_vaga(0) + Vector3(0, 0.02, 0.98)
	add_child(marca)


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
	return Vector3((i - (VAGAS - 1) / 2.0) * ESPACO_VAGA + 0.6, 0.0, POS_FILA_Z)


## Na horizontal a altura da mesa cabe na tela; na vertical, a largura.
func _ajustar_camera() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	if tamanho.x >= tamanho.y:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 44
		camera.look_at_from_position(Vector3(0.3, 8.6, 4.6), Vector3(0.3, 0, 0.15))
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 72
		camera.look_at_from_position(Vector3(0, 9.5, 6.0), Vector3(0, 0, 1.4))


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
	face.custom_minimum_size = Vector2(PIXELS_CARTA)
	face.size = Vector2(PIXELS_CARTA)
	vp.add_child(face)


func _chave(c) -> String:
	return "%s/%s" % [jogador.id, c.id_instancia]


func _atualizar(animar: bool) -> void:
	if jogador == null:
		return
	var em_campo: Array = jogador.fila + pendentes
	var destinos := {}
	for i in em_campo.size():
		var c = em_campo[i]
		var altura := 0.35 if (modo == "ataque" and c == atacante_escolhido) else 0.0
		destinos[c] = _pos_vaga(i) + Vector3(0, altura + 0.03, 0)
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
			var nova := _criar_carta_3d()
			nova.position = POS_ENTRADA
			cartas_3d[chave] = nova
		objetos_3d[chave] = c
		var carta: Node3D = cartas_3d[chave]
		if not carta.visible:
			carta.position = POS_ENTRADA
			carta.visible = true
		var estado := ""
		if modo == "ataque" and opcoes_ataque.has(c):
			estado = "destaque" if c == atacante_escolhido else "opcao"
		_desenhar(carta, _face_cavaleiro(c, Vector2(PIXELS_CARTA), estado))
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
	_atualizar_mao()
	var itens := "nenhum"
	if not jogador.itens_mao.is_empty():
		itens = ", ".join(jogador.itens_mao.map(func(i): return i["nome"]))
	rotulo_status.text = "%s%s   •   Moedas %d   •   Inimigos %d/4   •   Eventos %d/3   •   Itens: %s" % [
		_vez(jogador), jogador.reino_atual, jogador.moedas, jogador.inimigos, jogador.eventos, itens]


func _ao_revelar(carta_id: String) -> void:
	carta_revelada = carta_id
	armaduras_vistas.clear()
	_desenhar(carta_encontro, _face_encontro(Vector2(PIXELS_CARTA)))
	var tween := create_tween()
	carta_encontro.scale = Vector3(0.2, 1, 0.2)
	tween.tween_property(carta_encontro, "scale", Vector3(ESCALA_ENCONTRO, 1, ESCALA_ENCONTRO), 0.35).set_trans(Tween.TRANS_BACK)


## Chamado pela lógica entre os golpes: mostra o dano e espera um pouco.
func _ritmo_do_combate() -> void:
	_mostrar_danos()
	_atualizar(true)
	await get_tree().create_timer(0.8).timeout
	partida.continuar.emit()


func _mostrar_danos() -> void:
	var ini = partida.inimigo_atual
	if ini != null:
		var antes: int = armaduras_vistas.get("inimigo", ini.armadura_atual)
		if ini.armadura_atual != antes:
			_numero_flutuante(carta_encontro.position + Vector3(0, 0.6, 0), ini.armadura_atual - antes)
		armaduras_vistas["inimigo"] = ini.armadura_atual
	for c in jogador.fila + jogador.cemiterio:
		var chave := _chave(c)
		var antes: int = armaduras_vistas.get(chave, c.armadura_atual)
		var agora: int = c.armadura_atual if jogador.fila.has(c) else 0
		if agora != antes and cartas_3d.has(chave):
			_numero_flutuante(cartas_3d[chave].position + Vector3(0, 0.6, 0), agora - antes)
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
	var borda := cor.darkened(0.25)
	var espessura := int(4 * e)
	match estado:
		"marcada":
			borda = Color(1, 0.3, 0.25)
			espessura = int(7 * e)
		"destaque":
			borda = Color(0.4, 1, 0.5)
			espessura = int(8 * e)
		"opcao":
			borda = Color(0.4, 0.85, 1)
			espessura = int(6 * e)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = tamanho
	painel.pivot_offset = tamanho / 2
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.1, 0.08, 0.07), borda, espessura, int(14 * e), espessura))
	if estado == "apagada" or estado == "caido":
		painel.modulate = Color(0.5, 0.5, 0.5)
	# Fundo: a ilustração aprovada ou, enquanto não houver, a cor e a inicial.
	var textura := _textura_arte(c.id_carta)
	if textura != null:
		painel.add_child(_ilustracao(textura, e))
	else:
		painel.add_child(_arte(cor, _nome_curto(c).left(1), 0, e))
	# Por cima: custo e nome no topo, habilidade e atributos embaixo.
	var coluna := _ignorar_mouse(VBoxContainer.new())
	coluna.add_theme_constant_override("separation", int(2 * e))
	painel.add_child(coluna)
	var faixa_topo := _faixa(e)
	coluna.add_child(faixa_topo)
	var topo := _ignorar_mouse(HBoxContainer.new())
	topo.add_theme_constant_override("separation", int(4 * e))
	faixa_topo.add_child(topo)
	topo.add_child(_medalhao(str(c.custo()), Color(0.2, 0.42, 0.85), e * 0.75))
	var nome := _texto(_nome_curto(c), int(15 * e), Color.WHITE, int(4 * e))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(nome)
	var espaco := _ignorar_mouse(Control.new())
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(espaco)
	var faixa_base := _faixa(e, 0.68)
	coluna.add_child(faixa_base)
	var coluna_base := _ignorar_mouse(VBoxContainer.new())
	coluna_base.add_theme_constant_override("separation", 0)
	faixa_base.add_child(coluna_base)
	if c.habilidade != "":
		var hab := _texto(c.habilidade, int(11 * e), Color(1, 0.9, 0.65), int(3 * e))
		hab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coluna_base.add_child(hab)
	var base := _ignorar_mouse(HBoxContainer.new())
	coluna_base.add_child(base)
	base.add_child(_medalhao(str(c.forca_total()), COR_FORCA, e))
	var honra := _texto("Honra %d" % c.honra(), int(12 * e), Color(0.92, 0.92, 0.92), int(3 * e))
	honra.autowrap_mode = TextServer.AUTOWRAP_OFF
	honra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	honra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	honra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base.add_child(honra)
	var ferido: bool = c.armadura_atual < c.armadura_maxima()
	base.add_child(_medalhao(str(c.armadura_atual), COR_ARMADURA, e, Color(1, 0.55, 0.5) if ferido else Color.WHITE))
	return painel


func _face_item(item: Dictionary, tamanho: Vector2, estado: String = "") -> PanelContainer:
	var e := tamanho.x / 140.0
	var borda := Color(0.4, 1, 0.5) if estado == "marcada" else Color(0.45, 0.5, 0.75)
	var painel := _moldura(Color(0.12, 0.13, 0.2), borda, tamanho, int((7 if estado == "marcada" else 4) * e))
	if estado == "apagada":
		painel.modulate = Color(0.5, 0.5, 0.5)
	var coluna := _ignorar_mouse(VBoxContainer.new())
	coluna.add_theme_constant_override("separation", int(3 * e))
	painel.add_child(coluna)
	var topo := _ignorar_mouse(HBoxContainer.new())
	coluna.add_child(topo)
	topo.add_child(_medalhao(str(int(item["preco_mercador"])), COR_OURO.darkened(0.15), e * 0.8, Color.BLACK))
	var nome := _texto(item["nome"], int(14 * e), Color.WHITE, int(4 * e))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(nome)
	coluna.add_child(_texto("%s • %s" % [item["categoria"], item["raridade"]], int(11 * e), Color(0.7, 0.75, 1)))
	coluna.add_child(_texto(item["efeito"], int(10.5 * e), Color(0.92, 0.92, 0.92)))
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
	var painel := _moldura(fundo, borda, tamanho, int(5 * e))
	var coluna := _ignorar_mouse(VBoxContainer.new())
	coluna.add_theme_constant_override("separation", int(4 * e))
	painel.add_child(coluna)
	var nome := _texto(titulo, int(15 * e), Color.WHITE, int(4 * e))
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(nome)
	var marca := _texto(selo, int(12 * e), borda)
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(marca)
	var texto := _texto(corpo, int(11 * e), Color(0.9, 0.9, 0.9))
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(texto)
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
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 4.0
		carta.set_drag_forwarding(_arrastar_da_mao.bind(c), Callable(), Callable())
		mao_2d.add_child(carta)
		i += 1
	for item in jogador.itens_mao:
		var carta := _face_item(item, TAM_MAO)
		_tocavel(carta, _tocar_item.bind(item))
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 4.0
		mao_2d.add_child(carta)
		i += 1


func _tocar_item(item: Dictionary) -> void:
	if modo == "preparacao":
		_escolher_portador(item)
	else:
		_mostrar_detalhes("[b]%s[/b]  (%s, %s)\n\n%s" % [item["nome"], item["categoria"], item["raridade"], item["efeito"]])


func _arrastar_da_mao(_posicao: Vector2, c) -> Variant:
	if not _pode_jogar(c):
		return null
	var previa := _face_cavaleiro(c, TAM_MAO, "destaque")
	previa.modulate.a = 0.9
	var suporte := Control.new()
	suporte.add_child(previa)
	previa.position = -TAM_MAO / 2
	mao_2d.set_drag_preview(suporte)
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
	elif qual == NOTIFICATION_DRAG_END:
		zona_mesa.visible = false


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
	if _sob(ponto, carta_encontro, ESCALA_ENCONTRO):
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
	_mostrar_detalhes(texto)


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


func _mostrar_detalhes(texto: String) -> void:
	texto_detalhes.text = texto
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
	var tema := Theme.new()
	tema.default_font_size = 22
	raiz.theme = tema
	camada.add_child(raiz)

	# Área de soltar: cobre a mesa e só aparece enquanto uma carta é arrastada.
	zona_mesa = Control.new()
	raiz.add_child(zona_mesa)
	zona_mesa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zona_mesa.visible = false
	zona_mesa.set_drag_forwarding(Callable(), _pode_soltar, _soltar)

	# Topo: menu, registro e situação do jogador.
	var topo := PanelContainer.new()
	raiz.add_child(topo)
	topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topo.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.05, 0.05, 0.75), Color(0, 0, 0, 0), 0, 0, 4))
	var linha_topo := HBoxContainer.new()
	topo.add_child(linha_topo)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(96, 44)
	menu.pressed.connect(_ir_ao_menu)
	linha_topo.add_child(menu)
	var botao_registro := Button.new()
	botao_registro.text = "Registro"
	botao_registro.custom_minimum_size = Vector2(120, 44)
	botao_registro.pressed.connect(_alternar_registro)
	linha_topo.add_child(botao_registro)
	rotulo_status = Label.new()
	rotulo_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo_status.add_theme_font_size_override("font_size", 19)
	linha_topo.add_child(rotulo_status)

	# Dica do momento, logo abaixo do topo.
	rotulo_dica = Label.new()
	raiz.add_child(rotulo_dica)
	rotulo_dica.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rotulo_dica.offset_top = 54
	rotulo_dica.offset_bottom = 110
	rotulo_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo_dica.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	rotulo_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo_dica.add_theme_constant_override("outline_size", 8)
	rotulo_dica.add_theme_font_size_override("font_size", 23)

	# Mão: embaixo, no centro, saindo um pouco pela borda como nos jogos de cartas.
	mao_2d = HBoxContainer.new()
	raiz.add_child(mao_2d)
	mao_2d.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	mao_2d.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mao_2d.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mao_2d.offset_bottom = 30
	mao_2d.alignment = BoxContainer.ALIGNMENT_CENTER
	mao_2d.add_theme_constant_override("separation", -14)

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
	registro = RichTextLabel.new()
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 17)
	painel_registro.add_child(registro)
	painel_registro.visible = false

	# Escolhas: no centro da tela, com o fundo escurecido. O CenterContainer mantém
	# a janela centralizada qualquer que seja o tamanho do conteúdo.
	camada_escolha = _camada_central(raiz)
	escolha = PanelContainer.new()
	escolha.add_theme_stylebox_override("panel", _estilo(Color(0.1, 0.09, 0.08, 0.97), COR_OURO, 3, 16, 18))
	camada_escolha.get_child(1).add_child(escolha)
	var coluna_escolha := VBoxContainer.new()
	coluna_escolha.add_theme_constant_override("separation", 14)
	escolha.add_child(coluna_escolha)
	titulo_escolha = Label.new()
	titulo_escolha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_escolha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_escolha.custom_minimum_size = Vector2(980, 0)
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

	# Detalhes de uma carta, também centralizados.
	camada_detalhes = _camada_central(raiz)
	var detalhes := PanelContainer.new()
	detalhes.add_theme_stylebox_override("panel", _estilo(Color(0.1, 0.1, 0.12, 0.97), COR_OURO, 3, 16, 18))
	camada_detalhes.get_child(1).add_child(detalhes)
	var coluna_detalhes := VBoxContainer.new()
	detalhes.add_child(coluna_detalhes)
	texto_detalhes = RichTextLabel.new()
	texto_detalhes.bbcode_enabled = true
	texto_detalhes.fit_content = true
	texto_detalhes.custom_minimum_size = Vector2(620, 0)
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
	b.custom_minimum_size = Vector2(230, 84 if principal else 58)
	if principal:
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", _estilo(Color(0.2, 0.5, 0.25), Color(0.6, 1, 0.6)))
		b.add_theme_stylebox_override("hover", _estilo(Color(0.25, 0.6, 0.3), Color(0.7, 1, 0.7)))
		b.add_theme_stylebox_override("pressed", _estilo(Color(0.15, 0.4, 0.2), Color(0.6, 1, 0.6)))
	b.pressed.connect(acao)
	acoes.add_child(b)


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
	partida.definir_ordem_de_turno()
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
	rotulo_dica.text = "%sPreparação: arraste Cavaleiros da mão para a mesa, toque num item para equipar. Depois explore." % _vez(jogador)
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
