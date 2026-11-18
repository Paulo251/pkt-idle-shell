# pkt-idle-shell

> My personal shell inspired by [pocket-dots](https://github.com/diegoMalagrida/pocket-dots), but using a Pokémon minigame as an idle game.

**English** · [Português](README.pt-BR.md)

pkt-idle-shell is a Hyprland desktop built with Quickshell. While you use your computer, your Pokémon team gains experience, wild Pokémon appear in the notch, eggs hatch and trainers challenge you. When you want to play, PokéIdle opens as a full game with turn-based battles, gyms and leagues.

## Highlights

- **A game that follows your routine:** active time, music, videos and games all count toward progress.
- **Turn-based battles:** singles and doubles, with types, stats, status conditions and move effects.
- **Nine regions:** Kanto to Paldea, each with gyms, an Elite Four, a Champion and legendary Pokémon.
- **A complete desktop:** bar, notch, launcher, control center, wallpaper-based theming and lock screen.

## PokéIdle

Press `SUPER+I` to open the game.

### Your team

- Choose from 27 regional starters.
- Earn XP from active minutes and daily missions.
- Catch wild Pokémon directly from the notch, with animated throws and several ball types.
- Hatch eggs by staying active. Shiny Pokémon appear at 1 in 512 odds.
- Manage your team, box, moves, natures, items, Pokécenter and PokéMart.

### Friendship and evolution

- Friendship grows with active time, levels, battles and items.
- Music, videos and games double the friendship gained from time.
- Friendship evolutions follow the games, including day and night requirements.
- The **Evolve** button shows a preview of types, ability and stat changes before you confirm.

### Regions and progression

- Each region starts from zero and can be played in any order.
- Level caps follow the next gym leader or Champion.
- XP above the cap is stored and released when the cap rises.
- League teams are registered and stay locked until you win or lose.
- Winning a League unlocks the Hall of Fame, a shareable team card, rematches and legendary encounters.

### Battle modes

| Mode | Format | How it works |
|---|---|---|
| **Wandering trainers** | Singles or doubles | Trainers challenge you from the notch, up to 4 times a day |
| **Battle Tower** | Singles or doubles | 7-battle sets at level 50, with bosses at battles 21 and 49 |
| **Survival** | Singles | Endless level 50 battles where damage carries over |
| **Random Battles** | Singles or doubles | Both sides receive 6 random Pokémon |
| **Boss Rush** | Singles | All 8 gym leaders of a region in a row |
| **Daily Challenge** | Varies | One battle a day with a special rule |

Wins earn Battle Points for evolution items and strong TMs. The **Records** screen keeps your best streaks and teams.

## Desktop

- Dynamic notch for media, notifications, wild encounters and trainer challenges
- App launcher, clipboard history, workspace overview and Stage Manager
- Control center with network, Bluetooth, audio and display settings
- Wallpaper picker with automatic colors through pywal
- Screenshots, screen recording, OCR and color picker
- Lock screen and idle management
- Optional desktop companion: your team leader can walk across the screen with wl_shimeji

## Requirements

- Arch Linux or an Arch-based distribution
- Hyprland with Lua configuration support
- SSH access to this private repository
- `paru` or `yay` for AUR packages
- Internet access for the first data download, about 300 MB

## Installation

```bash
git clone git@github.com:Paulo251/pkt-idle-shell.git ~/pkt-idle-shell
```

```bash
cd ~/pkt-idle-shell
```

```bash
./install.sh
```

The installer:

1. Installs the packages listed in `packages/`.
2. Backs up files it would replace to `~/.local/state/pkt-idle-shell/backups/`.
3. Links the desktop from the repository into your home directory.
4. Creates the monitor configuration and initial color palette.
5. Downloads Pokémon data and enables the user services.

Your game save in `~/.config/poke-equipo` is never changed.

| Option | Description |
|---|---|
| `--dry-run` | Show what would be done without changing anything |
| `--no-packages` | Skip pacman and AUR packages |
| `--no-data` | Skip Pokémon data and sprite downloads |
| `--no-services` | Do not enable or restart user services |
| `--lang pt\|en\|es\|it` | Set the interface language |

## Updating

```bash
~/pkt-idle-shell/update.sh
```

Updates come only from this repository. The script stops if you have uncommitted changes.

## Shortcuts

| Shortcut | Action |
|---|---|
| `SUPER+I` | Open PokéIdle |
| `SUPER+SHIFT+O` | Open the Pokémon team panel |
| `SUPER+R` | App launcher |
| `SUPER+D` | Control center |
| `SUPER+Tab` | Workspace overview |
| `SUPER+SHIFT+Tab` | Stage Manager |
| `SUPER+SHIFT+W` | Choose wallpaper |
| `SUPER+SHIFT+V` | Clipboard history |
| `SUPER+SHIFT+D` | System monitor |
| `SUPER+SHIFT+M` | Media player |
| `SUPER+SHIFT+S` | Screenshot a region |
| `SUPER+SHIFT+E` | Power menu |
| `SUPER+,` | Shell settings |
| `SUPER+K` | List all shortcuts |
| `SUPER+G` | Reload the shell |

## Project structure

```text
home/.config/quickshell/     Bar, notch, panels and game interface
home/.config/hypr/           Hyprland configuration and scripts
home/.config/systemd/user/   User services
home/.local/bin/             poke-team and other commands
home/.local/lib/pokeidle/    Battle engine, game rules and data
packages/                    pacman and AUR dependencies
install.sh                   Installer
update.sh                    Updater
```

## Credits and license

Inspired by and based on [pocket-dots](https://github.com/diegoMalagrida/pocket-dots) by diegoMalagrida. Pokémon data and sprites come from [PokeAPI](https://pokeapi.co/), and trainer sprites come from [Pokémon Showdown](https://play.pokemonshowdown.com/).

The code is licensed under [GPL-3.0](LICENSE). See [NOTICE.md](NOTICE.md) for full credits.

This is an unofficial fan project, not affiliated with Nintendo, Game Freak, Creatures Inc. or The Pokémon Company. Pokémon artwork in this repository is not covered by the GPL and must not be redistributed.
