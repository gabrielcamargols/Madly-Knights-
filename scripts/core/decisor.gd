extends RefCounted
## Decisões de um jogador. A base escolhe opções simples e nunca usa habilidades
## opcionais. A interface e os cenários de teste substituem estes métodos.
## Cartas são devolvidas como objetos; descartes da mão, como ID de Cavaleiro ou de item.


func mulligan(_partida, _jogador) -> Array:
	return []


func escolher_iniciais(_partida, jogador) -> Array:
	var mao: Array = jogador.mao.duplicate()
	mao.sort_custom(func(a, b): return a.honra() > b.honra())
	return mao.slice(0, mini(3, mao.size()))


## Ações da Preparação: {"tipo": "equipar", "portador": id, "item": id},
## {"tipo": "recrutar", "cavaleiro": id}, {"tipo": "comprar_cavaleiro"}, {"tipo": "compra_as_cegas"}.
func acoes_preparacao(_partida, _jogador) -> Array:
	return []


## IDs dos itens a comprar entre os cinco revelados.
func itens_para_comprar(_partida, _jogador, _oferta: Array) -> Array:
	return []


func escolher_reposicao(_partida, _jogador, _reveladas: Array, pagaveis: Array) -> Variant:
	return pagaveis[0]


func ordem_de_empate(_partida, _jogador, grupo: Array) -> Array:
	return grupo


## ID do Cavaleiro em campo envolvido no Evento, ou null para o primeiro da fila.
func escolher_cavaleiro_evento(_partida, _jogador, _evento_id: String) -> Variant:
	return null


## ID de um Cavaleiro ou item da mão para atravessar a Ponte, ou null para rolar.
func travessia_ponte(_partida, _jogador) -> Variant:
	return null


## ID para descartar e somar +2 na Areia Movediça, ou null.
func descarte_areia(_partida, _jogador, _cavaleiro, _face: int) -> Variant:
	return null


## ID para montar a plataforma em O Chão é Lava, ou null.
func descarte_plataforma(_partida, _jogador) -> Variant:
	return null


## Quem ataca neste golpe, entre os permitidos pela regra (o primeiro vem antes).
func escolher_atacante(_partida, _jogador, opcoes: Array, _inimigo) -> Variant:
	return opcoes[0]


func usar_habilidade(_partida, _jogador, _cavaleiro, _habilidade: String) -> bool:
	return false


## "moedas" ou "status".
func conversao(_partida, _jogador) -> String:
	return "moedas"


func distribuir_status(_partida, _jogador, cavaleiro) -> Dictionary:
	return {"forca": cavaleiro.prestigio(), "armadura": 0, "honra": 0}


func escolher_reino(_partida, _jogador, permitidos: Array) -> String:
	return permitidos[0]


func descartar_por_mao_cheia(_partida, jogador) -> Variant:
	return jogador.mao[-1]
