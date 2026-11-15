extends RefCounted
## Lê os arquivos de dados do jogo e indexa as cartas por ID.

var config = {}
var cavaleiros: Dictionary = {}
var inimigos: Dictionary = {}  # monstros, inimigos, chefes e defensores
var eventos: Dictionary = {}
var itens: Dictionary = {}
var circuito: Array = []  # nomes dos reinos na ordem do circuito
var chefe_do_reino: Dictionary = {}


static func ler_json(caminho: String) -> Variant:
	var texto := FileAccess.get_file_as_string(caminho)
	if texto.is_empty():
		push_error("Não foi possível ler " + caminho)
		return null
	return JSON.parse_string(texto)


func carregar(pasta: String = "res://dados") -> bool:
	config = ler_json(pasta + "/pantano_maluco.json")
	var enc = ler_json(pasta + "/encontros.json")
	var it = ler_json(pasta + "/itens.json")
	var cat = ler_json(pasta + "/cavaleiros_catalogo.json")
	if config == null or enc == null or it == null or cat == null:
		return false
	for c in cat["cavaleiros"]:
		cavaleiros[c["id"]] = c
	for grupo in ["inimigos_do_playtest", "chefes_de_reino", "defensores_da_cidade_central"]:
		for e in enc[grupo]:
			inimigos[e["id"]] = e
	for e in enc["eventos"]:
		eventos[e["id"]] = e
	for i in it["itens"]:
		itens[i["id"]] = i
	for r in config["circuito"]:
		circuito.append(r["reino"])
		chefe_do_reino[r["reino"]] = r["chefe"]
	return true


func tipo_de_carta(id: String) -> String:
	if id == "mercador":
		return "mercador"
	if eventos.has(id):
		return "evento"
	if inimigos.has(id):
		return inimigos[id]["tipo"]
	return "desconhecido"


func nome_de_carta(id: String) -> String:
	if id == "mercador":
		return "Mercador"
	for tabela in [eventos, inimigos, itens, cavaleiros]:
		if tabela.has(id):
			return tabela[id]["nome"]
	return id


func proximo_reino(nome: String) -> String:
	var i := circuito.find(nome)
	if i < 0:
		return ""
	return circuito[(i + 1) % circuito.size()]
