extends RefCounted
## Uma cópia física de Cavaleiro, com identificador e estado próprios.

var id_instancia: String
var id_carta: String
var nome: String
var cor: String
var habilidade: String
var habilidade_texto: String
var forca_impressa: int
var armadura_impressa: int
var honra_impressa: int
var prestigio_impresso: int

var armadura_atual: int
var melhoria_forca := 0
var melhoria_armadura := 0
var melhoria_honra := 0
var prestigio_ganho := 0
var equipamentos: Array = []
var itens_retidos: Array = []  # itens que ficam com a carta no Cemitério
var forca_temporaria := 0  # efeitos até o fim do turno
var usos: Dictionary = {}  # habilidades usadas no combate atual
var flags_reino: Dictionary = {}  # efeitos de "uma vez por reino"


func _init(p_id_instancia: String, dados: Dictionary) -> void:
	id_instancia = p_id_instancia
	id_carta = dados["id"]
	nome = dados["nome"]
	cor = str(dados.get("cor", ""))
	habilidade = ""
	habilidade_texto = ""
	if dados.get("habilidade") is Dictionary:
		habilidade = dados["habilidade"]["nome"]
		habilidade_texto = str(dados["habilidade"].get("descricao", ""))
	forca_impressa = _num(dados.get("forca"))
	armadura_impressa = _num(dados.get("armadura"))
	honra_impressa = _num(dados.get("honra"))
	prestigio_impresso = _num(dados.get("prestigio"))
	armadura_atual = armadura_maxima()


static func _num(valor) -> int:
	return 0 if valor == null else int(valor)


func _soma_itens(campo: String) -> int:
	var total := 0
	for item in equipamentos:
		total += int(item.get(campo, 0))
	return total


func forca_total() -> int:
	return maxi(0, forca_impressa + melhoria_forca + _soma_itens("bonus_forca") + forca_temporaria)


func armadura_maxima() -> int:
	return armadura_impressa + melhoria_armadura + _soma_itens("bonus_armadura")


func honra() -> int:
	return honra_impressa + melhoria_honra


## Prestígio acessível: impresso + ganho + Espada equipada.
func prestigio() -> int:
	return prestigio_impresso + prestigio_ganho + _soma_itens("bonus_prestigio")


## Custo de entrada em campo: o Prestígio impresso.
func custo() -> int:
	return prestigio_impresso


func vivo() -> bool:
	return armadura_atual > 0


func tem_item(id_item: String) -> bool:
	for item in equipamentos:
		if item["id"] == id_item:
			return true
	return false


func tem_categoria(categoria: String) -> bool:
	for item in equipamentos:
		if item["categoria"] == categoria:
			return true
	return false


func limite_categoria(categoria: String) -> int:
	if id_carta == "cavaleiro_cerberus" and categoria == "Elmo":
		return 3
	return 1


## Aplica dano e devolve quanto de Armadura foi efetivamente perdido.
func sofrer(dano: int) -> int:
	var antes := armadura_atual
	armadura_atual = maxi(0, armadura_atual - dano)
	return antes - armadura_atual


func curar(pontos: int) -> void:
	armadura_atual = mini(armadura_maxima(), armadura_atual + pontos)


func curar_total() -> void:
	armadura_atual = armadura_maxima()


func iniciar_combate() -> void:
	usos.clear()


## Marca uma habilidade de "uma vez por combate". Devolve false se já foi usada.
func usar(habilidade_nome: String) -> bool:
	if usos.get(habilidade_nome, 0) > 0:
		return false
	usos[habilidade_nome] = 1
	return true


## Equipa um item preservando o dano sofrido. Devolve {"ok", "substituido", "motivo"}.
func equipar(item: Dictionary) -> Dictionary:
	var categoria: String = item["categoria"]
	var mesmos := equipamentos.filter(func(i): return i["categoria"] == categoria)
	var substituido = null
	if mesmos.size() >= limite_categoria(categoria):
		substituido = mesmos[0]
	var delta := int(item.get("bonus_armadura", 0))
	if substituido != null:
		delta -= int(substituido.get("bonus_armadura", 0))
	if armadura_atual + delta <= 0:
		return {"ok": false, "substituido": null, "motivo": "a troca deixaria o Cavaleiro sem Armadura"}
	if substituido != null:
		equipamentos.erase(substituido)
	equipamentos.append(item)
	armadura_atual += delta
	return {"ok": true, "substituido": substituido, "motivo": ""}


## No Cemitério a ficha volta aos valores impressos. Os itens ficam retidos com a carta.
func ao_ir_ao_cemiterio() -> void:
	itens_retidos.append_array(equipamentos)
	equipamentos.clear()
	melhoria_forca = 0
	melhoria_armadura = 0
	melhoria_honra = 0
	prestigio_ganho = 0
	forca_temporaria = 0
	usos.clear()
	flags_reino.clear()
	armadura_atual = armadura_impressa


func descricao() -> String:
	return "%s  F%d A%d/%d H%d P%d" % [nome, forca_total(), armadura_atual, armadura_maxima(), honra(), prestigio()]
