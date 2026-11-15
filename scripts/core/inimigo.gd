extends RefCounted
## Monstro, Inimigo ou chefe durante um encontro.

var id: String
var nome: String
var tipo: String
var habilidade: String
var forca: int
var armadura_maxima: int
var armadura_atual: int
var ameaca: int
var espadas := 0
var forca_temporaria := 0
var flags: Dictionary = {}


func _init(dados: Dictionary) -> void:
	id = dados["id"]
	nome = dados["nome"]
	tipo = dados["tipo"]
	habilidade = str(dados.get("habilidade", ""))
	forca = int(dados["forca"])
	armadura_maxima = int(dados["armadura_maxima"])
	armadura_atual = armadura_maxima
	ameaca = int(dados["ameaca"])


func receber_espadas(quantidade: int) -> void:
	espadas += quantidade
	forca += 10 * quantidade
	ganhar_armadura(15 * quantidade)


func ganhar_armadura(pontos: int) -> void:
	armadura_maxima += pontos
	armadura_atual += pontos


func forca_total() -> int:
	return maxi(0, forca + forca_temporaria)


func vivo() -> bool:
	return armadura_atual > 0


func sofrer(dano: int) -> int:
	var antes := armadura_atual
	armadura_atual = maxi(0, armadura_atual - dano)
	return antes - armadura_atual


func eh_chefe() -> bool:
	return tipo == "chefe" or tipo == "chefe_final"


func eh_comum() -> bool:
	return tipo == "monstro" or tipo == "inimigo"
