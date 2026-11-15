class_name Fila
extends RefCounted
## Fila ordenada de Cavaleiros em campo. O índice 0 é o próximo a agir.

var cartas: Array = []

func primeiro():
	return cartas[0] if not cartas.is_empty() else null

## Sobrevivente que venceu, superou Evento ou duelo vai ao fim.
func mover_ao_fim(carta) -> void:
	cartas.erase(carta)
	cartas.append(carta)

## Ordena por Honra decrescente. Empates mantêm a ordem atual (escolha do dono).
func ordenar_por_honra() -> void:
	var indexado := []
	for i in cartas.size():
		indexado.append([cartas[i], i])
	indexado.sort_custom(func(a, b):
		if a[0].honra() != b[0].honra():
			return a[0].honra() > b[0].honra()
		return a[1] < b[1])
	cartas = indexado.map(func(par): return par[0])
