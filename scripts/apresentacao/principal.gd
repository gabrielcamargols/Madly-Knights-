extends Node3D
## Mesa 3D provisória do playtest no Pântano Maluco.
## Só lê o estado da partida e mostra os resultados que a lógica devolveu;
## não decide regras nem rola dados. Os Cavaleiros usam modelos temporários.

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")

const LARGURA_CARTA := 1.1
const POS_FILA_Z := 1.2
const POS_MAO_Z := 2.9
const POS_CEMITERIO := Vector3(4.2, 0.0, 1.2)
const POS_BARALHO := Vector3(-4.2, 0.0, 1.2)
const POS_ENCONTRO := Vector3(0.0, 0.0, -1.4)
const POS_REINO := Vector3(-2.2, 0.0, -1.4)

var partida
var jogador
var cartas_3d: Dictionary = {}  # id_instancia -> Node3D
var carta_encontro: Node3D
var pilha_reino: Node3D
var rotulo_status: Label
var registro: RichTextLabel
var botao: Button


func _ready() -> void:
	_criar_ambiente()
	_criar_interface()
	var cat = Catalogo.new()
	if not cat.carregar():
		registro.append_text("[color=red]Erro ao carregar os dados do jogo.[/color]\n")
		botao.disabled = true
		return
	partida = Partida.new(cat, Dado.new(), Embaralhador.new())
	partida.registrou.connect(_ao_registrar)
	partida.montar_mesa()
	jogador = partida.adicionar_jogador("j1")
	partida.preparar_inicio(jogador)
	carta_encontro = _criar_carta("Pântano Maluco", Color(0.35, 0.5, 0.3))
	carta_encontro.position = POS_ENCONTRO
	pilha_reino = _criar_carta("Reino", Color(0.25, 0.35, 0.25))
	pilha_reino.position = POS_REINO
	_atualizar(false)


func _criar_ambiente() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 8.5, 6.5), Vector3(0, 0, 0.6))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-60, 30, 0)
	luz.shadow_enabled = true
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	ambiente.environment = env
	add_child(ambiente)
	var mesa := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(12, 8)
	mesa.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.22, 0.15)
	mesa.material_override = material
	mesa.position.y = -0.04
	add_child(mesa)


func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	add_child(camada)
	var painel := VBoxContainer.new()
	painel.position = Vector2(16, 16)
	painel.custom_minimum_size = Vector2(440, 0)
	camada.add_child(painel)
	rotulo_status = Label.new()
	painel.add_child(rotulo_status)
	botao = Button.new()
	botao.text = "Jogar turno"
	botao.pressed.connect(_jogar_turno)
	painel.add_child(botao)
	registro = RichTextLabel.new()
	registro.custom_minimum_size = Vector2(440, 380)
	registro.scroll_following = true
	painel.add_child(registro)


func _criar_carta(texto: String, cor: Color) -> Node3D:
	var raiz := Node3D.new()
	var malha := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.95, 0.06, 1.35)
	malha.mesh = caixa
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	malha.material_override = material
	raiz.add_child(malha)
	var rotulo := Label3D.new()
	rotulo.name = "Rotulo"
	rotulo.text = texto
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0035
	rotulo.width = 260
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.rotation_degrees.x = -90
	rotulo.position.y = 0.04
	rotulo.modulate = Color.BLACK
	rotulo.outline_size = 0
	raiz.add_child(rotulo)
	add_child(raiz)
	return raiz


func _cor_do_cavaleiro(c) -> Color:
	match c.cor:
		"Amarelo":
			return Color(0.95, 0.85, 0.4)
		"Vermelho":
			return Color(0.9, 0.45, 0.4)
	return Color(0.8, 0.8, 0.8)


func _texto_do_cavaleiro(c) -> String:
	return "%s\nF%d  A%d/%d\nH%d  P%d" % [c.nome.replace("Cavaleiro ", ""), c.forca_total(), c.armadura_atual, c.armadura_maxima(), c.honra(), c.prestigio()]


func _jogar_turno() -> void:
	if partida == null or partida.playtest_encerrado:
		return
	var rel: Dictionary = partida.jogar_turno(jogador)
	var revelada: String = rel.get("revelacao", "")
	_rotular(carta_encontro, partida.cat.nome_de_carta(revelada) if revelada != "" else "—")
	_atualizar(true)
	if partida.playtest_encerrado:
		botao.disabled = true
		botao.text = "Playtest concluído: chegou a %s" % jogador.reino_atual


func _rotular(carta: Node3D, texto: String) -> void:
	(carta.get_node("Rotulo") as Label3D).text = texto


## Posiciona cada Cavaleiro na fila, na mão ou no Cemitério, com animação.
func _atualizar(animar: bool) -> void:
	var destinos := {}
	var n: int = jogador.fila.size()
	for i in n:
		destinos[jogador.fila[i]] = Vector3((i - (n - 1) / 2.0) * LARGURA_CARTA, 0.0, POS_FILA_Z)
	var m: int = jogador.mao.size()
	for i in m:
		destinos[jogador.mao[i]] = Vector3((i - (m - 1) / 2.0) * LARGURA_CARTA, 0.0, POS_MAO_Z)
	for i in jogador.cemiterio.size():
		destinos[jogador.cemiterio[i]] = POS_CEMITERIO + Vector3(0, 0.07 * i, 0)
	for c in destinos:
		if not cartas_3d.has(c.id_instancia):
			var nova := _criar_carta("", _cor_do_cavaleiro(c))
			nova.position = POS_BARALHO
			cartas_3d[c.id_instancia] = nova
		var carta: Node3D = cartas_3d[c.id_instancia]
		_rotular(carta, _texto_do_cavaleiro(c))
		if animar:
			var tween := create_tween()
			tween.tween_property(carta, "position", destinos[c], 0.45).set_trans(Tween.TRANS_CUBIC)
		else:
			carta.position = destinos[c]
	_rotular(pilha_reino, "%s\n%d cartas" % [jogador.reino_atual, partida.baralhos_reino[jogador.reino_atual].size()])
	rotulo_status.text = "Reino: %s\nMoedas: %d   Inimigos: %d/4   Eventos: %d/3\nItens: %s" % [
		jogador.reino_atual, jogador.moedas, jogador.inimigos, jogador.eventos,
		", ".join(jogador.itens_mao.map(func(i): return i["nome"])) if not jogador.itens_mao.is_empty() else "nenhum",
	]


func _ao_registrar(texto: String) -> void:
	if registro != null:
		registro.append_text(texto + "\n")
