# Madly Knights!

Jogo de cartas de aventura em **Godot 4.7**, Modo Contra, com foco no **modo solo** (o modo local com vários jogadores no mesmo aparelho foi cancelado; o motor de regras ainda cobre o cenário de dois jogadores com Evento compartilhado).

O primeiro objetivo é o playtest 3D no **Pântano Maluco**, do recrutamento inicial ao primeiro avanço válido.

## Como abrir

Abra a pasta no Godot 4.7 e rode a cena principal. Cada clique em **Jogar turno** executa um turno completo. A fila, a mão e o Cemitério se movem na mesa, e o registro mostra as rolagens e os efeitos.

## Testes

```
godot --headless --path . --import
godot --headless --path . -s res://testes/executar_cenarios.gd
```

Os quatro cenários aprovados rodam com D6, ordem das cartas e embaralhamentos controlados. Os valores de referência são **21, 25 e 49 moedas** nos avanços solo e **8/6 moedas** no Evento compartilhado. O GitHub Actions roda os testes a cada envio.

## Estrutura

| Pasta | Conteúdo |
| --- | --- |
| `scripts/core/` | Estado e regras da partida, sem dependência da parte 3D |
| `scripts/apresentacao/` | Mesa 3D provisória, que só lê o estado |
| `dados/` | Cartas do reino, encontros, itens e catálogo de Cavaleiros (JSON) |
| `testes/` | Cenários aprovados e o executor |
| `docs/` | Regras aprovadas, notas de implementação e manual original |

Veja [docs/IMPLEMENTACAO.md](docs/IMPLEMENTACAO.md) para a arquitetura, as leituras de regra adotadas e o que falta.
