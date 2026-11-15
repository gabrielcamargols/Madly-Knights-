extends RefCounted
## Embaralha baralhos. No modo controlado segue as regras de reprodução dos cenários:
## move ao topo as cartas indicadas para o contexto e preserva a ordem das restantes;
## cartas devolvidas vão ao fundo, na ordem em que apareceram.

var controlado := false
var erros: Array = []
var _topos: Dictionary = {}  # contexto -> lista de listas de IDs
var _rng := RandomNumberGenerator.new()


func _init(semente: int = 0) -> void:
	if semente != 0:
		_rng.seed = semente
	else:
		_rng.randomize()


func definir_topo(contexto: String, ids: Array) -> void:
	if not _topos.has(contexto):
		_topos[contexto] = []
	_topos[contexto].append(ids)


func topos_pendentes() -> int:
	var total := 0
	for lista in _topos.values():
		total += lista.size()
	return total


## `id_de` recebe uma carta e devolve seu identificador (String).
func embaralhar(cartas: Array, contexto: String, id_de: Callable, devolvidas: Array = []) -> Array:
	var todas := cartas.duplicate()
	todas.append_array(devolvidas)
	if not controlado:
		for i in range(todas.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp = todas[i]
			todas[i] = todas[j]
			todas[j] = tmp
		return todas
	var topo: Array = []
	if _topos.has(contexto) and not _topos[contexto].is_empty():
		topo = _topos[contexto].pop_front()
	var resultado: Array = []
	for alvo in topo:
		var achou := false
		for k in todas.size():
			if id_de.call(todas[k]) == alvo:
				resultado.append(todas[k])
				todas.remove_at(k)
				achou = true
				break
		if not achou:
			erros.append("Carta '%s' indicada para o topo (%s) não está no baralho" % [alvo, contexto])
	resultado.append_array(todas)
	return resultado


## Índice aleatório para sorteios. No modo controlado escolhe o primeiro.
func sortear(tamanho: int) -> int:
	if controlado or tamanho <= 1:
		return 0
	return _rng.randi_range(0, tamanho - 1)
