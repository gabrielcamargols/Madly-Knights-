# Madly Knights! — Regras aprovadas para a Godot

## Preparação e turno

- Modo Contra para 1–4 jogadores. Cada jogador escolhe um reino inicial, começa com 6 moedas e tem um baralho pessoal de 20 Cavaleiros, de até duas cores e até três cópias de uma mesma carta.
- Compre cinco Cavaleiros. No mulligan, devolva quantos quiser, embaralhe e reponha a mesma quantidade. Pode repetir. Escolha três Cavaleiros para entrar gratuitamente. Em multiplayer, o maior D6 inicia a partida. Repita empates.
- A mão aceita até cinco Cavaleiros e a fila aceita até seis em campo. Se uma compra ou devolução criar uma mão de seis Cavaleiros, o dono escolhe um dos seis para enviar ao Cemitério. A mão de itens é ilimitada. Cavaleiros disponíveis ficam em campo ou na mão do jogador. A zona de banco foi removida.
- Cada turno passa por **Preparação → Exploração → Resolução → Reposição → Duelo opcional → Avanço**. Na Preparação, pode comprar um Cavaleiro por 1 moeda, recrutar Cavaleiros da mão pagando o Prestígio impresso, equipar ou substituir itens e fazer uma compra às cegas. Na Exploração, revele uma carta do topo do reino. Resolva o encontro por inteiro antes de repor vagas.
- Ordene a fila por Honra decrescente na formação inicial, ao recrutar ou repor e ao entrar em outro reino. Em empate, o dono escolhe a ordem. Quem derrota o inimigo, vence um duelo ou sobrevive como Cavaleiro envolvido em um Evento vai ao fim da fila quando continuar em campo. O Mercador preserva a ordem.

## Combate, descarte e reposição

O primeiro Cavaleiro da fila ataca. Se o inimigo sobreviver, contra-ataca. Alterne os ataques. Se o Cavaleiro cair, o próximo assume contra o mesmo inimigo com o dano já sofrido. Cada carta revelada gera um encontro separado. Habilidades podem mudar o alvo, a fila ou quem age.

| D6 final | Dano |
| ---: | --- |
| 1 | 0, erro |
| 2 | 1 fixo |
| 3 | Metade da Força total, arredondada para baixo |
| 4–5 | Força total |
| 6 | Dobro da Força total |

Some os bônus à Força antes de calcular o dano. Resolva primeiro as novas rolagens, depois os modificadores e por fim o dano e os gatilhos do resultado final, como os do Prego, Martelo e Manoplas. Quando houver Porquinhos, aplique o modificador deles antes dos outros. Armadura atual representa a vida restante. Ao chegar a zero, o Cavaleiro é derrotado e vai ao Cemitério.

Derrotar um inimigo rende moedas iguais à Ameaça. Derrotar um chefe que carrega Espadas também entrega essas Espadas. Após o combate contra o reino, para cada vaga normal a repor, embaralhe o baralho pessoal e revele duas cartas. Uma entra pelo custo de Prestígio e a outra vai ao Cemitério. Se faltar moeda, entra gratuitamente um Cavaleiro de Prestígio 1 do baralho ou, na ausência dele, um de menor Prestígio. Devolva as cartas examinadas que sobrarem e embaralhe. Reordene a fila depois da reposição. Derrotas em duelos entre jogadores seguem o recrutamento normal em um turno posterior.

No Cemitério, a ficha de Cavaleiro volta aos valores impressos. Na derrota contra um desafio, os itens comuns ficam com a carta até a reciclagem do Cemitério e então passam ao descarte de itens. Em derrota por duelo entre jogadores, os itens comuns vão ao descarte imediatamente. Se o baralho pessoal esgotar, o Cemitério embaralhado forma um novo baralho pessoal. As Espadas Douradas seguem a regra própria abaixo.

Se todos os Cavaleiros em campo forem derrotados por um desafio, descarte o desafio sem prêmio, zere os contadores do reino e volte ao reino inicial sem conversão. Preserve moedas, mão, itens guardados e reinos já concluídos. Com menos de três Cavaleiros na mão, complete até cinco gratuitamente. Faça mulligan se necessário, coloque três gratuitamente e reorganize por Honra. Na Cidade Central, o defensor em vez disso permanece com o dano sofrido.

## Eventos e Mercador

Os efeitos finais dos seis Eventos estão em `dados/encontros.json`. Quando o Evento diz “cada jogador”, participam os jogadores do mesmo reino. Cada participante que supera o desafio recebe **2 moedas e 1 Evento superado**. Um resultado de falha ou empate rende zero progresso. Quando a carta exige descartar da mão, o jogador pode usar um Cavaleiro ou um item. Cavaleiros descartados vão ao Cemitério e itens comuns vão ao descarte de itens.

O Mercador revela cinco itens. Compre quantos quiser pelos preços impressos, devolva os restantes ao baralho e embaralhe. Uma vez por turno, na Preparação, pode comprar o topo do baralho às cegas por 4 moedas. Quando o baralho de itens esgotar, embaralhe o descarte de itens comuns. A Espada Dourada custa 30 moedas no Mercador e segue o preço de 4 moedas na compra às cegas.

## Equipamentos

O baralho começa com **20 equipamentos**, cinco de cada raridade, e uma Espada Dourada. A Capa Invisível é extra. A lista de efeitos em `dados/itens.json` incorpora as decisões da revisão.

Equipe fora de combate. Cada Cavaleiro tem um espaço para cada categoria: Arma, Armadura, Artefato, Botas, Elmo, Escudo e Luvas. Arma e Escudo coexistem. Cerberus é a exceção com até três Elmos. Itens equipados são individuais. Trocar um item da mesma categoria envia o antigo ao descarte e preservar o dano é obrigatório. Um Cavaleiro com 3 de 5 de Armadura, ao equipar +2, passa a 5 de 7. A troca ou remoção que o deixaria em zero ou menos fica indisponível até que ele recupere Armadura suficiente.

## Mapa e avanço

| Ordem | Reino | Chefe |
| ---: | --- | --- |
| 1 | Reino das Panquecas | Imperador Panqueca |
| 2 | Pântano Maluco | Barão do Pântano |
| 3 | Reino dos Cavaleiros | Sir Apelão |
| 4 | Portal Temporal | Cronarca do Portal |
| 5 | Templo dos Ornitorrincos | Ornitorrinco Oráculo |
| 6 | Cascata da Fuligem | Grão-Duque da Sucata |

O circuito liga o último ao primeiro. Cada reino tem seis Monstros ou Inimigos diferentes entre si, quatro Eventos, dois Mercadores e um chefe. Uma carta de inimigo pode aparecer em mais de um reino. A Cidade Central começa bloqueada.

Derrotar **4 inimigos** ou superar **3 Eventos** conclui o reino e leva ao próximo do circuito. Derrotar seu chefe conclui o reino e permite escolher outro reino permitido. Os contadores são individuais. Termine de resolver a carta, recolha os prêmios, marque a conclusão, zere os contadores, converta Prestígio e mova a equipe. Ao avançar por inimigos ou Eventos, embaralhe e redistribua as cartas remanescentes daquele reino o mais igualmente possível entre os seis baralhos. Quem ficou mantém os próprios contadores. Quando o baralho de um reino acabar, embaralhe seu próprio descarte para repor.

Em um avanço válido, escolha uma modalidade para todos os Cavaleiros em campo. Na conversão para moedas, some o Prestígio acessível e ganhe uma moeda para cada ponto. Na conversão para status, cada Cavaleiro reparte seu Prestígio entre Força, Armadura máxima e Honra, na proporção de um ponto para um. O Prestígio continua disponível para avanços futuros. Ao chegar, cure os sobreviventes à Armadura máxima, encerre os efeitos temporários, preserve melhorias permanentes e equipamentos e reorganize a fila por Honra.

## Duelos, Cidade Central e vitória

- Um jogador pode iniciar um duelo por permanência no reino, com outro jogador no mesmo reino e ambos livres de combate. O desafiado pode pagar 3 moedas ao desafiante para recusar. A recusa gasta a oportunidade do desafiante. Ser desafiado não gasta a própria oportunidade.
- Cada lado escolhe um Cavaleiro. O maior D6 começa e empates são rolados de novo. Alterne ataques até uma derrota. O vencedor ganha 10 moedas e seu Cavaleiro ganha +5 de Prestígio permanente, mantém o dano e vai ao fim da fila. O derrotado vai ao Cemitério. O Evento **Lute por Honra!** usa a Honra para o primeiro ataque e D6 no empate.
- A fase final começa para todos quando qualquer jogador conclui pessoalmente os seis reinos. A partir daí, quem vence duelo pode tomar uma Espada do derrotado, inclusive da mão. Quem concluiu pessoalmente os seis pode viajar livremente entre reinos concluídos, explorar ao chegar e viajar sem conversão de Prestígio.
- Distribua cinco Espadas Douradas únicas. Uma no baralho de itens, uma em cada um dos três chefes de reino com maior Ameaça e uma com o Prefeito. Cronarca e Ornitorrinco recebem uma cada, com sorteio entre Imperador e Sir Apelão para a terceira. Cada Espada que um chefe carrega dá +10 Força e +15 Armadura. Cada Espada equipada por Cavaleiro dá +10 Força, +15 Armadura máxima e +20 Prestígio ao portador e dobra moedas de combates e duelos. A Espada na mão conta para vitória e seus bônus valem quando equipada.
- Espadas descartadas ou perdidas numa derrota vão à espera do próximo chefe revelado, ressalvado o roubo direto e o recolhimento da Cidade Central. Na primeira entrada de qualquer jogador na Cidade Central, o Prefeito recolhe todas as Espadas que ainda não pertencem a jogadores.
- A Cidade Central abre individualmente após os seis reinos. Embaralhe os três minibosses no início da partida e enfrente-os, um por vez, antes do Prefeito. A derrota e a Armadura atual dos defensores persistem e são compartilhadas. O finalizador recebe as moedas de Ameaça e, no caso do Prefeito, todas as Espadas que ele carrega. A ordem de ataque e as habilidades de cada defensor estão em `dados/encontros.json`.
- **A partida termina imediatamente quando um jogador possui as cinco Espadas Douradas**, equivalentes a 100 de Prestígio de objetivo. No solo, aplique a mesma estrutura para combates e Eventos e ignore duelos, recusa, recompensas de duelo e roubo entre jogadores. O playtest solo encerra especificamente ao primeiro avanço.
