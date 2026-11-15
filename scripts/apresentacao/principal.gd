extends Node3D
## Mesa jogável do playtest no Pântano Maluco, no estilo dos jogos de cartas digitais.
## Só lê o estado da partida e mostra os resultados que a lógica devolveu;
## não decide regras nem rola dados. As cartas usam visuais temporários.
##
## Mesa (3D): inimigo/encontro no topo, fila de Cavaleiros no meio, baralho do reino
## e Cemitério à direita. Mão (2D) embaixo; arraste uma carta para a mesa para jogá-la.
## Escolhas aparecem no meio da tela com as cartas grandes. Ações ficam à direita.

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")
const DecisorInterface = preload("res://scripts/apresentacao/decisor_interface.gd")
const Sessao = preload("res://scripts/apresentacao/sessao.gd")

const ESPACO_CARTA := 1.2
const POS_FILA_Z := 0.75
const POS_ENCONTRO := Vector3(0.0, 0.0, -2.0)
const ESCALA_ENCONTRO := 1.55
const POS_REINO := Vector3(4.3, 0.0, -1.9)
const POS_CEMITERIO := Vector3(4.3, 0.0, 0.6)
const POS_ENTRADA := Vector3(0.0, 0.0, 3.5)
const MEIA_LARGURA := 0.53
const MEIA_ALTURA := 0.73
const TAM_MAO := Vector2(140, 196)
const TAM_ESCOLHA := Vector2(170, 238)

var cat
var partida
var jogador  # jogador mostrado na mesa
var indice_preparo := 0
var indice_turno := 0

# Modo: "iniciais", "reerguer", "preparacao", "ataque" ou "" (aguardando a lógica).
var modo := ""
var pendentes: Array = []  # Cavaleiros arrastados para a mesa na colocação inicial
var decisor_atual = null  # decisor que espera uma resposta dada na mesa
var opcoes_ataque: Array = []
var atacante_escolhido = null
var selecionados: Array = []
var armaduras_vistas: Dictionary = {}  # para mostrar o dano que saltou

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
var fundo_escolha: ColorRect
var escolha: PanelContainer
var titulo_escolha: Label
var cartas_escolha: HFlowContainer
var botoes_escolha: HFlowContainer
var detalhes: PanelContainer
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
	carta_encontro = _criar_carta("Pântano Maluco", Color(0.45, 0.6, 0.4))
	carta_encontro.position = POS_ENCONTRO
	carta_encontro.scale = Vector3(ESCALA_ENCONTRO, 1.0, ESCALA_ENCONTRO)
	pilha_reino = _criar_carta("Reino", Color(0.3, 0.42, 0.3))
	pilha_reino.position = POS_REINO
	pilha_cemiterio = _criar_carta("Cemitério", Color(0.35, 0.33, 0.38))
	pilha_cemiterio.position = POS_CEMITERIO
	nova_partida()


func nova_partida() -> void:
	for no in cartas_3d.values():
		no.queue_free()
	cartas_3d.clear()
	objetos_3d.clear()
	armaduras_vistas.clear()
	registro.clear()
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
	if carta_encontro.has_meta("carta"):
		carta_encontro.remove_meta("carta")
	_rotular(carta_encontro, "Pântano Maluco")
	_colorir(carta_encontro, Color(0.45, 0.6, 0.4))
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
	env.background_color = Color(0.1, 0.12, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.65)
	ambiente.environment = env
	add_child(ambiente)
	var mesa := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(16, 11)
	mesa.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.23, 0.15)
	mesa.material_override = material
	mesa.position = Vector3(0, -0.04, 0)
	add_child(mesa)


## Na horizontal a altura da mesa cabe na tela; na vertical, a largura.
func _ajustar_camera() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	if tamanho.x >= tamanho.y:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 42
		camera.look_at_from_position(Vector3(0, 8.4, 4.4), Vector3(0, 0, -0.35))
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 62
		camera.look_at_from_position(Vector3(0, 8.8, 6.2), Vector3(0, 0, 1.2))


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


func _chave(c) -> String:
	return "%s/%s" % [jogador.id, c.id_instancia]


func _atualizar(animar: bool) -> void:
	if jogador == null:
		return
	var em_campo: Array = jogador.fila + pendentes
	var destinos := {}
	var n := em_campo.size()
	for i in n:
		var altura := 0.35 if (modo == "ataque" and em_campo[i] == atacante_escolhido) else 0.0
		destinos[em_campo[i]] = Vector3((i - (n - 1) / 2.0) * ESPACO_CARTA, altura, POS_FILA_Z)
	for i in jogador.cemiterio.size():
		destinos[jogador.cemiterio[i]] = POS_CEMITERIO + Vector3(0, 0.07 * (i + 1), 0)
	var visiveis := {}
	for c in destinos:
		visiveis[_chave(c)] = c
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
		var cor := _cor_do_cavaleiro(c)
		if modo == "ataque" and opcoes_ataque.has(c):
			cor = cor.lightened(0.35) if c == atacante_escolhido else cor.lightened(0.15)
		_colorir(carta, cor)
		if animar:
			var tween := create_tween()
			tween.tween_property(carta, "position", destinos[c], 0.4).set_trans(Tween.TRANS_CUBIC)
		else:
			carta.position = destinos[c]
	_rotular(pilha_reino, "%s\n%d cartas" % [jogador.reino_atual, partida.baralhos_reino[jogador.reino_atual].size()])
	_rotular(pilha_cemiterio, "Cemitério\n%d" % jogador.cemiterio.size())
	pilha_cemiterio.visible = jogador.cemiterio.is_empty()
	_atualizar_encontro()
	_atualizar_mao()
	var itens := "nenhum"
	if not jogador.itens_mao.is_empty():
		itens = ", ".join(jogador.itens_mao.map(func(i): return i["nome"]))
	rotulo_status.text = "%s%s   •   Moedas: %d   •   Inimigos %d/4   •   Eventos %d/3   •   Itens: %s" % [
		_vez(jogador), jogador.reino_atual, jogador.moedas, jogador.inimigos, jogador.eventos, itens]


func _atualizar_encontro() -> void:
	var ini = partida.inimigo_atual
	if ini != null:
		_rotular(carta_encontro, "%s\nF%d  A%d/%d\nAmeaça %d" % [ini.nome, ini.forca_total(), ini.armadura_atual, ini.armadura_maxima, ini.ameaca])
		var cor := Color(0.85, 0.35, 0.3) if ini.vivo() else Color(0.45, 0.4, 0.4)
		if modo == "ataque":
			cor = cor.lightened(0.2)
		_colorir(carta_encontro, cor)


func _ao_revelar(carta_id: String) -> void:
	var tipo: String = cat.tipo_de_carta(carta_id)
	carta_encontro.set_meta("carta", carta_id)
	armaduras_vistas.clear()
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
	r.font_size = 110
	r.pixel_size = 0.006
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r.modulate = Color(1, 0.25, 0.2) if valor < 0 else Color(0.3, 1, 0.4)
	r.outline_size = 18
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
		return "Contra-ataque: %s" % motivo.substr(14).capitalize()
	if motivo.begins_with("ataque_"):
		return "Ataque: %s" % motivo.substr(7).capitalize()
	if motivo.begins_with("iniciativa_"):
		return "Iniciativa: Jogador %s" % motivo.substr(12)
	return motivo.replace("_", " ").capitalize()


func _ao_registrar(texto: String) -> void:
	if registro != null:
		registro.append_text(texto + "\n")


# --- Cartas 2D ------------------------------------------------------------------

func _estilo(cor: Color, borda: Color, espessura: int = 3) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(espessura)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	return estilo


func _rotulo_2d(texto: String, tamanho: int, cor: Color = Color.BLACK) -> Label:
	var r := Label.new()
	r.text = texto
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_color_override("font_color", cor)
	r.add_theme_font_size_override("font_size", tamanho)
	return r


## Carta de Cavaleiro em 2D. estado: "", "marcada", "destaque" ou "apagada".
func _carta_2d(c, tamanho: Vector2, ao_tocar: Callable, estado: String = "") -> PanelContainer:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = tamanho
	painel.pivot_offset = tamanho / 2
	var borda := Color(0.12, 0.1, 0.08)
	if estado == "marcada":
		borda = Color(0.95, 0.25, 0.2)
	elif estado == "destaque":
		borda = Color(0.35, 1.0, 0.45)
	painel.add_theme_stylebox_override("panel", _estilo(_cor_do_cavaleiro(c), borda, 5 if estado != "" else 3))
	if estado == "apagada":
		painel.modulate = Color(0.55, 0.55, 0.55)
	var escala := tamanho.x / 140.0
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(topo)
	var custo := _rotulo_2d(str(c.custo()), int(22 * escala), Color(0.2, 0.25, 0.7))
	custo.autowrap_mode = TextServer.AUTOWRAP_OFF
	topo.add_child(custo)
	var nome := _rotulo_2d(_nome_curto(c), int(17 * escala))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(nome)
	if c.habilidade != "":
		coluna.add_child(_rotulo_2d(c.habilidade, int(13 * escala), Color(0.25, 0.2, 0.15)))
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(espaco)
	coluna.add_child(_rotulo_2d("Honra %d" % c.honra(), int(14 * escala), Color(0.2, 0.2, 0.2)))
	var base := HBoxContainer.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(base)
	var forca := _rotulo_2d("F%d" % c.forca_total(), int(22 * escala), Color(0.6, 0.1, 0.05))
	forca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base.add_child(forca)
	base.add_child(_rotulo_2d("A%d" % c.armadura_atual, int(22 * escala), Color(0.1, 0.25, 0.55)))
	if ao_tocar.is_valid():
		painel.gui_input.connect(_ao_toque_2d.bind(ao_tocar))
	return painel


func _carta_item_2d(item: Dictionary, tamanho: Vector2, ao_tocar: Callable, estado: String = "") -> PanelContainer:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = tamanho
	painel.pivot_offset = tamanho / 2
	var borda := Color(0.3, 0.35, 0.6)
	if estado == "marcada":
		borda = Color(0.35, 1.0, 0.45)
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.78, 0.82, 0.96), borda, 5 if estado != "" else 3))
	if estado == "apagada":
		painel.modulate = Color(0.55, 0.55, 0.55)
	var escala := tamanho.x / 140.0
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)
	coluna.add_child(_rotulo_2d(item["nome"], int(16 * escala)))
	coluna.add_child(_rotulo_2d("%s • %s" % [item["categoria"], item["raridade"]], int(12 * escala), Color(0.25, 0.25, 0.4)))
	coluna.add_child(_rotulo_2d(item["efeito"], int(12 * escala), Color(0.15, 0.15, 0.15)))
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(espaco)
	coluna.add_child(_rotulo_2d("%d moedas" % int(item["preco_mercador"]), int(16 * escala), Color(0.5, 0.35, 0.0)))
	if ao_tocar.is_valid():
		painel.gui_input.connect(_ao_toque_2d.bind(ao_tocar))
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
		var carta := _carta_2d(c, TAM_MAO, _mostrar_detalhes_cavaleiro.bind(c, "Na mão"), estado)
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 3.5
		carta.set_drag_forwarding(_arrastar_da_mao.bind(c), Callable(), Callable())
		mao_2d.add_child(carta)
		i += 1
	for item in jogador.itens_mao:
		var carta := _carta_item_2d(item, TAM_MAO, _tocar_item.bind(item))
		carta.rotation_degrees = (i - (total - 1) / 2.0) * 3.5
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
	var previa := _carta_2d(c, TAM_MAO, Callable(), "destaque")
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
	if detalhes.visible or escolha.visible or jogador == null:
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
			elif jogador.cemiterio.has(c):
				onde = "No Cemitério"
			_mostrar_detalhes_cavaleiro(c, onde)
			return


func _sob(ponto: Vector3, no: Node3D, escala: float) -> bool:
	return absf(ponto.x - no.position.x) < MEIA_LARGURA * escala and absf(ponto.z - no.position.z) < MEIA_ALTURA * escala


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
	if not carta_encontro.has_meta("carta"):
		return "[b]%s[/b]\n\nExplore o reino para revelar a primeira carta." % jogador.reino_atual
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


func _fechar_detalhes() -> void:
	detalhes.visible = false


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
	var linha_topo := HBoxContainer.new()
	topo.add_child(linha_topo)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(96, 48)
	menu.pressed.connect(_ir_ao_menu)
	linha_topo.add_child(menu)
	var botao_registro := Button.new()
	botao_registro.text = "Registro"
	botao_registro.custom_minimum_size = Vector2(120, 48)
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
	rotulo_dica.offset_top = 58
	rotulo_dica.offset_bottom = 120
	rotulo_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo_dica.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	rotulo_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo_dica.add_theme_constant_override("outline_size", 8)
	rotulo_dica.add_theme_font_size_override("font_size", 24)

	# Mão: embaixo, no centro.
	mao_2d = HBoxContainer.new()
	raiz.add_child(mao_2d)
	mao_2d.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	mao_2d.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mao_2d.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mao_2d.offset_bottom = 40  # a mão sai um pouco pela borda, como nos jogos de cartas
	mao_2d.alignment = BoxContainer.ALIGNMENT_CENTER
	mao_2d.add_theme_constant_override("separation", -18)

	# Ações: à direita, como o botão de fim de turno.
	acoes = VBoxContainer.new()
	raiz.add_child(acoes)
	acoes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	acoes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	acoes.grow_vertical = Control.GROW_DIRECTION_BOTH
	acoes.offset_right = -16
	acoes.offset_left = -16
	acoes.add_theme_constant_override("separation", 10)

	# Registro: painel à esquerda, aberto pelo botão do topo.
	painel_registro = PanelContainer.new()
	raiz.add_child(painel_registro)
	painel_registro.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	painel_registro.offset_top = 60
	painel_registro.offset_bottom = -10
	painel_registro.custom_minimum_size = Vector2(420, 0)
	registro = RichTextLabel.new()
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 17)
	painel_registro.add_child(registro)
	painel_registro.visible = false

	# Escolhas: no meio da tela, com o fundo escurecido.
	fundo_escolha = ColorRect.new()
	raiz.add_child(fundo_escolha)
	fundo_escolha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo_escolha.color = Color(0, 0, 0, 0.55)
	escolha = PanelContainer.new()
	raiz.add_child(escolha)
	escolha.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	escolha.grow_horizontal = Control.GROW_DIRECTION_BOTH
	escolha.grow_vertical = Control.GROW_DIRECTION_BOTH
	escolha.add_theme_stylebox_override("panel", _estilo(Color(0.13, 0.12, 0.1, 0.96), Color(0.98, 0.82, 0.3)))
	var coluna_escolha := VBoxContainer.new()
	coluna_escolha.add_theme_constant_override("separation", 14)
	escolha.add_child(coluna_escolha)
	titulo_escolha = Label.new()
	titulo_escolha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_escolha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_escolha.custom_minimum_size = Vector2(660, 0)
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
	rotulo_dado.custom_minimum_size = Vector2(520, 120)
	rotulo_dado.offset_left = -260
	rotulo_dado.offset_right = 260
	rotulo_dado.offset_top = -170
	rotulo_dado.offset_bottom = -50
	rotulo_dado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_dado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo_dado.add_theme_font_size_override("font_size", 44)
	rotulo_dado.add_theme_color_override("font_color", Color(1, 1, 1))
	rotulo_dado.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0))
	rotulo_dado.add_theme_constant_override("outline_size", 14)
	rotulo_dado.pivot_offset = Vector2(260, 60)
	rotulo_dado.visible = false

	# Detalhes de uma carta.
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
	fundo_escolha.visible = true
	escolha.visible = true
	escolha.reset_size()


func _fechar_escolha() -> void:
	fundo_escolha.visible = false
	escolha.visible = false


func _botao_escolha(texto: String, acao: Callable, ativo: bool = true) -> void:
	var b := Button.new()
	b.text = texto
	b.disabled = not ativo
	b.custom_minimum_size = Vector2(180, 60)
	b.pressed.connect(acao)
	botoes_escolha.add_child(b)


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
		b.add_theme_stylebox_override("normal", _estilo(Color(0.85, 0.62, 0.15), Color(1, 0.9, 0.5)))
		b.add_theme_stylebox_override("hover", _estilo(Color(0.95, 0.7, 0.2), Color(1, 0.95, 0.6)))
		b.add_theme_color_override("font_color", Color.BLACK)
		b.add_theme_color_override("font_hover_color", Color.BLACK)
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
		var estado := "marcada" if selecionados.has(c) else ""
		cartas_escolha.add_child(_carta_2d(c, TAM_ESCOLHA, _alternar_mulligan.bind(c), estado))
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
	rotulo_dica.text = "%s%sArraste %d Cavaleiro%s da mão para a mesa. Entram de graça." % [_vez(jogador), inicio, faltam, "" if faltam == 1 else "s"]


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
		cartas_escolha.add_child(_carta_2d(c, TAM_ESCOLHA, _equipar.bind(c, item)))
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
				cartas_escolha.add_child(_carta_2d(c, TAM_ESCOLHA, acao, "" if pode else "apagada"))
		"cavaleiro_evento":
			var ev: Dictionary = cat.eventos[dados["evento"]]
			_abrir_escolha("%s%s\n%s\n\nEscolha o Cavaleiro." % [vez, ev["nome"], ev["efeito"]])
			for c in quem.fila:
				cartas_escolha.add_child(_carta_2d(c, TAM_ESCOLHA, _responder.bind(decisor, c.id_instancia)))
		"descarte":
			var ev: Dictionary = cat.eventos[dados["evento"]]
			_abrir_escolha(vez + dados.get("texto", "%s\n%s\n\nToque numa carta da mão para descartá-la." % [ev["nome"], ev["efeito"]]))
			for c in quem.mao:
				cartas_escolha.add_child(_carta_2d(c, TAM_ESCOLHA, _responder.bind(decisor, c.id_instancia)))
			for item in quem.itens_mao:
				cartas_escolha.add_child(_carta_item_2d(item, TAM_ESCOLHA, _responder.bind(decisor, item["id"])))
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
			cartas_escolha.add_child(_carta_2d(c, TAM_ESCOLHA, _tela_empate.bind(decisor, quem, grupo, escolhidos + [c])))
	if escolhidos.is_empty():
		_botao_escolha("Manter ordem atual", _responder.bind(decisor, grupo))


func _tela_mercador(decisor, quem, oferta: Array) -> void:
	var total := 0
	for item in selecionados:
		total += int(item["preco_mercador"])
	_abrir_escolha("%sMercador! Toque nos itens que quer comprar. Você tem %d moedas." % [_vez(quem), quem.moedas])
	for item in oferta:
		cartas_escolha.add_child(_carta_item_2d(item, TAM_ESCOLHA, _alternar_item.bind(decisor, quem, oferta, item), "marcada" if selecionados.has(item) else ""))
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
