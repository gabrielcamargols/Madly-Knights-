extends SceneTree
## Executa os cenários aprovados de `testes/cenarios.json` com ordem de cartas,
## embaralhamentos e D6 controlados.
##   godot --headless --path . -s res://testes/executar_cenarios.gd

const Catalogo = preload("res://scripts/core/catalogo.gd")
const Partida = preload("res://scripts/core/partida.gd")
const Dado = preload("res://scripts/core/dado.gd")
const Embaralhador = preload("res://scripts/core/embaralhador.gd")
const Jogador = preload("res://scripts/core/jogador.gd")
const Regras = preload("res://scripts/core/regras.gd")
const DecisorCenario = preload("res://testes/decisor_cenario.gd")

var falhas: Array = []
var verificacoes := 0


func _initialize() -> void:
	var cat = Catalogo.new()
	if not cat.carregar():
		print("ERRO: não foi possível carregar os dados do jogo.")
		quit(1)
		return
	var dados = Catalogo.ler_json("res://testes/cenarios.json")
	if dados == null:
		print("ERRO: não foi possível ler testes/cenarios.json.")
		quit(1)
		return
	for cenario in dados["cenarios"]:
		_rodar(cat, cenario)
	print("")
	print("%d verificações, %d falha(s)." % [verificacoes, falhas.size()])
	for f in falhas:
		print("  FALHA  " + f)
	if falhas.is_empty():
		print("TODOS OS CENÁRIOS PASSARAM")
		quit(0)
	else:
		print("HÁ CENÁRIOS COM FALHA")
		quit(1)


func _rodar(cat, cenario: Dictionary) -> void:
	var nome: String = cenario["id"]
	print("\n=== Cenário %s ===" % nome)
	var dado = Dado.new()
	dado.controlado = true
	var emb = Embaralhador.new()
	emb.controlado = true
	emb.definir_topo("reino", cenario["ordem_reino_do_topo"])
	if cenario.has("ordem_itens_do_topo"):
		emb.definir_topo("itens", cenario["ordem_itens_do_topo"])
	var partida = Partida.new(cat, dado, emb)
	partida.registrou.connect(func(t): print("  · " + t))
	partida.montar_mesa()

	var decisores := {}
	for k in int(cenario["jogadores"]):
		var id: String = "j%d" % (k + 1)
		var dec = DecisorCenario.new()
		dec.iniciais = cat.config["mao_inicial_em_campo"]
		decisores[id] = dec
		var j = partida.adicionar_jogador(id, cat.config["ordem_pessoal_de_teste_do_topo"], dec)
		partida.preparar_inicio(j, false)
		_checar(nome + " início " + id, Jogador.ids(j.fila), cat.config["mao_inicial_em_campo"], "fila inicial")
		_checar(nome + " início " + id, Jogador.ids(j.mao), cat.config["mao_inicial_restante"], "mão inicial")
		_checar(nome + " início " + id, j.moedas, cat.config["moedas_iniciais"], "moedas iniciais")

	if cenario.has("d6_iniciativa"):
		dado.fixar(cenario["d6_iniciativa"])
		partida.definir_ordem_de_turno()
		_conferir_dado(nome + " iniciativa", dado)

	var numero := 0
	for turno in cenario["turnos"]:
		numero += 1
		var contexto: String = "%s turno %d" % [nome, numero]
		var acoes: Array = turno["acoes"]
		for id in decisores:
			decisores[id].acoes = acoes.filter(func(a): return a.get("jogador", "j1") == id)
		for a in acoes:
			if a.has("na_reposicao") and a["na_reposicao"].has("topo_apos_embaralhar"):
				emb.definir_topo("reposicao", a["na_reposicao"]["topo_apos_embaralhar"])
		dado.fixar(turno["d6_em_ordem"])
		var ativo = partida.jogadores[0]
		var rel: Dictionary = partida.jogar_turno(ativo)
		_checar(contexto, rel.get("revelacao", ""), turno["revelacao"], "carta revelada")
		_conferir_reposicao(contexto, acoes, ativo)
		_conferir_dado(contexto, dado)
		_conferir_esperado(contexto, partida, ativo, rel, turno["esperado"])
	for e in emb.erros:
		falhas.append("%s — embaralhamento: %s" % [nome, e])
	_checar(nome, emb.topos_pendentes(), 0, "topos de embaralhamento não usados")


func _conferir_dado(contexto: String, dado) -> void:
	print("  Rolagens: %s" % ", ".join(dado.registro.map(func(r): return "%s=%d" % [r["motivo"], r["face"]])))
	for e in dado.erros:
		falhas.append("%s — %s" % [contexto, e])
	dado.erros.clear()
	_checar(contexto, dado.restantes(), 0, "rolagens previstas não usadas")
	dado.registro.clear()


func _conferir_reposicao(contexto: String, acoes: Array, j) -> void:
	for a in acoes:
		if not a.has("na_reposicao"):
			continue
		var rep: Dictionary = a["na_reposicao"]
		if rep.has("recrutar"):
			_checar(contexto, j.fila.any(func(c): return c.id_instancia == rep["recrutar"]), true, "recrutado na reposição em campo")
		if rep.has("enviar_ao_cemiterio"):
			_checar(contexto, j.cemiterio.any(func(c): return c.id_instancia == rep["enviar_ao_cemiterio"]), true, "enviado ao Cemitério na reposição")


func _conferir_esperado(contexto: String, partida, j, rel: Dictionary, esperado: Dictionary) -> void:
	# Cenários com vários jogadores agrupam o esperado por jogador.
	if esperado.keys().all(func(k): return partida.buscar_jogador(k) != null):
		for id in esperado:
			_conferir_esperado(contexto + " " + id, partida, partida.buscar_jogador(id), rel, esperado[id])
		return
	for campo in esperado:
		var v = esperado[campo]
		match campo:
			"moedas", "inimigos", "eventos":
				_checar(contexto, j.get(campo), v, campo)
			"fila":
				_checar(contexto, Jogador.ids(j.fila), v, campo)
			"cemiterio":
				_checar(contexto, Jogador.ids(j.cemiterio), v, campo)
			"itens_na_mao":
				_checar(contexto, j.ids_itens(), v, campo)
			"armadura_atual", "prestigio":
				for id in v:
					var c = j.encontrar(id)
					if c == null:
						falhas.append("%s — %s: %s não encontrado" % [contexto, campo, id])
						continue
					var obtido = c.armadura_atual if campo == "armadura_atual" else c.prestigio()
					_checar(contexto, obtido, v[id], "%s de %s" % [campo, id])
			"contadores_apos_avanco":
				_checar(contexto, {"inimigos": j.inimigos, "eventos": j.eventos}, v, campo)
			"contra_ataques", "moedas_antes_reposicao", "moedas_antes_conversao", "inimigos_antes_avanco", "eventos_antes_avanco", "avanco_por", "reino", "reino_concluido", "conversao_prestigio_em_moedas", "cartas_remanescentes_antes_da_redistribuicao", "espadas_recebidas", "armadura_antes_avanco":
				_checar(contexto, rel.get(campo), v, campo)
			"fila_apos_primeiro_salto":
				_checar(contexto, _item(rel["filas_apos_salto"], 0), v, campo)
			"fila_apos_segundo_salto":
				_checar(contexto, _item(rel["filas_apos_salto"], 1), v, campo)
			"redistribuir":
				_checar(contexto, rel.get("redistribuido", false), v, campo)
				if v == true:
					_conferir_redistribuicao(contexto, partida, rel)
			"encerra_playtest":
				_checar(contexto, partida.playtest_encerrado, v, campo)
			_:
				if campo.begins_with("dano_ao_"):
					var total := 0
					for d in rel["danos_ao_inimigo"]:
						total += int(d)
					_checar(contexto, total, v, campo)
				elif campo.begins_with("armadura_do_") and campo.ends_with("_em_ordem"):
					_checar(contexto, rel["armadura_inimigo"], v, campo)
				elif campo.begins_with("forca_efetiva_"):
					var alvo: String = campo.substr(14)
					var obtido = null
					for ataque in rel["forca_ataques"]:
						if Regras.chave(ataque["cavaleiro"]) == alvo:
							obtido = ataque["forca"]
							break
					_checar(contexto, obtido, v, campo)
				else:
					falhas.append("%s — campo esperado sem verificação: %s" % [contexto, campo])


func _conferir_redistribuicao(contexto: String, partida, rel: Dictionary) -> void:
	var total: int = rel.get("cartas_remanescentes_antes_da_redistribuicao", 0)
	var esperado := {}
	for r in partida.cat.circuito:
		esperado[r] = 0
	for k in total:
		esperado[partida.cat.circuito[k % partida.cat.circuito.size()]] += 1
	_checar(contexto, rel.get("redistribuicao"), esperado, "cartas transferidas por reino")
	var no_destino := 0
	for r in partida.cat.circuito:
		no_destino += partida.baralhos_reino[r].size()
	_checar(contexto, no_destino, total, "cartas nos baralhos após redistribuir")


func _item(lista: Array, indice: int):
	return lista[indice] if indice < lista.size() else null


## Normaliza números do JSON (float) para comparar com inteiros.
func _normalizar(valor):
	if valor is float and valor == floorf(valor):
		return int(valor)
	if valor is Array:
		return valor.map(func(x): return _normalizar(x))
	if valor is Dictionary:
		var d := {}
		var chaves: Array = valor.keys()
		chaves.sort()
		for k in chaves:
			d[k] = _normalizar(valor[k])
		return d
	return valor


func _checar(contexto: String, obtido, esperado, campo: String) -> void:
	verificacoes += 1
	var a := JSON.stringify(_normalizar(obtido))
	var b := JSON.stringify(_normalizar(esperado))
	if a == b:
		print("  ok  %s = %s" % [campo, a])
	else:
		falhas.append("%s — %s: esperado %s, obtido %s" % [contexto, campo, b, a])
		print("  FALHA  %s: esperado %s, obtido %s" % [campo, b, a])
