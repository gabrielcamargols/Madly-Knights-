extends RefCounted
## D6 resolvido pela lógica do jogo. A apresentação só mostra o resultado.
## No modo controlado consome uma lista de {motivo, face} e confere o motivo.

var controlado := false
var registro: Array = []  # {motivo, face}
var erros: Array = []
var _fixos: Array = []
var _rng := RandomNumberGenerator.new()


func _init(semente: int = 0) -> void:
	if semente != 0:
		_rng.seed = semente
	else:
		_rng.randomize()


func fixar(lista: Array) -> void:
	_fixos = lista.duplicate(true)
	controlado = true


func restantes() -> int:
	return _fixos.size()


func rolar(motivo: String) -> int:
	var face := 0
	if controlado:
		if _fixos.is_empty():
			erros.append("Rolagem não prevista: %s" % motivo)
			face = 1
		else:
			var previsto: Dictionary = _fixos.pop_front()
			face = int(previsto["face"])
			if str(previsto["motivo"]) != motivo:
				erros.append("Rolagem prevista '%s', mas a lógica pediu '%s'" % [previsto["motivo"], motivo])
	else:
		face = _rng.randi_range(1, 6)
	registro.append({"motivo": motivo, "face": face})
	return face
