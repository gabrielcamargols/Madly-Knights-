# Madly Knights! — Direção visual

## Direção aprovada

O jogo utiliza personagens e cenários em 3D cartunesco.
As ilustrações das cartas são 2D, desenhadas e pintadas.

As imagens de referência dos cavaleiros são a base para o design
dos personagens. Preserve a identidade de cada um: silhueta,
elmo, armadura, cores, equipamentos e tema.

O tom do jogo é heroico, cômico e divertido. Os cavaleiros têm
personalidade e presença; o humor surge de suas ações, dos seus
temas e das situações inesperadas que enfrentam.

### Referências — estudar aspectos específicos

- Armello: convivência entre cartas ilustradas, interface e mundo 3D.
- Stormbound: organização visual das cartas e do campo.
- Wardens: apresentação de um tabuleiro tático 3D.
- Clash Royale: silhuetas reconhecíveis, cores e clareza visual.
- Knight Squad 2: variedade de cavaleiros e energia das cenas.
- Floppy Knights: personalidade na apresentação das cartas 2D.
- Tiny Glade: arquitetura medieval e ambientação acolhedora.

Esses jogos são referências visuais e de apresentação. Não copie
automaticamente suas regras, câmera, mecânicas ou estilo de jogo.

Para as regras e características dos personagens, siga os materiais
aprovados de Madly Knights!. Quando algum detalhe não estiver definido,
identifique-o como proposta em vez de tratá-lo como regra oficial.

## Estado atual da implementação

**Aprovado e em uso**
- Ilustrações 2D aprovadas dos lotes 1, 2, 3 e 10 nas cartas (`arte/cavaleiros/`).
- Cartas 2D na mão, nas escolhas e nos detalhes; mundo 3D no tabuleiro.

**Propostas (aguardam aprovação)**
- Modelos 3D *temporários* dos Cavaleiros, montados com formas simples (`scripts/apresentacao/figuras.gd`): proporção "chibi" com cabeça grande, base redonda, escudo e espada.
- Cores e formato de elmo de cada modelo (`dados/paletas_cavaleiros.json`). Para os Cavaleiros do baralho de teste com ilustração (Pizza, Banana, Boxeador, Aranha, Bombado, Pão com Manteiga, Dando Grau), definidos à mão a partir da arte. Para Dragão, Tigre e Rosquinha de Chocolate, que ainda não têm ilustração, as cores e o elmo são inventados. Os demais Cavaleiros usam cores extraídas automaticamente.
- Inimigos como criaturas cartunescas de olhos grandes; chefes maiores, com coroa.
- Plaquinha flutuante sobre cada figura (nome, barra de Armadura, Força e Armadura), no espírito da clareza visual do Clash Royale.
- Pântano acolhedor em volta do tablado: poças, vitórias-régias, juncos, árvores e duas torres de pedra (inspiração Tiny Glade).
- Animações: pulinho de ataque, tremida ao levar dano, inimigo derrotado tomba, respiração das figuras.

**Pendente**
- Modelos 3D definitivos que preservem a identidade completa de cada Cavaleiro.
- Ilustrações de Dragão, Tigre, Rosquinha de Chocolate, dos inimigos, Eventos e Mercador.
