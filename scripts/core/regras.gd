extends RefCounted
## Constantes e cálculos puros do Modo Contra.

const MOEDAS_INICIAIS := 6
const TAMANHO_MAO_INICIAL := 5
const LIMITE_MAO := 5
const LIMITE_CAMPO := 6
const RECRUTAMENTOS_GRATUITOS := 3
const INIMIGOS_PARA_AVANCAR := 4
const EVENTOS_PARA_AVANCAR := 3
const MOEDAS_POR_EVENTO := 2
const PRECO_COMPRA_CAVALEIRO := 1
const PRECO_COMPRA_AS_CEGAS := 4
const ITENS_DO_MERCADOR := 5
const ID_ESPADA := "espada_dourada_de_equinix"


## Dano pela tabela do D6, a partir do resultado final e da Força total.
static func dano(d6: int, forca_total: int) -> int:
	match d6:
		1:
			return 0
		2:
			return 1
		3:
			return forca_total / 2
		4, 5:
			return forca_total
		6:
			return forca_total * 2
	push_error("D6 inválido: %d" % d6)
	return 0


## Nome curto usado no motivo das rolagens: "cavaleiro_pizza:1" -> "pizza",
## "mercenario_do_deserto" -> "mercenario".
static func chave(id: String) -> String:
	var base: String = id.split(":")[0]
	if base.begins_with("cavaleiro_"):
		base = base.substr(10)
	return base.split("_")[0]
