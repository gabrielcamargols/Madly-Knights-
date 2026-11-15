extends Control
## Menu inicial provisório.

const Sessao = preload("res://scripts/apresentacao/sessao.gd")
const Tema = preload("res://scripts/apresentacao/tema.gd")

var painel_principal: VBoxContainer
var painel_jogar: VBoxContainer
var painel_regras: VBoxContainer
var botoes_jogadores: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.criar()
	add_theme_font_size_override("font_size", 24)
	var fundo := ColorRect.new()
	fundo.color = Color(0.16, 0.22, 0.15)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var coluna := VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(520, 0)
	coluna.add_theme_constant_override("separation", 18)
	centro.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "MADLY\nKNIGHTS!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 84)
	titulo.add_theme_font_override("font", Tema.fonte_titulo())
	titulo.add_theme_color_override("font_color", Color(0.98, 0.82, 0.3))
	titulo.add_theme_color_override("font_outline_color", Tema.MADEIRA_ESCURA)
	titulo.add_theme_constant_override("outline_size", 18)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "Protótipo • Pântano Maluco"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7))
	coluna.add_child(subtitulo)

	painel_principal = _painel(coluna)
	_botao(painel_principal, "Jogar", _mostrar.bind("jogar"))
	_botao(painel_principal, "Como jogar", _mostrar.bind("regras"))
	if not OS.has_feature("web"):
		_botao(painel_principal, "Sair", get_tree().quit)

	painel_jogar = _painel(coluna)
	var rotulo := Label.new()
	rotulo.text = "Quantos jogadores neste aparelho?"
	rotulo.add_theme_color_override("font_color", Tema.CREME)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painel_jogar.add_child(rotulo)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 12)
	painel_jogar.add_child(linha)
	for n in range(1, 5):
		var b := Button.new()
		b.text = str(n)
		b.toggle_mode = true
		b.button_pressed = n == Sessao.jogadores
		b.custom_minimum_size = Vector2(90, 80)
		b.pressed.connect(_escolher_jogadores.bind(n))
		linha.add_child(b)
		botoes_jogadores.append(b)
	_botao(painel_jogar, "Começar partida", _comecar)
	_botao(painel_jogar, "Voltar", _mostrar.bind("principal"))

	painel_regras = _painel(coluna)
	var texto := RichTextLabel.new()
	texto.fit_content = true
	texto.add_theme_color_override("default_color", Tema.CREME)
	texto.custom_minimum_size = Vector2(520, 0)
	texto.text = "Cada jogador começa com 6 moedas, escolhe o reino inicial e compra 5 Cavaleiros. Pode trocar cartas no mulligan e coloca 3 em campo de graça. A fila se ordena pela Honra.\n\nNo turno: Preparação (comprar, recrutar, equipar), Exploração (revelar uma carta do reino), Resolução, Reposição e Avanço.\n\nO primeiro da fila ataca. D6: 1 erra, 2 causa 1, 3 metade da Força, 4–5 a Força, 6 o dobro.\n\nDerrote 4 inimigos, supere 3 Eventos ou vença o chefe para concluir o reino. O protótipo termina no primeiro avanço."
	painel_regras.add_child(texto)
	_botao(painel_regras, "Voltar", _mostrar.bind("principal"))
	_mostrar("principal")


func _painel(pai: Control) -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 14)
	pai.add_child(p)
	return p


func _botao(pai: Control, texto: String, acao: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(acao)
	pai.add_child(b)


func _mostrar(qual: String) -> void:
	painel_principal.visible = qual == "principal"
	painel_jogar.visible = qual == "jogar"
	painel_regras.visible = qual == "regras"


func _escolher_jogadores(n: int) -> void:
	Sessao.jogadores = n
	for i in botoes_jogadores.size():
		botoes_jogadores[i].button_pressed = i + 1 == n


func _comecar() -> void:
	get_tree().change_scene_to_file("res://cenas/principal.tscn")
