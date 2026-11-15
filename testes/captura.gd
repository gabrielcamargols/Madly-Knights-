extends SceneTree
## Abre a mesa jogável, passa pelo início de partida e salva capturas de tela.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://testes/captura.gd

var cena


func _initialize() -> void:
	cena = load("res://cenas/principal.tscn").instantiate()
	root.add_child(cena)
	await _esperar(1.0)
	_salvar("capturas/1_mao_inicial.png")
	cena._tela_iniciais()
	cena.selecionados = cena.jogador.mao.slice(0, 3)
	cena._confirmar_iniciais()
	await _esperar(1.0)
	_salvar("capturas/2_preparacao.png")
	cena._explorar()
	await _esperar(1.0)
	_salvar("capturas/3_primeira_exploracao.png")
	quit()


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
