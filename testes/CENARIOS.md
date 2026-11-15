# Playtest do Pântano Maluco

Use uma partida nova por cenário. O [arquivo JSON](cenarios.json) fixa cada sequência de cartas e D6, além das ações do jogador e dos estados a verificar. Em solo, carregue o deck do Pântano e simule o primeiro avanço para o Reino dos Cavaleiros. Use o modo controlado para iniciar cada combate com os atributos impressos dos dados e aplicar os bônus durante a resolução.

## Estado inicial de cada jogador

| Local | Cartas e recursos |
| --- | --- |
| Campo, da esquerda para a direita | Pizza, Banana, Dragão |
| Mão | Pão com Manteiga e Tigre |
| Moedas | 6 |
| Equipamento e progresso | Nenhum equipamento. Ambos os contadores começam em zero. |

A mão inicial contém as cinco cartas acima. O campo é formado por três recrutamentos gratuitos. Use Banana antes de Dragão em empate de Honra. O baralho pessoal tem 20 cartas, duas cópias de cada Cavaleiro listado na configuração. No cenário de reposição, a segunda cópia de Pão com Manteiga entra em campo, enquanto a primeira pode permanecer na mão.

## A. Avanço por quatro inimigos

| Turno | Ações e rolagens | Esperado |
| ---: | --- | --- |
| 1 | Mercador oferece Elmo de Panela, Botas do Corre-Corre, Luvas de Forno de Guerra, Escudo de Porta Velha e Espada de Madeira com Prego. Compre Elmo por 2. | 4 moedas. Fila intacta. |
| 2 | Equipe o Elmo em Pizza na Preparação. Revele Guerreiro Beduíno. Pizza tira 4 no ataque. | Pizza tem 7 de Armadura. Beduíno cai. 6 moedas e uma vitória. Fila Banana → Dragão → Pizza. |
| 3 | Ratos Mafiosos. Banana tira 6 para 6 de dano. | Ratos caem antes de contra-atacar. 9 moedas, duas vitórias. Fila Dragão → Pizza → Banana. |
| 4 | Mercenário do Deserto. Dragão tira 2 e causa 1. Mercenário tira 4 e derrota Dragão com 5. Pizza tira 3 e causa 2. Mercenário tira 4 e causa 5. Pizza tira 2 e causa 1. | O Mercenário passa de 4 para 3, depois 1 e enfim zero de Armadura. Pizza fica com 2. O prêmio leva o saldo a 13. Na reposição, revele o segundo Pão e o segundo Tigre. Pão entra por 2 e Tigre vai ao Cemitério com Dragão. Saldo 11, três vitórias. Fila Pizza → Banana → Pão. |
| 5 | Xerife do Mal reduz a Força de Pizza de 4 para 3. Pizza tira 6 e causa 6. Converta Prestígio em moedas. | Quarta vitória, saldo 13 antes da conversão e **21** depois de converter 8 de Prestígio. Ao chegar ao Reino dos Cavaleiros, Pizza volta a 7 de Armadura. Fila Pizza → Banana → Pão, contadores zerados. Oito cartas restantes são redistribuídas. |

## B. Avanço por três Eventos

| Turno | Ações e rolagens | Esperado |
| ---: | --- | --- |
| 1 | Areia Movediça! Escolha Pizza, tire 3 e recuse o descarte. | Pizza fica com 3 de Armadura, 8 moedas, um Evento superado. |
| 2 | Ponte Despencando! Descarte Tigre para atravessar. | Banana ganha +2 de Prestígio. 10 moedas, dois Eventos superados. |
| 3 | Gato de Botas! Escolha Dragão e tire 5. Converta Prestígio em moedas. | Dragão ganha +3 de Prestígio. 12 moedas e três Eventos superados antes da conversão. Converta 13 de Prestígio e chegue ao Reino dos Cavaleiros com **25 moedas**. Pizza volta a 5 de Armadura. Contadores zerados. Dez cartas restantes são redistribuídas. |

## C. Avanço pelo Barão do Pântano

O Barão começa com 18 de Armadura. Pizza tira 6, causa 8 e deixa o Barão com 10. O Barão tira 1. O Salto Lodoso move Pizza ao fim e causa 1 a Banana e Dragão. Banana tira 6 e reduz a Armadura do Barão de 10 para 4. Na vez do Barão, o D6 do Escorregão Tático é 2 e o D6 de ataque do Barão é 1. O Salto Lodoso move Banana ao fim e causa 1 a Pizza e Dragão. Dragão tira 4 e derrota o Barão com 5 de dano.

**Esperado.** Prêmio de 35 moedas e saldo de 41 antes da conversão. Escolha o Reino dos Cavaleiros, converta 8 de Prestígio e chegue com **49 moedas**. Restaure a Armadura e reordene por Honra. As doze cartas restantes ficam no Pântano.

## D. Evento compartilhado

Recrute as mesmas fichas separadamente para dois jogadores no Pântano. O primeiro vence a iniciativa com 6 contra 4. Na Ponte Despencando!, ele descarta Tigre para atravessar. O segundo tira 2 e seu Pizza sofre 2 de dano.

**Esperado.** O primeiro fica com **8 moedas**, um Evento superado e +2 de Prestígio no seu Pizza. O segundo fica com **6 moedas**, zero Eventos superados e 3 de Armadura no próprio Pizza. A fila de cada um passa a Banana → Dragão → Pizza, pois seu Cavaleiro envolvido sobreviveu em campo.

Os valores acima são resultados esperados dos testes. O Claude pode usá-los para verificar a implementação na Godot.
