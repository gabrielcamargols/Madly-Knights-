extends SceneTree
## Abre o menu e a mesa, passa pela preparação da partida (arrastando cartas da
## mão para a mesa), joga um turno, toca numa carta e salva capturas de tela.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://testes/captura.gd

var cena


func _initialize() -> void:
	var menu = load("res://cenas/menu.tscn").instantiate()
	root.add_child(menu)
	await _esperar(0.5)
	_salvar("capturas/0_menu.png")
	menu.queue_free()
	cena = load("res://cenas/principal.tscn").instantiate()
	root.add_child(cena)
	await _esperar(0.8)
	_apertar("Pântano Maluco")
	await _esperar(0.8)
	_salvar("capturas/1_mao_inicial.png")
	_apertar("Manter mão")
	await _esperar(0.3)
	for n in 3:
		var livres: Array = cena.jogador.mao.filter(func(c): return not cena.pendentes.has(c))
		cena.jogar_em_campo(livres[0])
		if n == 0:
			await _esperar(0.6)
			_salvar("capturas/2_arrastando_iniciais.png")
	await _esperar(0.8)
	for tentativa in 4:
		if "empate" in cena.rotulo_pergunta.text:
			_salvar("capturas/3_empate_de_honra.png")
			_apertar("Manter ordem atual")
			await _esperar(0.5)
	_salvar("capturas/4_preparacao.png")
	_apertar("Explorar o reino")
	await _esperar(1.6)
	_salvar("capturas/5_durante_o_turno.png")
	for espera in 20:
		if cena.rotulo_pergunta.text != "Explorando…":
			break
		await _esperar(0.5)
	_salvar("capturas/6_fim_do_turno.png")
	if not cena.jogador.fila.is_empty():
		var no: Node3D = cena.cartas_3d["%s/%s" % [cena.jogador.id, cena.jogador.fila[0].id_instancia]]
		var ponto: Vector2 = root.get_camera_3d().unproject_position(no.position)
		_clicar(ponto)
		await _esperar(0.4)
		_salvar("capturas/7_detalhes_da_carta.png")
		print("Detalhes visíveis: %s" % cena.detalhes.visible)
	print("Pergunta final: " + cena.rotulo_pergunta.text)
	quit()


func _clicar(ponto: Vector2) -> void:
	for apertado in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = apertado
		ev.position = ponto
		ev.global_position = ponto
		root.push_input(ev)


func _apertar(texto: String) -> void:
	for b in cena.botoes.get_children() + cena.lista.get_children():
		if b is Button and b.text == texto and not b.disabled:
			b.pressed.emit()
			return
	print("Botão não encontrado: " + texto)


func _esperar(segundos: float) -> void:
	await create_timer(segundos).timeout
	await process_frame
	await process_frame


func _salvar(caminho: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://capturas")
	var imagem := root.get_viewport().get_texture().get_image()
	imagem.resize(imagem.get_width() / 2, imagem.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	imagem.save_png("res://" + caminho)
	print("Captura salva: " + caminho)
