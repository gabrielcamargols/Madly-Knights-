extends Node3D
## Mesa jogável do playtest no Pântano Maluco.
## Só lê o estado da partida e mostra os resultados que a lógica devolveu;
## não decide regras nem rola dados. As cartas usam visuais temporários.
##
## Na mesa (3D): Cavaleiros em campo, carta do encontro, baralho do reino e Cemitério.
## Na mão (2D, embaixo): as cartas que o jogador segura. Arraste da mão para a mesa
## para jogar um Cavaleiro em campo. Toque numa carta para ver os detalhes.

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")
const DecisorInterface = preload("res://scripts/apresentacao/decisor_interface.gd")
const Sessao = preload("res://scripts/apresentacao/sessao.gd")

const ESPACO_CARTA := 1.15
const POS_FILA_Z := 0.6
const POS_ENCONTRO := Vector3(0.0, 0.0, -1.5)
const POS_REINO := Vector3(-2.5, 0.0, -1.5)
const POS_CEMITERIO := Vector3(2.5, 0.0, -1.5)
const POS_ENTRADA := Vector3(0.0, 0.0, 3.5)  # de onde as cartas vêm (a mão)
const MEIA_LARGURA := 0.53
const MEIA_ALTURA := 0.73

var cat
var partida
var jogador  # jogador mostrado na mesa
var indice_preparo := 0
var indice_turno := 0

# Modo da interface: "mulligan", "iniciais", "reerguer", "preparacao" ou "" (aguardando).
var modo := ""
var pendentes: Array = []  # Cavaleiros arrastados para a mesa na colocação inicial
var decisor_reerguer = null
var selecionados: Array = []

var cartas_3d: Dictionary = {}  # "jogador/id_instancia" -> Node3D
var objetos_3d: Dictionary = {}  # mesma chave -> Cavaleiro
var carta_encontro: Node3D
var pilha_reino: Node3D

var rotulo_status: Label
var rotulo_pergunta: Label
var mao_2d: HBoxContainer
var botoes: HFlowContainer
var lista: VBoxContainer
var registro: RichTextLabel
var zona_mesa: Control
var detalhes: PanelContainer
var texto_detalhes: RichTextLabel


func _ready() -> void:
	_criar_ambiente()
	_criar_interface()
	cat = Catalogo.new()
	if not cat.carregar():
		rotulo_pergunta.text = "Erro ao carregar os dados do jogo."
		return
	carta_encontro = _criar_carta("Pântano Maluco", Color(0.45, 0.6, 0.4))
	carta_encontro.position = POS_ENCONTRO
	carta_encontro.scale = Vector3(1.25, 1.0, 1.25)
	pilha_reino = _criar_carta("Reino", Color(0.3, 0.42, 0.3))
	pilha_reino.position = POS_REINO
	var rotulo_cemiterio := Label3D.new()
	rotulo_cemiterio.text = "Cemitério"
	rotulo_cemiterio.font_size = 44
	rotulo_cemiterio.pixel_size = 0.005
	rotulo_cemiterio.rotation_degrees.x = -90
	rotulo_cemiterio.position = POS_CEMITERIO + Vector3(0, 0.01, 0.95)
	add_child(rotulo_cemiterio)
	nova_partida()


func nova_partida() -> void:
	for no in cartas_3d.values():
		no.queue_free()
	cartas_3d.clear()
	objetos_3d.clear()
	registro.clear()
	partida = Partida.new(cat, Dado.new(), Embaralhador.new())
	partida.registrou.connect(_ao_registrar)
	partida.revelou.connect(_ao_revelar)
	partida.com_pausas = true
	partida.passo_de_combate.connect(_ritmo_do_combate)
	partida.montar_mesa()
	for k in clampi(Sessao.jogadores, 1, 4):
		var decisor = DecisorInterface.new()
		decisor.pedido.connect(_ao_pedido.bind(decisor))
		partida.adicionar_jogador("j%d" % (k + 1), [], decisor)
	indice_preparo = 0
	indice_turno = 0
	_rotular(carta_encontro, "Pântano Maluco")
	_preparar_proximo_jogador()


func _nome(j) -> String:
	return "Jogador %s" % j.id.substr(1)


func _vez(j) -> String:
	return "" if partida.jogadores.size() == 1 else "%s: " % _nome(j)


# --- Cena 3D --------------------------------------------------------------------

func _criar_ambiente() -> void:
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 48
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 7.5, 5.6), Vector3(0, 0, 2.0))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-60, 30, 0)
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.65)
	ambiente.environment = env
	add_child(ambiente)
	var mesa := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(12, 9)
	mesa.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.23, 0.15)
	mesa.material_override = material
	mesa.position = Vector3(0, -0.04, 0.5)
	add_child(mesa)


func _criar_carta(texto: String, cor: Color) -> Node3D:
	var raiz := Node3D.new()
	var malha := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1.05, 0.06, 1.45)
	malha.mesh = caixa
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	malha.material_override = material
	malha.name = "Malha"
	raiz.add_child(malha)
	var rotulo := Label3D.new()
	rotulo.name = "Rotulo"
	rotulo.text = texto
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0042
	rotulo.width = 240
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.rotation_degrees.x = -90
	rotulo.position.y = 0.04
	rotulo.modulate = Color.BLACK
	rotulo.outline_size = 0
	raiz.add_child(rotulo)
	add_child(raiz)
	return raiz


func _rotular(carta: Node3D, texto: String) -> void:
	(carta.get_node("Rotulo") as Label3D).text = texto


func _colorir(carta: Node3D, cor: Color) -> void:
	((carta.get_node("Malha") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = cor


func _cor_do_cavaleiro(c) -> Color:
	match c.cor:
		"Amarelo":
			return Color(0.96, 0.86, 0.42)
		"Vermelho":
			return Color(0.92, 0.5, 0.45)
	return Color(0.8, 0.8, 0.8)


func _nome_curto(c) -> String:
	return c.nome.replace("Cavaleiro ", "")


func _texto_do_cavaleiro(c) -> String:
	return "%s\nF%d A%d/%d\nH%d P%d" % [_nome_curto(c), c.forca_total(), c.armadura_atual, c.armadura_maxima(), c.honra(), c.prestigio()]


func _atualizar(animar: bool) -> void:
	if jogador == null:
		return
	# Mesa: fila (ou os escolhidos na colocação inicial) e Cemitério.
	var em_campo: Array = jogador.fila + pendentes
	var destinos := {}
	var n := em_campo.size()
	for i in n:
		destinos[em_campo[i]] = Vector3((i - (n - 1) / 2.0) * ESPACO_CARTA, 0.0, POS_FILA_Z)
	for i in jogador.cemiterio.size():
		destinos[jogador.cemiterio[i]] = POS_CEMITERIO + Vector3(0, 0.07 * (i + 1), 0)
	var visiveis := {}
	for c in destinos:
		visiveis["%s/%s" % [jogador.id, c.id_instancia]] = c
	for chave in cartas_3d.keys():
		if not visiveis.has(chave):
			cartas_3d[chave].visible = false
	for chave in visiveis:
		var c = visiveis[chave]
		if not cartas_3d.has(chave):
			var nova := _criar_carta("", _cor_do_cavaleiro(c))
			nova.position = POS_ENTRADA
			cartas_3d[chave] = nova
		objetos_3d[chave] = c
		var carta: Node3D = cartas_3d[chave]
		if not carta.visible:
			carta.position = POS_ENTRADA
			carta.visible = true
		_rotular(carta, _texto_do_cavaleiro(c))
		if animar:
			var tween := create_tween()
			tween.tween_property(carta, "position", destinos[c], 0.45).set_trans(Tween.TRANS_CUBIC)
		else:
			carta.position = destinos[c]
	_rotular(pilha_reino, "%s\n%d cartas" % [jogador.reino_atual, partida.baralhos_reino[jogador.reino_atual].size()])
	_atualizar_encontro()
	_atualizar_mao()
	var itens := "nenhum"
	if not jogador.itens_mao.is_empty():
		itens = ", ".join(jogador.itens_mao.map(func(i): return i["nome"]))
	rotulo_status.text = "%s%s   •   Moedas: %d\nInimigos: %d/4   Eventos: %d/3   Itens: %s" % [
		_vez(jogador), jogador.reino_atual, jogador.moedas, jogador.inimigos, jogador.eventos, itens]


func _atualizar_encontro() -> void:
	var ini = partida.inimigo_atual
	if ini != null:
		_rotular(carta_encontro, "%s\nF%d  A%d/%d\nAmeaça %d" % [ini.nome, ini.forca_total(), ini.armadura_atual, ini.armadura_maxima, ini.ameaca])
		_colorir(carta_encontro, Color(0.85, 0.35, 0.3) if ini.vivo() else Color(0.45, 0.4, 0.4))


func _ao_revelar(carta_id: String) -> void:
	var tipo: String = cat.tipo_de_carta(carta_id)
	carta_encontro.set_meta("carta", carta_id)
	match tipo:
		"evento":
			_rotular(carta_encontro, "%s\nEvento" % cat.nome_de_carta(carta_id))
			_colorir(carta_encontro, Color(0.45, 0.6, 0.9))
		"mercador":
			_rotular(carta_encontro, "Mercador")
			_colorir(carta_encontro, Color(0.95, 0.75, 0.3))
		_:
			_rotular(carta_encontro, cat.nome_de_carta(carta_id))
			_colorir(carta_encontro, Color(0.85, 0.35, 0.3))


## Chamado pela lógica entre os golpes, para o combate acontecer à vista.
func _ritmo_do_combate() -> void:
	_atualizar(true)
	await get_tree().create_timer(0.7).timeout
	partida.continuar.emit()


func _ao_registrar(texto: String) -> void:
	if registro != null:
		registro.append_text(texto + "\n")


# --- Mão em 2D ------------------------------------------------------------------

func _atualizar_mao() -> void:
	for filho in mao_2d.get_children():
		mao_2d.remove_child(filho)
		filho.queue_free()
	var cartas: Array = jogador.mao.filter(func(c): return not pendentes.has(c))
	var total := cartas.size()
	for i in total:
		var c = cartas[i]
		var carta := _carta_da_mao(c)
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 4.0
		mao_2d.add_child(carta)
	for item in jogador.itens_mao:
		mao_2d.add_child(_item_da_mao(item))


func _estilo(cor: Color, borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 6
	estilo.content_margin_right = 6
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	return estilo


func _carta_da_mao(c) -> PanelContainer:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(124, 172)
	painel.pivot_offset = Vector2(62, 172)
	var marcada := selecionados.has(c)
	var jogavel := _pode_jogar(c)
	var borda := Color(1, 1, 1) if jogavel else Color(0.15, 0.15, 0.15)
	if marcada:
		borda = Color(0.2, 0.9, 0.3)
	painel.add_theme_stylebox_override("panel", _estilo(_cor_do_cavaleiro(c), borda))
	if not jogavel and modo == "preparacao":
		painel.modulate = Color(0.75, 0.75, 0.75)
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)
	var nome := Label.new()
	nome.text = _nome_curto(c)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_color_override("font_color", Color.BLACK)
	nome.add_theme_font_size_override("font_size", 19)
	coluna.add_child(nome)
	var atributos := Label.new()
	atributos.text = "F%d  A%d\nHonra %d" % [c.forca_total(), c.armadura_maxima(), c.honra()]
	atributos.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	atributos.add_theme_font_size_override("font_size", 17)
	coluna.add_child(atributos)
	var custo := Label.new()
	custo.text = "Custo %d" % c.custo()
	custo.add_theme_color_override("font_color", Color(0.35, 0.15, 0.0))
	custo.add_theme_font_size_override("font_size", 17)
	coluna.add_child(custo)
	painel.set_drag_forwarding(_arrastar_da_mao.bind(c), Callable(), Callable())
	painel.gui_input.connect(_toque_na_mao.bind(c))
	return painel


func _item_da_mao(item: Dictionary) -> PanelContainer:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(110, 172)
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.75, 0.8, 0.95), Color(0.3, 0.35, 0.6)))
	var rotulo := Label.new()
	rotulo.text = "%s\n(%s)" % [item["nome"], item["categoria"]]
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_color_override("font_color", Color.BLACK)
	rotulo.add_theme_font_size_override("font_size", 16)
	painel.add_child(rotulo)
	painel.gui_input.connect(_toque_no_item.bind(item))
	return painel


func _toque_na_mao(evento: InputEvent, c) -> void:
	if not (evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed):
		return
	if modo == "mulligan":
		_marcar(not selecionados.has(c), c)
		_atualizar_mao()
	else:
		_mostrar_detalhes(_detalhes_do_cavaleiro(c, "Na mão"))


func _toque_no_item(evento: InputEvent, item: Dictionary) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
		_mostrar_detalhes("[b]%s[/b]  (%s, %s)\n\n%s\n\nPara usar, toque em \"Equipar\" na Preparação." % [
			item["nome"], item["categoria"], item["raridade"], item["efeito"]])


func _arrastar_da_mao(_posicao: Vector2, c) -> Variant:
	if not _pode_jogar(c):
		return null
	var previa := PanelContainer.new()
	previa.custom_minimum_size = Vector2(124, 172)
	previa.add_theme_stylebox_override("panel", _estilo(_cor_do_cavaleiro(c), Color.WHITE))
	var nome := Label.new()
	nome.text = _nome_curto(c)
	nome.add_theme_color_override("font_color", Color.BLACK)
	previa.add_child(nome)
	previa.modulate.a = 0.85
	var suporte := Control.new()
	suporte.add_child(previa)
	previa.position = Vector2(-62, -86)
	mao_2d.set_drag_preview(suporte)
	return {"cavaleiro": c}


## Quem pode ser arrastado para a mesa agora.
func _pode_jogar(c) -> bool:
	match modo:
		"iniciais", "reerguer":
			return pendentes.size() < 3 and not pendentes.has(c)
		"preparacao":
			return jogador.fila.size() < 6 and jogador.moedas >= c.custo()
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
		"iniciais":
			pendentes.append(c)
			_atualizar(true)
			if pendentes.size() == mini(3, jogador.mao.size()):
				_concluir_iniciais()
			else:
				_tela_iniciais()
		"reerguer":
			pendentes.append(c)
			_atualizar(true)
			if pendentes.size() == mini(3, jogador.mao.size()):
				var escolhidos := pendentes.duplicate()
				pendentes.clear()
				modo = ""
				decisor_reerguer.responder(escolhidos)
		"preparacao":
			modo = ""
			_perguntar("")
			await partida.recrutar_da_mao(jogador, c.id_instancia)
			_tela_preparacao()


func _notification(qual: int) -> void:
	if zona_mesa == null:
		return
	if qual == NOTIFICATION_DRAG_BEGIN:
		zona_mesa.visible = true
	elif qual == NOTIFICATION_DRAG_END:
		zona_mesa.visible = false


# --- Toques na mesa e detalhes -------------------------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if detalhes.visible or jogador == null:
		return
	if not (evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed):
		return
	var camera := get_viewport().get_camera_3d()
	var origem := camera.project_ray_origin(evento.position)
	var direcao := camera.project_ray_normal(evento.position)
	if absf(direcao.y) < 0.001:
		return
	var ponto := origem + direcao * (-origem.y / direcao.y)
	if _sob(ponto, carta_encontro, 1.25):
		_mostrar_detalhes(_detalhes_do_encontro())
		return
	if _sob(ponto, pilha_reino, 1.0):
		_mostrar_detalhes("[b]%s[/b]\n\n%d cartas no baralho do reino e %d no descarte." % [
			jogador.reino_atual, partida.baralhos_reino[jogador.reino_atual].size(), partida.descartes_reino[jogador.reino_atual].size()])
		return
	if absf(ponto.x - POS_CEMITERIO.x) < MEIA_LARGURA and absf(ponto.z - POS_CEMITERIO.z) < MEIA_ALTURA:
		var nomes: Array = jogador.cemiterio.map(func(c): return _nome_curto(c))
		_mostrar_detalhes("[b]Cemitério[/b]\n\n%s" % (", ".join(nomes) if not nomes.is_empty() else "Vazio."))
		return
	for chave in cartas_3d:
		var no: Node3D = cartas_3d[chave]
		if no.visible and _sob(ponto, no, 1.0) and objetos_3d.has(chave):
			var c = objetos_3d[chave]
			var onde := "Na mesa"
			if jogador.fila.has(c):
				onde = "Em campo, posição %d da fila" % (jogador.fila.find(c) + 1)
			_mostrar_detalhes(_detalhes_do_cavaleiro(c, onde))
			return


func _sob(ponto: Vector3, no: Node3D, escala: float) -> bool:
	return absf(ponto.x - no.position.x) < MEIA_LARGURA * escala and absf(ponto.z - no.position.z) < MEIA_ALTURA * escala


func _detalhes_do_cavaleiro(c, onde: String) -> String:
	var texto := "[b]%s[/b]  (%s)\n%s\n\nForça %d   Armadura %d/%d   Honra %d   Prestígio %d\nCusto para entrar em campo: %d" % [
		c.nome, c.cor, onde, c.forca_total(), c.armadura_atual, c.armadura_maxima(), c.honra(), c.prestigio(), c.custo()]
	if c.habilidade != "":
		texto += "\n\n[b]%s[/b]: %s" % [c.habilidade, c.habilidade_texto]
	if not c.equipamentos.is_empty():
		texto += "\n\n[b]Equipamentos[/b]"
		for item in c.equipamentos:
			texto += "\n• %s: %s" % [item["nome"], item["efeito"]]
	return texto


func _detalhes_do_encontro() -> String:
	if not carta_encontro.has_meta("carta"):
		return "[b]Pântano Maluco[/b]\n\nExplore o reino para revelar a primeira carta."
	var id: String = carta_encontro.get_meta("carta")
	var tipo: String = cat.tipo_de_carta(id)
	if tipo == "mercador":
		return "[b]Mercador[/b]\n\nRevela cinco itens. Compre quantos quiser pelos preços impressos."
	if tipo == "evento":
		var ev: Dictionary = cat.eventos[id]
		return "[b]%s[/b]  (Evento)\n\n%s" % [ev["nome"], ev["efeito"]]
	var dados: Dictionary = cat.inimigos[id]
	var ini = partida.inimigo_atual
	var estado := ""
	if ini != null and ini.id == id:
		estado = "\nForça %d   Armadura %d/%d   Ameaça %d%s" % [ini.forca_total(), ini.armadura_atual, ini.armadura_maxima, ini.ameaca, "" if ini.vivo() else "   (derrotado)"]
	return "[b]%s[/b]  (%s)%s\n\n[b]%s[/b]: %s" % [dados["nome"], dados["tipo"], estado, dados["habilidade"], dados["efeito"]]


func _mostrar_detalhes(texto: String) -> void:
	texto_detalhes.text = texto
	detalhes.visible = true


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

	var topo := PanelContainer.new()
	raiz.add_child(topo)
	topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var linha_topo := HBoxContainer.new()
	topo.add_child(linha_topo)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(90, 50)
	menu.pressed.connect(_ir_ao_menu)
	linha_topo.add_child(menu)
	rotulo_status = Label.new()
	rotulo_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_topo.add_child(rotulo_status)

	var base := PanelContainer.new()
	raiz.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	base.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var margem := MarginContainer.new()
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 10)
	base.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	margem.add_child(coluna)
	mao_2d = HBoxContainer.new()
	mao_2d.alignment = BoxContainer.ALIGNMENT_CENTER
	mao_2d.add_theme_constant_override("separation", -10)
	mao_2d.custom_minimum_size = Vector2(0, 180)
	coluna.add_child(mao_2d)
	rotulo_pergunta = Label.new()
	rotulo_pergunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(rotulo_pergunta)
	botoes = HFlowContainer.new()
	botoes.add_theme_constant_override("h_separation", 8)
	botoes.add_theme_constant_override("v_separation", 8)
	coluna.add_child(botoes)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	coluna.add_child(lista)
	registro = RichTextLabel.new()
	registro.custom_minimum_size = Vector2(0, 130)
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 16)
	coluna.add_child(registro)

	detalhes = PanelContainer.new()
	raiz.add_child(detalhes)
	detalhes.custom_minimum_size = Vector2(620, 0)
	detalhes.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	detalhes.grow_horizontal = Control.GROW_DIRECTION_BOTH
	detalhes.grow_vertical = Control.GROW_DIRECTION_BOTH
	detalhes.add_theme_stylebox_override("panel", _estilo(Color(0.12, 0.12, 0.14, 0.97), Color(0.98, 0.82, 0.3)))
	var coluna_detalhes := VBoxContainer.new()
	detalhes.add_child(coluna_detalhes)
	texto_detalhes = RichTextLabel.new()
	texto_detalhes.bbcode_enabled = true
	texto_detalhes.fit_content = true
	texto_detalhes.custom_minimum_size = Vector2(600, 0)
	coluna_detalhes.add_child(texto_detalhes)
	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.custom_minimum_size = Vector2(0, 54)
	fechar.pressed.connect(_fechar_detalhes)
	coluna_detalhes.add_child(fechar)
	detalhes.visible = false


func _fechar_detalhes() -> void:
	detalhes.visible = false


func _ir_ao_menu() -> void:
	get_tree().change_scene_to_file("res://cenas/menu.tscn")


func _perguntar(texto: String) -> void:
	if not texto.is_empty():
		texto = texto[0].to_upper() + texto.substr(1)
	rotulo_pergunta.text = texto
	for recipiente in [botoes, lista]:
		for b in recipiente.get_children():
			recipiente.remove_child(b)
			b.queue_free()


func _botao(texto: String, acao: Callable, ativo: bool = true) -> Button:
	var b := Button.new()
	b.text = texto
	b.disabled = not ativo
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(acao)
	botoes.add_child(b)
	return b


func _alternavel(texto: String, valor) -> Button:
	var b := Button.new()
	b.text = texto
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 54)
	b.toggled.connect(_marcar.bind(valor))
	if "\n" in texto:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lista.add_child(b)
	else:
		botoes.add_child(b)
	return b


func _marcar(ligado: bool, valor) -> void:
	if ligado and not selecionados.has(valor):
		selecionados.append(valor)
	elif not ligado:
		selecionados.erase(valor)


func _rotulo_cavaleiro(c) -> String:
	return "%s  F%d A%d/%d H%d P%d" % [_nome_curto(c), c.forca_total(), c.armadura_atual, c.armadura_maxima(), c.honra(), c.prestigio()]


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
	_atualizar(false)
	_perguntar("%sescolha o reino inicial. Você começa com %d moedas." % [_vez(jogador), jogador.moedas])
	for r in cat.circuito:
		var tem_cartas: bool = not partida.baralhos_reino[r].is_empty()
		_botao(r if tem_cartas else "%s (em breve)" % r, _escolher_reino_inicial.bind(r), tem_cartas)


func _escolher_reino_inicial(reino: String) -> void:
	partida.definir_reino_inicial(jogador, reino)
	partida.comprar_mao_inicial(jogador)
	_tela_mulligan()


func _tela_mulligan() -> void:
	modo = "mulligan"
	selecionados.clear()
	_atualizar(true)
	_perguntar("%sesta é sua mão. Toque nas cartas que quer devolver ao baralho para comprar outras (mulligan), quantas vezes quiser." % _vez(jogador))
	_botao("Trocar marcadas", _trocar_marcadas)
	_botao("Manter mão", _tela_iniciais)


func _trocar_marcadas() -> void:
	if selecionados.is_empty():
		return
	partida.fazer_mulligan(jogador, selecionados.duplicate())
	_tela_mulligan()


func _tela_iniciais() -> void:
	modo = "iniciais"
	selecionados.clear()
	_atualizar(false)
	var faltam := mini(3, jogador.mao.size()) - pendentes.size()
	_perguntar("%sarraste %d Cavaleiro%s da mão para a mesa. Os 3 primeiros entram de graça." % [_vez(jogador), faltam, "" if faltam == 1 else "s"])


func _concluir_iniciais() -> void:
	modo = ""
	var escolhidos := pendentes.duplicate()
	pendentes.clear()
	_perguntar("")
	await partida.colocar_iniciais(jogador, escolhidos)
	_atualizar(true)
	indice_preparo += 1
	_preparar_proximo_jogador()


func _tela_iniciativa() -> void:
	if partida.jogadores.size() == 1:
		_comecar_turno()
		return
	_perguntar("Todos rolam o D6. O maior resultado começa; empates rolam de novo.")
	_botao("Rolar o D6", _rolar_iniciativa)


func _rolar_iniciativa() -> void:
	partida.definir_ordem_de_turno()
	var rolagens: Array = partida.dado.registro.filter(func(r): return r["motivo"].begins_with("iniciativa_"))
	var texto := ", ".join(rolagens.map(func(r): return "Jogador %s tirou %d" % [r["motivo"].substr(12), r["face"]]))
	_perguntar("%s.\n%s começa!" % [texto, _nome(partida.jogadores[0])])
	_botao("Começar", _comecar_turno)


# --- Turno ------------------------------------------------------------------------

func _comecar_turno() -> void:
	jogador = partida.jogadores[indice_turno]
	modo = ""
	_atualizar(false)
	_perguntar("")
	var avancou: bool = await partida.iniciar_turno(jogador)
	if avancou or partida.playtest_encerrado:
		_tela_final()
		return
	_tela_preparacao()


func _tela_preparacao() -> void:
	modo = "preparacao"
	_atualizar(true)
	_perguntar("%sPreparação: arraste um Cavaleiro da mão para a mesa para recrutá-lo (paga o custo), compre ou equipe. Depois explore o reino." % _vez(jogador))
	_botao("Explorar o reino", _explorar)
	_botao("Comprar Cavaleiro (1)", _comprar_cavaleiro, not jogador.comprou_cavaleiro_no_turno and jogador.moedas >= 1)
	var tem_itens: bool = not partida.baralho_itens.is_empty() or not partida.descarte_itens.is_empty()
	_botao("Compra às cegas (4)", _comprar_as_cegas, not jogador.comprou_as_cegas_no_turno and jogador.moedas >= 4 and tem_itens)
	for item in jogador.itens_mao:
		_botao("Equipar %s" % item["nome"], _escolher_portador.bind(item))


func _comprar_cavaleiro() -> void:
	partida.comprar_cavaleiro(jogador)
	_tela_preparacao()


func _comprar_as_cegas() -> void:
	partida.comprar_as_cegas(jogador)
	_tela_preparacao()


func _escolher_portador(item: Dictionary) -> void:
	modo = ""
	_atualizar(false)
	_perguntar("Quem vai equipar %s? (%s: %s)" % [item["nome"], item["categoria"], item["efeito"]])
	for c in jogador.fila + jogador.mao:
		_botao(_rotulo_cavaleiro(c), _equipar.bind(c, item))
	_botao("Voltar", _tela_preparacao)


func _equipar(c, item: Dictionary) -> void:
	partida.equipar_item(jogador, c.id_instancia, item["id"])
	_tela_preparacao()


func _explorar() -> void:
	modo = ""
	_atualizar(false)
	_perguntar("Explorando…")
	var moedas_antes: int = jogador.moedas
	await partida.explorar_e_resolver(jogador)
	_atualizar(true)
	if partida.playtest_encerrado:
		_tela_final()
		return
	var saldo: int = jogador.moedas - moedas_antes
	_perguntar("%sfim do turno. Moedas: %d (%s%d). Toque nas cartas para ver detalhes." % [_vez(jogador), jogador.moedas, "+" if saldo >= 0 else "", saldo])
	if partida.jogadores.size() == 1:
		_botao("Próximo turno", _proximo_turno)
	else:
		var proximo = partida.jogadores[(indice_turno + 1) % partida.jogadores.size()]
		_botao("Passar para %s" % _nome(proximo), _proximo_turno)


func _proximo_turno() -> void:
	indice_turno = (indice_turno + 1) % partida.jogadores.size()
	_comecar_turno()


func _tela_final() -> void:
	modo = ""
	var r: Dictionary = partida.relatorio
	_perguntar("Playtest concluído! %sconcluiu %s (%s) e chegou a %s com %d moedas." % [
		_vez(jogador), r.get("reino_concluido", "o Pântano"), _texto_avanco(r.get("avanco_por", "")), jogador.reino_atual, jogador.moedas])
	_botao("Jogar de novo", nova_partida)
	_botao("Menu", _ir_ao_menu)


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

func _ao_pedido(tipo: String, dados: Dictionary, decisor) -> void:
	var quem = dados["jogador"]
	modo = ""
	_atualizar(true)
	var vez := _vez(quem)
	match tipo:
		"mercador":
			_tela_mercador(decisor, quem, dados["oferta"])
		"reposicao":
			_tela_reposicao(decisor, quem, dados["reveladas"], dados["pagaveis"])
		"cavaleiro_evento":
			_tela_cavaleiro_evento(decisor, quem, dados["evento"])
		"descarte":
			_tela_descarte(decisor, quem, dados)
		"empate":
			_tela_empate(decisor, quem, dados["grupo"], [])
		"iniciais":
			modo = "reerguer"
			decisor_reerguer = decisor
			pendentes.clear()
			_atualizar(true)
			_perguntar("%sderrota total! Arraste 3 Cavaleiros da mão para a mesa para recomeçar no reino inicial." % vez)
		"conversao":
			_perguntar("%sreino concluído! Converta o Prestígio dos Cavaleiros em campo." % vez)
			_botao("Moedas (+%d)" % dados["total"], decisor.responder.bind("moedas"))
			_botao("Status permanente", decisor.responder.bind("status"))
		"status":
			var c = dados["cavaleiro"]
			var p: int = c.prestigio()
			_perguntar("%s%s tem %d de Prestígio. Onde aplicar os pontos?" % [vez, c.nome, p])
			_botao("+%d Força" % p, decisor.responder.bind({"forca": p, "armadura": 0, "honra": 0}))
			_botao("+%d Armadura máxima" % p, decisor.responder.bind({"forca": 0, "armadura": p, "honra": 0}))
			_botao("+%d Honra" % p, decisor.responder.bind({"forca": 0, "armadura": 0, "honra": p}))
		"reino":
			_perguntar("%schefe derrotado! Escolha o próximo reino." % vez)
			for r in dados["permitidos"]:
				_botao(r, decisor.responder.bind(r))
		_:
			decisor.responder(null)


## Empate de Honra: o dono toca os Cavaleiros na ordem em que quer que fiquem.
func _tela_empate(decisor, quem, grupo: Array, escolhidos: Array) -> void:
	if escolhidos.size() == grupo.size():
		decisor.responder(escolhidos)
		return
	var nomes := ", ".join(grupo.map(func(c): return _nome_curto(c)))
	var ja := ""
	if not escolhidos.is_empty():
		ja = "\nOrdem até agora: %s." % ", ".join(escolhidos.map(func(c): return _nome_curto(c)))
	_perguntar("%sempate de Honra (%d) entre %s. Toque quem vem primeiro na fila.%s" % [_vez(quem), grupo[0].honra(), nomes, ja])
	for c in grupo:
		if not escolhidos.has(c):
			_botao(_nome_curto(c), _tela_empate.bind(decisor, quem, grupo, escolhidos + [c]))
	if escolhidos.is_empty():
		_botao("Manter ordem atual", decisor.responder.bind(grupo))


func _tela_mercador(decisor, quem, oferta: Array) -> void:
	selecionados = []
	_perguntar("%sMercador! Marque os itens que quer comprar. Você tem %d moedas." % [_vez(quem), quem.moedas])
	for item in oferta:
		_alternavel("%s (%d)\n%s" % [item["nome"], int(item["preco_mercador"]), item["efeito"]], item)
	_botao("Comprar marcados", _confirmar_mercador.bind(decisor, quem))
	_botao("Não comprar nada", decisor.responder.bind([]))


func _confirmar_mercador(decisor, quem) -> void:
	var total := 0
	for item in selecionados:
		total += int(item["preco_mercador"])
	if total > quem.moedas:
		rotulo_pergunta.text = "Os itens marcados custam %d e você tem %d moedas." % [total, quem.moedas]
		return
	decisor.responder(selecionados.map(func(i): return i["id"]))


func _tela_reposicao(decisor, quem, reveladas: Array, pagaveis: Array) -> void:
	var nomes := ", ".join(reveladas.map(func(c): return _nome_curto(c)))
	_perguntar(_vez(quem) + "Reposição: saíram %s. Escolha quem entra em campo pagando o custo; a outra carta vai ao Cemitério." % nomes)
	for c in pagaveis:
		_botao("%s (%d moedas)" % [_rotulo_cavaleiro(c), c.custo()], decisor.responder.bind(c))


func _tela_cavaleiro_evento(decisor, quem, evento_id: String) -> void:
	var ev: Dictionary = cat.eventos[evento_id]
	_perguntar("%s%s\n%s\nEscolha o Cavaleiro." % [_vez(quem), ev["nome"], ev["efeito"]])
	for c in quem.fila:
		_botao(_rotulo_cavaleiro(c), decisor.responder.bind(c.id_instancia))


func _tela_descarte(decisor, quem, dados: Dictionary) -> void:
	var ev: Dictionary = cat.eventos[dados["evento"]]
	_perguntar(_vez(quem) + dados.get("texto", "%s\n%s" % [ev["nome"], ev["efeito"]]))
	_botao(dados["recusa"], decisor.responder.bind(null))
	for c in quem.mao:
		_botao("Descartar %s" % _nome_curto(c), decisor.responder.bind(c.id_instancia))
	for item in quem.itens_mao:
		_botao("Descartar %s" % item["nome"], decisor.responder.bind(item["id"]))
