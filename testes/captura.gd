extends SceneTree
## Abre o menu e a mesa, faz a preparação da partida (arrastando cartas para a mesa),
## joga um turno atacando o inimigo, toca numa carta e salva capturas de tela.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1280x720 -s res://testes/captura.gd

var cena
var capturados: Dictionary = {}


func _initialize() -> void:
	var menu = load("res://cenas/menu.tscn").instantiate()
	root.add_child(menu)
	await _esperar(0.5)
	_salvar("0_menu")
	menu.queue_free()
	cena = load("res://cenas/principal.tscn").instantiate()
	root.add_child(cena)
	await _esperar(0.8)
	_salvar("1_reino_inicial")
	_apertar("Pântano Maluco")
	await _esperar(0.6)
	_salvar("2_mulligan")
	_apertar("Manter mão")
	await _esperar(0.4)
	for n in 3:
		var livres: Array = cena.jogador.mao.filter(func(c): return not cena.pendentes.has(c))
		cena.jogar_em_campo(livres[0])
		if n == 0:
			await _esperar(0.6)
			_salvar("3_colocando_iniciais")
	await _esperar(0.8)
	for tentativa in 4:
		if cena.camada_escolha.visible:
			_salvar("4_empate_de_honra")
			_apertar("Manter ordem atual")
			await _esperar(0.5)
	_salvar("5_preparacao")
	# Põe um inimigo no topo do reino para a captura mostrar o ataque.
	var baralho: Array = cena.partida.baralhos_reino[cena.jogador.reino_atual]
	if baralho.has("mercenario_do_deserto"):
		baralho.erase("mercenario_do_deserto")
		baralho.push_front("mercenario_do_deserto")
	_apertar("Explorar o reino")
	for passo in 80:
		await _esperar(0.4)
		if _botao_existe("Próximo turno") or cena.partida.playtest_encerrado:
			break
		if cena.camada_dado.visible and cena.dado_aguardando:
			_salvar_uma_vez("8a_jogue_o_dado")
			cena._lancar_dado()
			await _esperar(0.3)
			_salvar_uma_vez("8b_dado_girando")
			await _esperar(0.7)
			_salvar_uma_vez("8c_resultado_do_dado")
		elif cena.camada_dado.visible:
			pass
		elif cena.modo == "ataque":
			_salvar_uma_vez("6_vez_de_atacar")
			cena.atacar()
			await _esperar(0.25)
			_salvar_uma_vez("7_dado_e_dano")
		elif cena.camada_escolha.visible:
			_salvar_uma_vez("8_escolha_" + str(passo))
			_resolver_escolha()
		elif cena.modo == "reerguer":
			var livres: Array = cena.jogador.mao.filter(func(c): return not cena.pendentes.has(c))
			if not livres.is_empty():
				cena.jogar_em_campo(livres[0])
	await _esperar(0.6)
	_salvar("9_fim_do_turno")
	if not cena.jogador.fila.is_empty() and not cena.camada_escolha.visible:
		var no: Node3D = cena.cartas_3d[cena._chave(cena.jogador.fila[0])]
		_clicar(cena.camera.unproject_position(no.position))
		await _esperar(0.4)
		_salvar("10_detalhes_da_carta")
		print("Detalhes visíveis: %s" % cena.camada_detalhes.visible)
	print("Dica final: " + cena.rotulo_dica.text)
	quit()


## Escolhe a opção mais segura: o último botão; sem botões, a primeira carta.
func _resolver_escolha() -> void:
	var botoes: Array = cena.botoes_escolha.get_children().filter(func(b): return b is Button and not b.disabled)
	if not botoes.is_empty():
		botoes[-1].pressed.emit()
		return
	for carta in cena.cartas_escolha.get_children():
		if carta.modulate.r > 0.9:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = false
			carta.gui_input.emit(ev)
			return


func _botao_existe(texto: String) -> bool:
	for b in cena.acoes.get_children():
		if b is Button and b.text == texto:
			return true
	return false


func _clicar(ponto: Vector2) -> void:
	for apertado in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = apertado
		ev.position = ponto
		ev.global_position = ponto
		root.push_input(ev)


func _apertar(texto: String) -> void:
	for b in cena.botoes_escolha.get_children() + cena.acoes.get_children():
		if b is Button and b.text == texto and not b.disabled:
			b.pressed.emit()
			return
	print("Botão não encontrado: " + texto)


func _esperar(segundos: float) -> void:
	await create_timer(segundos).timeout
	await process_frame
	await process_frame


func _salvar_uma_vez(nome: String) -> void:
	var tipo := nome.split("_")[0]
	if capturados.has(tipo):
		return
	capturados[tipo] = true
	_salvar(nome)


func _salvar(nome: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://capturas/miniaturas")
	var imagem := root.get_viewport().get_texture().get_image()
	imagem.save_png("res://capturas/%s.png" % nome)
	imagem.resize(imagem.get_width() / 2, imagem.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	imagem.save_png("res://capturas/miniaturas/%s.png" % nome)
	print("Captura salva: " + nome)
