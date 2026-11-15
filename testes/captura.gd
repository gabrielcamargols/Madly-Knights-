extends SceneTree
## Abre o menu e a mesa e joga um turno usando entrada real (toques e arraste),
## conferindo o que a tela mostra. Salva capturas para revisão.
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
	# Seleção: toca na primeira carta do mulligan (fica marcada) e troca.
	var primeira: Control = cena.cartas_escolha.get_child(0)
	await _tocar(primeira.get_global_rect().get_center())
	await _esperar(0.3)
	_salvar("2_mulligan_com_selecao")
	print("Mulligan: %d carta(s) marcada(s) pelo toque" % cena.selecionados.size())
	_apertar("Trocar 1 marcada")
	await _esperar(0.4)
	_apertar("Manter mão")
	await _esperar(0.6)
	# Mão inteira dentro da tela.
	var tela: Rect2 = root.get_visible_rect()
	var dentro := true
	for carta in cena.mao_2d.get_children():
		var r: Rect2 = carta.get_global_rect()
		if r.position.y < 0 or r.end.y > tela.size.y + 1 or r.position.x < 0 or r.end.x > tela.size.x:
			dentro = false
	print("Mão inteira visível: %s (%d cartas, mão de y=%d a y=%d, tela %d)" % [dentro, cena.mao_2d.get_child_count(), int(cena.mao_2d.get_global_rect().position.y), int(cena.mao_2d.get_global_rect().end.y), int(tela.size.y)])
	_salvar("3_mao_e_vagas")
	# Arraste real: três cartas da mão até a vaga iluminada.
	for n in 3:
		var carta: Control = cena.mao_2d.get_child(0)
		var de := carta.get_global_rect().get_center()
		var para: Vector2 = cena.camera.unproject_position(cena._pos_vaga(cena.pendentes.size()))
		await _arrastar(de, para, n == 0)
		await _esperar(0.5)
	print("Arraste: %d Cavaleiro(s) em campo após 3 arrastes" % cena.jogador.fila.size())
	for tentativa in 4:
		if cena.camada_escolha.visible:
			_salvar("5_empate_de_honra")
			_apertar("Manter ordem atual")
			await _esperar(0.5)
	print("Ordem de ataque (fila): %s" % ", ".join(cena.jogador.fila.map(func(c): return "%s(H%d)" % [c.nome, c.honra()])))
	_salvar("6_preparacao")
	# Põe um inimigo no topo para a captura mostrar o combate.
	var baralho: Array = cena.partida.baralhos_reino[cena.jogador.reino_atual]
	if baralho.has("mercenario_do_deserto"):
		baralho.erase("mercenario_do_deserto")
		baralho.push_front("mercenario_do_deserto")
	_apertar("Explorar o reino")
	for passo in 90:
		await _esperar(0.35)
		if _botao_existe("Próximo turno") or cena.partida.playtest_encerrado:
			break
		if cena.vitrine.visible:
			_salvar_uma_vez("7_revelacao")
		if cena.camada_dado.visible and cena.dado_aguardando:
			_salvar_uma_vez("9_jogue_o_dado")
			cena._lancar_dado()
		elif cena.camada_dado.visible:
			_salvar_uma_vez("10_dado_rolando")
		elif cena.modo == "ataque":
			_salvar_uma_vez("8_vez_de_atacar")
			# Toque real no inimigo.
			await _tocar(cena.camera.unproject_position(cena.POS_ENCONTRO + Vector3(0, 0.6, 0)))
		elif cena.faixa.visible:
			_salvar_uma_vez("11_faixa")
		elif cena.legenda.visible:
			_salvar_uma_vez("12_legenda")
		elif cena.camada_escolha.visible:
			_salvar_uma_vez("13_escolha")
			_resolver_escolha()
		elif cena.modo == "reerguer":
			var livres: Array = cena.jogador.mao.filter(func(c): return not cena.pendentes.has(c))
			if not livres.is_empty():
				cena.jogar_em_campo(livres[0])
	await _esperar(0.6)
	_salvar("14_fim_do_turno")
	var j = cena.jogador
	print("Contadores: moedas=%d (%s), inimigos=%d (%s), eventos=%d (%s)" % [j.moedas, cena.chips["moedas"].text, j.inimigos, cena.chips["inimigos"].text, j.eventos, cena.chips["eventos"].text])
	if not j.fila.is_empty():
		var no: Node3D = cena.cartas_3d[cena._chave(j.fila[0])]
		await _tocar(cena.camera.unproject_position(no.position + Vector3(0, 0.5, 0)))
		await _esperar(0.4)
		_salvar("15_detalhes_da_carta")
		print("Detalhes abertos pelo toque na figura: %s" % cena.camada_detalhes.visible)
	print("Dica final: " + cena.rotulo_dica.text)
	quit()


func _resolver_escolha() -> void:
	var botoes: Array = cena.botoes_escolha.get_children().filter(func(b): return b is Button and not b.disabled)
	if not botoes.is_empty():
		botoes[-1].pressed.emit()
		return
	for carta in cena.cartas_escolha.get_children():
		if carta.modulate.r > 0.9:
			await _tocar(carta.get_global_rect().get_center())
			return


func _botao_existe(texto: String) -> bool:
	for b in cena.acoes.get_children():
		if b is Button and b.text == texto:
			return true
	return false


func _mouse(posicao: Vector2, apertado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = apertado
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	ev.position = posicao
	ev.global_position = posicao
	root.push_input(ev)


func _tocar(posicao: Vector2) -> void:
	_mouse(posicao, true)
	await process_frame
	_mouse(posicao, false)
	await process_frame


## Arraste de verdade: aperta, move em passos e solta.
func _arrastar(de: Vector2, para: Vector2, capturar: bool) -> void:
	_mouse(de, true)
	await process_frame
	var anterior := de
	for k in range(1, 16):
		var p := de.lerp(para, k / 15.0)
		var ev := InputEventMouseMotion.new()
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev.position = p
		ev.global_position = p
		ev.relative = p - anterior
		root.push_input(ev)
		anterior = p
		await process_frame
		if capturar and k == 12:
			_salvar("4_arrastando_para_a_vaga")
	_mouse(para, false)
	await process_frame


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
