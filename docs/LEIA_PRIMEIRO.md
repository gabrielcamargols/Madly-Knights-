# Madly Knights! — Pacote para Claude e Godot

Implemente o primeiro playtest 3D no **Pântano Maluco**. A sessão solo começa no recrutamento inicial e termina no primeiro avanço válido. O cenário com dois jogadores usa um Evento compartilhado.

| Arquivo | Uso |
| --- | --- |
| [REGRAS_APROVADAS.md](REGRAS_APROVADAS.md) | Regras da partida e decisões aprovadas na revisão. Em caso de diferença com o texto de uma imagem, aplique as regras deste pacote. |
| [dados/pantano_maluco.json](dados/pantano_maluco.json) | Baralho de 13 cartas do reino, baralho pessoal de teste e configuração inicial. |
| [dados/encontros.json](dados/encontros.json) | Fichas do Pântano, seis Eventos, os seis chefes do circuito e os quatro defensores da Cidade Central. |
| [dados/itens.json](dados/itens.json) | Os 20 equipamentos do baralho, a Espada Dourada e a Capa Invisível extra. |
| [dados/cavaleiros_catalogo.json](dados/cavaleiros_catalogo.json) | Catálogo histórico de Cavaleiros. Para o playtest, selecione as fichas pelos IDs do baralho pessoal. |
| [testes/CENARIOS.md](testes/CENARIOS.md) · [testes/cenarios.json](testes/cenarios.json) | Quatro cenários aprovados, com ações, rolagens e estados esperados. |
| `referencias/` | Manual de mesa original e imagens recuperadas para o playtest. As artes trazem o texto da edição em que foram criadas. |

## Instrução para o Claude

Implemente primeiro Preparação, Exploração, Resolução, Reposição e Avanço. Separe o estado da partida da apresentação 3D. Cada cópia tem um identificador próprio, Armadura atual, melhorias, equipamento e contadores de habilidade. A fila é uma lista ordenada. O D6 é resolvido pela lógica do jogo e a apresentação mostra o resultado que ela retornou.

Use os quatro cenários para testar o fluxo com ordem de cartas, embaralhamentos e D6 controlados. Registre as rolagens com o motivo de cada chamada. Os resultados de referência são **21, 25 e 49 moedas** nos três avanços solo e **8/6 moedas** no Evento compartilhado. Após validar as regras, ligue os movimentos de fila e a troca de reino à apresentação 3D. Use modelos temporários para os Cavaleiros.

Os cinco reinos além do Pântano têm os nomes, a ordem e os chefes aprovados. A composição dos respectivos baralhos ainda está em aberto. O teste de avanço pode verificar a transição e a redistribuição através do estado, sem exigir o conteúdo dos próximos reinos. O Shogun Lendário está registrado como Monstro Lendário com Ameaça pendente.

As listas completas de teste incluem decisões operacionais para reprodução, como a ordem dos itens ofertados e as cartas que completam o baralho pessoal. Essas escolhas pertencem aos cenários e podem ser variadas em partidas livres.
