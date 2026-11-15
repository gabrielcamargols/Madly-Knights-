extends Node3D
## Mesa 3D jogável do playtest no Pântano Maluco.
## Só lê o estado da partida e mostra os resultados que a lógica devolveu;
## não decide regras nem rola dados. Os Cavaleiros usam modelos temporários.

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")
const DecisorInterface = preload("res://scripts/apresentacao/decisor_interface.gd")

const ESPACO_CARTA := 1.15
const POS_FILA_Z := 0.5
const POS_MAO_Z := 2.3
const POS_ENCONTRO := Vector3(0.0, 0.0, -1.6)
const POS_REINO := Vector3(-2.4, 0.0, -1.6)
const POS_CEMITERIO := Vector3(2.4, 0.0, -1.6)
const POS_BARALHO := Vector3(-4.5, 0.0, 2.3)

var cat
var partida
var jogador
var decisor
var cartas_3d: Dictionary = {}  # id_instancia -> Node3D
var carta_encontro: Node3D
var pilha_reino: Node3D
var rotulo_cemiterio: Label3D
var selecionados: Array = []

var rotulo_status: Label
var rotulo_pergunta: Label
var botoes: HFlowContainer
var lista: VBoxContainer  # opções longas, uma por linha
var registro: RichTextLabel


func _ready() -> void:
	_criar_ambiente()
	_criar_interface()
	cat = Catalogo.new()
	if not cat.carregar():
		rotulo_pergunta.text = "Erro ao carregar os dados do jogo."
		return
	carta_encontro = _criar_carta("Pântano Maluco", Color(0.45, 0.6, 0.4))
	carta_encontro.position = POS_ENCONTRO
	pilha_reino = _criar_carta("Reino", Color(0.3, 0.42, 0.3))
	pilha_reino.position = POS_REINO
	rotulo_cemiterio = Label3D.new()
	rotulo_cemiterio.text = "Cemitério"
	rotulo_cemiterio.font_size = 48
	rotulo_cemiterio.pixel_size = 0.005
	rotulo_cemiterio.rotation_degrees.x = -90
	rotulo_cemiterio.position = POS_CEMITERIO + Vector3(0, 0.01, 0.95)
	add_child(rotulo_cemiterio)
	nova_partida()


func nova_partida() -> void:
	for no in cartas_3d.values():
		no.queue_free()
	cartas_3d.clear()
	registro.clear()
	_rotular(carta_encontro, "Pântano Maluco")
	partida = Partida.new(cat, Dado.new(), Embaralhador.new())
	partida.registrou.connect(_ao_registrar)
	partida.revelou.connect(_ao_revelar)
	decisor = DecisorInterface.new()
	decisor.pedido.connect(_ao_pedido)
	partida.montar_mesa()
	jogador = partida.adicionar_jogador("j1", [], decisor)
	partida.comprar_mao_inicial(jogador)
	_atualizar(false)
	_tela_mulligan()


# --- Cena 3D --------------------------------------------------------------------

func _criar_ambiente() -> void:
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 48
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 7.5, 6.0), Vector3(0, 0, 2.4))
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


## Posiciona cada Cavaleiro na fila, na mão ou no Cemitério, com animação.
func _atualizar(animar: bool) -> void:
	if jogador == null:
		return
	var destinos := {}
	var n: int = jogador.fila.size()
	for i in n:
		destinos[jogador.fila[i]] = Vector3((i - (n - 1) / 2.0) * ESPACO_CARTA, 0.0, POS_FILA_Z)
	var m: int = jogador.mao.size()
	for i in m:
		destinos[jogador.mao[i]] = Vector3((i - (m - 1) / 2.0) * ESPACO_CARTA, 0.0, POS_MAO_Z)
	for i in jogador.cemiterio.size():
		destinos[jogador.cemiterio[i]] = POS_CEMITERIO + Vector3(0, 0.07 * i, 0)
	for id in cartas_3d.keys():
		if not destinos.keys().any(func(c): return c.id_instancia == id):
			cartas_3d[id].visible = false
	for c in destinos:
		if not cartas_3d.has(c.id_instancia):
			var nova := _criar_carta("", _cor_do_cavaleiro(c))
			nova.position = POS_BARALHO
			cartas_3d[c.id_instancia] = nova
		var carta: Node3D = cartas_3d[c.id_instancia]
		carta.visible = true
		_rotular(carta, _texto_do_cavaleiro(c))
		if animar:
			var tween := create_tween()
			tween.tween_property(carta, "position", destinos[c], 0.45).set_trans(Tween.TRANS_CUBIC)
		else:
			carta.position = destinos[c]
	_rotular(pilha_reino, "%s\n%d cartas" % [jogador.reino_atual, partida.baralhos_reino[jogador.reino_atual].size()])
	var itens := "nenhum"
	if not jogador.itens_mao.is_empty():
		itens = ", ".join(jogador.itens_mao.map(func(i): return i["nome"]))
	rotulo_status.text = "%s   •   Moedas: %d\nInimigos: %d/4   Eventos: %d/3   Itens na mão: %s" % [
		jogador.reino_atual, jogador.moedas, jogador.inimigos, jogador.eventos, itens]


func _ao_revelar(carta_id: String) -> void:
	_rotular(carta_encontro, cat.nome_de_carta(carta_id))


func _ao_registrar(texto: String) -> void:
	if registro != null:
		registro.append_text(texto + "\n")


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

	var topo := PanelContainer.new()
	raiz.add_child(topo)
	topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rotulo_status = Label.new()
	rotulo_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topo.add_child(rotulo_status)

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
	registro.custom_minimum_size = Vector2(0, 190)
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 17)
	coluna.add_child(registro)


func _perguntar(texto: String) -> void:
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
		# Opção longa: ocupa a linha inteira e quebra o texto.
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


# --- Início -----------------------------------------------------------------------

func _tela_mulligan() -> void:
	_perguntar("Sua mão inicial. Marque as cartas que quer trocar (mulligan) ou mantenha a mão.")
	selecionados = []
	for c in jogador.mao:
		_alternavel(_rotulo_cavaleiro(c), c)
	_botao("Trocar marcadas", _trocar_marcadas)
	_botao("Manter mão", _tela_iniciais)


func _trocar_marcadas() -> void:
	if selecionados.is_empty():
		return
	partida.fazer_mulligan(jogador, selecionados)
	_atualizar(true)
	_tela_mulligan()


func _tela_iniciais() -> void:
	_perguntar("Escolha 3 Cavaleiros para entrar em campo de graça. A fila se ordena pela Honra.")
	selecionados = []
	for c in jogador.mao:
		_alternavel(_rotulo_cavaleiro(c), c)
	_botao("Confirmar", _confirmar_iniciais)


func _confirmar_iniciais() -> void:
	if selecionados.size() != mini(3, jogador.mao.size()):
		rotulo_pergunta.text = "Marque exatamente 3 Cavaleiros."
		return
	partida.colocar_iniciais(jogador, selecionados)
	_atualizar(true)
	_comecar_turno()


# --- Turno ------------------------------------------------------------------------

func _comecar_turno() -> void:
	_perguntar("")
	var avancou: bool = await partida.iniciar_turno(jogador)
	_atualizar(true)
	if avancou or partida.playtest_encerrado:
		_tela_final()
		return
	_tela_preparacao()


func _tela_preparacao() -> void:
	_atualizar(true)
	_perguntar("Preparação: compre, recrute ou equipe. Depois explore o reino.")
	_botao("Explorar o reino", _explorar)
	_botao("Comprar Cavaleiro (1)", _comprar_cavaleiro, not jogador.comprou_cavaleiro_no_turno and jogador.moedas >= 1)
	var tem_itens: bool = not partida.baralho_itens.is_empty() or not partida.descarte_itens.is_empty()
	_botao("Compra às cegas (4)", _comprar_as_cegas, not jogador.comprou_as_cegas_no_turno and jogador.moedas >= 4 and tem_itens)
	for c in jogador.mao:
		_botao("Recrutar %s (%d)" % [_nome_curto(c), c.custo()], _recrutar.bind(c), jogador.fila.size() < 6 and jogador.moedas >= c.custo())
	for item in jogador.itens_mao:
		_botao("Equipar %s" % item["nome"], _escolher_portador.bind(item))


func _comprar_cavaleiro() -> void:
	partida.comprar_cavaleiro(jogador)
	_tela_preparacao()


func _comprar_as_cegas() -> void:
	partida.comprar_as_cegas(jogador)
	_tela_preparacao()


func _recrutar(c) -> void:
	partida.recrutar_da_mao(jogador, c.id_instancia)
	_tela_preparacao()


func _escolher_portador(item: Dictionary) -> void:
	_perguntar("Quem vai equipar %s? (%s: %s)" % [item["nome"], item["categoria"], item["efeito"]])
	for c in jogador.fila + jogador.mao:
		_botao(_rotulo_cavaleiro(c), _equipar.bind(c, item))
	_botao("Voltar", _tela_preparacao)


func _equipar(c, item: Dictionary) -> void:
	partida.equipar_item(jogador, c.id_instancia, item["id"])
	_tela_preparacao()


func _explorar() -> void:
	_perguntar("Explorando…")
	var moedas_antes: int = jogador.moedas
	await partida.explorar_e_resolver(jogador)
	_atualizar(true)
	if partida.playtest_encerrado:
		_tela_final()
		return
	var saldo: int = jogador.moedas - moedas_antes
	_perguntar("Fim do turno. Moedas: %d (%s%d). Veja os detalhes no registro abaixo." % [jogador.moedas, "+" if saldo >= 0 else "", saldo])
	_botao("Próximo turno", _comecar_turno)


func _tela_final() -> void:
	var r: Dictionary = partida.relatorio
	_perguntar("Playtest concluído! Você concluiu %s (%s) e chegou a %s com %d moedas." % [
		r.get("reino_concluido", "o Pântano"), _texto_avanco(r.get("avanco_por", "")), jogador.reino_atual, jogador.moedas])
	_botao("Jogar de novo", nova_partida)


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

func _ao_pedido(tipo: String, dados: Dictionary) -> void:
	_atualizar(true)
	match tipo:
		"mercador":
			_tela_mercador(dados["oferta"])
		"reposicao":
			_tela_reposicao(dados["reveladas"], dados["pagaveis"])
		"cavaleiro_evento":
			_tela_cavaleiro_evento(dados["evento"])
		"descarte":
			_tela_descarte(dados)
		"conversao":
			_perguntar("Reino concluído! Converta o Prestígio dos Cavaleiros em campo.")
			_botao("Moedas (+%d)" % dados["total"], decisor.responder.bind("moedas"))
			_botao("Status permanente", decisor.responder.bind("status"))
		"status":
			var c = dados["cavaleiro"]
			var p: int = c.prestigio()
			_perguntar("%s tem %d de Prestígio. Onde aplicar os pontos?" % [c.nome, p])
			_botao("+%d Força" % p, decisor.responder.bind({"forca": p, "armadura": 0, "honra": 0}))
			_botao("+%d Armadura máxima" % p, decisor.responder.bind({"forca": 0, "armadura": p, "honra": 0}))
			_botao("+%d Honra" % p, decisor.responder.bind({"forca": 0, "armadura": 0, "honra": p}))
		"reino":
			_perguntar("Chefe derrotado! Escolha o próximo reino.")
			for r in dados["permitidos"]:
				_botao(r, decisor.responder.bind(r))
		_:
			decisor.responder(null)


func _tela_mercador(oferta: Array) -> void:
	selecionados = []
	_perguntar("Mercador! Marque os itens que quer comprar. Você tem %d moedas." % jogador.moedas)
	for item in oferta:
		_alternavel("%s (%d)\n%s" % [item["nome"], int(item["preco_mercador"]), item["efeito"]], item)
	_botao("Comprar marcados", _confirmar_mercador)
	_botao("Não comprar nada", decisor.responder.bind([]))


func _confirmar_mercador() -> void:
	var total := 0
	for item in selecionados:
		total += int(item["preco_mercador"])
	if total > jogador.moedas:
		rotulo_pergunta.text = "Os itens marcados custam %d e você tem %d moedas." % [total, jogador.moedas]
		return
	decisor.responder(selecionados.map(func(i): return i["id"]))


func _tela_reposicao(reveladas: Array, pagaveis: Array) -> void:
	var nomes := ", ".join(reveladas.map(func(c): return _nome_curto(c)))
	_perguntar("Reposição: saíram %s. Escolha quem entra em campo pagando o Prestígio; a outra carta vai ao Cemitério." % nomes)
	for c in pagaveis:
		_botao("%s (%d moedas)" % [_rotulo_cavaleiro(c), c.custo()], decisor.responder.bind(c))


func _tela_cavaleiro_evento(evento_id: String) -> void:
	var ev: Dictionary = cat.eventos[evento_id]
	_perguntar("%s\n%s\nEscolha o Cavaleiro." % [ev["nome"], ev["efeito"]])
	for c in jogador.fila:
		_botao(_rotulo_cavaleiro(c), decisor.responder.bind(c.id_instancia))


func _tela_descarte(dados: Dictionary) -> void:
	var ev: Dictionary = cat.eventos[dados["evento"]]
	_perguntar(dados.get("texto", "%s\n%s" % [ev["nome"], ev["efeito"]]))
	_botao(dados["recusa"], decisor.responder.bind(null))
	for c in jogador.mao:
		_botao("Descartar %s" % _nome_curto(c), decisor.responder.bind(c.id_instancia))
	for item in jogador.itens_mao:
		_botao("Descartar %s" % item["nome"], decisor.responder.bind(item["id"]))
