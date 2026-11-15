class_name Dado
extends RefCounted
## D6 resolvido pela lógica do jogo. Aceita uma fila de resultados fixos para os
## cenários de teste e registra cada rolagem com o motivo da chamada.

var _fixos: Array[int] = []
var _rng := RandomNumberGenerator.new()
var registro: Array[Dictionary] = []

func _init(semente: int = 0) -> void:
	if semente != 0:
		_rng.seed = semente
	else:
		_rng.randomize()

func fixar(resultados: Array[int]) -> void:
	_fixos = resultados.duplicate()

func rolar(motivo: String) -> int:
	var valor := _fixos.pop_front() if not _fixos.is_empty() else _rng.randi_range(1, 6)
	registro.append({"motivo": motivo, "valor": valor})
	return valor
