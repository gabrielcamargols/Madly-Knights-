# Madly Knights!

Jogo de cartas de aventura em **Godot 4.7** — Modo Contra, 1 a 4 jogadores.

Primeiro objetivo: playtest 3D no **Pântano Maluco**, do recrutamento inicial ao primeiro avanço válido.

## Estrutura

| Pasta | Conteúdo |
| --- | --- |
| `scripts/core/` | Estado e regras da partida, sem dependência da parte 3D |
| `scripts/apresentacao/` | Cenas e visual 3D, que só leem o estado |
| `dados/` | Cartas, encontros, itens e catálogo de Cavaleiros (JSON) |
| `testes/` | Cenários aprovados com D6 e ordem de cartas controlados |
| `docs/` | Regras aprovadas, instruções e manual original |

## Referência dos cenários

Avanços solo: **21, 25 e 49 moedas**. Evento compartilhado: **8/6 moedas**.
