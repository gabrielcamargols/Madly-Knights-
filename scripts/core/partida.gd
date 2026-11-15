extends RefCounted
## Estado e fluxo de uma partida do Modo Contra.
## Não conhece a apresentação 3D: ela lê o estado e escuta o sinal `registrou`.

signal registrou(texto: String)
signal revelou(carta_id: String)
signal passo_de_combate
signal continuar

const Regras = preload("res://scripts/core/regras.gd")
const Cavaleiro = preload("res://scripts/core/cavaleiro.gd")
const Inimigo = preload("res://scripts/core/inimigo.gd")
const Jogador = preload("res://scripts/core/jogador.gd")
const Decisor = preload("res://scripts/core/decisor.gd")

var cat
var dado
var embaralhador
var jogadores: Array = []  # em ordem de turno
var decisores: Dictionary = {}  # id do jogador -> decisor
var baralhos_reino: Dictionary = {}  # nome do reino -> IDs de carta, topo no índice 0
var descartes_reino: Dictionary = {}
var baralho_itens: Array = []
var descarte_itens: Array = []
var espadas_por_chefe: Dictionary = {}
var espadas_em_espera := 0
var modo_playtest := true  # o playtest encerra no primeiro avanço
var playtest_encerrado := false
var historico: Array = []
var relatorio: Dictionary = {}  # dados do turno atual, para a apresentação e os testes
var turno := 0
var inimigo_atual = null  # inimigo do encontro em curso (ou o último), para a apresentação
## Com pausas ligadas, a lógica emite `passo_de_combate` entre os golpes e espera
## a apresentação emitir `continuar`. Os testes deixam desligado.
var com_pausas := false


func _init(p_catalogo, p_dado, p_embaralhador) -> void:
	cat = p_catalogo
	dado = p_dado
	embaralhador = p_embaralhador


func registrar(texto: String) -> void:
	historico.append(texto)
	registrou.emit(texto)


func _id_de_texto(x) -> String:
	return x


func _id_de_item(item) -> String:
	return item["id"]


func _id_de_cavaleiro(c) -> String:
	return c.id_instancia


# --- Preparação da mesa -------------------------------------------------------

func montar_mesa() -> void:
	for r in cat.circuito:
		baralhos_reino[r] = []
		descartes_reino[r] = []
	var inicial: String = cat.config["reino_inicial"]
	for entrada in cat.config["baralho_do_reino"]:
		for n in int(entrada["copias"]):
			baralhos_reino[inicial].append(entrada["id"])
	baralhos_reino[inicial] = embaralhador.embaralhar(baralhos_reino[inicial], "reino", _id_de_texto)
	for item in cat.itens.values():
		if item.get("baralho_inicial", false):
			baralho_itens.append(item)
	baralho_itens = embaralhador.embaralhar(baralho_itens, "itens", _id_de_item)
	_distribuir_espadas()


## Uma Espada no baralho de itens, uma com cada um dos três chefes de maior Ameaça
## (empates sorteados) e uma com o Prefeito.
func _distribuir_espadas() -> void:
	var chefes: Array = []
	for r in cat.circuito:
		chefes.append(cat.chefe_do_reino[r])
	var ameaca_de := func(c): return int(cat.inimigos[c]["ameaca"])
	chefes.sort_custom(func(a, b): return ameaca_de.call(a) > ameaca_de.call(b))
	var corte: int = ameaca_de.call(chefes[2])
	var escolhidos := chefes.filter(func(c): return ameaca_de.call(c) > corte)
	var empatados := chefes.filter(func(c): return ameaca_de.call(c) == corte)
	while escolhidos.size() < 3 and not empatados.is_empty():
		var k: int = embaralhador.sortear(empatados.size())
		escolhidos.append(empatados[k])
		empatados.remove_at(k)
	for c in escolhidos:
		espadas_por_chefe[c] = 1
	espadas_por_chefe["prefeito_tita"] = 1


## Cria o jogador. Com `ordem_instancias` o baralho fica nessa ordem (topo primeiro);
## sem ela, usa o baralho pessoal de teste embaralhado.
func adicionar_jogador(id: String, ordem_instancias: Array = [], decisor = null) -> Variant:
	var j = Jogador.new(id)
	j.moedas = int(cat.config["moedas_iniciais"])
	j.reino_atual = cat.config["reino_inicial"]
	j.reino_inicial = j.reino_atual
	var ordem := ordem_instancias.duplicate()
	if ordem.is_empty():
		for entrada in cat.config["baralho_pessoal_do_teste"]:
			for n in int(entrada["copias"]):
				ordem.append("%s:%d" % [entrada["id"], n + 1])
	for id_instancia in ordem:
		var id_carta: String = id_instancia.split(":")[0]
		j.baralho.append(Cavaleiro.new(id_instancia, cat.cavaleiros[id_carta]))
	if ordem_instancias.is_empty():
		j.baralho = embaralhador.embaralhar(j.baralho, "pessoal", _id_de_cavaleiro)
	jogadores.append(j)
	decisores[id] = decisor if decisor != null else Decisor.new()
	return j


## Cada jogador escolhe o reino inicial antes de comprar a mão.
func definir_reino_inicial(j, reino: String) -> void:
	if not cat.circuito.has(reino):
		return
	j.reino_inicial = reino
	j.reino_atual = reino
	registrar("%s começa em %s." % [j.id, reino])


func buscar_jogador(id: String) -> Variant:
	for j in jogadores:
		if j.id == id:
			return j
	return null


## Compra a mão inicial, faz mulligan e coloca três Cavaleiros gratuitamente.
func preparar_inicio(j, com_mulligan: bool = true) -> void:
	comprar_mao_inicial(j)
	if com_mulligan:
		for tentativa in 10:
			var devolver: Array = decisores[j.id].mulligan(self, j)
			if devolver.is_empty():
				break
			fazer_mulligan(j, devolver)
	var iniciais: Array = await decisores[j.id].escolher_iniciais(self, j)
	await colocar_iniciais(j, iniciais)


func comprar_mao_inicial(j) -> void:
	_comprar(j, Regras.TAMANHO_MAO_INICIAL)


## Devolve as cartas ao baralho, embaralha e compra a mesma quantidade.
func fazer_mulligan(j, devolver: Array) -> void:
	var quantidade := 0
	for c in devolver:
		if j.mao.has(c):
			j.mao.erase(c)
			j.baralho.append(c)
			quantidade += 1
	j.baralho = embaralhador.embaralhar(j.baralho, "mulligan", _id_de_cavaleiro)
	_comprar(j, quantidade)
	registrar("%s troca %d carta(s) no mulligan." % [j.id, quantidade])


## Coloca até três Cavaleiros da mão em campo, sem custo, e ordena por Honra.
func colocar_iniciais(j, iniciais: Array) -> void:
	for c in iniciais.slice(0, Regras.RECRUTAMENTOS_GRATUITOS):
		if j.mao.has(c):
			j.mao.erase(c)
			j.fila.append(c)
	await ordenar_fila(j)
	registrar("%s começa com %s." % [j.id, ", ".join(j.fila.map(func(c): return c.nome))])


## Em multiplayer, o maior D6 começa. Empates rolam de novo.
func definir_ordem_de_turno() -> void:
	if jogadores.size() < 2:
		return
	var candidatos := jogadores.duplicate()
	while true:
		var faces := {}
		var maior := 0
		for j in candidatos:
			var face: int = dado.rolar("iniciativa_" + j.id)
			faces[j] = face
			maior = maxi(maior, face)
		var vencedores := candidatos.filter(func(j): return faces[j] == maior)
		if vencedores.size() == 1:
			var primeiro = vencedores[0]
			while jogadores[0] != primeiro:
				jogadores.append(jogadores.pop_front())
			registrar("%s começa a partida." % primeiro.id)
			return
		candidatos = vencedores


# --- Mão, baralho pessoal e fila ----------------------------------------------

func _comprar(j, quantidade: int) -> void:
	for n in quantidade:
		if j.baralho.is_empty():
			_reciclar_cemiterio(j)
		if j.baralho.is_empty():
			return
		j.mao.append(j.baralho.pop_front())
		_checar_limite_mao(j)


func _checar_limite_mao(j) -> void:
	while j.mao.size() > Regras.LIMITE_MAO:
		var c = decisores[j.id].descartar_por_mao_cheia(self, j)
		if c == null or not j.mao.has(c):
			c = j.mao[-1]
		j.mao.erase(c)
		_enviar_ao_cemiterio(j, c)


func _enviar_ao_cemiterio(j, c) -> void:
	c.ao_ir_ao_cemiterio()
	# Espadas Douradas nunca ficam no Cemitério.
	for item in c.itens_retidos.duplicate():
		if item["id"] == Regras.ID_ESPADA:
			c.itens_retidos.erase(item)
			espadas_em_espera += 1
	j.cemiterio.append(c)


func _reciclar_cemiterio(j) -> void:
	if j.cemiterio.is_empty():
		return
	for c in j.cemiterio:
		descarte_itens.append_array(c.itens_retidos)
		c.itens_retidos.clear()
	j.baralho = embaralhador.embaralhar(j.baralho + j.cemiterio, "cemiterio", _id_de_cavaleiro)
	j.cemiterio.clear()
	registrar("O Cemitério de %s volta a ser baralho." % j.id)


func _descartar_item(item) -> void:
	if item["id"] == Regras.ID_ESPADA:
		espadas_em_espera += 1
	else:
		descarte_itens.append(item)


## Descarta da mão um Cavaleiro (ao Cemitério) ou um item (ao descarte). Devolve false se não achou.
func _descartar_da_mao(j, id_carta) -> bool:
	if id_carta == null:
		return false
	for c in j.mao:
		if c.id_instancia == id_carta:
			j.mao.erase(c)
			_enviar_ao_cemiterio(j, c)
			registrar("%s descarta %s." % [j.id, c.nome])
			return true
	var item = j.item_na_mao(id_carta)
	if item != null:
		j.itens_mao.erase(item)
		_descartar_item(item)
		registrar("%s descarta %s." % [j.id, item["nome"]])
		return true
	return false


## Ordena por Honra decrescente; em empate o dono escolhe (decisor).
func ordenar_fila(j) -> void:
	var ordenada: Array = []
	for c in j.fila:
		var pos := ordenada.size()
		while pos > 0 and ordenada[pos - 1].honra() < c.honra():
			pos -= 1
		ordenada.insert(pos, c)
	var i := 0
	while i < ordenada.size():
		var k := i
		while k + 1 < ordenada.size() and ordenada[k + 1].honra() == ordenada[i].honra():
			k += 1
		if k > i:
			var grupo := ordenada.slice(i, k + 1)
			var escolhida: Array = await decisores[j.id].ordem_de_empate(self, j, grupo)
			if escolhida.size() == grupo.size() and grupo.all(func(c): return escolhida.has(c)):
				for n in grupo.size():
					ordenada[i + n] = escolhida[n]
		i = k + 1
	j.fila = ordenada


func _mover_ao_fim(j, c) -> void:
	if j.fila.has(c):
		j.fila.erase(c)
		j.fila.append(c)


## Movimento ao fim depois de atacar (permite as Botas do Fura-Fila e do Coice de Mula).
func _mover_apos_ataque(j, c, inimigo_vivo) -> void:
	if not j.fila.has(c):
		return
	var destino: int = j.fila.size() - 1
	if c.tem_item("botas_do_fura_fila_real") and j.fila.size() > 2 \
			and _quer(j, c, "Com Licença!") and c.usar("Com Licença!"):
		destino = 1
	j.fila.erase(c)
	j.fila.insert(destino, c)
	if inimigo_vivo != null and inimigo_vivo.vivo() and c.tem_item("botas_do_coice_de_mula"):
		_ferir_inimigo(inimigo_vivo, 1)


func _entrar_em_campo(j, c) -> void:
	j.fila.append(c)
	if c.id_carta == "cavaleiro_pizza":
		for aliado in j.fila:
			if aliado != c:
				aliado.curar(2)
	registrar("%s entra em campo." % c.nome)


func _quer(j, c, habilidade: String) -> bool:
	return decisores[j.id].usar_habilidade(self, j, c, habilidade)


# --- Turno ----------------------------------------------------------------------

## Turno completo de uma vez (testes e jogadores automáticos).
func jogar_turno(j) -> Dictionary:
	var encerrado: bool = await iniciar_turno(j)
	if encerrado:
		return relatorio
	await _preparacao(j)
	return await explorar_e_resolver(j)


## Abre o turno. Devolve true se o jogador avançou por uma condição já cumprida
## no turno de outro jogador; nesse caso o turno termina sem exploração.
func iniciar_turno(j) -> bool:
	turno += 1
	relatorio = {
		"jogador": j.id, "revelacao": "", "armadura_inimigo": [], "danos_ao_inimigo": [],
		"contra_ataques": 0, "forca_ataques": [], "filas_apos_salto": [],
		"chefe_derrotado": false, "espadas_recebidas": 0, "redistribuido": false,
	}
	j.comprou_cavaleiro_no_turno = false
	j.comprou_as_cegas_no_turno = false
	registrar("— Turno %d de %s em %s —" % [turno, j.id, j.reino_atual])
	var avancou: bool = await _verificar_avanco(j)
	if avancou:
		_fim_do_turno(j)
	return avancou


## Exploração, Resolução, Reposição e Avanço. As decisões do jogador podem esperar a interface.
func explorar_e_resolver(j) -> Dictionary:
	var carta_id := _explorar(j)
	relatorio["revelacao"] = carta_id
	var resultado: String = await _resolver(j, carta_id)
	if resultado != "derrota_total":
		relatorio["moedas_antes_reposicao"] = j.moedas
		await _repor(j)
		for outro in jogadores:
			if outro != j and outro.vagas > 0:
				await _repor(outro)
		await _verificar_avanco(j)
	_fim_do_turno(j)
	return relatorio


func _fim_do_turno(j) -> void:
	for c in j.fila + j.mao:
		c.forca_temporaria = 0


# --- Preparação -----------------------------------------------------------------

func _preparacao(j) -> void:
	for acao in decisores[j.id].acoes_preparacao(self, j):
		await executar_acao_preparacao(j, acao)


func executar_acao_preparacao(j, acao: Dictionary) -> bool:
	match acao.get("tipo", ""):
		"comprar_cavaleiro":
			return comprar_cavaleiro(j)
		"recrutar":
			return await recrutar_da_mao(j, acao["cavaleiro"])
		"equipar":
			return equipar_item(j, acao["portador"], acao["item"])
		"compra_as_cegas":
			return comprar_as_cegas(j)
	push_warning("Ação de Preparação desconhecida: %s" % str(acao))
	return false


func comprar_cavaleiro(j) -> bool:
	if j.comprou_cavaleiro_no_turno or j.moedas < Regras.PRECO_COMPRA_CAVALEIRO:
		return false
	j.moedas -= Regras.PRECO_COMPRA_CAVALEIRO
	j.comprou_cavaleiro_no_turno = true
	_comprar(j, 1)
	registrar("%s compra um Cavaleiro." % j.id)
	return true


func recrutar_da_mao(j, id_instancia: String) -> bool:
	var c = null
	for m in j.mao:
		if m.id_instancia == id_instancia:
			c = m
	if c == null or j.fila.size() >= Regras.LIMITE_CAMPO or j.moedas < c.custo():
		return false
	j.moedas -= c.custo()
	j.mao.erase(c)
	_entrar_em_campo(j, c)
	await ordenar_fila(j)
	return true


func equipar_item(j, id_portador: String, id_item: String) -> bool:
	var portador = null
	for c in j.fila + j.mao:
		if c.id_instancia == id_portador:
			portador = c
	var item = j.item_na_mao(id_item)
	if portador == null or item == null:
		registrar("Não foi possível equipar %s em %s." % [id_item, id_portador])
		return false
	var r: Dictionary = portador.equipar(item)
	if not r["ok"]:
		registrar("%s não pode equipar %s: %s." % [portador.nome, item["nome"], r["motivo"]])
		return false
	j.itens_mao.erase(item)
	if r["substituido"] != null:
		_descartar_item(r["substituido"])
	registrar("%s equipa %s (Armadura %d/%d)." % [portador.nome, item["nome"], portador.armadura_atual, portador.armadura_maxima()])
	return true


func comprar_as_cegas(j) -> bool:
	if j.comprou_as_cegas_no_turno or j.moedas < Regras.PRECO_COMPRA_AS_CEGAS:
		return false
	if baralho_itens.is_empty():
		_reciclar_itens()
	if baralho_itens.is_empty():
		return false
	j.moedas -= Regras.PRECO_COMPRA_AS_CEGAS
	j.comprou_as_cegas_no_turno = true
	var item = baralho_itens.pop_front()
	j.itens_mao.append(item)
	registrar("%s compra às cegas: %s." % [j.id, item["nome"]])
	return true


func _reciclar_itens() -> void:
	baralho_itens = embaralhador.embaralhar(descarte_itens, "descarte_itens", _id_de_item)
	descarte_itens = []


# --- Exploração e Resolução ---------------------------------------------------

func _explorar(j) -> String:
	var r: String = j.reino_atual
	if baralhos_reino[r].is_empty() and not descartes_reino[r].is_empty():
		baralhos_reino[r] = embaralhador.embaralhar(descartes_reino[r], "reino", _id_de_texto)
		descartes_reino[r] = []
	if baralhos_reino[r].is_empty():
		registrar("O baralho de %s está vazio." % r)
		return ""
	var carta: String = baralhos_reino[r].pop_front()
	inimigo_atual = null
	revelou.emit(carta)
	registrar("%s revela %s." % [j.id, cat.nome_de_carta(carta)])
	return carta


func _resolver(j, carta_id: String) -> String:
	if carta_id == "":
		return "ok"
	match cat.tipo_de_carta(carta_id):
		"mercador":
			await _mercador(j)
			descartes_reino[j.reino_atual].append(carta_id)
		"evento":
			await _evento(j, carta_id)
			descartes_reino[j.reino_atual].append(carta_id)
		"monstro", "inimigo", "chefe":
			return await _combate(j, carta_id)
		_:
			registrar("Carta desconhecida: %s" % carta_id)
	return "ok"


# --- Mercador -------------------------------------------------------------------

func _mercador(j) -> void:
	var oferta: Array = []
	for n in Regras.ITENS_DO_MERCADOR:
		if baralho_itens.is_empty():
			_reciclar_itens()
		if baralho_itens.is_empty():
			break
		oferta.append(baralho_itens.pop_front())
	relatorio["oferta_mercador"] = oferta.map(_id_de_item)
	registrar("O Mercador oferece: %s." % ", ".join(oferta.map(func(i): return i["nome"])))
	var devolvidos := oferta.duplicate()
	var escolhidos: Array = await decisores[j.id].itens_para_comprar(self, j, oferta)
	for id_item in escolhidos:
		var item = null
		for o in devolvidos:
			if o["id"] == id_item:
				item = o
				break
		if item == null:
			registrar("%s não está na oferta." % id_item)
			continue
		var preco := int(item["preco_mercador"])
		if j.moedas < preco:
			registrar("Moedas insuficientes para %s." % item["nome"])
			continue
		j.moedas -= preco
		j.itens_mao.append(item)
		devolvidos.erase(item)
		registrar("%s compra %s por %d." % [j.id, item["nome"], preco])
	baralho_itens = embaralhador.embaralhar(baralho_itens, "itens_mercador", _id_de_item, devolvidos)


# --- Combate --------------------------------------------------------------------

func _combate(j, carta_id: String) -> String:
	var ini = Inimigo.new(cat.inimigos[carta_id])
	if ini.eh_chefe():
		var n: int = espadas_por_chefe.get(carta_id, 0) + espadas_em_espera
		espadas_por_chefe.erase(carta_id)
		espadas_em_espera = 0
		if n > 0:
			ini.receber_espadas(n)
			registrar("%s carrega %d Espada(s) Dourada(s)." % [ini.nome, n])
	relatorio["inimigo"] = ini.id
	inimigo_atual = ini
	for c in j.fila:
		c.iniciar_combate()
	_abertura(j, ini)
	relatorio["armadura_inimigo"] = [ini.armadura_atual]
	registrar("Combate contra %s (F%d A%d)." % [ini.nome, ini.forca_total(), ini.armadura_atual])
	await _pausa()
	var ultimo = null
	while ini.vivo():
		if j.fila.is_empty():
			return await _derrota_total(j, ini)
		var atacante = await _escolher_atacante(j, ini)
		ultimo = atacante
		_ataque_do_cavaleiro(j, atacante, ini)
		await _pausa()
		if not ini.vivo():
			break
		if not atacante.vivo():
			continue
		_contra_ataque(j, atacante, ini)
		await _pausa()
	_vitoria(j, ultimo, ini)
	return "ok"


## O primeiro da fila ataca. Fila do Café: o Pão com Manteiga em segundo pode atacar no lugar.
func _escolher_atacante(j, ini) -> Variant:
	var opcoes: Array = [j.fila[0]]
	if j.fila.size() > 1 and j.fila[1].id_carta == "cavaleiro_pao_com_manteiga":
		opcoes.append(j.fila[1])
	var escolhido = await decisores[j.id].escolher_atacante(self, j, opcoes, ini)
	return escolhido if opcoes.has(escolhido) else opcoes[0]


func _pausa() -> void:
	if com_pausas:
		passo_de_combate.emit()
		await continuar


func _abertura(j, ini) -> void:
	for c in j.fila:
		if c.tem_item("cofrinho_carnivoro") and j.moedas >= 1 and _quer(j, c, "Investimento Agressivo"):
			j.moedas -= 1
			c.forca_temporaria += 2
	match ini.id:
		"mercenario_do_deserto":
			# Sempre sozinho: cada carta revelada é um encontro separado.
			ini.forca += 1
			ini.ganhar_armadura(1)
		"xerife_do_mal", "lobo_mal":
			if not j.fila.is_empty():
				j.fila[0].forca_temporaria -= 1
				ini.flags["disfarce"] = j.fila[0]
				registrar("%s sofre −1 de Força até o fim do turno." % j.fila[0].nome)
		"sir_apelao":
			if j.fila.size() == 1:
				_ferir_cavaleiro(j, j.fila[0], 3, ini)
			elif j.fila.size() > 1:
				_mover_ao_fim(j, j.fila[0])
		"grao_duque_da_sucata":
			var perdido := 0
			for c in j.fila.duplicate():
				perdido += _ferir_cavaleiro(j, c, 1, ini)
			ini.ganhar_armadura(perdido)
		"ornitorrinco_oraculo":
			var topo: Array = baralhos_reino[j.reino_atual]
			if not topo.is_empty():
				var tipo: String = cat.tipo_de_carta(topo[0])
				if (tipo == "monstro" or tipo == "inimigo") and not j.fila.is_empty():
					_ferir_cavaleiro(j, j.fila[0], 3, ini)
				else:
					_comprar(j, 1)


func _ataque_do_cavaleiro(j, c, ini) -> void:
	var ch := Regras.chave(c.id_instancia)
	if ini.id == "lobo_mal" and ini.flags.get("disfarce") == c and not ini.flags.get("disfarce_usado", false):
		ini.flags["disfarce_usado"] = true
		ini.ganhar_armadura(1)
		_anotar_armadura(ini)
	var modificador := 0
	if ini.id == "imperador_panqueca":
		var calda: int = dado.rolar("calda_imperial")
		if calda <= 3:
			modificador -= 1
		else:
			_ferir_inimigo(ini, 3)
			if not ini.vivo():
				return
	var face: int = dado.rolar("ataque_" + ch)
	# Novas rolagens
	if face == 1 and c.tem_item("botas_do_corre_corre") and _quer(j, c, "Passo Apressado") and c.usar("Passo Apressado"):
		face = dado.rolar("passo_apressado_" + ch)
	# Modificadores: Porquinhos primeiro
	if ini.id == "porquinhos_viloes":
		face = maxi(1, face - 1)
		if face == 1:
			registrar("Trapaça Suína! 2 de dano em todos os Cavaleiros.")
			_dano_em_todos(j, 2)
			if not c.vivo():
				return
	face = clampi(face + modificador, 1, 6)
	if face < 6 and c.tem_item("dado_real_viciado") and _quer(j, c, "Totalmente Honesto") and c.usar("Totalmente Honesto"):
		face += 1
	# Dano e gatilhos do resultado final
	var forca: int = c.forca_total()
	relatorio["forca_ataques"].append({"cavaleiro": c.id_instancia, "forca": forca, "face": face})
	var dano := Regras.dano(face, forca)
	if face >= 5 and c.id_carta == "cavaleiro_bombado":
		dano += 2
	if face == 6 and c.tem_item("manoplas_do_soco_meteorico"):
		dano += 6
	if face == 6 and c.id_carta == "cavaleiro_dando_grau":
		j.moedas += 3
	if dano > 0 and c.tem_item("espada_tubaronica") and ini.eh_comum() and ini.armadura_atual * 2 <= ini.armadura_maxima:
		dano = maxi(dano, ini.armadura_atual)
	relatorio["danos_ao_inimigo"].append(dano)
	registrar("%s tira %d e causa %d." % [c.nome, face, dano])
	_ferir_inimigo(ini, dano)
	if face == 1 and c.tem_item("espada_de_madeira_com_prego"):
		_ferir_cavaleiro(j, c, 1, null)
	if face == 6 and c.tem_item("martelo_galo_despertador"):
		ini.flags["sem_contra_ataque"] = true


func _contra_ataque(j, alvo, ini) -> void:
	if ini.flags.get("sem_contra_ataque", false):
		ini.flags.erase("sem_contra_ataque")
		registrar("%s perde o contra-ataque." % ini.nome)
		return
	relatorio["contra_ataques"] += 1
	var falhou := false
	if alvo.id_carta == "cavaleiro_banana" and alvo.usar("Escorregão Tático"):
		var escorregao: int = dado.rolar("escorregao_tatico_" + Regras.chave(alvo.id_instancia))
		if escorregao >= 5:
			falhou = true
			registrar("Escorregão Tático! O ataque de %s falha." % ini.nome)
	if not falhou:
		var ch := Regras.chave(ini.id)
		var face: int = dado.rolar("contra_ataque_" + ch)
		if alvo.tem_item("capacete_do_nao_valeu") and _quer(j, alvo, "Não Valeu!") and alvo.usar("Não Valeu!"):
			face = dado.rolar("nao_valeu_" + ch)
		if ini.id == "porquinhos_viloes":
			face = mini(6, face + 1)
			if face == 6:
				registrar("Trapaça Suína! 2 de dano em todos os Cavaleiros.")
				_dano_em_todos(j, 2)
		var dano := Regras.dano(face, ini.forca_total())
		registrar("%s tira %d e causa %d." % [ini.nome, face, dano])
		if alvo.vivo():
			if ini.id == "ratos_mafiosos":
				j.moedas = maxi(0, j.moedas - dano)
				registrar("Os Ratos roubam até %d moedas." % dano)
			else:
				if dano > 0 and alvo.tem_item("guarda_chuva_draconico") and _quer(j, alvo, "Previsão: Dor") and alvo.usar("Previsão: Dor"):
					dano = dano / 2
				_ferir_cavaleiro(j, alvo, dano, ini, true)
	if ini.id == "barao_do_pantano" and ini.vivo():
		if alvo.vivo():
			_mover_apos_ataque(j, alvo, ini)
		for outro in j.fila.duplicate():
			if outro != alvo:
				_ferir_cavaleiro(j, outro, 1, null)
		relatorio["filas_apos_salto"].append(Jogador.ids(j.fila))
		registrar("Salto Lodoso! Fila: %s." % ", ".join(j.fila.map(func(c): return c.nome)))


func _anotar_armadura(ini) -> void:
	var lista: Array = relatorio["armadura_inimigo"]
	if lista.is_empty() or lista[-1] != ini.armadura_atual:
		lista.append(ini.armadura_atual)


func _ferir_inimigo(ini, dano: int) -> void:
	if dano <= 0:
		return
	ini.sofrer(dano)
	_anotar_armadura(ini)


## Dano a quem atacou: inimigo ou Cavaleiro rival (Lute por Honra).
func _ferir_fonte(fonte, dano: int) -> void:
	if fonte is Inimigo:
		_ferir_inimigo(fonte, dano)
	elif fonte != null:
		fonte.sofrer(dano)


func _dano_em_todos(j, dano: int) -> void:
	for c in j.fila.duplicate():
		_ferir_cavaleiro(j, c, dano, null)


## Aplica dano a um Cavaleiro com as reações dele e dos itens. Devolve a Armadura perdida.
func _ferir_cavaleiro(j, c, dano: int, fonte, contra_ataque: bool = false) -> int:
	if dano <= 0 or not c.vivo():
		return 0
	var ch := Regras.chave(c.id_instancia)
	if c.id_carta == "cavaleiro_aranha" and c.usar("Sentido Aranha"):
		if dado.rolar("sentido_aranha_" + ch) >= 4:
			registrar("Sentido Aranha! %s ignora o dano." % c.nome)
			return 0
	if fonte != null and c.tem_item("escudo_do_espelho_desaforado"):
		if dado.rolar("espelho_" + ch) >= 4:
			registrar("Devolve na Cara! %s reflete %d." % [c.nome, dano * 2])
			_ferir_fonte(fonte, dano * 2)
			return 0
	var perdido := 0
	if c.tem_item("armadura_cebola_real") and dano >= c.armadura_atual and not c.flags_reino.get("cebola", false):
		c.flags_reino["cebola"] = true
		perdido = c.armadura_atual - 1
		c.armadura_atual = 1
		registrar("Ainda Tem Camada! %s fica com 1 de Armadura." % c.nome)
	else:
		perdido = c.sofrer(dano)
	if fonte != null and c.vivo() and perdido > 0 and c.id_carta == "cavaleiro_boxeador":
		if dado.rolar("contra_golpe_" + ch) >= 5:
			_ferir_fonte(fonte, dano)
	if contra_ataque and fonte != null and c.tem_item("armadura_do_porco_espinho"):
		_ferir_fonte(fonte, 1)
	if not c.vivo():
		_cavaleiro_derrotado(j, c, fonte)
	return perdido


func _cavaleiro_derrotado(j, c, fonte) -> void:
	j.fila.erase(c)
	_enviar_ao_cemiterio(j, c)
	j.vagas += 1
	registrar("%s é derrotado e vai ao Cemitério." % c.nome)
	if fonte is Inimigo and fonte.id == "cronarca_do_portal":
		fonte.armadura_atual = fonte.armadura_maxima
		fonte.forca_temporaria = 0
		_anotar_armadura(fonte)


func _vitoria(j, atacante, ini) -> void:
	var moedas: int = ini.ameaca
	if atacante != null and atacante.tem_item(Regras.ID_ESPADA):
		moedas *= 2
	j.moedas += moedas
	registrar("%s derrota %s e ganha %d moedas." % [atacante.nome if atacante != null else j.id, ini.nome, moedas])
	if ini.espadas > 0:
		for n in ini.espadas:
			j.itens_mao.append(cat.itens[Regras.ID_ESPADA])
		relatorio["espadas_recebidas"] = ini.espadas
	if ini.eh_chefe():
		relatorio["chefe_derrotado"] = true
	else:
		j.inimigos += 1
	if atacante != null and atacante.vivo() and j.fila.has(atacante):
		if atacante.id_carta == "cavaleiro_rosquinha_de_chocolate":
			atacante.curar(3)
		_mover_apos_ataque(j, atacante, null)
	descartes_reino[j.reino_atual].append(ini.id)


func _derrota_total(j, ini) -> String:
	registrar("Derrota total! %s volta a %s." % [j.id, j.reino_inicial])
	relatorio["derrota_total"] = true
	descartes_reino[j.reino_atual].append(ini.id)
	espadas_em_espera += ini.espadas
	j.inimigos = 0
	j.eventos = 0
	j.vagas = 0
	j.reino_atual = j.reino_inicial
	if j.mao.size() < 3:
		_comprar(j, Regras.TAMANHO_MAO_INICIAL - j.mao.size())
	var iniciais: Array = await decisores[j.id].escolher_iniciais(self, j)
	await colocar_iniciais(j, iniciais)
	return "derrota_total"


# --- Eventos --------------------------------------------------------------------

func _participantes(j, evento: Dictionary) -> Array:
	if evento["participantes"] == "jogador_ativo":
		return [j]
	var lista: Array = []
	var inicio := jogadores.find(j)
	for k in jogadores.size():
		var p = jogadores[(inicio + k) % jogadores.size()]
		if p.reino_atual == j.reino_atual:
			lista.append(p)
	return lista


func _evento(j, id: String) -> void:
	var ev: Dictionary = cat.eventos[id]
	relatorio["evento"] = id
	var participantes := _participantes(j, ev)
	match id:
		"ponte_despencando":
			await _ponte(participantes)
		"areia_movedica":
			for p in participantes:
				await _areia(p)
		"gato_de_botas":
			for p in participantes:
				await _gato(p)
		"o_chao_e_lava":
			await _chao_e_lava(participantes)
		"lute_por_honra":
			_lute_por_honra(j)
		"furacao_tubarao":
			_furacao(j)
		_:
			registrar("Evento sem implementação: %s" % id)


func _superou_evento(p) -> void:
	p.moedas += Regras.MOEDAS_POR_EVENTO
	p.eventos += 1
	registrar("%s supera o Evento (+2 moedas, %d Evento(s))." % [p.id, p.eventos])


func _envolvido_ao_fim(p, c) -> void:
	if c != null and c.vivo() and p.fila.has(c):
		_mover_ao_fim(p, c)


func _cavaleiro_escolhido(p, evento_id: String) -> Variant:
	var id = await decisores[p.id].escolher_cavaleiro_evento(self, p, evento_id)
	if id != null:
		for c in p.fila:
			if c.id_instancia == id:
				return c
	return p.fila[0] if not p.fila.is_empty() else null


func _ponte(participantes: Array) -> void:
	var alguem_atravessou := false
	for p in participantes:
		if p.fila.is_empty():
			continue
		var envolvido = p.fila[0]
		var atravessou := false
		var descarte = await decisores[p.id].travessia_ponte(self, p)
		if _descartar_da_mao(p, descarte):
			atravessou = true
		else:
			var face: int = dado.rolar("ponte_" + p.id)
			if face >= 4:
				atravessou = true
			else:
				registrar("%s escorrega na Ponte." % envolvido.nome)
				_ferir_cavaleiro(p, envolvido, 2, null)
		if atravessou:
			if not alguem_atravessou:
				alguem_atravessou = true
				envolvido.prestigio_ganho += 2
				registrar("%s atravessa primeiro: +2 de Prestígio." % envolvido.nome)
			_superou_evento(p)
		_envolvido_ao_fim(p, envolvido)


func _areia(p) -> void:
	var c = await _cavaleiro_escolhido(p, "areia_movedica")
	if c == null:
		return
	var face: int = dado.rolar("areia_" + Regras.chave(c.id_instancia))
	var descarte = await decisores[p.id].descarte_areia(self, p, c, face)
	if _descartar_da_mao(p, descarte):
		face = mini(6, face + 2)
	if face <= 2:
		p.fila.erase(c)
		p.mao.append(c)
		registrar("%s afunda e volta à mão." % c.nome)
		_checar_limite_mao(p)
		return
	if face <= 4:
		_ferir_cavaleiro(p, c, 2, null)
		if c.vivo():
			_superou_evento(p)
	else:
		_superou_evento(p)
	_envolvido_ao_fim(p, c)


func _gato(p) -> void:
	var c = await _cavaleiro_escolhido(p, "gato_de_botas")
	if c == null:
		return
	var face: int = dado.rolar("gato_" + Regras.chave(c.id_instancia))
	if c.tem_categoria("Arma"):
		face = mini(6, face + 1)
	if face <= 2:
		_ferir_cavaleiro(p, c, 2, null)
	elif face >= 5:
		c.prestigio_ganho += 3
		registrar("%s ganha +3 de Prestígio." % c.nome)
		_superou_evento(p)
	else:
		registrar("Empate com o Gato de Botas: sem progresso.")
	_envolvido_ao_fim(p, c)


func _chao_e_lava(participantes: Array) -> void:
	var todos_descartaram := true
	for p in participantes:
		var descarte = await decisores[p.id].descarte_plataforma(self, p)
		if _descartar_da_mao(p, descarte):
			_superou_evento(p)
		else:
			todos_descartaram = false
			var c = await _cavaleiro_escolhido(p, "o_chao_e_lava")
			if c != null:
				_ferir_cavaleiro(p, c, 3, null)
				_envolvido_ao_fim(p, c)
	if todos_descartaram:
		for p in participantes:
			_comprar(p, 1)


func _furacao(j) -> void:
	var face: int = dado.rolar("furacao_" + j.id)
	if face <= 2:
		_dano_em_todos(j, 3)
	elif face >= 4:
		_superou_evento(j)
		for item in baralho_itens:
			if item["id"] == "espada_tubaronica":
				baralho_itens.erase(item)
				j.itens_mao.append(item)
				baralho_itens = embaralhador.embaralhar(baralho_itens, "itens_furacao", _id_de_item)
				break


func _lute_por_honra(j) -> void:
	if j.fila.is_empty():
		return
	if j.baralho.is_empty():
		_reciclar_cemiterio(j)
	if j.baralho.is_empty():
		return
	var rival = j.baralho.pop_front()
	var meu = j.fila[0]
	meu.iniciar_combate()
	registrar("%s enfrenta %s por Honra." % [meu.nome, rival.nome])
	var vez_do_meu := true
	if meu.honra() != rival.honra():
		vez_do_meu = meu.honra() > rival.honra()
	else:
		while true:
			var a: int = dado.rolar("honra_" + Regras.chave(meu.id_instancia))
			var b: int = dado.rolar("honra_rival_" + Regras.chave(rival.id_instancia))
			if a != b:
				vez_do_meu = a > b
				break
	while meu.vivo() and rival.vivo():
		if vez_do_meu:
			var f: int = dado.rolar("ataque_" + Regras.chave(meu.id_instancia))
			rival.sofrer(Regras.dano(f, meu.forca_total()))
		else:
			var f2: int = dado.rolar("ataque_rival_" + Regras.chave(rival.id_instancia))
			_ferir_cavaleiro(j, meu, Regras.dano(f2, rival.forca_total()), rival)
		vez_do_meu = not vez_do_meu
	if meu.vivo():
		meu.prestigio_ganho += 5
		_superou_evento(j)
		_enviar_ao_cemiterio(j, rival)
		_envolvido_ao_fim(j, meu)
	else:
		rival.curar_total()
		j.baralho.append(rival)


# --- Reposição ------------------------------------------------------------------

func _repor(j) -> void:
	if j.vagas <= 0:
		return
	while j.vagas > 0 and j.fila.size() < Regras.LIMITE_CAMPO:
		j.vagas -= 1
		if j.baralho.is_empty():
			_reciclar_cemiterio(j)
		if j.baralho.is_empty():
			break
		j.baralho = embaralhador.embaralhar(j.baralho, "reposicao", _id_de_cavaleiro)
		var reveladas: Array = []
		for n in 2:
			if not j.baralho.is_empty():
				reveladas.append(j.baralho.pop_front())
		var moedas: int = j.moedas
		var pagaveis := reveladas.filter(func(c): return c.custo() <= moedas)
		if not pagaveis.is_empty():
			var escolhida = await decisores[j.id].escolher_reposicao(self, j, reveladas, pagaveis)
			if escolhida == null or not pagaveis.has(escolhida):
				escolhida = pagaveis[0]
			j.moedas -= escolhida.custo()
			_entrar_em_campo(j, escolhida)
			for c in reveladas:
				if c != escolhida:
					_enviar_ao_cemiterio(j, c)
		else:
			j.baralho.append_array(reveladas)
			var gratis = _menor_prestigio(j.baralho)
			if gratis != null:
				j.baralho.erase(gratis)
				_entrar_em_campo(j, gratis)
			j.baralho = embaralhador.embaralhar(j.baralho, "reposicao_busca", _id_de_cavaleiro)
	j.vagas = 0
	await ordenar_fila(j)


func _menor_prestigio(lista: Array) -> Variant:
	var melhor = null
	for c in lista:
		if c.custo() == 1:
			return c
		if melhor == null or c.custo() < melhor.custo():
			melhor = c
	return melhor


# --- Avanço ---------------------------------------------------------------------

func _verificar_avanco(j) -> bool:
	var por := ""
	if relatorio.get("chefe_derrotado", false) and relatorio.get("jogador") == j.id:
		por = "chefe_derrotado"
	elif j.inimigos >= Regras.INIMIGOS_PARA_AVANCAR:
		por = "quatro_inimigos"
	elif j.eventos >= Regras.EVENTOS_PARA_AVANCAR:
		por = "tres_eventos"
	if por == "":
		return false
	var origem: String = j.reino_atual
	relatorio["inimigos_antes_avanco"] = j.inimigos
	relatorio["eventos_antes_avanco"] = j.eventos
	relatorio["moedas_antes_conversao"] = j.moedas
	var armaduras := {}
	for c in j.fila:
		armaduras[c.id_instancia] = c.armadura_atual
	relatorio["armadura_antes_avanco"] = armaduras
	if not j.reinos_concluidos.has(origem):
		j.reinos_concluidos.append(origem)
	j.inimigos = 0
	j.eventos = 0
	# Conversão de Prestígio
	var modo: String = await decisores[j.id].conversao(self, j)
	if modo == "status":
		for c in j.fila:
			var dist: Dictionary = await decisores[j.id].distribuir_status(self, j, c)
			var f := int(dist.get("forca", 0))
			var a := int(dist.get("armadura", 0))
			var h := int(dist.get("honra", 0))
			if f < 0 or a < 0 or h < 0 or f + a + h != c.prestigio():
				f = c.prestigio()
				a = 0
				h = 0
			c.melhoria_forca += f
			c.melhoria_armadura += a
			c.melhoria_honra += h
		registrar("%s converte Prestígio em status." % j.id)
	else:
		var total := 0
		for c in j.fila:
			total += c.prestigio()
		j.moedas += total
		relatorio["conversao_prestigio_em_moedas"] = total
		registrar("%s converte %d de Prestígio em moedas." % [j.id, total])
	relatorio["cartas_remanescentes_antes_da_redistribuicao"] = baralhos_reino[origem].size()
	if por != "chefe_derrotado":
		_redistribuir(origem)
	var destino: String = cat.proximo_reino(origem)
	if por == "chefe_derrotado":
		var permitidos: Array = cat.circuito.filter(func(r): return r != origem)
		var escolha: String = await decisores[j.id].escolher_reino(self, j, permitidos)
		destino = escolha if permitidos.has(escolha) else permitidos[0]
	j.reino_atual = destino
	for c in j.fila:
		c.forca_temporaria = 0
		c.flags_reino.clear()
		c.curar_total()
	await ordenar_fila(j)
	relatorio["avanco_por"] = por
	relatorio["reino_concluido"] = origem
	relatorio["reino"] = destino
	registrar("%s conclui %s e chega a %s com %d moedas." % [j.id, origem, destino, j.moedas])
	if modo_playtest:
		playtest_encerrado = true
	return true


## Embaralha as cartas restantes e distribui uma por reino, em ordem de circuito.
func _redistribuir(origem: String) -> void:
	var restantes: Array = embaralhador.embaralhar(baralhos_reino[origem], "redistribuicao", _id_de_texto)
	baralhos_reino[origem] = []
	var contagem := {}
	for r in cat.circuito:
		contagem[r] = 0
	for k in restantes.size():
		var r: String = cat.circuito[k % cat.circuito.size()]
		baralhos_reino[r].append(restantes[k])
		contagem[r] += 1
	relatorio["redistribuicao"] = contagem
	relatorio["redistribuido"] = true
