extends "res://scripts/core/decisor.gd"
## Decisões tomadas pela pessoa na interface. Cada pergunta emite `pedido`
## e espera a interface chamar `responder()`.

signal pedido(tipo: String, dados: Dictionary)
signal respondido(valor)


var _tem_resposta := false
var _resposta = null


func responder(valor) -> void:
	_tem_resposta = true
	_resposta = valor
	respondido.emit(valor)


func _perguntar(tipo: String, dados: Dictionary) -> Variant:
	_tem_resposta = false
	pedido.emit(tipo, dados)
	# A interface pode responder na hora, antes de começarmos a esperar.
	if not _tem_resposta:
		await respondido
	_tem_resposta = false
	return _resposta


func escolher_iniciais(_partida, jogador) -> Array:
	var r = await _perguntar("iniciais", {"jogador": jogador})
	return r if r is Array else []


func ordem_de_empate(_partida, jogador, grupo: Array) -> Array:
	var r = await _perguntar("empate", {"jogador": jogador, "grupo": grupo})
	if r is Array and r.size() == grupo.size():
		return r
	return grupo


func escolher_atacante(_partida, jogador, opcoes: Array, inimigo) -> Variant:
	return await _perguntar("ataque", {"jogador": jogador, "opcoes": opcoes, "inimigo": inimigo})


func itens_para_comprar(_partida, jogador, oferta: Array) -> Array:
	var r = await _perguntar("mercador", {"jogador": jogador, "oferta": oferta})
	return r if r is Array else []


func escolher_reposicao(_partida, jogador, reveladas: Array, pagaveis: Array) -> Variant:
	return await _perguntar("reposicao", {"jogador": jogador, "reveladas": reveladas, "pagaveis": pagaveis})


func escolher_cavaleiro_evento(_partida, jogador, evento_id: String) -> Variant:
	if jogador.fila.size() <= 1:
		return null
	return await _perguntar("cavaleiro_evento", {"jogador": jogador, "evento": evento_id})


func travessia_ponte(_partida, jogador) -> Variant:
	return await _perguntar("descarte", {"jogador": jogador, "evento": "ponte_despencando", "recusa": "Rolar o D6"})


func descarte_areia(_partida, jogador, cavaleiro, face: int) -> Variant:
	if face >= 5 or (jogador.mao.is_empty() and jogador.itens_mao.is_empty()):
		return null
	return await _perguntar("descarte", {
		"jogador": jogador, "evento": "areia_movedica", "recusa": "Ficar com o resultado",
		"texto": "%s tirou %d na Areia Movediça. Descartar uma carta da mão soma +2." % [cavaleiro.nome, face],
	})


func descarte_plataforma(_partida, jogador) -> Variant:
	return await _perguntar("descarte", {"jogador": jogador, "evento": "o_chao_e_lava", "recusa": "Não descartar (sofrer 3 de dano)"})


func usar_habilidade(_partida, _jogador, _cavaleiro, habilidade: String) -> bool:
	# Habilidades de "uma vez por combate" que só ajudam são usadas automaticamente.
	return habilidade in ["Passo Apressado", "Totalmente Honesto", "Previsão: Dor", "Investimento Agressivo"]


func conversao(partida, jogador) -> String:
	var total := 0
	for c in jogador.fila:
		total += c.prestigio()
	var r = await _perguntar("conversao", {"jogador": jogador, "total": total, "reino": jogador.reino_atual})
	return r if r is String else "moedas"


func distribuir_status(_partida, jogador, cavaleiro) -> Dictionary:
	var r = await _perguntar("status", {"jogador": jogador, "cavaleiro": cavaleiro})
	return r if r is Dictionary else {"forca": cavaleiro.prestigio(), "armadura": 0, "honra": 0}


func escolher_reino(_partida, jogador, permitidos: Array) -> String:
	var r = await _perguntar("reino", {"jogador": jogador, "permitidos": permitidos})
	return r if r is String else permitidos[0]
