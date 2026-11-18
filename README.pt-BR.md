# pkt-idle-shell

> Meu shell pessoal inspirado no [pocket-dots](https://github.com/diegoMalagrida/pocket-dots), usando um minijogo de Pokémon como jogo idle.

[English](README.md) · **Português**

O pkt-idle-shell é um desktop Hyprland feito com Quickshell. Enquanto você usa o computador, seu time de Pokémon ganha experiência, pokémon selvagens aparecem no notch, ovos chocam e treinadores desafiam você. Quando quiser jogar, o PokéIdle abre como um jogo completo, com batalhas por turnos, ginásios e ligas.

## Destaques

- **Um jogo que acompanha sua rotina:** tempo ativo, músicas, vídeos e jogos contam para o progresso.
- **Batalhas por turnos:** singles e duplas, com tipos, atributos, problemas de status e efeitos de golpes.
- **Nove regiões:** de Kanto a Paldea, cada uma com ginásios, Elite 4, Campeão e lendários.
- **Desktop completo:** barra, notch, lançador, central de controle, cores baseadas no wallpaper e tela de bloqueio.

## PokéIdle

Pressione `SUPER+I` para abrir o jogo.

### Seu time

- Escolha entre 27 iniciais regionais.
- Ganhe XP com minutos ativos e missões diárias.
- Capture pokémon selvagens direto do notch, com animação e vários tipos de bola.
- Choque ovos enquanto usa o PC. A chance de shiny é de 1 em 512.
- Gerencie time, caixa, golpes, naturezas, itens, Pokécenter e PokéMart.

### Amizade e evolução

- A amizade cresce com tempo ativo, níveis, batalhas e itens.
- Músicas, vídeos e jogos dobram a amizade ganha pelo tempo.
- As evoluções por amizade seguem os jogos, incluindo as regras de dia e noite.
- O botão **Evoluir** mostra uma prévia dos tipos, da habilidade e dos status antes de confirmar.

### Regiões e progressão

- Cada região começa do zero e pode ser jogada em qualquer ordem.
- O level cap acompanha o próximo líder de ginásio ou Campeão.
- A XP acima do cap fica guardada e é liberada quando o cap sobe.
- O time da Liga é inscrito e fica travado até você vencer ou perder.
- Vencer uma Liga libera o Hall da Fama, um cartão do time para compartilhar, revanches e encontros com lendários.

### Modos de batalha

| Modo | Formato | Como funciona |
|---|---|---|
| **Treinadores avulsos** | Singles ou duplas | Desafiam você pelo notch, até 4 vezes por dia |
| **Battle Tower** | Singles ou duplas | Séries de 7 lutas no nível 50, com chefes nas lutas 21 e 49 |
| **Survival** | Singles | Lutas sem fim no nível 50, com dano acumulado |
| **Random Battles** | Singles ou duplas | Os dois lados recebem 6 pokémon sorteados |
| **Boss Rush** | Singles | Os 8 líderes de uma região em sequência |
| **Desafio diário** | Varia | Uma luta por dia com uma regra especial |

As vitórias rendem pontos de batalha (BP) para comprar itens de evolução e TMs fortes. A tela de **Recordes** guarda suas melhores sequências e times.

## Desktop

- Notch dinâmico para mídia, notificações, selvagens e desafios de treinadores
- Lançador de apps, histórico da área de transferência, visão das workspaces e Stage Manager
- Central de controle com rede, Bluetooth, áudio e monitores
- Seletor de wallpapers com cores automáticas pelo pywal
- Capturas de tela, gravação, OCR e conta-gotas de cor
- Tela de bloqueio e controle de inatividade
- Companheiro opcional: o líder do time pode andar pela tela com o wl_shimeji

## Requisitos

- Arch Linux ou distribuição baseada nele, como CachyOS
- Hyprland com suporte à configuração em Lua
- Acesso SSH a este repositório privado
- `paru` ou `yay` para os pacotes do AUR
- Internet para o primeiro download de dados, cerca de 300 MB

## Instalação

```bash
git clone git@github.com:Paulo251/pkt-idle-shell.git ~/pkt-idle-shell
```

```bash
cd ~/pkt-idle-shell
```

```bash
./install.sh
```

O instalador:

1. Instala os pacotes listados em `packages/`.
2. Faz backup dos arquivos substituídos em `~/.local/state/pkt-idle-shell/backups/`.
3. Cria links do repositório para a sua pasta pessoal.
4. Gera a configuração do monitor e a paleta inicial de cores.
5. Baixa os dados de Pokémon e ativa os serviços do usuário.

O save do jogo em `~/.config/poke-equipo` nunca é alterado.

| Opção | Descrição |
|---|---|
| `--dry-run` | Mostra o que seria feito, sem alterar nada |
| `--no-packages` | Não instala pacotes do pacman nem do AUR |
| `--no-data` | Não baixa dados e sprites de Pokémon |
| `--no-services` | Não ativa nem reinicia os serviços do usuário |
| `--lang pt\|en\|es\|it` | Define o idioma da interface |

## Atualização

```bash
~/pkt-idle-shell/update.sh
```

As atualizações vêm somente deste repositório. O script para se houver alterações sem commit.

## Atalhos

| Atalho | Ação |
|---|---|
| `SUPER+I` | Abrir o PokéIdle |
| `SUPER+SHIFT+O` | Abrir o painel do time |
| `SUPER+R` | Lançador de apps |
| `SUPER+D` | Central de controle |
| `SUPER+Tab` | Visão das workspaces |
| `SUPER+SHIFT+Tab` | Stage Manager |
| `SUPER+SHIFT+W` | Escolher wallpaper |
| `SUPER+SHIFT+V` | Histórico da área de transferência |
| `SUPER+SHIFT+D` | Monitor do sistema |
| `SUPER+SHIFT+M` | Player de mídia |
| `SUPER+SHIFT+S` | Capturar uma região da tela |
| `SUPER+SHIFT+E` | Menu de energia |
| `SUPER+,` | Configurações do shell |
| `SUPER+K` | Listar todos os atalhos |
| `SUPER+G` | Recarregar o shell |

## Estrutura do projeto

```text
home/.config/quickshell/     Barra, notch, painéis e interface do jogo
home/.config/hypr/           Configuração e scripts do Hyprland
home/.config/systemd/user/   Serviços do usuário
home/.local/bin/             poke-team e outros comandos
home/.local/lib/pokeidle/    Motor de batalha, regras e dados do jogo
packages/                    Dependências do pacman e do AUR
install.sh                   Instalador
update.sh                    Atualizador
```

## Créditos e licença

Inspirado e baseado no [pocket-dots](https://github.com/diegoMalagrida/pocket-dots), de diegoMalagrida. Os dados e sprites de Pokémon vêm da [PokeAPI](https://pokeapi.co/), e os sprites de treinadores vêm do [Pokémon Showdown](https://play.pokemonshowdown.com/).

O código é licenciado sob a [GPL-3.0](LICENSE). Veja os créditos completos em [NOTICE.md](NOTICE.md).

Este é um projeto de fã não oficial, sem vínculo com Nintendo, Game Freak, Creatures Inc. ou The Pokémon Company. A arte de Pokémon neste repositório não é coberta pela GPL e não deve ser redistribuída.
