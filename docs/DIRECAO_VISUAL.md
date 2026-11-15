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
- Pântano cartunesco em volta do tablado (`scripts/apresentacao/visual.gd`), com sombreamento em degraus (toon) e contorno escuro: chão facetado com manchas de grama, musgo e lama; poças com margem irregular de lama e água com profundidade, reflexos animados e espuma na borda (`shaders/agua.gdshader`); vitórias-régias, juncos, árvores com barba-de-velho, arbustos, pedras com musgo, troncos caídos, cogumelos, píer de tábuas, placa "Pântano Maluco", duas torres de pedra e vaga-lumes.
- Tablado de tábuas sobre base de pedra, arena do inimigo com aro de latão e vagas em escudo de madeira numeradas de 1º a 6º ("1º — ATACA"), com setas indicando o caminho até o inimigo. Estados das vagas: aro cinza (livre), aro verde pulsando (próxima vaga que pode receber, mais forte durante o arraste), aro bronze (ocupada) e aro dourado (Cavaleiro selecionado para atacar).
- Cartas 2D com faixa de nome (Lora), janela de arte em 4:5 que mostra a ilustração inteira, sem esticar nem recortar, habilidade, Força, Honra e Armadura. A mão cabe inteira em 1280×720.
- Interface em madeira, pergaminho e latão, com as fontes Lora e Poppins (`fontes/`, licença SIL OFL): barra do topo com contadores de moedas, inimigos, eventos e itens; fita das fases; dica num pergaminho pequeno; janelas e registro em pergaminho.
- Animações: pulinho de ataque, tremida ao levar dano, inimigo derrotado tomba, respiração das figuras.

**Pendente**
- Modelos 3D definitivos que preservem a identidade completa de cada Cavaleiro.
- Ilustrações que faltam. Onde não há arte, a carta mostra o aviso "ILUSTRAÇÃO PENDENTE" com o nome do arquivo esperado:
  - Baralho de teste: `arte/cavaleiros/cavaleiro_dragao.jpg`, `cavaleiro_tigre.jpg`, `cavaleiro_rosquinha_de_chocolate.jpg`.
  - Outros 73 Cavaleiros do catálogo (116 no total, 40 com ilustração).
  - Inimigos, Eventos, Mercador e itens: ainda não há pasta nem arquivos; a carta mostra o texto da regra no lugar da arte.
  - Verso das cartas (hoje um verso provisório com "MK").
- Modelos 3D dos Cavaleiros e inimigos: não há nenhum modelo (.glb/.gltf) no projeto. As figuras atuais são a representação funcional provisória e não devem ser tratadas como versões finais.
- Fonte com identidade própria do jogo (Lora e Poppins são provisórias).
