extends SceneTree
## Abre o menu e a mesa, passa pela preparação da partida e salva capturas de tela.
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
	_salvar("capturas/1_reino_inicial.png")
	_apertar("Pântano Maluco")
	await _esperar(0.8)
	_salvar("capturas/2_mao_inicial.png")
	_apertar("Manter mão")
	await _esperar(0.2)
	var marcados := 0
	for b in cena.botoes.get_children() + cena.lista.get_children():
		if b is Button and b.toggle_mode and marcados < 3:
			b.button_pressed = true
			marcados += 1
	_apertar("Confirmar")
	await _esperar(0.8)
	for tentativa in 4:
		if "empate" in cena.rotulo_pergunta.text:
			_salvar("capturas/3_empate_de_honra.png")
			_apertar("Manter ordem atual")
			await _esperar(0.5)
	_salvar("capturas/4_preparacao.png")
	_apertar("Explorar o reino")
	await _esperar(1.0)
	_salvar("capturas/5_primeiro_turno.png")
	print("Pergunta final: " + cena.rotulo_pergunta.text)
	quit()


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
