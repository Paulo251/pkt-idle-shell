// PokeTema.qml — paleta e tabelas visuais da janela do PokéIdle.
//
// A janela NÃO segue o pywal de propósito: ela tem a cara de um menu de jogo
// (azul-marinho escuro, cartões e barras coloridas por status). O único tom
// variável é `acc`, a cor do tipo do líder do time.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: tema

    // ── superfícies ──
    readonly property color bg:    "#151a24"
    readonly property color side:  "#1a202b"
    readonly property color card:  "#1c2330"
    readonly property color card2: "#222a38"
    readonly property color hover: "#29323f"
    readonly property color line:  "#2a3341"
    readonly property color track: "#2a3242"
    readonly property color sombra: "#0e1219"

    // ── texto ──
    readonly property color text: "#e7eaf0"
    readonly property color sub:  "#9ba4b4"
    readonly property color dim:  "#687184"

    // ── estados ──
    readonly property color ok:   "#5fc06e"
    readonly property color warn: "#f0a33a"
    readonly property color crit: "#e5555f"
    readonly property color xp:   "#4ea4e6"
    readonly property color pokeRed: "#e5484d"

    readonly property string ui: Config.fontUI
    readonly property string mono: "JetBrainsMono Nerd Font"

    // cor de cada status, na ordem hp, atk, def, spa, spd, spe
    readonly property var corStat: ({
        hp: "#5fc06e", atk: "#f0913a", def: "#4ea4e6",
        spa: "#9a70d8", spd: "#e5566a", spe: "#f2c84b"
    })
    readonly property var corStatLista: ["#5fc06e", "#f0913a", "#4ea4e6", "#9a70d8", "#e5566a", "#f2c84b"]

    readonly property var corTipo: ({
        normal: "#9fa19f", fire: "#ee8130", water: "#4f8ef0", electric: "#f2c21b",
        grass: "#5fbd58", ice: "#5fcfd0", fighting: "#d2453c", poison: "#a552cc",
        ground: "#d9a54a", flying: "#89aae3", psychic: "#f2668b", bug: "#91c12f",
        rock: "#c5b78c", ghost: "#6f5ea8", dragon: "#5070d6", dark: "#5a5465",
        steel: "#5a8ea2", fairy: "#ec8fe6"
    })
    readonly property var nomeTipo: ({
        normal: "Normal", fire: "Fogo", water: "Água", electric: "Elétrico", grass: "Planta",
        ice: "Gelo", fighting: "Lutador", poison: "Venenoso", ground: "Terra", flying: "Voador",
        psychic: "Psíquico", bug: "Inseto", rock: "Pedra", ghost: "Fantasma", dragon: "Dragão",
        dark: "Sombrio", steel: "Aço", fairy: "Fada"
    })
    // Material Design Icons da Nerd Font (codepoints conferidos com fc-list)
    readonly property var iconeTipo: ({
        normal: 0xF0766, fire: 0xF0238, water: 0xF058C, electric: 0xF0241, grass: 0xF032A,
        ice: 0xF0717, fighting: 0xF0B65, poison: 0xF068C, ground: 0xF056A, flying: 0xF06D3,
        psychic: 0xF0208, bug: 0xF00E4, rock: 0xF01C8, ghost: 0xF02A0, dragon: 0xF150E,
        dark: 0xF0F65, steel: 0xF0498, fairy: 0xF0AE2
    })
    readonly property var nomeClasse: ({ physical: "Físico", special: "Especial", status: "Status" })

    function ic(cp) { return cp ? String.fromCodePoint(cp) : ""; }
    // sprites recortados de ~/.local/lib/pokeidle/assets (recortar.py)
    readonly property string assets: Quickshell.env("HOME") + "/.local/lib/pokeidle/assets"
    function imgTipo(t) { return t ? "file://" + assets + "/tipos/" + t + ".png" : ""; }
    function imgCenario(n) { return n ? "file://" + assets + "/cenarios/" + n + (n === "ginasio" ? ".png" : ".jpg") : ""; }
    function imgCategoria(c) { return c ? "file://" + assets + "/categorias/" + c + ".png" : ""; }
    function imgInsignia(reg, id) { return reg && id ? "file://" + assets + "/insignias/" + reg + "/" + id + ".png" : ""; }
    function cor(tipo) { return corTipo[tipo] || "#8a93a3"; }
    function tinta(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // tom de destaque: o tipo do líder
    readonly property color acc: {
        const e = (ShellState.pokeTeam || {}).equipo || [];
        const m = e[0];
        return m && m.tipos && m.tipos.length ? cor(m.tipos[0].id) : "#5fbd58";
    }
}
