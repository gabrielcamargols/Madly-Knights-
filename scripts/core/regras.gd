extends Node
## Regras puras do Modo Contra, sem dependência da apresentação 3D.

const MOEDAS_INICIAIS := 6
const LIMITE_MAO := 5
const LIMITE_CAMPO := 6
const CAVALEIROS_GRATUITOS := 3
const INIMIGOS_PARA_AVANCAR := 4
const EVENTOS_PARA_AVANCAR := 3
const MOEDAS_POR_EVENTO := 2

const REINOS := [
	{"id": "panquecas", "nome": "Reino das Panquecas", "chefe": "Imperador Panqueca"},
	{"id": "pantano", "nome": "Pântano Maluco", "chefe": "Barão do Pântano"},
	{"id": "cavaleiros", "nome": "Reino dos Cavaleiros", "chefe": "Sir Apelão"},
	{"id": "portal", "nome": "Portal Temporal", "chefe": "Cronarca do Portal"},
	{"id": "ornitorrincos", "nome": "Templo dos Ornitorrincos", "chefe": "Ornitorrinco Oráculo"},
	{"id": "fuligem", "nome": "Cascata da Fuligem", "chefe": "Grão-Duque da Sucata"},
]

## Dano pela tabela do D6, a partir do resultado final e da Força total.
static func dano(d6: int, forca_total: int) -> int:
	match d6:
		1: return 0
		2: return 1
		3: return forca_total / 2
		4, 5: return forca_total
		6: return forca_total * 2
	push_error("D6 inválido: %d" % d6)
	return 0

## Próximo reino do circuito (o último liga ao primeiro).
static func proximo_reino(id_atual: String) -> String:
	for i in REINOS.size():
		if REINOS[i].id == id_atual:
			return REINOS[(i + 1) % REINOS.size()].id
	return ""
