extends Node
## Efeitos sonoros provisórios, sintetizados em código (sem arquivos de áudio).
## Proposta: serão trocados por sons definitivos.

const TAXA := 22050

var _sons: Dictionary = {}
var _tocadores: Array = []


func _ready() -> void:
	for i in 6:
		var t := AudioStreamPlayer.new()
		t.volume_db = -6.0
		add_child(t)
		_tocadores.append(t)
	_sons["dado"] = _gerar(_dado())
	_sons["golpe"] = _gerar(_golpe(95.0, 0.22))
	_sons["critico"] = _gerar(_golpe(70.0, 0.4) + _notas([880.0, 1320.0], 0.07))
	_sons["erro"] = _gerar(_ruido(0.18, 0.25))
	_sons["moeda"] = _gerar(_notas([1318.5, 1975.5], 0.09))
	_sons["vitoria"] = _gerar(_notas([523.3, 659.3, 784.0, 1046.5], 0.13))
	_sons["derrota"] = _gerar(_notas([392.0, 330.0, 262.0, 196.0], 0.16))
	_sons["carta"] = _gerar(_ruido(0.22, 0.12, true))
	_sons["clique"] = _gerar(_notas([660.0], 0.04))


func tocar(nome: String) -> void:
	if not _sons.has(nome):
		return
	for t in _tocadores:
		if not t.playing:
			t.stream = _sons[nome]
			t.play()
			return


func _gerar(amostras: PackedFloat32Array) -> AudioStreamWAV:
	var dados := PackedByteArray()
	dados.resize(amostras.size() * 2)
	for i in amostras.size():
		dados.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA
	som.stereo = false
	som.data = dados
	return som


func _notas(frequencias: Array, duracao: float) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	for f in frequencias:
		var n := int(duracao * TAXA)
		for i in n:
			var t := float(i) / TAXA
			var envelope := exp(-t * 18.0) * minf(1.0, t * 400.0)
			saida.append((sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * 0.45 * envelope)
	return saida


func _golpe(frequencia: float, duracao: float) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	var n := int(duracao * TAXA)
	for i in n:
		var t := float(i) / TAXA
		var f := frequencia * (1.0 + 2.0 * exp(-t * 30.0))
		var envelope := exp(-t * 12.0)
		saida.append((sin(TAU * f * t) * 0.8 + randf_range(-0.35, 0.35) * exp(-t * 40.0)) * envelope)
	return saida


func _ruido(duracao: float, volume: float, suave: bool = false) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	var n := int(duracao * TAXA)
	var anterior := 0.0
	for i in n:
		var t := float(i) / TAXA
		var r := randf_range(-1.0, 1.0)
		if suave:
			anterior = anterior * 0.85 + r * 0.15
			r = anterior * 3.0
		saida.append(r * volume * sin(PI * t / duracao))
	return saida


func _dado() -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	for k in 7:
		var batida := _golpe(900.0 + k * 140.0, 0.035)
		for i in batida.size():
			batida[i] *= 0.35 * (1.0 - k / 8.0)
		saida.append_array(batida)
		var pausa := int(TAXA * (0.03 + k * 0.012))
		for i in pausa:
			saida.append(0.0)
	return saida
