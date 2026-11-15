extends "res://scripts/core/decisor.gd"
## Decisões lidas das ações de um turno de `cenarios.json`.
## Ações opcionais não registradas ficam inativas.

var acoes: Array = []  # ações deste jogador no turno atual
var iniciais: Array = []  # IDs dos três Cavaleiros que entram gratuitamente


func _acao(chave: String) -> Variant:
	for a in acoes:
		if a.has(chave):
			return a[chave]
	return null


func escolher_iniciais(_partida, jogador) -> Array:
	var escolhidos: Array = []
	for id in iniciais:
		for c in jogador.mao:
			if c.id_instancia == id:
				escolhidos.append(c)
	return escolhidos


func acoes_preparacao(_partida, _jogador) -> Array:
	var lista: Array = []
	for a in acoes:
		if a.has("equipar"):
			lista.append({"tipo": "equipar", "portador": a["equipar"]["portador"], "item": a["equipar"]["item"]})
		if a.has("recrutar_da_mao"):
			lista.append({"tipo": "recrutar", "cavaleiro": a["recrutar_da_mao"]})
	return lista


func itens_para_comprar(_partida, _jogador, _oferta: Array) -> Array:
	var lista: Array = []
	for a in acoes:
		if a.has("comprar_item"):
			lista.append(a["comprar_item"])
	return lista


func escolher_reposicao(partida, jogador, reveladas: Array, pagaveis: Array) -> Variant:
	var rep = _acao("na_reposicao")
	if rep != null:
		for c in reveladas:
			if c.id_instancia == rep["recrutar"]:
				return c
	return super(partida, jogador, reveladas, pagaveis)


func ordem_de_empate(_partida, _jogador, grupo: Array) -> Array:
	var ordem = _acao("ordem_de_empate_honra")
	if ordem == null:
		return grupo
	var posicao := func(c):
		var i: int = ordem.find(c.id_instancia)
		return i if i >= 0 else 100 + grupo.find(c)
	var resultado := grupo.duplicate()
	resultado.sort_custom(func(a, b): return posicao.call(a) < posicao.call(b))
	return resultado


func escolher_cavaleiro_evento(_partida, _jogador, _evento_id: String) -> Variant:
	return _acao("escolher_cavaleiro")


func travessia_ponte(_partida, _jogador) -> Variant:
	if _acao("escolher") == "rolar":
		return null
	return _acao("descartar_da_mao")


func descarte_areia(_partida, _jogador, _cavaleiro, _face: int) -> Variant:
	if _acao("usar_descarte_para_mais_2") == true:
		return _acao("descartar_da_mao")
	return null


func conversao(_partida, _jogador) -> String:
	var modo = _acao("converter_prestigio")
	return modo if modo != null else "moedas"


func escolher_reino(partida, jogador, permitidos: Array) -> String:
	var reino = _acao("escolher_reino")
	if reino != null and permitidos.has(reino):
		return reino
	return super(partida, jogador, permitidos)
