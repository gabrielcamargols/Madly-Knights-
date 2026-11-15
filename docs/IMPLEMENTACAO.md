# Notas de implementação

## Arquitetura

| Arquivo | Papel |
| --- | --- |
| `scripts/core/partida.gd` | Fluxo do turno: Preparação, Exploração, Resolução, Reposição e Avanço |
| `scripts/core/cavaleiro.gd` | Cada cópia, com ID próprio (`cavaleiro_pizza:1`), Armadura atual, melhorias, equipamento e usos de habilidade |
| `scripts/core/inimigo.gd` | Monstros, Inimigos e chefes durante o encontro |
| `scripts/core/jogador.gd` | Moedas, mão, fila ordenada, Cemitério, baralho pessoal e contadores |
| `scripts/core/dado.gd` | D6 da lógica. Registra `{motivo, face}` de cada rolagem e, no modo controlado, confere o motivo |
| `scripts/core/embaralhador.gd` | Embaralhamento aleatório ou controlado conforme as regras de reprodução dos cenários |
| `scripts/core/decisor.gd` | Toda escolha do jogador passa por aqui. A interface e os testes substituem os métodos |
| `scripts/apresentacao/principal.gd` | Mesa 3D provisória. Só lê o estado e anima os movimentos |
| `testes/executar_cenarios.gd` | Roda os quatro cenários de `cenarios.json` e confere cada estado esperado |

O estado não depende da apresentação. A cena 3D chama `partida.jogar_turno()` e redesenha a partir do estado.

## Rodar os testes

```
godot --headless --path . --import
godot --headless --path . -s res://testes/executar_cenarios.gd
```

O GitHub Actions roda os mesmos comandos a cada envio (`.github/workflows/testes.yml`).

## Leituras adotadas onde o texto deixa margem

- **Escorregão Tático (Banana):** dispara quando o inimigo ataca a própria Banana, uma vez por combate, antes do D6 do inimigo. Coincide com o cenário C.
- **Salto Lodoso:** é aplicado mesmo quando o ataque do Barão falha pelo Escorregão.
- **Mercenário do Deserto:** sempre recebe o bônus de "sozinho", porque cada carta revelada é um encontro separado.
- **Lobo Mal e Xerife:** o −1 de Força vai ao primeiro da fila na abertura e dura até o fim do turno.
- **Areia Movediça com 1–2:** o Cavaleiro volta à mão e não abre vaga de reposição.
- **Ponte Despencando:** o envolvido é o primeiro da fila de cada participante. Se ele sobreviver, vai ao fim da fila mesmo quando o jogador falha.
- **Condição de avanço atingida no turno de outro jogador** (Evento compartilhado): o jogador avança no início do próprio turno e encerra o turno sem explorar.
- **Escolha de reino após derrotar o chefe:** qualquer reino do circuito diferente do atual.
- **Ratos Mafiosos:** o dano do contra-ataque sai das moedas, não da Armadura.
- **Espada Tubarônica:** "acertar" quer dizer causar dano maior que zero.

## Ainda não implementado

- Duelos entre jogadores, Cidade Central e seus defensores, fase final e roubo de Espadas.
- Habilidades opcionais que dependem de vários inimigos ou de turno extra: Bafo pela Viseira (Dragão), Rajada de Garras (Tigre), Fila do Café (Pão com Manteiga), Elmo do Papagaio Copiador, A Grande Coxa de Frango, Ampulheta do Turno Extra e Capa Invisível.
- Interface para as escolhas do jogador. Por enquanto a mesa 3D usa as decisões padrão (`decisor.gd`): não compra itens, converte Prestígio em moedas e recusa habilidades opcionais.

## Dados

`dados/itens.json` ganhou os campos `bonus_forca`, `bonus_armadura` e `bonus_prestigio`, extraídos do texto dos efeitos passivos. Os efeitos condicionais continuam no texto e estão na lógica.
