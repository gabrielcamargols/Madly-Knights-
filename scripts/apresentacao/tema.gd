extends RefCounted
## Tema visual da interface: madeira, pergaminho e latão, com fontes Lora (títulos)
## e Poppins (textos). Usado pelo menu e pela mesa.

const MADEIRA := Color(0.42, 0.27, 0.15)
const MADEIRA_CLARA := Color(0.55, 0.37, 0.2)
const MADEIRA_ESCURA := Color(0.24, 0.15, 0.08)
const PERGAMINHO := Color(0.95, 0.89, 0.74)
const PERGAMINHO_ESCURO := Color(0.84, 0.75, 0.56)
const TINTA := Color(0.26, 0.16, 0.09)
const LATAO := Color(0.86, 0.66, 0.28)
const CREME := Color(1.0, 0.95, 0.84)

static var _titulo: FontVariation
static var _texto: FontFile
static var _texto_forte: FontFile


static func fonte_titulo() -> Font:
	if _titulo == null:
		_titulo = FontVariation.new()
		_titulo.base_font = load("res://fontes/Lora-Variable.ttf")
		_titulo.variation_opentype = {"wght": 700}
	return _titulo


static func fonte_texto() -> Font:
	if _texto == null:
		_texto = load("res://fontes/Poppins-Medium.ttf")
	return _texto


static func fonte_forte() -> Font:
	if _texto_forte == null:
		_texto_forte = load("res://fontes/Poppins-Bold.ttf")
	return _texto_forte


static func caixa(fundo: Color, borda: Color, espessura: int = 3, raio: int = 12, margem: int = 10, sombra: int = 0) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fundo
	c.border_color = borda
	c.set_border_width_all(espessura)
	c.set_corner_radius_all(raio)
	c.content_margin_left = margem
	c.content_margin_right = margem
	c.content_margin_top = margem * 0.7
	c.content_margin_bottom = margem * 0.7
	if sombra > 0:
		c.shadow_color = Color(0, 0, 0, 0.35)
		c.shadow_size = sombra
		c.shadow_offset = Vector2(0, sombra * 0.5)
	return c


## Painel de madeira (barras e botões).
static func madeira(clara: bool = false) -> StyleBoxFlat:
	var c := caixa(MADEIRA_CLARA if clara else MADEIRA, MADEIRA_ESCURA, 3, 10, 12, 4)
	c.border_width_top = 2
	c.border_width_bottom = 5
	return c


## Painel de pergaminho emoldurado em madeira (janelas e avisos).
static func pergaminho(margem: int = 18) -> StyleBoxFlat:
	var c := caixa(PERGAMINHO, MADEIRA, 6, 14, margem, 10)
	return c


static func criar() -> Theme:
	var t := Theme.new()
	t.default_font = fonte_texto()
	t.default_font_size = 20
	# Botões de madeira com borda de latão.
	var normal := caixa(MADEIRA, LATAO.darkened(0.25), 3, 12, 14, 4)
	normal.border_width_bottom = 5
	var foco := caixa(MADEIRA_CLARA, LATAO, 3, 12, 14, 6)
	foco.border_width_bottom = 5
	var apertado := caixa(MADEIRA_ESCURA, LATAO.darkened(0.25), 3, 12, 14, 0)
	apertado.border_width_top = 5
	apertado.border_width_bottom = 2
	var desligado := caixa(Color(0.4, 0.34, 0.28), Color(0.3, 0.25, 0.2), 3, 12, 14, 0)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", foco)
	t.set_stylebox("pressed", "Button", apertado)
	t.set_stylebox("hover_pressed", "Button", apertado)
	t.set_stylebox("disabled", "Button", desligado)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREME)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", LATAO)
	t.set_color("font_hover_pressed_color", "Button", LATAO)
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.65, 0.58))
	t.set_font("font", "Button", fonte_forte())
	# Pergaminho como painel padrão; texto em tinta escura.
	t.set_stylebox("panel", "PanelContainer", pergaminho())
	t.set_color("font_color", "Label", TINTA)
	t.set_color("default_color", "RichTextLabel", TINTA)
	t.set_font("bold_font", "RichTextLabel", fonte_titulo())
	return t


## Botão principal (ação do turno): verde de brasão com latão.
static func botao_principal(b: Button) -> void:
	var normal := caixa(Color(0.2, 0.45, 0.22), LATAO, 4, 14, 16, 6)
	normal.border_width_bottom = 7
	var foco := caixa(Color(0.25, 0.55, 0.27), Color(1, 0.85, 0.45), 4, 14, 16, 8)
	foco.border_width_bottom = 7
	var apertado := caixa(Color(0.15, 0.35, 0.17), LATAO, 4, 14, 16, 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", foco)
	b.add_theme_stylebox_override("pressed", apertado)
	b.add_theme_font_override("font", fonte_titulo())
