extends RefCounted
## Estado de um jogador: moedas, mão, fila, Cemitério, baralho pessoal e progresso.

var id: String
var moedas := 0
var mao: Array = []  # Cavaleiros
var fila: Array = []  # Cavaleiros em campo; índice 0 age primeiro
var cemiterio: Array = []
var baralho: Array = []  # índice 0 é o topo
var itens_mao: Array = []
var reino_atual := ""
var reino_inicial := ""
var inimigos := 0
var eventos := 0
var reinos_concluidos: Array = []
var vagas := 0
var comprou_cavaleiro_no_turno := false
var comprou_as_cegas_no_turno := false


func _init(p_id: String) -> void:
	id = p_id


static func ids(lista: Array) -> Array:
	return lista.map(func(c): return c.id_instancia)


func ids_itens() -> Array:
	return itens_mao.map(func(i): return i["id"])


func encontrar(id_instancia: String) -> Variant:
	for lista in [fila, mao, cemiterio, baralho]:
		for c in lista:
			if c.id_instancia == id_instancia:
				return c
	return null


func item_na_mao(id_item: String) -> Variant:
	for item in itens_mao:
		if item["id"] == id_item:
			return item
	return null
