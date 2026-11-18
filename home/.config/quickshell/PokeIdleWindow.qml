// PokeIdleWindow.qml — a janela do PokéIdle (SUPER+I).
//
// Fase 1: gerenciamento e progressão. Abas: Time, Resumo, Mochila,
// Pokécenter, PokéMart e Liga (placeholder da fase 2).
//
// Visual: menu de jogo em azul-marinho (paleta em PokeTema.qml), cartões com
// borda fina, status com barra colorida e o tom de destaque vindo do tipo do
// líder.
//
// Como no painel do notch, NADA do jogo é decidido aqui: tudo vem do JSON do
// ~/.local/bin/poke-team (ShellState.pokeTeam) e toda ação vira uma ordem pela
// fila ShellState.pokeEvento(). As respostas aparecem como aviso no notch e a
// janela relê o estado sozinha.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

Scope {
    id: root

    readonly property var t: ShellState.pokeTeam || ({})
    readonly property var equipo: t.equipo || []
    readonly property int selIdx: Math.min(ShellState.pokeIdleSel, Math.max(0, equipo.length - 1))
    readonly property var sel: equipo.length ? equipo[selIdx] : null
    property string catMochila: "cura"
    property string itemSel: ""
    property int golpeSlot: -1
    // caixa: 30 por página, como nos jogos (6 linhas × 5)
    readonly property var caja: t.caja || []
    readonly property int porCaixa: 30
    readonly property int nCaixas: Math.max(1, Math.ceil(caja.length / porCaixa))
    property int caixaPag: 0
    property int caixaSel: 0
    readonly property var caixaM: caixaSel >= 0 && caixaSel < caja.length ? caja[caixaSel] : null
    property var martQtd: ({})
    // para a contagem regressiva do Pokécenter: quando o estado chegou
    property real tRef: Date.now()
    property real agora: Date.now()
    onTChanged: root.tRef = Date.now()
    onCajaChanged: {
        if (root.caixaSel >= root.caja.length) root.caixaSel = Math.max(0, root.caja.length - 1);
        if (root.caixaPag >= root.nCaixas) root.caixaPag = root.nCaixas - 1;
    }
    Timer { interval: 1000; repeat: true; running: win.visible; onTriggered: root.agora = Date.now() }

    function simboloGenero(g) { return g === "f" ? " ♀" : g === "m" ? " ♂" : ""; }
    function siglaStatus(s) { return ({ par: "PAR", brn: "QUE", psn: "ENV", tox: "ENV", slp: "DOR", frz: "CON" })[s] || ""; }
    function corStatus(s) { return ({ par: "#f2c84b", brn: "#f0913a", psn: "#a552cc", tox: "#a552cc", slp: "#9ba4b4", frz: "#5fcfd0" })[s] || PokeTema.sub; }
    function gifNum(num, shiny) { return ShellState.home + (shiny ? "/.cache/pokeshiny/" : "/.cache/pokeanim/") + num + ".gif"; }
    function nomeEspecie(num) {
        const todos = root.equipo.concat(root.caja);
        const m = todos.find(x => x.num === num);
        return m ? m.especie_es : "#" + num;
    }
    function inscritoIdx(i) {
        const x = root.t.liga_inscricao || {};
        return Object.keys(x).some(k => (x[k].puestos || []).indexOf(i) >= 0);
    }
    // cartão do Hall da Fama -> ~/Imagens/PokeIdle/*.png + clipboard
    property var cartaoDados: null
    function gerarCartao(e) {
        root.cartaoDados = e;
        Quickshell.execDetached(["mkdir", "-p", ShellState.home + "/Imagens/PokeIdle"]);
        cartaoTimer.restart();
    }
    Timer {
        id: cartaoTimer
        interval: 700
        onTriggered: {
            const e = root.cartaoDados;
            if (!e) return;
            const caminho = ShellState.home + "/Imagens/PokeIdle/hall-" + e.regiao + "-" + e.data + "-" + (e.vez || 1) + ".png";
            cartao.grabToImage(function (r) {
                if (r.saveToFile(caminho)) {
                    Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\"", "sh", caminho]);
                    ShellState.toast(Icons.pokeball, "Cartão salvo em Imagens/PokeIdle e copiado para a área de transferência!");
                } else {
                    ShellState.toast(Icons.pokeball, "Não deu para salvar o cartão.");
                }
                root.cartaoDados = null;
            }, Qt.size(1200, 630));
        }
    }

    function nomeDe(m) { return m ? (m.mote || m.especie_es || m.especie || "?") : ""; }
    function gifDe(m) { return m && m.gif ? "file://" + m.gif : ""; }
    function corHp(p) { return p > 0.5 ? PokeTema.ok : p > 0.2 ? PokeTema.warn : PokeTema.crit; }
    function dinheiro(v) { return (v || 0).toLocaleString(Qt.locale("pt_BR"), "f", 0); }
    function tempo(seg) {
        seg = Math.max(0, Math.floor(seg));
        const h = Math.floor(seg / 3600), m = Math.floor((seg % 3600) / 60), s = seg % 60;
        return h > 0 ? h + "h" + String(m).padStart(2, "0") : m + ":" + String(s).padStart(2, "0");
    }
    function restante(m) { return (m.centro_restante || 0) - (root.agora - root.tRef) / 1000; }
    function abrirResumo(i) {
        ShellState.pokeIdleSel = i;
        ShellState.pokeIdleAba = "resumo";
        root.golpeSlot = -1;
        ShellState.pokeGolpesCarregar(i);
    }

    // qs ipc call pokeidle aba mochila   (também: toggle)
    IpcHandler {
        target: "pokeidle"
        function toggle(): void { ShellState.pokeIdleToggle(); }
        // teste: faz um selvagem aparecer agora (qs ipc call pokeidle selvagem)
        function selvagem(): void { ShellState.pokeEvento(["evento", "minuto", "--forcar-encontro"]); }
        // teste: qs ipc call pokeidle batalha "golpe 0"
        // teste: qs ipc call pokeidle lancar ultra-ball
        function lancar(bola: string): void { ShellState.pokeLancar(bola); }
        // teste: qs ipc call pokeidle menu golpes   (acoes|golpes|pokemon|bolsa)
        function menu(nome: string): void { bat.menu = nome; }
        // teste: qs ipc call pokeidle previa 0
        function previa(puesto: int): void { ShellState.pokePreviaAbrir(puesto); }
        // qs ipc call pokeidle cartao 0   (gera o cartão da entrada N do Hall)
        function cartao(i: int): void { const h = (root.t.ligas || {}).hall || []; if (h[i]) root.gerarCartao(h[i]); }
        function batalha(acao: string): void { ShellState.pokeBatalhaAcao(acao.split(" ")); ShellState.pokeIdleOpen = true; }
        function aba(nome: string): void {
            if (nome === "resumo") root.abrirResumo(root.selIdx);
            else ShellState.pokeIdleAba = nome;
            ShellState.pokeIdleOpen = true;
        }
    }

    FloatingWindow {
        id: win
        visible: ShellState.pokeIdleOpen
        title: "PokéIdle"
        implicitWidth: 1100
        implicitHeight: 720
        minimumSize.width: 900
        minimumSize.height: 600
        color: PokeTema.bg
        onVisibleChanged: {
            if (!win.visible) ShellState.pokeIdleOpen = false;
            else ShellState.pokeBatalhaRetomar();
        }
        Connections {
            target: ShellState
            function onPokeTeamChanged() { if (win.visible) ShellState.pokeBatalhaRetomar(); }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: ShellState.pokeIdleOpen = false
            Shortcut { sequence: "Ctrl+W"; onActivated: ShellState.pokeIdleOpen = false }

            // ═══════════ PRIMEIRA VEZ: escolha do inicial ═══════════
            Rectangle {
                id: telaInicial
                anchors.fill: parent
                z: 10
                visible: !!root.t.precisa_inicial
                color: PokeTema.bg

                property string regiao: "Kanto"
                property var escolhido: null
                readonly property var regioes: ["Kanto", "Johto", "Hoenn", "Sinnoh", "Unova", "Kalos", "Alola", "Galar", "Paldea"]
                readonly property var numerais: ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
                readonly property var daRegiao: (root.t.iniciais || []).filter(p => p.regiao === telaInicial.regiao)
                readonly property color acc: escolhido && escolhido.tipos.length ? PokeTema.cor(escolhido.tipos[0].id) : "#5fbd58"
                onVisibleChanged: { telaInicial.escolhido = null; apelido.text = ""; }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // barra lateral: as regiões
                    Lateral {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 230
                        acc: telaInicial.acc
                        subtitulo: "Escolha seu parceiro"

                        Repeater {
                            model: telaInicial.regioes
                            AbaLateral {
                                required property string modelData
                                required property int index
                                Layout.fillWidth: true
                                acc: telaInicial.acc
                                rotulo: modelData
                                ativa: telaInicial.regiao === modelData
                                onClicked: { telaInicial.regiao = modelData; telaInicial.escolhido = null; }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 24
                        spacing: 18

                        ColumnLayout {
                            spacing: 4
                            Txt { text: "Bem-vindo ao mundo Pokémon!"; font.pixelSize: 24; font.weight: Font.DemiBold }
                            Txt {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: "Toda jornada começa com um parceiro. Ele começa no nível 5 e cresce com o tempo que você passa no PC e com as missões do dia."
                                color: PokeTema.sub
                                font.pixelSize: 13
                            }
                        }

                        // os 3 iniciais da região
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16
                            Repeater {
                                model: telaInicial.daRegiao
                                Card {
                                    id: ini
                                    required property var modelData
                                    readonly property bool marcado: !!telaInicial.escolhido && telaInicial.escolhido.num === modelData.num
                                    readonly property color corT: modelData.tipos.length ? PokeTema.cor(modelData.tipos[0].id) : PokeTema.acc
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: marcado ? Qt.tint(PokeTema.card, PokeTema.tinta(corT, 0.10)) : iniMa.containsMouse ? PokeTema.card2 : PokeTema.card
                                    border.width: marcado ? 2 : 1
                                    border.color: marcado ? corT : PokeTema.line
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea {
                                        id: iniMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: telaInicial.escolhido = ini.modelData
                                    }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 18
                                        spacing: 10
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Txt { text: ini.modelData.especie_es; font.pixelSize: 20; font.weight: Font.DemiBold }
                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: ini.modelData.genero; color: PokeTema.dim; font.pixelSize: 11 }
                                            Row {
                                                Layout.topMargin: 6
                                                spacing: 6
                                                Repeater {
                                                    model: ini.modelData.tipos
                                                    TipoPill { required property var modelData; tipo: modelData.id; pequeno: true }
                                                }
                                            }
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 150
                                            PokeBola { topo: "#283141"; fundo: "#283141"; anchors.centerIn: parent; width: 150; height: 150; traco: ini.color }
                                            Sombra { anchors.horizontalCenter: parent.horizontalCenter; y: 126 }
                                            AnimatedImage {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 14
                                                width: 124; height: 124
                                                source: ini.modelData.gif ? "file://" + ini.modelData.gif : ""
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                playing: win.visible && telaInicial.visible
                                            }
                                        }
                                        // status base
                                        Repeater {
                                            model: ini.modelData.base || []
                                            RowLayout {
                                                required property int modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Txt {
                                                    Layout.preferredWidth: 62
                                                    text: ["HP", "Ataque", "Defesa", "At. Esp.", "Def. Esp.", "Veloc."][index]
                                                    color: PokeTema.sub
                                                    font.pixelSize: 12
                                                }
                                                Num { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignRight; text: modelData; font.pixelSize: 12 }
                                                Barra { Layout.fillWidth: true; valor: modelData / 130; cor: PokeTema.corStatLista[index]; altura: 6 }
                                            }
                                        }
                                        Txt {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.topMargin: 4
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            text: ini.modelData.desc
                                            color: PokeTema.sub
                                            font.pixelSize: 12
                                            lineHeight: 1.15
                                        }
                                    }
                                }
                            }
                        }

                        // confirmação
                        Card {
                            Layout.fillWidth: true
                            implicitHeight: 66
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 14
                                spacing: 12
                                PokeBola { width: 22; height: 22; traco: PokeTema.card }
                                Txt {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: telaInicial.escolhido
                                          ? "Escolher " + telaInicial.escolhido.especie_es + " como seu parceiro?"
                                          : "Clique num pokémon para escolher."
                                    color: telaInicial.escolhido ? PokeTema.text : PokeTema.dim
                                    font.pixelSize: 14
                                }
                                TextField {
                                    id: apelido
                                    visible: !!telaInicial.escolhido
                                    Layout.preferredWidth: 190
                                    implicitHeight: 38
                                    placeholderText: "Apelido (opcional)"
                                    maximumLength: 12
                                    color: PokeTema.text
                                    placeholderTextColor: PokeTema.dim
                                    font.family: PokeTema.ui
                                    font.pixelSize: 13
                                    leftPadding: 12
                                    background: Rectangle {
                                        radius: 10
                                        color: PokeTema.card2
                                        border.width: 1
                                        border.color: apelido.activeFocus ? telaInicial.acc : PokeTema.line
                                    }
                                    onAccepted: btnConfirmar.clicked()
                                }
                                Botao {
                                    id: btnConfirmar
                                    visible: !!telaInicial.escolhido
                                    texto: "Confirmar"
                                    primario: true
                                    acc: telaInicial.acc
                                    implicitHeight: 38
                                    onClicked: {
                                        const a = ["inicial", telaInicial.escolhido.especie];
                                        if (apelido.text.trim()) a.push("--mote", apelido.text.trim());
                                        ShellState.pokeEvento(a);
                                        ShellState.pokeIdleAba = "time";
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════ BATALHA (fase 2) ═══════════
            // Toca em sequência os eventos que 'poke-team batalha' devolve:
            // texto com máquina de escrever, barras de HP animadas, entradas e
            // desmaios. Nada é decidido aqui.
            Rectangle {
                id: bat
                anchors.fill: parent
                z: 20
                visible: !!ShellState.pokeBatalha
                color: PokeTema.bg
                clip: true

                readonly property var b: ShellState.pokeBatalha
                readonly property int n: b && b.n ? b.n : 1
                // quem aparece em cada posição: {lut, hp, caiu, pisca}
                property var cena: ({ meu: [null, null], ini: [null, null] })
                // duplas: o comando de cada pokémon é montado antes de enviar o turno
                property int posAtual: 0
                property var planos: []
                property var golpeMira: null
                // só para a tela: quem caiu, abertura e cor do último golpe
                property var baixas: ({ meu: 0, ini: 0 })
                property bool abertura: false
                property bool treinadorEmCampo: false
                property color ultimaCor: "#ffffff"
                property real tremorX: 0
                readonly property var palco: ({
                    ginasio: { ini: 0.67, meu: 0.97, alinha: Image.AlignBottom },
                    arena: { ini: 0.52, meu: 0.97, alinha: Image.AlignVCenter },
                    campo: { ini: 0.58, meu: 0.97, alinha: Image.AlignVCenter }
                })[b && b.cenario ? b.cenario : "arena"]
                property string texto: ""
                property int mostrados: 0
                property var fila: []
                // espera | acoes | golpes | mira | pokemon | bolsa | alvo | fugir | troca | resultado
                property string menu: "espera"
                property string itemEscolhido: ""
                property int dicaGolpe: -1
                readonly property real campoH: height - 196

                onVisibleChanged: if (!visible) {
                    bat.cenaVazia(); bat.planos = []; bat.fila = []; bat.menu = "espera"; bat.texto = "";
                    bat.abertura = false; bat.treinadorEmCampo = false;
                }
                Connections {
                    target: ShellState
                    function onPokeBatalhaSeqChanged() { bat.receber(); }
                }
                Component.onCompleted: if (ShellState.pokeBatalha) bat.receber()

                function lut(lado, i) {
                    const x = bat.b ? bat.b[lado][i] : null;
                    return x ? Object.assign({}, x) : null;
                }
                function cenaVazia() { bat.cena = { meu: [null, null], ini: [null, null] }; }
                function por(lado, pos, dados) {
                    const c = { meu: bat.cena.meu.slice(), ini: bat.cena.ini.slice() };
                    c[lado][pos] = Object.assign({ pisca: 0, caiu: false }, c[lado][pos] || {}, dados);
                    bat.cena = c;
                }
                function receber() {
                    const b = ShellState.pokeBatalha;
                    if (!b)
                        return;
                    const evs = ShellState.pokeBatalhaEventos || [];
                    const novaLuta = evs.some(e => e.t === "inicio");
                    if (novaLuta) {
                        bat.cenaVazia();
                        bat.baixas = { meu: 0, ini: 0 };
                    } else if (!bat.cena.meu[0] && !bat.cena.ini[0]) {
                        bat.baixas = { meu: b.meu.filter(l => l.hp <= 0).length, ini: b.ini.filter(l => l.hp <= 0).length };
                    }
                    for (const lado of ["meu", "ini"]) {
                        for (let p = 0; p < b.n; p++) {
                            const i = b.campo[lado][p];
                            if (!bat.cena[lado][p] && i !== null && !evs.some(e => e.t === "entra" && e.lado === lado && e.pos === p)) {
                                const x = bat.lut(lado, i);
                                bat.por(lado, p, { lut: x, hp: x.hp, caiu: x.hp <= 0, est: b.vol[lado][p].est });
                            }
                        }
                    }
                    bat.fila = bat.fila.concat(evs);
                    bat.menu = "espera";
                    if (!passo.running && !digita.running)
                        bat.proximo();
                }
                function proximo() {
                    if (bat.fila.length === 0) {
                        const b = bat.b;
                        if (!b) return;
                        bat.menu = b.fim ? "resultado" : b.aguardando_troca ? "troca" : "acoes";
                        if (bat.menu === "acoes") {
                            bat.planos = [];
                            bat.posAtual = bat.vivas()[0] || 0;
                        }
                        return;
                    }
                    const e = bat.fila[0];
                    bat.fila = bat.fila.slice(1);
                    if (bat.abertura)
                        bat.treinadorEmCampo = !!(bat.b && bat.b.sprite_treinador);
                    bat.abertura = false;
                    const atual = e.lado && e.pos !== undefined ? (bat.cena[e.lado][e.pos] || {}) : {};
                    if (e.t === "inicio") {
                        bat.abertura = true;
                        bat.esperar(1500);
                    } else if (e.t === "txt") {
                        bat.texto = e.txt;
                        bat.mostrados = 0;
                        digita.start();
                    } else if (e.t === "golpe") {
                        bat.ultimaCor = PokeTema.cor(e.tipo);
                        bat.por(e.lado, e.pos, { atk: (atual.atk || 0) + 1 });
                        if (e.classe === "status") {
                            for (const a of e.alvos) {
                                const x = bat.cena[a[0]][a[1]] || {};
                                bat.por(a[0], a[1], { brilho: (x.brilho || 0) + 1, flashCor: bat.ultimaCor });
                            }
                        }
                        bat.proximo();
                    } else if (e.t === "efeito") {
                        const partes = [];
                        if (e.critico) partes.push("Crítico");
                        if (e.mult === 0) partes.push("Não afeta");
                        else if (e.mult > 1) partes.push("Super efetivo");
                        else if (e.mult < 1) partes.push("Pouco efetivo");
                        if (partes.length) {
                            bat.por(e.lado, e.pos, {
                                aviso: partes.join(" · "), avisoN: (atual.avisoN || 0) + 1,
                                avisoCor: e.mult === 0 ? "#c7cedb" : e.mult < 1 && !e.critico ? "#ff9b8f" : "#ffd75e"
                            });
                        }
                        if (e.critico || e.mult > 1) tremeTela.restart();
                        bat.proximo();
                    } else if (e.t === "estagio") {
                        bat.por(e.lado, e.pos, { est: e.est });
                        bat.proximo();
                    } else if (e.t === "hp") {
                        bat.por(e.lado, e.pos, {
                            hp: e.hp, pisca: (atual.pisca || 0) + (e.golpe ? 1 : 0),
                            flash: (atual.flash || 0) + (e.golpe ? 1 : 0), flashCor: bat.ultimaCor
                        });
                        bat.esperar(e.golpe ? 650 : 450);
                    } else if (e.t === "status") {
                        bat.por(e.lado, e.pos, { lut: Object.assign({}, atual.lut, { status: e.status }) });
                        bat.proximo();
                    } else if (e.t === "entra") {
                        const x = Object.assign(bat.lut(e.lado, e.i) || {}, { hp: e.hp, hp_max: e.hp_max, status: e.status });
                        if (e.lado === "ini") bat.treinadorEmCampo = false;
                        bat.por(e.lado, e.pos, { lut: x, hp: e.hp, caiu: false, est: {}, entra: (atual.entra || 0) + 1 });
                        bat.esperar(450);
                    } else if (e.t === "desmaia") {
                        bat.por(e.lado, e.pos, { caiu: true });
                        const b2 = { meu: bat.baixas.meu, ini: bat.baixas.ini };
                        b2[e.lado]++;
                        bat.baixas = b2;
                        bat.esperar(700);
                    } else {
                        bat.proximo();
                    }
                }
                // posições do seu lado que ainda recebem comando
                function vivas() {
                    if (!bat.b) return [];
                    const fora = [];
                    for (let p = 0; p < bat.n; p++) {
                        const i = bat.b.campo.meu[p];
                        if (i !== null && bat.b.meu[i].hp > 0) fora.push(p);
                    }
                    return fora;
                }
                function lutAtual() { return bat.b ? bat.b.meu[bat.b.campo.meu[bat.posAtual]] || null : null; }
                function planejar(a) {
                    const p = bat.planos.concat([Object.assign({ pos: bat.posAtual }, a)]);
                    const v = bat.vivas();
                    const k = v.indexOf(bat.posAtual);
                    if (k + 1 < v.length) {
                        bat.planos = p;
                        bat.posAtual = v[k + 1];
                        bat.dicaGolpe = 0;
                        bat.menu = "acoes";
                    } else {
                        bat.planos = [];
                        bat.acao(["turno", JSON.stringify(p)]);
                    }
                }
                function voltarPlano() {
                    const p = bat.planos.slice();
                    const u = p.pop();
                    bat.planos = p;
                    bat.posAtual = u.pos;
                    bat.menu = "acoes";
                }
                function escolherGolpe(slot, g) {
                    const uma = ["selected-pokemon", "selected-pokemon-me-first", "user-or-ally"].indexOf(g.alvo) >= 0;
                    if (bat.n > 1 && uma && bat.opcoesMira(g).length > 1) {
                        bat.golpeMira = { slot: slot, g: g };
                        bat.menu = "mira";
                    } else {
                        bat.dicaGolpe = -1;
                        bat.planejar({ tipo: "golpe", slot: slot });
                    }
                }
                function opcoesMira(g) {
                    const fora = [];
                    if (!g || !bat.b) return fora;
                    if (g.alvo !== "user-or-ally") {
                        for (let p = 0; p < bat.n; p++) {
                            const e = bat.cena.ini[p];
                            if (e && !e.caiu && e.lut)
                                fora.push({ alvo: "ini:" + p, nome: e.lut.nome, detalhe: g.classe === "status" ? "" : bat.fmtMult(bat.multEm(g, e.lut)), img: e.lut.tipos ? PokeTema.imgTipo(e.lut.tipos[0]) : "" });
                        }
                    } else {
                        fora.push({ alvo: "meu:" + bat.posAtual, nome: bat.lutAtual().nome, detalhe: "Ele mesmo", img: "" });
                    }
                    for (const p of bat.vivas()) {
                        if (p !== bat.posAtual) {
                            const l = bat.b.meu[bat.b.campo.meu[p]];
                            fora.push({ alvo: "meu:" + p, nome: l.nome, detalhe: "Parceiro", img: "" });
                        }
                    }
                    return fora;
                }
                function planejados() { return bat.planos.filter(a => a.tipo === "trocar").map(a => a.i); }
                function esperar(ms) { passo.interval = ms; passo.restart(); }
                function pular() {
                    if (digita.running) { digita.stop(); bat.mostrados = bat.texto.length; bat.esperar(250); }
                    else if (passo.running) { passo.stop(); bat.proximo(); }
                }
                function acao(args) {
                    bat.menu = "espera";
                    ShellState.pokeBatalhaAcao(args);
                }
                Timer {
                    id: digita
                    interval: 16
                    repeat: true
                    onTriggered: {
                        bat.mostrados += 2;
                        if (bat.mostrados >= bat.texto.length) {
                            stop();
                            bat.mostrados = bat.texto.length;
                            // a última frase (a pergunta) não espera
                            bat.esperar(bat.fila.length === 0 ? 10 : 750);
                        }
                    }
                }
                Timer { id: passo; onTriggered: bat.proximo() }

                SequentialAnimation {
                    id: tremeTela
                    NumberAnimation { target: bat; property: "tremorX"; to: 9; duration: 45 }
                    NumberAnimation { target: bat; property: "tremorX"; to: -8; duration: 70 }
                    NumberAnimation { target: bat; property: "tremorX"; to: 5; duration: 60 }
                    NumberAnimation { target: bat; property: "tremorX"; to: 0; duration: 60 }
                }
                // ── cenário em tela inteira ──
                Image {
                    anchors.fill: parent
                    anchors.margins: -14
                    source: bat.b ? PokeTema.imgCenario(bat.b.cenario) : ""
                    fillMode: Image.PreserveAspectCrop
                    verticalAlignment: bat.palco.alinha
                    smooth: true
                    mipmap: true
                    transform: Translate { x: bat.tremorX }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 150
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#8c090d14" }
                        GradientStop { position: 1; color: "#00090d14" }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 300
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00090d14" }
                        GradientStop { position: 1; color: "#b8090d14" }
                    }
                }

                // ── campo ──
                Item {
                    id: campo
                    transform: Translate { x: bat.tremorX }
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: bat.campoH

                    // o treinador espera em campo até mandar o primeiro pokémon
                    Image {
                        readonly property real lado: Math.min(230, campo.height * 0.5)
                        width: lado
                        height: lado
                        x: bat.treinadorEmCampo ? campo.width * 0.72 - lado / 2 : campo.width + 40
                        y: campo.height * bat.palco.ini - lado * 0.9
                        source: bat.b && bat.b.sprite_treinador ? "file://" + bat.b.sprite_treinador : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
                    }

                    // inimigos (de frente)
                    Repeater {
                        model: bat.n
                        LutadorCampo {
                            required property int index
                            dado: bat.cena.ini[index]
                            lado: Math.min(bat.n > 1 ? 150 : 190, campo.height * (bat.n > 1 ? 0.32 : 0.42))
                            cx: campo.width * (bat.n > 1 ? [0.62, 0.84][index] : 0.72)
                            cy: campo.height * bat.palco.ini
                            ativo: bat.visible
                        }
                    }
                    // os seus (de costas)
                    Repeater {
                        model: bat.n
                        LutadorCampo {
                            id: meuCampo
                            required property int index
                            dado: bat.cena.meu[index]
                            lado: Math.min(bat.n > 1 ? 190 : 250, campo.height * (bat.n > 1 ? 0.42 : 0.56))
                            cx: campo.width * (bat.n > 1 ? [0.16, 0.40][index] : 0.27)
                            cy: campo.height * bat.palco.meu
                            costas: true
                            ativo: bat.visible
                            Text {
                                visible: bat.n > 1 && meuCampo.index === bat.posAtual && ["acoes", "golpes", "mira", "pokemon", "bolsa", "alvo"].indexOf(bat.menu) >= 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -10
                                text: "▼"
                                color: "#ffffff"
                                style: Text.Outline
                                styleColor: "#0b0f17"
                                font.pixelSize: 20
                            }
                        }
                    }

                    // painéis de HP
                    Column {
                        x: 24; y: 20
                        spacing: 6
                        Repeater {
                            model: bat.n
                            PainelHp {
                                required property int index
                                readonly property var e: bat.cena.ini[index]
                                width: Math.min(bat.n > 1 ? 340 : 400, campo.width * 0.4)
                                lut: e ? e.lut : null
                                hp: e ? e.hp : 0
                                est: e && e.est ? e.est : ({})
                                inimigo: true
                                compacto: bat.n > 1
                                visible: !!lut && !(bat.n > 1 && e.caiu)
                            }
                        }
                        BolasTime { total: bat.b ? bat.b.ini.length : 0; vivos: total - bat.baixas.ini }
                    }
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        spacing: 6
                        BolasTime { anchors.right: parent.right; total: bat.b ? bat.b.meu.length : 0; vivos: total - bat.baixas.meu }
                        Repeater {
                            model: bat.n
                            PainelHp {
                                required property int index
                                readonly property var e: bat.cena.meu[index]
                                width: Math.min(bat.n > 1 ? 350 : 420, campo.width * 0.42)
                                lut: e ? e.lut : null
                                hp: e ? e.hp : 0
                                est: e && e.est ? e.est : ({})
                                inimigo: false
                                compacto: bat.n > 1
                                visible: !!lut && !(bat.n > 1 && e.caiu)
                            }
                        }
                    }
                    // quem é o adversário e o cap do desafio
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        width: rotuloLuta.implicitWidth + 22
                        height: 28
                        radius: 14
                        color: "#b8101621"
                        Txt {
                            id: rotuloLuta
                            anchors.centerIn: parent
                            text: !bat.b ? "" : bat.b.treinador + (bat.b.cap ? "  ·  cap " + bat.b.cap : bat.b.rotulo ? "  ·  " + bat.b.rotulo : "")
                            font.pixelSize: 12
                        }
                    }
                }

                // ── caixa de texto + botões ──
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.top: campo.bottom
                    anchors.margins: 18
                    spacing: 16

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: "#e6141a25"
                        border.width: 1
                        border.color: "#55ffffff"
                        Rectangle { x: 0; width: 6; height: parent.height; radius: 3; color: PokeTema.acc }
                        MouseArea { anchors.fill: parent; onClicked: bat.pular() }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 22
                            anchors.leftMargin: 30
                            wrapMode: Text.WordWrap
                            text: {
                                if (bat.menu === "golpes") return "";
                                if (bat.menu === "acoes" && bat.n > 1 && bat.lutAtual()) return "O que " + bat.lutAtual().nome + " vai fazer?";
                                if (bat.menu === "mira") return "Qual alvo?";
                                if (bat.menu === "fugir") return "Desistir conta como derrota. Quer mesmo desistir?";
                                if (bat.menu === "pokemon") return "Quem vai entrar?";
                                if (bat.menu === "troca") return "Escolha o próximo pokémon.";
                                if (bat.menu === "bolsa") return "Escolha um item de cura.";
                                if (bat.menu === "alvo") return "Usar em quem?";
                                return bat.texto.substring(0, bat.mostrados);
                            }
                            color: PokeTema.text
                            font.family: PokeTema.mono
                            font.pixelSize: 19
                            lineHeight: 1.25
                        }
                        // ── inspeção do golpe: tipo · categoria / PP · efetividade ──
                        ColumnLayout {
                            id: inspec
                            readonly property var g: bat.menu === "golpes" ? (bat.golpesMeu()[Math.max(0, bat.dicaGolpe)] || null) : null
                            readonly property var m: bat.mult(g)
                            visible: !!g
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 14
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            spacing: 8
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Txt { text: inspec.g ? inspec.g.nome : ""; font.pixelSize: 18; font.weight: Font.DemiBold }
                                Num {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: inspec.g ? "Poder " + (inspec.g.poder || "—") + "  ·  Precisão " + (inspec.g.precisao ? inspec.g.precisao + "%" : "—") : ""
                                    color: PokeTema.sub
                                    font.pixelSize: 12
                                }
                                Botao { pequeno: true; icone: 0xF0141; texto: "Voltar"; onClicked: bat.menu = "acoes" }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8
                                // tipo
                                Quadro {
                                    TipoPill { tipo: inspec.g ? inspec.g.tipo : ""; lado: 26 }
                                    Txt { Layout.fillWidth: true; text: inspec.g ? (PokeTema.nomeTipo[inspec.g.tipo] || inspec.g.tipo) : ""; font.pixelSize: 15 }
                                }
                                // categoria
                                Quadro {
                                    Image {
                                        Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                        source: inspec.g ? PokeTema.imgCategoria(inspec.g.classe) : ""
                                        sourceSize: Qt.size(64, 64)
                                        smooth: true; mipmap: true
                                    }
                                    Txt { Layout.fillWidth: true; text: inspec.g ? (PokeTema.nomeClasse[inspec.g.classe] || "") : ""; font.pixelSize: 15 }
                                }
                                // PP
                                Quadro {
                                    Txt { text: "PP"; color: PokeTema.sub; font.pixelSize: 13; font.weight: Font.Bold }
                                    Num { text: inspec.g ? inspec.g.pp_atual + " / " + inspec.g.pp_max : ""; font.pixelSize: 15 }
                                    Barra {
                                        Layout.fillWidth: true
                                        altura: 6
                                        valor: inspec.g ? inspec.g.pp_atual / Math.max(1, inspec.g.pp_max) : 0
                                        cor: inspec.g && inspec.g.pp_atual / Math.max(1, inspec.g.pp_max) <= 0.25 ? PokeTema.warn : PokeTema.xp
                                    }
                                }
                                // efetividade
                                Quadro {
                                    Num {
                                        text: inspec.m === null ? "—" : bat.textoMult(inspec.g)
                                        color: bat.corMult(inspec.m)
                                        font.pixelSize: 17
                                        font.weight: Font.Bold
                                    }
                                    Txt {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: inspec.m === null ? "Sem dano direto"
                                            : bat.inimigosVivos().length > 1 ? "Por alvo"
                                            : inspec.m === 0 ? "Não afeta" : inspec.m > 1 ? "Super efetivo"
                                            : inspec.m < 1 ? "Pouco efetivo" : "Efetivo"
                                        color: bat.corMult(inspec.m)
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                        Text {
                            visible: bat.menu === "espera" && !digita.running && passo.running
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 16
                            text: "▼"
                            color: PokeTema.sub
                            font.pixelSize: 13
                        }
                        Botao {
                            visible: ["pokemon", "bolsa", "alvo"].indexOf(bat.menu) >= 0 || (bat.menu === "acoes" && bat.planos.length > 0)
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            pequeno: true
                            icone: 0xF0141
                            texto: "Voltar"
                            onClicked: { if (bat.menu === "acoes") bat.voltarPlano(); else bat.menu = "acoes"; }
                        }
                    }

                    // 2×2 à direita: ações, golpes ou confirmação
                    GridLayout {
                        Layout.preferredWidth: 420
                        Layout.maximumWidth: 420
                        Layout.minimumWidth: 420
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 12
                        visible: bat.gradeAberta
                        Repeater {
                            model: bat.menu === "golpes" ? 4 : bat.menu === "fugir" ? 2 : bat.menu === "mira" ? bat.listaMira.length + 1 : 4
                            BotaoBatalha {
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                readonly property var g: bat.menu === "golpes" ? (bat.golpesMeu()[index] || null) : null
                                readonly property var mi: bat.menu === "mira" ? (bat.listaMira[index] || null) : null
                                destaque: (bat.menu === "acoes" && index === 0) || (bat.menu === "golpes" && index === Math.max(0, bat.dicaGolpe))
                                icone: bat.menu === "acoes" ? [0xF040A, 0xF041D, 0xF0E10, 0xF070E][index]
                                     : bat.menu === "fugir" ? [0xF012C, 0xF0156][index]
                                     : bat.menu === "mira" && !mi ? 0xF0141 : 0
                                imagem: g ? PokeTema.imgTipo(g.tipo) : mi ? mi.img : ""
                                corIcone: g ? PokeTema.cor(g.tipo) : PokeTema.sub
                                temTipo: !!g
                                corTipo: g ? PokeTema.cor(g.tipo) : "#ffffff"
                                imagem2: g ? PokeTema.imgCategoria(g.classe) : ""
                                selo: g && bat.mult(g) !== null ? bat.fmtMult(bat.mult(g)) : ""
                                corSelo: g ? bat.corMult(bat.mult(g)) : PokeTema.sub
                                corDetalhe: !g ? PokeTema.sub : g.pp_atual <= 0 ? PokeTema.crit : g.pp_atual / Math.max(1, g.pp_max) <= 0.25 ? PokeTema.warn : PokeTema.text
                                texto: bat.menu === "acoes" ? ["Lutar", "Pokémon", "Bolsa", "Fugir"][index]
                                     : bat.menu === "fugir" ? ["Desistir", "Continuar"][index]
                                     : bat.menu === "mira" ? (mi ? mi.nome : "Voltar")
                                     : g ? g.nome : "—"
                                detalhe: g ? "PP " + g.pp_atual + "/" + g.pp_max : mi ? mi.detalhe : ""
                                habilitado: bat.menu === "golpes" ? (!!g && (g.pp_atual > 0 || bat.semPP()))
                                          : !(bat.menu === "acoes" && index === 2 && bat.b && bat.b.sem_itens)
                                onHover: (sim) => { if (bat.menu === "golpes" && sim && g) bat.dicaGolpe = index; }
                                onClicked: {
                                    if (bat.menu === "acoes") {
                                        bat.dicaGolpe = 0;
                                        bat.menu = ["golpes", "pokemon", "bolsa", "fugir"][index];
                                    } else if (bat.menu === "fugir") {
                                        if (index === 0) bat.acao(["desistir"]); else bat.menu = "acoes";
                                    } else if (bat.menu === "mira") {
                                        if (mi) {
                                            bat.dicaGolpe = -1;
                                            bat.planejar({ tipo: "golpe", slot: bat.golpeMira.slot, alvo: mi.alvo });
                                        } else {
                                            bat.menu = "golpes";
                                        }
                                    } else if (g) {
                                        bat.escolherGolpe(index, g);
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        Layout.preferredWidth: 420
                        Layout.fillHeight: true
                        visible: !bat.gradeAberta
                        Txt {
                            anchors.centerIn: parent
                            visible: bat.menu === "espera"
                            text: ShellState.pokeBatalhaOcupado ? "…" : ""
                            color: PokeTema.dim
                        }
                    }
                }
                readonly property bool gradeAberta: ["acoes", "golpes", "fugir", "mira"].indexOf(bat.menu) >= 0
                readonly property var listaMira: bat.menu === "mira" && bat.golpeMira ? bat.opcoesMira(bat.golpeMira.g) : []
                function golpesMeu() {
                    const l = bat.lutAtual();
                    return l ? (l.golpes_info || []) : [];
                }
                function semPP() { return bat.golpesMeu().every(g => g.pp_atual <= 0); }
                function inimigosVivos() {
                    return bat.cena.ini.filter((e, p) => p < bat.n && e && e.lut && !e.caiu);
                }
                function multEm(g, l) {
                    let m = 1;
                    for (const t of l.tipos || [])
                        m *= bat.tabela(g.tipo, t);
                    return m;
                }
                function mult(g) {
                    const v = bat.inimigosVivos();
                    if (!g || g.classe === "status" || !v.length) return null;
                    return Math.max.apply(null, v.map(e => bat.multEm(g, e.lut)));
                }
                function textoMult(g) {
                    return bat.inimigosVivos().map(e => bat.fmtMult(bat.multEm(g, e.lut))).join("  /  ");
                }
                function corMult(m) {
                    return m === null ? PokeTema.sub : m === 0 ? PokeTema.dim : m > 1 ? PokeTema.ok : m < 1 ? PokeTema.crit : PokeTema.text;
                }
                function fmtMult(m) { return String(m).replace(".", ",") + "×"; }
                readonly property var _tab: ({
                    normal: { rock: .5, ghost: 0, steel: .5 },
                    fire: { fire: .5, water: .5, grass: 2, ice: 2, bug: 2, rock: .5, dragon: .5, steel: 2 },
                    water: { fire: 2, water: .5, grass: .5, ground: 2, rock: 2, dragon: .5 },
                    electric: { water: 2, electric: .5, grass: .5, ground: 0, flying: 2, dragon: .5 },
                    grass: { fire: .5, water: 2, grass: .5, poison: .5, ground: 2, flying: .5, bug: .5, rock: 2, dragon: .5, steel: .5 },
                    ice: { fire: .5, water: .5, grass: 2, ice: .5, ground: 2, flying: 2, dragon: 2, steel: .5 },
                    fighting: { normal: 2, ice: 2, poison: .5, flying: .5, psychic: .5, bug: .5, rock: 2, ghost: 0, dark: 2, steel: 2, fairy: .5 },
                    poison: { grass: 2, poison: .5, ground: .5, rock: .5, ghost: .5, steel: 0, fairy: 2 },
                    ground: { fire: 2, electric: 2, grass: .5, poison: 2, flying: 0, bug: .5, rock: 2, steel: 2 },
                    flying: { electric: .5, grass: 2, fighting: 2, bug: 2, rock: .5, steel: .5 },
                    psychic: { fighting: 2, poison: 2, psychic: .5, dark: 0, steel: .5 },
                    bug: { fire: .5, grass: 2, fighting: .5, poison: .5, flying: .5, psychic: 2, ghost: .5, dark: 2, steel: .5, fairy: .5 },
                    rock: { fire: 2, ice: 2, fighting: .5, ground: .5, flying: 2, bug: 2, steel: .5 },
                    ghost: { normal: 0, psychic: 2, ghost: 2, dark: .5 },
                    dragon: { dragon: 2, steel: .5, fairy: 0 },
                    dark: { fighting: .5, psychic: 2, ghost: 2, dark: .5, fairy: .5 },
                    steel: { fire: .5, water: .5, electric: .5, ice: 2, rock: 2, steel: .5, fairy: 2 },
                    fairy: { fire: .5, fighting: 2, poison: .5, dragon: 2, dark: 2, steel: .5 }
                })
                function tabela(a, d) { const x = (bat._tab[a] || {})[d]; return x === undefined ? 1 : x; }

                // ── lista do time (trocar / alvo do item) ──
                Card {
                    visible: ["pokemon", "troca", "alvo"].indexOf(bat.menu) >= 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    width: Math.min(640, parent.width - 48)
                    height: listaCol.implicitHeight + 36
                    z: 5
                    ColumnLayout {
                        id: listaCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 8
                        Cabecalho {
                            Layout.fillWidth: true
                            texto: bat.menu === "alvo" ? "Usar " + (bat.itemNome() || "") : "Seu time"
                            extra: bat.menu === "troca" ? "escolha quem entra" : ""
                        }
                        Repeater {
                            model: bat.b ? bat.b.meu : []
                            Rectangle {
                                id: linhaT
                                required property var modelData
                                required property int index
                                readonly property bool emCampo: !!bat.b && bat.b.campo.meu.indexOf(index) >= 0
                                readonly property bool podeTrocar: modelData.hp > 0 && !emCampo && bat.planejados().indexOf(index) < 0
                                readonly property bool podeItem: modelData.hp > 0 && modelData.hp < modelData.hp_max
                                readonly property bool ok: bat.menu === "alvo" ? podeItem : podeTrocar
                                Layout.fillWidth: true
                                implicitHeight: 56
                                radius: 12
                                color: ok && ltMa.containsMouse ? PokeTema.hover : PokeTema.card2
                                border.width: 1
                                border.color: emCampo ? PokeTema.tinta(PokeTema.acc, 0.6) : PokeTema.line
                                opacity: ok ? 1 : 0.5
                                MouseArea {
                                    id: ltMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: linhaT.ok ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!linhaT.ok) return;
                                        if (bat.menu === "alvo") bat.planejar({ tipo: "item", item: bat.itemEscolhido, i: linhaT.index });
                                        else if (bat.menu === "pokemon") bat.planejar({ tipo: "trocar", i: linhaT.index });
                                        else bat.acao(["trocar", String(linhaT.index)]);
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 16
                                    spacing: 12
                                    AnimatedImage {
                                        Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                        source: root.gifDe({ gif: linhaT.modelData.icone })
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                        playing: false
                                    }
                                    ColumnLayout {
                                        Layout.preferredWidth: 170
                                        spacing: 0
                                        Txt { text: linhaT.modelData.nome + root.simboloGenero(linhaT.modelData.genero); font.pixelSize: 15 }
                                        Num { text: "Nv. " + linhaT.modelData.nivel + (linhaT.emCampo ? "  · em campo" : ""); color: PokeTema.sub; font.pixelSize: 12 }
                                    }
                                    Barra {
                                        Layout.fillWidth: true
                                        altura: 8
                                        valor: linhaT.modelData.hp / Math.max(1, linhaT.modelData.hp_max)
                                        cor: root.corHp(linhaT.modelData.hp / Math.max(1, linhaT.modelData.hp_max))
                                    }
                                    Num { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: linhaT.modelData.hp + "/" + linhaT.modelData.hp_max; font.pixelSize: 13 }
                                    Etiqueta { visible: !!linhaT.modelData.status; texto: root.siglaStatus(linhaT.modelData.status); cor: root.corStatus(linhaT.modelData.status) }
                                }
                            }
                        }
                        Txt {
                            visible: !!(bat.b && bat.b.fora && bat.b.fora.length)
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: bat.b && bat.b.fora ? "Fora deste desafio: " + bat.b.fora.join("; ") : ""
                            color: PokeTema.dim
                            font.pixelSize: 12
                        }
                    }
                }
                function itemNome() {
                    const x = (root.t.mochila_lista || []).find(i => i.id === bat.itemEscolhido);
                    return x ? x.nome : "";
                }

                // ── bolsa ──
                Card {
                    visible: bat.menu === "bolsa"
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    width: Math.min(560, parent.width - 48)
                    height: bolsaCol.implicitHeight + 36
                    z: 5
                    ColumnLayout {
                        id: bolsaCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 18
                        spacing: 8
                        Cabecalho { Layout.fillWidth: true; texto: "Bolsa"; extra: "só itens de cura contra treinadores" }
                        Repeater {
                            model: (root.t.mochila_lista || []).filter(x => x.cat === "cura")
                            Rectangle {
                                id: linhaB
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 12
                                color: lbMa.containsMouse ? PokeTema.hover : PokeTema.card2
                                border.width: 1
                                border.color: PokeTema.line
                                MouseArea {
                                    id: lbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { bat.itemEscolhido = linhaB.modelData.id; bat.menu = "alvo"; }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 16
                                    spacing: 12
                                    Image { Layout.preferredWidth: 32; Layout.preferredHeight: 32; source: linhaB.modelData.sprite ? "file://" + linhaB.modelData.sprite : ""; smooth: false; fillMode: Image.PreserveAspectFit }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Txt { text: linhaB.modelData.nome; font.pixelSize: 14 }
                                        Txt { text: linhaB.modelData.desc; color: PokeTema.dim; font.pixelSize: 11 }
                                    }
                                    Num { text: "×" + linhaB.modelData.qtd; color: PokeTema.sub; font.pixelSize: 14 }
                                }
                            }
                        }
                        Txt {
                            visible: (root.t.mochila_lista || []).filter(x => x.cat === "cura").length === 0
                            text: "Sem itens de cura. A PokéMart vende poções."
                            color: PokeTema.dim
                        }
                    }
                }

                // ── abertura: treinador contra você ──
                Rectangle {
                    visible: bat.abertura
                    anchors.fill: parent
                    z: 7
                    color: "#a8070a10"
                    MouseArea { anchors.fill: parent; onClicked: bat.pular() }
                    Rectangle {
                        id: faixaVs
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 210
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#f0141a25" }
                            GradientStop { position: 1; color: PokeTema.tinta(PokeTema.acc, 0.82) }
                        }
                        Rectangle { width: parent.width; height: 3; color: "#ffffff" }
                        Rectangle { y: parent.height - 3; width: parent.width; height: 3; color: "#ffffff" }
                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.leftMargin: 56
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Txt { text: "Seu time"; font.pixelSize: 26; font.weight: Font.DemiBold }
                            BolasTime { total: bat.b ? bat.b.meu.length : 0; vivos: total; lado: 24 }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "VS"
                            color: "#ffffff"
                            font.family: PokeTema.ui
                            font.pixelSize: 68
                            font.weight: Font.Black
                            font.italic: true
                        }
                        ColumnLayout {
                            anchors.right: spriteVs.left
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Txt { Layout.alignment: Qt.AlignRight; text: bat.b ? bat.b.treinador : ""; font.pixelSize: 24; font.weight: Font.DemiBold }
                            BolasTime { Layout.alignment: Qt.AlignRight; total: bat.b ? bat.b.ini.length : 0; vivos: total; lado: 24 }
                        }
                        Image {
                            id: spriteVs
                            y: -28
                            width: 240
                            height: 240
                            source: bat.b && bat.b.sprite_treinador ? "file://" + bat.b.sprite_treinador : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            NumberAnimation on x {
                                running: bat.abertura
                                from: faixaVs.width
                                to: faixaVs.width - 262
                                duration: 340
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                // ── resultado ──
                Rectangle {
                    visible: bat.menu === "resultado"
                    anchors.fill: parent
                    z: 6
                    color: Qt.rgba(0.05, 0.07, 0.1, 0.72)
                    MouseArea { anchors.fill: parent }
                    Card {
                        id: resCard
                        readonly property var r: bat.b && bat.b.resultado ? bat.b.resultado : null
                        readonly property bool venceu: !!(r && r.resultado === "vitoria")
                        anchors.centerIn: parent
                        width: 480
                        height: resCol.implicitHeight + 48
                        border.color: venceu ? PokeTema.tinta(PokeTema.acc, 0.7) : PokeTema.line
                        ColumnLayout {
                            id: resCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 24
                            spacing: 10
                            RowLayout {
                                spacing: 12
                                Insignia { visible: !!(resCard.r && resCard.r.insignia); tipo: bat.b ? bat.b.tipo_treinador : ""; regiao: bat.b ? bat.b.regiao : ""; lider: bat.b ? bat.b.alvo : ""; ganha: true; lado: 64 }
                                ColumnLayout {
                                    spacing: 0
                                    Txt {
                                        text: !resCard.r ? "" : resCard.r.campeao ? "Novo Campeão!" : resCard.venceu ? "Vitória!" : "Derrota"
                                        font.pixelSize: 26
                                        font.weight: Font.DemiBold
                                        color: resCard.venceu ? Qt.lighter(PokeTema.acc, 1.2) : PokeTema.crit
                                    }
                                    Txt { text: bat.b ? bat.b.treinador : ""; color: PokeTema.sub; font.pixelSize: 13 }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: PokeTema.line }
                            Txt { visible: !!(resCard.r && resCard.r.insignia); text: resCard.r && resCard.r.insignia ? "🏅 " + resCard.r.insignia : ""; font.pixelSize: 15 }
                            Txt { visible: !!(resCard.r && resCard.r.tm); text: resCard.r && resCard.r.tm ? "Prêmio: " + resCard.r.tm : ""; font.pixelSize: 14 }
                            Num {
                                text: !resCard.r ? "" : (resCard.venceu ? "+₽ " : "−₽ ") + root.dinheiro(Math.abs(resCard.r.premio))
                                color: resCard.venceu ? PokeTema.ok : PokeTema.crit
                                font.pixelSize: 16
                            }
                            Num { visible: !!(resCard.r && resCard.r.bp); text: resCard.r ? "+" + resCard.r.bp + " BP" : ""; color: PokeTema.xp; font.pixelSize: 16 }
                            Txt {
                                visible: !!(resCard.r && resCard.r.sequencia)
                                text: resCard.r ? "Sequência: " + resCard.r.sequencia + (resCard.r.recorde ? "  ·  novo recorde!" : "") : ""
                                color: resCard.r && resCard.r.recorde ? PokeTema.warn : PokeTema.sub
                                font.pixelSize: 14
                            }
                            Repeater {
                                model: resCard.r ? Object.keys(resCard.r.xp || {}) : []
                                Txt {
                                    required property string modelData
                                    readonly property var l: bat.b ? bat.b.meu.find(x => String(x.puesto) === modelData) : null
                                    text: l ? l.nome + " ganhou " + resCard.r.xp[modelData] + " XP" : ""
                                    color: PokeTema.sub
                                    font.pixelSize: 13
                                }
                            }
                            Repeater {
                                model: resCard.r ? resCard.r.subiu || [] : []
                                Txt { required property var modelData; text: modelData.quien + " subiu para o nível " + modelData.nivel + "!"; font.pixelSize: 13 }
                            }
                            Txt {
                                visible: !!(resCard.r && !resCard.venceu && bat.b && !bat.b.sem_xp)
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: "Quem desmaiou foi para o Pokécenter (24 h). Tente de novo com quem estiver saudável."
                                color: PokeTema.dim
                                font.pixelSize: 12
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                Layout.topMargin: 6
                                spacing: 8
                                Botao {
                                    visible: !!(resCard.r && resCard.r.continua)
                                    texto: "Encerrar"
                                    onClicked: { ShellState.pokeModoAcao(["modos", "encerrar"]); ShellState.pokeIdleAba = "batalhas"; }
                                }
                                Botao {
                                    primario: true
                                    texto: resCard.r && resCard.r.continua ? "Próxima luta" : "Continuar"
                                    onClicked: {
                                        if (resCard.r && resCard.r.continua) {
                                            ShellState.pokeModoAcao(["modos", "continuar"]);
                                        } else {
                                            const modo = bat.b && bat.b.tipo === "modo";
                                            ShellState.pokeBatalhaAcao(["fechar"]);
                                            ShellState.pokeIdleAba = modo ? "batalhas" : "liga";
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════ PRÉVIA DE EVOLUÇÃO ═══════════
            Rectangle {
                id: previa
                anchors.fill: parent
                z: 30
                visible: !!p
                color: "#c20b0f16"

                readonly property var p: ShellState.pokePrevia
                property int escolha: 0
                readonly property var op: p && p.opcoes.length ? p.opcoes[Math.min(escolha, p.opcoes.length - 1)] : null
                onPChanged: escolha = 0

                MouseArea { anchors.fill: parent; onClicked: ShellState.pokePrevia = null }

                Card {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 880)
                    height: previaCol.implicitHeight + 48
                    MouseArea { anchors.fill: parent }

                    ColumnLayout {
                        id: previaCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 24
                        spacing: 18

                        Cabecalho {
                            Layout.fillWidth: true
                            texto: previa.p ? "Evolução de " + previa.p.quem : ""
                            extra: previa.p ? "Nível " + previa.p.nivel : ""
                        }

                        Flow {
                            visible: !!(previa.p && previa.p.opcoes.length > 1)
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: previa.p ? previa.p.opcoes : []
                                Botao {
                                    required property var modelData
                                    required property int index
                                    pequeno: true
                                    texto: modelData.especie_es
                                    selecionado: previa.escolha === index
                                    opacity: modelData.disponivel || selecionado ? 1 : 0.55
                                    onClicked: previa.escolha = index
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 24

                            // forma atual → forma nova
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: previa.p && previa.op ? [previa.p.atual, previa.op] : []
                                    RowLayout {
                                        id: formaItem
                                        required property var modelData
                                        required property int index
                                        spacing: 8
                                        Icone {
                                            visible: formaItem.index === 1
                                            cp: 0xF0054
                                            color: PokeTema.dim
                                            font.pixelSize: 24
                                        }
                                        ColumnLayout {
                                            Layout.preferredWidth: 164
                                            spacing: 6
                                            AnimatedImage {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth: 132
                                                Layout.preferredHeight: 132
                                                source: "file://" + formaItem.modelData.gif
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                playing: previa.visible
                                            }
                                            Txt {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                text: formaItem.modelData.especie_es
                                                font.pixelSize: 17
                                                font.weight: Font.DemiBold
                                            }
                                            Row {
                                                Layout.alignment: Qt.AlignHCenter
                                                spacing: 6
                                                Repeater {
                                                    model: formaItem.modelData.tipos
                                                    TipoPill { required property var modelData; tipo: modelData; pequeno: true }
                                                }
                                            }
                                            Txt {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                text: formaItem.modelData.habilidade
                                                color: PokeTema.sub
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }
                            }

                            // status: antes, depois e a diferença
                            ColumnLayout {
                                Layout.preferredWidth: 300
                                Layout.alignment: Qt.AlignTop
                                spacing: 9
                                Repeater {
                                    model: previa.op ? previa.op.stats : []
                                    RowLayout {
                                        id: statPrevia
                                        required property var modelData
                                        readonly property int dif: modelData.valor - modelData.antes
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Txt { Layout.fillWidth: true; text: statPrevia.modelData.nome; color: PokeTema.sub; font.pixelSize: 14 }
                                        Num { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: statPrevia.modelData.antes; color: PokeTema.dim; font.pixelSize: 15 }
                                        Num { text: "→"; color: PokeTema.dim; font.pixelSize: 13 }
                                        Num { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: statPrevia.modelData.valor; font.pixelSize: 15; font.weight: Font.DemiBold }
                                        Num {
                                            Layout.preferredWidth: 42
                                            horizontalAlignment: Text.AlignRight
                                            text: statPrevia.dif > 0 ? "+" + statPrevia.dif : statPrevia.dif < 0 ? String(statPrevia.dif) : "="
                                            color: statPrevia.dif > 0 ? PokeTema.ok : statPrevia.dif < 0 ? PokeTema.crit : PokeTema.dim
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Txt {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: previa.op && !previa.op.disponivel ? "Ainda não: " + previa.op.motivo : ""
                                color: PokeTema.warn
                                font.pixelSize: 13
                            }
                            Botao { texto: "Agora não"; onClicked: ShellState.pokePrevia = null }
                            Botao {
                                primario: true
                                acc: PokeTema.acc
                                texto: "Evoluir"
                                habilitado: !!(previa.op && previa.op.disponivel)
                                onClicked: ShellState.pokePreviaConfirmar(previa.op.especie)
                            }
                        }
                    }
                }
            }

            // ═══════════ cartão do Hall da Fama (renderizado fora da tela) ═══════════
            Rectangle {
                id: cartao
                x: win.width + 200
                y: 0
                width: 1200
                height: 630
                visible: !!root.cartaoDados
                readonly property var e: root.cartaoDados
                gradient: Gradient {
                    GradientStop { position: 0; color: "#121722" }
                    GradientStop { position: 1; color: "#1c2533" }
                }
                PokeBola { x: 760; y: 170; width: 560; height: 560; topo: "#1e2633"; fundo: "#1e2633"; traco: "#18202c" }
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: PokeTema.acc; radius: 0 }
                RowLayout {
                    x: 56; y: 44
                    spacing: 18
                    PokeBola { width: 56; height: 56; traco: "#141a24" }
                    ColumnLayout {
                        spacing: 0
                        Txt { text: "Hall da Fama"; font.pixelSize: 44; font.weight: Font.Bold }
                        Txt {
                            text: cartao.e ? "Campeão de " + cartao.e.nome + (cartao.e.vez > 1 ? " (" + cartao.e.vez + "ª vez)" : "") + "  ·  " + cartao.e.data : ""
                            color: PokeTema.sub
                            font.pixelSize: 22
                        }
                    }
                }
                GridLayout {
                    x: 56; y: 170
                    width: 1088
                    columns: 3
                    rowSpacing: 18
                    columnSpacing: 18
                    Repeater {
                        model: cartao.e ? cartao.e.time : []
                        Rectangle {
                            id: cm
                            required property var modelData
                            Layout.preferredWidth: 350
                            Layout.preferredHeight: 182
                            radius: 18
                            color: "#1f2735"
                            border.width: 1
                            border.color: "#2d3747"
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14
                                Image {
                                    Layout.preferredWidth: 120; Layout.preferredHeight: 120
                                    source: "file://" + root.gifNum(cm.modelData.num, cm.modelData.shiny)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Txt {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: (cm.modelData.mote || root.nomeEspecie(cm.modelData.num)) + root.simboloGenero(cm.modelData.genero) + (cm.modelData.shiny ? " ✦" : "")
                                        font.pixelSize: 22
                                        font.weight: Font.DemiBold
                                    }
                                    Num { text: "Nv. " + cm.modelData.nivel; color: PokeTema.sub; font.pixelSize: 17 }
                                    Txt {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        text: (cm.modelData.golpes || []).join(" · ")
                                        color: PokeTema.dim
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }
                Txt { x: 56; y: 586; text: "PokéIdle"; color: PokeTema.dim; font.pixelSize: 16; font.weight: Font.DemiBold }
            }

            // ═══════════ O JOGO ═══════════
            RowLayout {
                anchors.fill: parent
                spacing: 0
                visible: !root.t.precisa_inicial

                // ── barra lateral ────────────────────────────────────────────
                Lateral {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 230
                    acc: PokeTema.acc

                    // saldo
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.bottomMargin: 14
                        spacing: 8
                        RowLayout {
                            spacing: 10
                            Num { text: "₽"; font.pixelSize: 22; font.weight: Font.Bold }
                            Num { text: root.dinheiro(root.t.dinheiro); font.pixelSize: 22 }
                        }
                        RowLayout {
                            spacing: 10
                            PokeBola { width: 18; height: 18; traco: PokeTema.side }
                            Txt { text: (root.t.pokebolas || 0) + " Poké Bolas"; color: PokeTema.sub; font.pixelSize: 13 }
                        }
                        Txt {
                            visible: !!root.t.hoje
                            text: root.t.hoje ? root.t.hoje.texto : ""
                            color: PokeTema.dim
                            font.pixelSize: 11
                        }
                    }

                    Repeater {
                        model: [
                            { id: "time", rot: "Time", ico: 0xF03E9 },
                            { id: "caixa", rot: "Caixa", ico: 0xF03D6 },
                            { id: "resumo", rot: "Resumo", ico: 0xF041D },
                            { id: "mochila", rot: "Mochila", ico: 0xF0E10 },
                            { id: "centro", rot: "Pokécenter", ico: 0xF02E0 },
                            { id: "mart", rot: "PokéMart", ico: 0xF0110 },
                            { id: "liga", rot: "Liga", ico: 0xF0538 },
                            { id: "batalhas", rot: "Batalhas", ico: 0xF0787 }
                        ]
                        AbaLateral {
                            required property var modelData
                            Layout.fillWidth: true
                            acc: PokeTema.acc
                            rotulo: modelData.rot
                            icone: modelData.ico
                            ativa: ShellState.pokeIdleAba === modelData.id
                            onClicked: {
                                if (modelData.id === "resumo")
                                    root.abrirResumo(root.selIdx);
                                else
                                    ShellState.pokeIdleAba = modelData.id;
                            }
                        }
                    }
                }

                // ── conteúdo ────────────────────────────────────────────────
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 24
                    currentIndex: ["time", "caixa", "resumo", "mochila", "centro", "mart", "liga", "batalhas"].indexOf(ShellState.pokeIdleAba)

                    // ═══════════ TIME ═══════════
                    ColumnLayout {
                        spacing: 16
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Cabecalho { Layout.fillWidth: true; texto: "Time"; extra: root.equipo.length + " / 6" }
                            // o líder anda pelo desktop (wl_shimeji)
                            Botao {
                                icone: 0xF03E9
                                texto: root.t.pasear ? "Líder passeando" : "Passear no desktop"
                                selecionado: root.t.pasear === true
                                acc: PokeTema.acc
                                onClicked: ShellState.pokeOrden(["pasear", "toggle"])
                            }
                        }
                        Txt {
                            visible: !!root.t.pasea_fallo
                            text: "Não deu para levar para passear: " + ((root.t.pasea_fallo || {}).motivo || "")
                            color: PokeTema.warn
                            font.pixelSize: 12
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 3
                            columnSpacing: 16
                            rowSpacing: 16
                            Repeater {
                                model: 6
                                Card {
                                    id: card
                                    required property int index
                                    readonly property var m: index < root.equipo.length ? root.equipo[index] : null
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    color: !m ? "transparent" : cardMa.containsMouse ? PokeTema.card2 : PokeTema.card
                                    border.color: m && index === 0 ? PokeTema.tinta(PokeTema.acc, 0.55) : PokeTema.line
                                    MouseArea {
                                        id: cardMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: card.m ? root.abrirResumo(card.index) : (ShellState.pokeIdleAba = "caixa")
                                    }
                                    // vazio
                                    Txt {
                                        visible: !card.m
                                        anchors.centerIn: parent
                                        text: "—  Vazio  —"
                                        color: PokeTema.dim
                                        font.pixelSize: 13
                                    }
                                    ColumnLayout {
                                        visible: !!card.m
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Txt {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: root.nomeDe(card.m)
                                                font.pixelSize: 16
                                                font.weight: Font.DemiBold
                                            }
                                            Txt { visible: !!(card.m && card.m.shiny); text: "✦"; color: "#f2c84b"; font.pixelSize: 14 }
                                            Etiqueta { visible: card.index === 0; texto: "LÍDER"; cor: PokeTema.acc }
                                        }
                                        Num { text: card.m ? "Nv. " + card.m.nivel : ""; color: PokeTema.sub; font.pixelSize: 13 }
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.minimumHeight: 70
                                            PokeBola { topo: "#283141"; fundo: "#283141";
                                                anchors.centerIn: parent
                                                width: Math.min(parent.height, 110); height: width
                                                traco: card.color.a > 0 ? card.color : PokeTema.bg
                                            }
                                            AnimatedImage {
                                                anchors.centerIn: parent
                                                width: Math.min(parent.height, 96); height: width
                                                source: root.gifDe(card.m)
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                playing: win.visible && ShellState.pokeIdleAba === "time"
                                                opacity: card.m && card.m.no_centro ? 0.45 : 1
                                            }
                                            Etiqueta {
                                                visible: !!(card.m && card.m.no_centro)
                                                anchors.centerIn: parent
                                                texto: "POKÉCENTER  " + (card.m ? root.tempo(root.restante(card.m)) : "")
                                                cor: PokeTema.warn
                                            }
                                        }
                                        Row {
                                            spacing: 4
                                            Repeater {
                                                model: card.m ? card.m.tipos : []
                                                TipoPill { required property var modelData; tipo: modelData.id; pequeno: true }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Txt { text: "HP"; color: PokeTema.sub; font.pixelSize: 12 }
                                            Barra { Layout.fillWidth: true; altura: 7; valor: card.m ? card.m.hp_pct : 0; cor: root.corHp(card.m ? card.m.hp_pct : 0) }
                                            Num { text: card.m ? card.m.hp + "/" + card.m.hp_max : ""; font.pixelSize: 12; color: PokeTema.sub }
                                        }
                                        Barra { Layout.fillWidth: true; altura: 4; valor: card.m ? card.m.progreso : 0; cor: PokeTema.xp }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ CAIXA ═══════════
                    ColumnLayout {
                        spacing: 16
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            ColumnLayout {
                                spacing: 2
                                Txt { text: "Caixa Pokémon"; font.pixelSize: 20; font.weight: Font.DemiBold }
                                Txt {
                                    text: root.caja.length === 0 ? "Armazene seus Pokémon aqui."
                                        : root.caja.length + (root.caja.length === 1 ? " pokémon guardado" : " pokémon guardados")
                                    color: PokeTema.dim
                                    font.pixelSize: 12
                                }
                            }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: PokeTema.line }
                            Seta {
                                icone: 0xF0141
                                opacity: root.caixaPag > 0 ? 1 : 0.35
                                onClicked: if (root.caixaPag > 0) root.caixaPag--
                            }
                            Rectangle {
                                implicitWidth: 120
                                implicitHeight: 36
                                radius: 10
                                color: PokeTema.tinta(PokeTema.acc, 0.12)
                                border.width: 1
                                border.color: PokeTema.tinta(PokeTema.acc, 0.7)
                                Txt {
                                    anchors.centerIn: parent
                                    text: "Caixa " + (root.caixaPag + 1)
                                    color: Qt.lighter(PokeTema.acc, 1.25)
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                            }
                            Seta {
                                icone: 0xF0142
                                opacity: root.caixaPag < root.nCaixas - 1 ? 1 : 0.35
                                onClicked: if (root.caixaPag < root.nCaixas - 1) root.caixaPag++
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            // ── detalhe do selecionado ──
                            Card {
                                id: cxDet
                                readonly property var m: root.caixaM
                                Layout.preferredWidth: 290
                                Layout.fillHeight: true

                                Txt {
                                    visible: !cxDet.m
                                    anchors.centerIn: parent
                                    width: parent.width - 48
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "A caixa está vazia.\nCom o time cheio, as capturas e os ovos vêm para cá."
                                    color: PokeTema.dim
                                    font.pixelSize: 13
                                    lineHeight: 1.2
                                }

                                ColumnLayout {
                                    visible: !!cxDet.m
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 5
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 9
                                        PokeBola { width: 20; height: 20; traco: PokeTema.card }
                                        Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: root.nomeDe(cxDet.m); font.pixelSize: 19; font.weight: Font.DemiBold }
                                        Txt { visible: !!(cxDet.m && cxDet.m.shiny); text: "✦"; color: "#f2c84b"; font.pixelSize: 15 }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Num { Layout.fillWidth: true; text: cxDet.m ? "Nv. " + cxDet.m.nivel : ""; color: PokeTema.sub; font.pixelSize: 14 }
                                        Row {
                                            spacing: 4
                                            Repeater {
                                                model: cxDet.m ? cxDet.m.tipos : []
                                                TipoPill { required property var modelData; tipo: modelData.id; pequeno: true }
                                            }
                                        }
                                    }
                                    Item {
                                        id: cxPalco
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 100
                                        readonly property real lado: Math.min(height, 170)
                                        PokeBola { anchors.centerIn: parent; width: cxPalco.lado; height: cxPalco.lado; topo: "#283141"; fundo: "#283141"; traco: PokeTema.card }
                                        AnimatedImage {
                                            anchors.centerIn: parent
                                            width: cxPalco.lado * 0.85; height: width
                                            source: root.gifDe(cxDet.m)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: false
                                            playing: win.visible && ShellState.pokeIdleAba === "caixa"
                                        }
                                    }
                                    Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4; implicitHeight: 1; color: PokeTema.line }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 0
                                            Txt { text: "Natureza"; color: PokeTema.dim; font.pixelSize: 12 }
                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: cxDet.m && cxDet.m.natureza_info ? cxDet.m.natureza_info.nome : "—"; font.pixelSize: 15 }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 0
                                            Txt { text: "Habilidade"; color: PokeTema.dim; font.pixelSize: 12 }
                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: cxDet.m && cxDet.m.habilidade ? cxDet.m.habilidade : "—"; font.pixelSize: 15 }
                                        }
                                    }
                                    Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 2; implicitHeight: 1; color: PokeTema.line }
                                    Txt { text: "Golpes"; color: PokeTema.dim; font.pixelSize: 12 }
                                    Repeater {
                                        model: 4
                                        RowLayout {
                                            required property int index
                                            readonly property var g: cxDet.m && cxDet.m.golpes_info ? cxDet.m.golpes_info[index] || null : null
                                            Layout.fillWidth: true
                                            spacing: 9
                                            Item {
                                                implicitWidth: 20; implicitHeight: 20
                                                TipoPill { anchors.centerIn: parent; tipo: parent.parent.g ? parent.parent.g.tipo : ""; lado: 20 }
                                                Rectangle { visible: !parent.parent.g; anchors.fill: parent; radius: 10; color: PokeTema.card2 }
                                            }
                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: parent.g ? parent.g.nome : "—"; color: parent.g ? PokeTema.text : PokeTema.dim; font.pixelSize: 13 }
                                        }
                                    }

                                    // ações
                                    Botao {
                                        visible: root.equipo.length < 6
                                        Layout.fillWidth: true
                                        Layout.topMargin: 8
                                        primario: true
                                        acc: PokeTema.acc
                                        icone: 0xF03E9
                                        texto: "Levar ao time"
                                        onClicked: ShellState.pokeOrden(["sacar", String(root.caixaSel)])
                                    }
                                    Txt {
                                        visible: root.equipo.length >= 6
                                        Layout.topMargin: 8
                                        text: "Time cheio · trocar com:"
                                        color: PokeTema.sub
                                        font.pixelSize: 12
                                    }
                                    Flow {
                                        visible: root.equipo.length >= 6
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: root.equipo
                                            Rectangle {
                                                id: troca
                                                required property var modelData
                                                required property int index
                                                width: 36; height: 36; radius: 10
                                                color: trocaMa.containsMouse ? PokeTema.hover : PokeTema.card2
                                                border.width: 1
                                                border.color: trocaMa.containsMouse ? PokeTema.acc : PokeTema.line
                                                AnimatedImage {
                                                    anchors.centerIn: parent
                                                    width: 32; height: 32
                                                    source: root.gifDe(troca.modelData)
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: false
                                                    playing: false
                                                }
                                                MouseArea {
                                                    id: trocaMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: ShellState.pokeOrden(["trocar", String(troca.index), String(root.caixaSel)])
                                                }
                                                ToolTip.visible: trocaMa.containsMouse
                                                ToolTip.text: "Trocar com " + root.nomeDe(troca.modelData)
                                                ToolTip.delay: 300
                                            }
                                        }
                                    }
                                }
                            }

                            // ── a grade da caixa ──
                            Card {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                GridLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    columns: 5
                                    rowSpacing: 4
                                    columnSpacing: 4
                                    Repeater {
                                        model: root.porCaixa
                                        Rectangle {
                                            id: cel
                                            required property int index
                                            readonly property int gi: root.caixaPag * root.porCaixa + index
                                            readonly property var m: gi < root.caja.length ? root.caja[gi] : null
                                            readonly property bool marcado: !!m && root.caixaSel === gi
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 1
                                            radius: 12
                                            z: marcado ? 2 : 0
                                            color: marcado ? PokeTema.tinta(PokeTema.acc, 0.14)
                                                 : celMa.containsMouse && m ? PokeTema.hover : "transparent"
                                            border.width: marcado ? 2 : 1
                                            border.color: marcado ? PokeTema.acc : "#212835"
                                            PokeBola {
                                                visible: !cel.m
                                                anchors.centerIn: parent
                                                width: 28; height: 28
                                                topo: "#232a37"; fundo: "#232a37"; traco: PokeTema.card
                                            }
                                            AnimatedImage {
                                                visible: !!cel.m
                                                anchors.centerIn: parent
                                                width: Math.min(parent.width, parent.height) - 6
                                                height: width
                                                source: root.gifDe(cel.m)
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                                playing: win.visible && ShellState.pokeIdleAba === "caixa" && (cel.marcado || celMa.containsMouse)
                                            }
                                            Txt {
                                                visible: !!(cel.m && cel.m.shiny)
                                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 5
                                                text: "✦"; color: "#f2c84b"; font.pixelSize: 11
                                            }
                                            Num {
                                                visible: !!cel.m
                                                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 5
                                                text: cel.m ? cel.m.nivel : ""
                                                color: PokeTema.dim; font.pixelSize: 10
                                            }
                                            // a setinha do cursor, como nos jogos
                                            Txt {
                                                visible: cel.marcado
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.top
                                                anchors.bottomMargin: -7
                                                text: "▼"
                                                color: PokeTema.text
                                                font.pixelSize: 12
                                            }
                                            MouseArea {
                                                id: celMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: cel.m ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: if (cel.m) root.caixaSel = cel.gi
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ RESUMO ═══════════
                    Item {
                        Txt { visible: !root.sel; anchors.centerIn: parent; text: "Nenhum pokémon no time ainda."; color: PokeTema.sub }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 18
                            visible: !!root.sel

                            // ── coluna esquerda: identidade ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 42
                                Layout.fillHeight: true
                                spacing: 18

                                Card {
                                    id: heroi
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 22
                                        spacing: 2
                                        RowLayout {
                                            spacing: 8
                                            Txt { text: root.nomeDe(root.sel); font.pixelSize: 26; font.weight: Font.DemiBold }
                                            Txt {
                                                visible: !!(root.sel && root.sel.genero && root.sel.genero !== "-")
                                                text: root.sel && root.sel.genero === "f" ? "♀" : "♂"
                                                color: root.sel && root.sel.genero === "f" ? "#f06292" : "#4ea4e6"
                                                font.pixelSize: 22
                                            }
                                            Etiqueta { visible: root.inscritoIdx(root.selIdx); texto: "LIGA"; cor: PokeTema.acc }
                                            Txt { visible: !!(root.sel && root.sel.shiny); text: "✦"; color: "#f2c84b"; font.pixelSize: 18 }
                                        }
                                        Num {
                                            text: root.sel ? "Nv. " + root.sel.nivel + (root.sel.mote ? "  ·  " + root.sel.especie_es : "") : ""
                                            color: PokeTema.sub
                                            font.pixelSize: 15
                                        }
                                        Etiqueta {
                                            visible: !!(root.sel && root.sel.no_centro)
                                            Layout.topMargin: 6
                                            texto: "NO POKÉCENTER  " + (root.sel ? root.tempo(root.restante(root.sel)) : "")
                                            cor: PokeTema.warn
                                        }
                                    }
                                    Column {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 22
                                        spacing: 6
                                        Repeater {
                                            model: root.sel ? root.sel.tipos : []
                                            TipoPill { required property var modelData; tipo: modelData.id; anchors.right: parent.right }
                                        }
                                    }

                                    // sprite sobre a Poké Bola apagada
                                    Item {
                                        id: palco
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 84
                                        anchors.bottom: acoes.top
                                        anchors.bottomMargin: 8
                                        width: parent.width
                                        readonly property real lado: Math.min(height, 230)
                                        PokeBola { topo: "#283141"; fundo: "#283141"; anchors.centerIn: parent; width: palco.lado; height: palco.lado; traco: heroi.color }
                                        Sombra { anchors.horizontalCenter: parent.horizontalCenter; y: palco.height / 2 + palco.lado * 0.27; largura: palco.lado * 0.5 }
                                        AnimatedImage {
                                            anchors.centerIn: parent
                                            width: palco.lado * 0.8; height: width
                                            source: root.gifDe(root.sel)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: false
                                            playing: win.visible && ShellState.pokeIdleAba === "resumo"
                                        }
                                        // trocar de pokémon
                                        Seta {
                                            anchors.left: parent.left; anchors.leftMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: root.equipo.length > 1
                                            icone: 0xF0141
                                            onClicked: root.abrirResumo((root.selIdx + root.equipo.length - 1) % root.equipo.length)
                                        }
                                        Seta {
                                            anchors.right: parent.right; anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: root.equipo.length > 1
                                            icone: 0xF0142
                                            onClicked: root.abrirResumo((root.selIdx + 1) % root.equipo.length)
                                        }
                                    }

                                    Flow {
                                        id: acoes
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 18
                                        spacing: 8
                                        Botao {
                                            visible: !!(root.sel && !root.sel.no_centro && root.sel.hp < root.sel.hp_max) && !root.inscritoIdx(root.selIdx)
                                            pequeno: true
                                            icone: 0xF02E0
                                            texto: "Pokécenter " + (root.sel ? root.tempo(root.sel.centro_estimado) : "")
                                            onClicked: ShellState.pokeCentro(root.selIdx)
                                        }
                                        Botao {
                                            visible: !!(root.sel && root.sel.puede_evolucionar)
                                            pequeno: true
                                            primario: true
                                            acc: PokeTema.acc
                                            texto: "Evoluir"
                                            onClicked: ShellState.pokePreviaAbrir(root.selIdx)
                                        }
                                        Botao {
                                            visible: root.equipo.length > 1
                                            pequeno: true
                                            icone: 0xF03D6
                                            texto: "Guardar na caixa"
                                            onClicked: {
                                                ShellState.pokeOrden(["guardar", String(root.selIdx)]);
                                                root.caixaSel = root.caja.length;
                                                root.caixaPag = Math.floor(root.caja.length / root.porCaixa);
                                                ShellState.pokeIdleAba = "caixa";
                                            }
                                        }
                                        Botao {
                                            visible: root.selIdx > 0
                                            pequeno: true
                                            texto: "Tornar líder"
                                            onClicked: ShellState.pokeLiderA(root.selIdx)
                                        }
                                        Botao {
                                            pequeno: true
                                            icone: 0xF0E10
                                            texto: "Usar item"
                                            onClicked: ShellState.pokeIdleAba = "mochila"
                                        }
                                    }
                                }

                                Card {
                                    Layout.fillWidth: true
                                    implicitHeight: natCol.implicitHeight + 40
                                    ColumnLayout {
                                        id: natCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 20
                                        spacing: 6
                                        readonly property var n: root.sel ? root.sel.natureza_info : null
                                        Txt { text: "Natureza"; color: PokeTema.sub; font.pixelSize: 14 }
                                        Txt { text: natCol.n ? natCol.n.nome : "—"; font.pixelSize: 21; font.weight: Font.DemiBold }
                                        Txt {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: !natCol.n ? ""
                                                : natCol.n.sobe ? "Aumenta " + natCol.n.sobe + " e diminui " + natCol.n.desce.replace(/\.$/, "") + "."
                                                : "Neutra: não muda nenhum status."
                                            color: PokeTema.sub
                                            font.pixelSize: 13
                                        }
                                        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 6; implicitHeight: 1; color: PokeTema.line }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Txt { Layout.fillWidth: true; text: "Experiência"; color: PokeTema.sub; font.pixelSize: 14 }
                                            Par {
                                                visible: !!(root.sel && root.sel.umbral)
                                                a: root.sel ? root.sel.xp : 0
                                                b: root.sel ? root.sel.umbral : 0
                                            }
                                            Txt { visible: !!(root.sel && !root.sel.umbral); text: "Nível máximo"; font.pixelSize: 13 }
                                        }
                                        Barra { Layout.fillWidth: true; altura: 8; valor: root.sel ? root.sel.progreso : 0; cor: PokeTema.xp }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.topMargin: 6
                                            spacing: 6
                                            Txt { text: "Amizade"; color: PokeTema.sub; font.pixelSize: 14 }
                                            Etiqueta { visible: !!root.t.amizade_bonus; texto: "×2"; cor: PokeTema.ok }
                                            Etiqueta { visible: !!(root.sel && root.sel.sino); texto: "SINO"; cor: PokeTema.warn }
                                            Item { Layout.fillWidth: true }
                                            Row {
                                                spacing: 2
                                                Repeater {
                                                    model: 5
                                                    Icone {
                                                        required property int index
                                                        readonly property bool cheio: !!root.sel && index < root.sel.amizade_coracoes
                                                        cp: cheio ? 0xF02D1 : 0xF02D5
                                                        color: cheio ? "#ef7fa5" : PokeTema.dim
                                                        font.pixelSize: 16
                                                    }
                                                }
                                            }
                                        }
                                        Barra {
                                            visible: !!(root.sel && root.sel.amizade_evolui)
                                            Layout.fillWidth: true
                                            altura: 6
                                            valor: root.sel ? root.sel.amizade / root.sel.amizade_min : 0
                                            cor: "#ef7fa5"
                                        }
                                        Repeater {
                                            model: root.sel ? root.sel.evolucao_precisa : []
                                            Txt {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                Layout.topMargin: 2
                                                elide: Text.ElideRight
                                                text: "Evolui para " + modelData.especie_es + ": " + (modelData.tipo === "amizade" ? modelData.condicao : modelData.tipo === "item" ? "precisa de " + modelData.item_nome : "nível " + modelData.nivel)
                                                color: PokeTema.dim
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }
                            }

                            // ── coluna direita: status + golpes ──
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 58
                                Layout.fillHeight: true
                                spacing: 18

                                Card {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    // status
                                    ColumnLayout {
                                        visible: root.golpeSlot < 0
                                        anchors.fill: parent
                                        anchors.margins: 22
                                        spacing: 0
                                        Cabecalho { Layout.fillWidth: true; Layout.bottomMargin: 8; texto: "Status"; extra: "atual / base" }
                                        Repeater {
                                            model: root.sel ? root.sel.stats : []
                                            RowLayout {
                                                required property var modelData
                                                readonly property bool ehHp: modelData.chave === "hp"
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                spacing: 14
                                                RowLayout {
                                                    Layout.preferredWidth: 112
                                                    spacing: 4
                                                    Txt { text: modelData.nome; color: PokeTema.sub; font.pixelSize: 15 }
                                                    Txt {
                                                        visible: modelData.natureza !== ""
                                                        text: modelData.natureza === "+" ? "▲" : "▼"
                                                        color: modelData.natureza === "+" ? "#ef7a6a" : "#6aa7ef"
                                                        font.pixelSize: 9
                                                    }
                                                }
                                                Par {
                                                    Layout.preferredWidth: 92
                                                    alinharDireita: true
                                                    a: parent.ehHp && root.sel ? root.sel.hp : modelData.valor
                                                    b: parent.ehHp && root.sel ? root.sel.hp_max : modelData.base
                                                }
                                                Barra {
                                                    Layout.fillWidth: true
                                                    altura: 10
                                                    valor: parent.ehHp ? (root.sel ? root.sel.hp_pct : 0) : modelData.base / 150
                                                    cor: parent.ehHp ? root.corHp(root.sel ? root.sel.hp_pct : 0) : (PokeTema.corStat[modelData.chave] || PokeTema.acc)
                                                }
                                            }
                                        }
                                    }

                                    // golpes aprendíveis para o slot escolhido
                                    ColumnLayout {
                                        visible: root.golpeSlot >= 0
                                        anchors.fill: parent
                                        anchors.margins: 22
                                        spacing: 10
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Cabecalho {
                                                Layout.fillWidth: true
                                                readonly property var atual: root.sel && root.sel.golpes_info && root.golpeSlot >= 0 ? root.sel.golpes_info[root.golpeSlot] : null
                                                texto: atual ? "Trocar " + atual.nome : "Aprender no slot " + (root.golpeSlot + 1)
                                                extra: ShellState.pokeGolpesCarregando ? "carregando…" : ""
                                            }
                                            Seta { icone: 0xF0156; onClicked: root.golpeSlot = -1 }
                                        }
                                        ListView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            spacing: 6
                                            ScrollBar.vertical: ScrollBar {}
                                            model: (ShellState.pokeGolpesDisp.aprendiveis || []).filter(g => !(root.sel && (root.sel.golpes || []).indexOf(g.id) >= 0))
                                            delegate: Rectangle {
                                                id: lin
                                                required property var modelData
                                                width: ListView.view.width - 12
                                                height: 54
                                                radius: 12
                                                color: linMa.containsMouse ? PokeTema.hover : PokeTema.card2
                                                border.width: 1
                                                border.color: PokeTema.line
                                                MouseArea {
                                                    id: linMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        ShellState.pokeGolpe(root.selIdx, root.golpeSlot, lin.modelData.id);
                                                        root.golpeSlot = -1;
                                                    }
                                                }
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 14
                                                    anchors.rightMargin: 14
                                                    spacing: 12
                                                    TipoPill { tipo: lin.modelData.tipo }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 1
                                                        Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: lin.modelData.nome; font.pixelSize: 14 }
                                                        Txt {
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                            text: (PokeTema.nomeClasse[lin.modelData.classe] || "") + "  ·  Poder " + (lin.modelData.poder || "—")
                                                                  + "  ·  Precisão " + (lin.modelData.precisao || "—") + "  ·  " + lin.modelData.efeito
                                                            color: PokeTema.dim
                                                            font.pixelSize: 11
                                                        }
                                                    }
                                                    Etiqueta { visible: lin.modelData.via === "tm"; texto: "TM"; cor: PokeTema.xp }
                                                }
                                            }
                                        }
                                    }
                                }

                                Card {
                                    Layout.fillWidth: true
                                    implicitHeight: golCol.implicitHeight + 40
                                    ColumnLayout {
                                        id: golCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 20
                                        spacing: 14
                                        RowLayout {
                                            spacing: 10
                                            PokeBola { width: 22; height: 22; traco: PokeTema.card }
                                            Txt { text: "Golpes"; font.pixelSize: 18; font.weight: Font.DemiBold }
                                            Txt {
                                                visible: !!(root.sel && !root.sel.golpes_baixados)
                                                text: "ainda não baixados (poke-api time)"
                                                color: PokeTema.warn
                                                font.pixelSize: 12
                                            }
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 2
                                            columnSpacing: 12
                                            rowSpacing: 12
                                            Repeater {
                                                model: 4
                                                Rectangle {
                                                    id: slot
                                                    required property int index
                                                    readonly property var g: root.sel && root.sel.golpes_info ? root.sel.golpes_info[index] || null : null
                                                    readonly property bool marcado: root.golpeSlot === index
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 1
                                                    implicitHeight: 76
                                                    radius: 12
                                                    color: slotMa.containsMouse ? PokeTema.hover : g ? PokeTema.card2 : "transparent"
                                                    border.width: marcado ? 2 : 1
                                                    border.color: marcado ? PokeTema.acc : PokeTema.line
                                                    MouseArea {
                                                        id: slotMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.golpeSlot = slot.marcado ? -1 : slot.index;
                                                            ShellState.pokeGolpesCarregar(root.selIdx);
                                                        }
                                                    }
                                                    Txt {
                                                        visible: !slot.g
                                                        anchors.centerIn: parent
                                                        text: "—  Vazio  —"
                                                        color: PokeTema.dim
                                                        font.pixelSize: 14
                                                    }
                                                    ColumnLayout {
                                                        visible: !!slot.g
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 16
                                                        anchors.rightMargin: 16
                                                        anchors.topMargin: 12
                                                        anchors.bottomMargin: 12
                                                        spacing: 6
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 10
                                                            TipoPill { tipo: slot.g ? slot.g.tipo : ""; pequeno: true }
                                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: slot.g ? slot.g.nome : ""; font.pixelSize: 15 }
                                                        }
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 8
                                                            Txt { text: slot.g ? (PokeTema.nomeClasse[slot.g.classe] || "") : ""; color: PokeTema.sub; font.pixelSize: 12 }
                                                            Item { Layout.fillWidth: true }
                                                            Num { text: slot.g ? "PP " + slot.g.pp + "/" + slot.g.pp : ""; color: PokeTema.sub; font.pixelSize: 13 }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ MOCHILA ═══════════
                    ColumnLayout {
                        id: pagMochila
                        spacing: 16
                        Cabecalho { Layout.fillWidth: true; texto: "Mochila"; extra: "clique num item para usar" }
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: ["cura", "bola", "evolucao", "amizade", "tm", "outros"]
                                Botao {
                                    required property string modelData
                                    texto: (root.t.categorias || {})[modelData] || modelData
                                    selecionado: root.catMochila === modelData
                                    acc: PokeTema.acc
                                    onClicked: { root.catMochila = modelData; root.itemSel = ""; }
                                }
                            }
                        }
                        GridLayout {
                            id: gradeItens
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: 12
                            rowSpacing: 12
                            Repeater {
                                model: (root.t.mochila_lista || []).filter(x => x.cat === root.catMochila)
                                Rectangle {
                                    id: it
                                    required property var modelData
                                    readonly property bool marcado: root.itemSel === modelData.id
                                    Layout.preferredWidth: (pagMochila.width - 36) / 4
                                    implicitHeight: 72
                                    radius: 14
                                    color: itMa.containsMouse ? PokeTema.card2 : PokeTema.card
                                    border.width: marcado ? 2 : 1
                                    border.color: marcado ? PokeTema.acc : PokeTema.line
                                    MouseArea { id: itMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.itemSel = it.modelData.id }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12
                                        Rectangle {
                                            Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                            radius: 22
                                            color: PokeTema.card2
                                            Image {
                                                anchors.centerIn: parent
                                                width: 36; height: 36
                                                source: it.modelData.sprite ? "file://" + it.modelData.sprite : ""
                                                fillMode: Image.PreserveAspectFit
                                                smooth: false
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: it.modelData.nome; font.pixelSize: 14 }
                                            Num { text: "×" + it.modelData.qtd; color: PokeTema.sub; font.pixelSize: 13 }
                                        }
                                    }
                                }
                            }
                        }
                        Txt {
                            visible: (root.t.mochila_lista || []).filter(x => x.cat === root.catMochila).length === 0
                            text: "Nada aqui ainda. Missões dão itens; a PokéMart vende poções e bolas."
                            color: PokeTema.dim
                            font.pixelSize: 13
                        }
                        Item { Layout.fillHeight: true }
                        // detalhe + usar em
                        Card {
                            id: detalhe
                            readonly property var item: (root.t.mochila_lista || []).find(x => x.id === root.itemSel) || null
                            visible: !!item
                            Layout.fillWidth: true
                            implicitHeight: detCol.implicitHeight + 36
                            ColumnLayout {
                                id: detCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 18
                                spacing: 12
                                RowLayout {
                                    spacing: 14
                                    Image {
                                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                        source: detalhe.item && detalhe.item.sprite ? "file://" + detalhe.item.sprite : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Txt { text: detalhe.item ? detalhe.item.nome : ""; font.pixelSize: 17; font.weight: Font.DemiBold }
                                        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: detalhe.item ? detalhe.item.desc : ""; color: PokeTema.sub; font.pixelSize: 13 }
                                    }
                                }
                                Txt {
                                    visible: !!(detalhe.item && detalhe.item.cat === "bola")
                                    text: "Bolas são usadas nos encontros selvagens, direto no notch."
                                    color: PokeTema.dim
                                    font.pixelSize: 12
                                }
                                Flow {
                                    visible: !!(detalhe.item && detalhe.item.cat !== "bola")
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Txt { height: 40; verticalAlignment: Text.AlignVCenter; text: "Usar em"; color: PokeTema.sub; font.pixelSize: 13; rightPadding: 4 }
                                    Repeater {
                                        model: root.equipo
                                        Rectangle {
                                            id: alvo
                                            required property var modelData
                                            required property int index
                                            width: alvoRow.implicitWidth + 20
                                            height: 40
                                            radius: 10
                                            color: alvoMa.containsMouse ? PokeTema.hover : PokeTema.card2
                                            border.width: 1
                                            border.color: PokeTema.line
                                            MouseArea {
                                                id: alvoMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ShellState.pokeUsar(root.itemSel, alvo.index, -1)
                                            }
                                            Row {
                                                id: alvoRow
                                                anchors.centerIn: parent
                                                spacing: 6
                                                AnimatedImage {
                                                    width: 30; height: 30
                                                    source: root.gifDe(alvo.modelData)
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: false
                                                    playing: false
                                                }
                                                Txt { anchors.verticalCenter: parent.verticalCenter; text: root.nomeDe(alvo.modelData); font.pixelSize: 13 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ POKÉCENTER ═══════════
                    ColumnLayout {
                        spacing: 12
                        Cabecalho { Layout.fillWidth: true; texto: "Pokécenter" }
                        Txt {
                            Layout.bottomMargin: 4
                            text: "Até 2 h conforme o HP perdido. Derrotado fica 24 h. Lá dentro não ganha XP."
                            color: PokeTema.dim
                            font.pixelSize: 12
                        }
                        Repeater {
                            model: root.equipo
                            Card {
                                id: pc
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 78
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 16
                                    spacing: 14
                                    AnimatedImage {
                                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                        source: root.gifDe(pc.modelData); fillMode: Image.PreserveAspectFit; smooth: false
                                        playing: win.visible && ShellState.pokeIdleAba === "centro"
                                    }
                                    ColumnLayout {
                                        Layout.preferredWidth: 150
                                        spacing: 0
                                        Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: root.nomeDe(pc.modelData); font.pixelSize: 15; font.weight: Font.DemiBold }
                                        Num { text: "Nv. " + pc.modelData.nivel; color: PokeTema.sub; font.pixelSize: 12 }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Barra {
                                            Layout.fillWidth: true
                                            altura: 9
                                            valor: pc.modelData.no_centro
                                                ? 1 - root.restante(pc.modelData) / Math.max(1, pc.modelData.centro_estimado || 1)
                                                : pc.modelData.hp_pct
                                            cor: pc.modelData.no_centro ? PokeTema.xp : root.corHp(pc.modelData.hp_pct)
                                        }
                                        Txt {
                                            text: pc.modelData.no_centro
                                                ? "Em tratamento · pronto em " + root.tempo(root.restante(pc.modelData))
                                                : pc.modelData.hp >= pc.modelData.hp_max ? "Saudável · " + pc.modelData.hp + "/" + pc.modelData.hp_max + " HP"
                                                : "Ferido · " + pc.modelData.hp + "/" + pc.modelData.hp_max + " HP"
                                            color: pc.modelData.no_centro ? PokeTema.xp : PokeTema.sub
                                            font.pixelSize: 12
                                        }
                                    }
                                    Botao {
                                        visible: !pc.modelData.no_centro && pc.modelData.hp < pc.modelData.hp_max && !root.inscritoIdx(pc.index)
                                        icone: 0xF02E0
                                        texto: "Internar · " + root.tempo(pc.modelData.centro_estimado)
                                        onClicked: ShellState.pokeCentro(pc.index)
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // ═══════════ POKÉMART ═══════════
                    ColumnLayout {
                        spacing: 14
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Cabecalho { Layout.fillWidth: true; texto: "PokéMart"; extra: "itens raros só em missões" }
                            Num { text: "₽ " + root.dinheiro(root.t.dinheiro); font.pixelSize: 18 }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 10
                            ScrollBar.vertical: ScrollBar {}
                            model: root.t.mart || []
                            delegate: Card {
                                id: mi
                                required property var modelData
                                readonly property int qtd: root.martQtd[modelData.id] || 1
                                readonly property bool podeComprar: (root.t.dinheiro || 0) >= modelData.preco * qtd
                                width: ListView.view.width - 12
                                height: 66
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 14
                                    Rectangle {
                                        Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                        radius: 22
                                        color: PokeTema.card2
                                        Image { anchors.centerIn: parent; width: 34; height: 34; source: mi.modelData.sprite ? "file://" + mi.modelData.sprite : ""; fillMode: Image.PreserveAspectFit; smooth: false }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Txt { text: mi.modelData.nome; font.pixelSize: 15 }
                                        Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: mi.modelData.desc; color: PokeTema.dim; font.pixelSize: 12 }
                                    }
                                    Num { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: "₽ " + root.dinheiro(mi.modelData.preco); color: PokeTema.sub; font.pixelSize: 13 }
                                    Seta {
                                        icone: 0xF0374
                                        onClicked: { const q = Object.assign({}, root.martQtd); q[mi.modelData.id] = Math.max(1, mi.qtd - 1); root.martQtd = q; }
                                    }
                                    Num { Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter; text: mi.qtd; font.pixelSize: 14 }
                                    Seta {
                                        icone: 0xF0415
                                        onClicked: { const q = Object.assign({}, root.martQtd); q[mi.modelData.id] = Math.min(99, mi.qtd + 1); root.martQtd = q; }
                                    }
                                    Botao {
                                        Layout.preferredWidth: 140
                                        texto: "Comprar  ₽ " + root.dinheiro(mi.modelData.preco * mi.qtd)
                                        selecionado: mi.podeComprar
                                        habilitado: mi.podeComprar
                                        acc: PokeTema.acc
                                        onClicked: ShellState.pokeComprar(mi.modelData.id, mi.qtd)
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ LIGA (fase 2) ═══════════
                    Item {
                        id: pagLiga
                        readonly property var lig: root.t.ligas || null
                        property string reg: "kanto"
                        readonly property var reg_: lig && lig.regioes ? lig.regioes[reg] : null
                        property var marcados: []
                        onRegChanged: marcados = []

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14
                            Cabecalho { Layout.fillWidth: true; texto: "Liga Pokémon"; extra: pagLiga.lig ? "level cap de XP: " + pagLiga.lig.cap_xp : "" }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: pagLiga.lig ? pagLiga.lig.ordem : []
                                    Botao {
                                        required property string modelData
                                        readonly property var rr: pagLiga.lig.regioes[modelData]
                                        pequeno: true
                                        selecionado: pagLiga.reg === modelData
                                        texto: rr.nome + "  " + rr.insignias + "/8" + (rr.campeao > 0 ? "  ★" : "")
                                        onClicked: pagLiga.reg = modelData
                                    }
                                }
                            }
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentHeight: ligaCol.implicitHeight + 8
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar {}
                                ColumnLayout {
                                    id: ligaCol
                                    width: parent.width - 14
                                    spacing: 16
                                    Txt {
                                        visible: !!pagLiga.reg_
                                        text: pagLiga.reg_ ? pagLiga.reg_.jogo + "  ·  próximo desafio com cap " + pagLiga.reg_.cap
                                                          + (pagLiga.reg_.selos ? "  ·  em Alola, os desafios são os Capitães e os Kahunas" : "") : ""
                                        color: PokeTema.dim
                                        font.pixelSize: 12
                                    }
                                    // ── os 8 ginásios ──
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 12
                                        rowSpacing: 12
                                        Repeater {
                                            model: pagLiga.reg_ ? pagLiga.reg_.ginasios : []
                                            Card {
                                                id: gin
                                                required property var modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 1
                                                implicitHeight: 172
                                                border.color: modelData.proximo ? PokeTema.tinta(PokeTema.cor(modelData.tipo), 0.7) : PokeTema.line
                                                opacity: modelData.vencido || modelData.proximo || pagLiga.reg_.campeao > 0 ? 1 : 0.55
                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 14
                                                    spacing: 5
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 10
                                                        Insignia { tipo: gin.modelData.tipo; regiao: pagLiga.reg; lider: gin.modelData.id; ganha: gin.modelData.vencido; lado: 36 }
                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 0
                                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: gin.modelData.nome; font.pixelSize: 15; font.weight: Font.DemiBold }
                                                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: gin.modelData.cidade; color: PokeTema.dim; font.pixelSize: 11 }
                                                        }
                                                        Image {
                                                            Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                                            source: gin.modelData.sprite ? "file://" + gin.modelData.sprite : ""
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: false
                                                        }
                                                    }
                                                    RowLayout {
                                                        spacing: 6
                                                        TipoPill { tipo: gin.modelData.tipo; pequeno: true }
                                                        Num { text: "Nv. " + gin.modelData.ace; color: PokeTema.sub; font.pixelSize: 12 }
                                                    }
                                                    Txt {
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                        text: gin.modelData.insignia + (gin.modelData.tm_nome ? " · TM " + gin.modelData.tm_nome : "")
                                                        color: PokeTema.sub
                                                        font.pixelSize: 11
                                                    }
                                                    Item { Layout.fillHeight: true }
                                                    Botao {
                                                        visible: gin.modelData.proximo
                                                        Layout.fillWidth: true
                                                        pequeno: true
                                                        primario: true
                                                        acc: PokeTema.cor(gin.modelData.tipo)
                                                        texto: "Desafiar"
                                                        habilitado: !ShellState.pokeBatalhaOcupado
                                                        onClicked: ShellState.pokeBatalhaAcao(["iniciar", pagLiga.reg, gin.modelData.id])
                                                    }
                                                    Botao {
                                                        visible: gin.modelData.vencido && pagLiga.reg_.campeao > 0
                                                        Layout.fillWidth: true
                                                        pequeno: true
                                                        texto: "Revanche · Nv. " + pagLiga.reg_.revanche_ace
                                                        onClicked: ShellState.pokeBatalhaAcao(["iniciar", pagLiga.reg, "revanche:" + gin.modelData.id])
                                                    }
                                                    Txt {
                                                        visible: !gin.modelData.proximo && !(gin.modelData.vencido && pagLiga.reg_.campeao > 0)
                                                        text: gin.modelData.vencido ? "✓ Vencido" : "Bloqueado"
                                                        color: gin.modelData.vencido ? PokeTema.ok : PokeTema.dim
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── Elite 4 + Campeão ──
                                    Card {
                                        id: ligaCard
                                        readonly property var lg: pagLiga.reg_ ? pagLiga.reg_.liga : null
                                        readonly property var insc: lg ? lg.inscricao : null
                                        Layout.fillWidth: true
                                        implicitHeight: ligaIn.implicitHeight + 36
                                        ColumnLayout {
                                            id: ligaIn
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 18
                                            spacing: 12
                                            Cabecalho {
                                                Layout.fillWidth: true
                                                texto: "Elite 4 e Campeão"
                                                extra: ligaCard.lg ? "cap " + ligaCard.lg.cap + (pagLiga.reg_.campeao > 0 ? " · revanche" : "") : ""
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 10
                                                Repeater {
                                                    model: ligaCard.lg ? ligaCard.lg.elite4.concat([ligaCard.lg.campeao]) : []
                                                    Rectangle {
                                                        id: e4
                                                        required property var modelData
                                                        required property int index
                                                        readonly property bool feito: !!ligaCard.insc && ligaCard.lg.etapa > index
                                                        readonly property bool agora: !!ligaCard.insc && ligaCard.lg.etapa === index
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                        implicitHeight: 112
                                                        radius: 12
                                                        color: PokeTema.card2
                                                        border.width: agora ? 2 : 1
                                                        border.color: agora ? PokeTema.cor(modelData.tipo) : PokeTema.line
                                                        opacity: feito ? 0.5 : 1
                                                        ColumnLayout {
                                                            anchors.centerIn: parent
                                                            spacing: 3
                                                            Image {
                                                                Layout.alignment: Qt.AlignHCenter
                                                                Layout.preferredWidth: 52; Layout.preferredHeight: 52
                                                                source: e4.modelData.sprite ? "file://" + e4.modelData.sprite : ""
                                                                fillMode: Image.PreserveAspectFit
                                                                smooth: false
                                                            }
                                                            Txt { Layout.alignment: Qt.AlignHCenter; text: (e4.index === 4 ? "★ " : "") + e4.modelData.nome + (e4.feito ? " ✓" : ""); font.pixelSize: 13; font.weight: Font.DemiBold }
                                                            TipoPill { Layout.alignment: Qt.AlignHCenter; tipo: e4.modelData.tipo; pequeno: true; semIcone: true }
                                                        }
                                                    }
                                                }
                                            }
                                            Txt {
                                                visible: !!ligaCard.lg && !ligaCard.lg.liberada
                                                text: "Exige as 8 insígnias da região (" + (pagLiga.reg_ ? pagLiga.reg_.insignias : 0) + "/8)."
                                                color: PokeTema.dim
                                                font.pixelSize: 13
                                            }
                                            // inscrição
                                            ColumnLayout {
                                                visible: !!ligaCard.lg && ligaCard.lg.liberada && !ligaCard.insc
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Txt {
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WordWrap
                                                    text: "Inscreva até 6 (nível ≤ " + (ligaCard.lg ? ligaCard.lg.cap : 0) + "). A equipe fica travada até vencer ou perder, não pode ir ao Pokécenter, mas pode usar itens de cura."
                                                    color: PokeTema.sub
                                                    font.pixelSize: 12
                                                }
                                                Flow {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Repeater {
                                                        model: root.equipo
                                                        Botao {
                                                            required property var modelData
                                                            required property int index
                                                            readonly property bool ok: ligaCard.lg && modelData.nivel <= ligaCard.lg.cap && !modelData.no_centro && modelData.hp > 0
                                                            pequeno: true
                                                            habilitado: ok
                                                            selecionado: pagLiga.marcados.indexOf(index) >= 0
                                                            texto: root.nomeDe(modelData) + " · " + modelData.nivel
                                                            onClicked: {
                                                                const m = pagLiga.marcados.slice();
                                                                const k = m.indexOf(index);
                                                                if (k >= 0) m.splice(k, 1); else if (m.length < 6) m.push(index);
                                                                pagLiga.marcados = m;
                                                            }
                                                        }
                                                    }
                                                }
                                                Botao {
                                                    primario: true
                                                    habilitado: pagLiga.marcados.length > 0
                                                    texto: "Inscrever " + pagLiga.marcados.length
                                                    onClicked: {
                                                        ShellState.pokeEvento(["liga", "inscrever", pagLiga.reg].concat(pagLiga.marcados.map(String)));
                                                        pagLiga.marcados = [];
                                                    }
                                                }
                                            }
                                            RowLayout {
                                                visible: !!ligaCard.insc
                                                Layout.fillWidth: true
                                                spacing: 10
                                                Txt {
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    text: ligaCard.insc ? "Inscritos: " + ligaCard.insc.puestos.map(q => root.nomeDe(root.equipo[q])).join(", ") : ""
                                                    color: PokeTema.sub
                                                    font.pixelSize: 13
                                                }
                                                Botao {
                                                    visible: !!ligaCard.insc && ligaCard.lg.etapa === 0
                                                    pequeno: true
                                                    texto: "Cancelar"
                                                    onClicked: ShellState.pokeEvento(["liga", "cancelar", pagLiga.reg])
                                                }
                                                Botao {
                                                    primario: true
                                                    habilitado: !ShellState.pokeBatalhaOcupado
                                                    texto: ligaCard.lg ? "Desafiar " + (ligaCard.lg.etapa < 4 ? ligaCard.lg.elite4[ligaCard.lg.etapa].nome : ligaCard.lg.campeao.nome) : ""
                                                    onClicked: ShellState.pokeBatalhaAcao(["iniciar", pagLiga.reg, "liga"])
                                                }
                                            }
                                        }
                                    }

                                    // ── lendários (depois do título) ──
                                    Card {
                                        visible: !!(pagLiga.reg_ && pagLiga.reg_.lendarios.length)
                                        Layout.fillWidth: true
                                        implicitHeight: lendCol.implicitHeight + 36
                                        ColumnLayout {
                                            id: lendCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 18
                                            spacing: 12
                                            Cabecalho { Layout.fillWidth: true; texto: "Lendários"; extra: "3 bolas por dia · a Master Ball pega sempre" }
                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 12
                                                Repeater {
                                                    model: pagLiga.reg_ ? pagLiga.reg_.lendarios : []
                                                    Rectangle {
                                                        id: lend
                                                        required property var modelData
                                                        width: 196
                                                        height: 196
                                                        radius: 12
                                                        color: PokeTema.card2
                                                        border.width: 1
                                                        border.color: PokeTema.line
                                                        ColumnLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 10
                                                            spacing: 4
                                                            AnimatedImage {
                                                                Layout.alignment: Qt.AlignHCenter
                                                                Layout.preferredWidth: 84; Layout.preferredHeight: 84
                                                                source: lend.modelData.gif ? "file://" + lend.modelData.gif : ""
                                                                fillMode: Image.PreserveAspectFit
                                                                smooth: false
                                                                playing: win.visible && ShellState.pokeIdleAba === "liga"
                                                                opacity: lend.modelData.capturado ? 0.5 : 1
                                                            }
                                                            Txt { Layout.alignment: Qt.AlignHCenter; text: lend.modelData.nome + "  ·  Nv. " + lend.modelData.nivel; font.pixelSize: 13 }
                                                            Txt {
                                                                Layout.alignment: Qt.AlignHCenter
                                                                text: lend.modelData.capturado ? "✓ Capturado" : lend.modelData.restantes > 0 ? lend.modelData.restantes + " tentativa(s) hoje" : "Foi embora · volta amanhã"
                                                                color: lend.modelData.capturado ? PokeTema.ok : PokeTema.dim
                                                                font.pixelSize: 11
                                                            }
                                                            Flow {
                                                                visible: !lend.modelData.capturado && lend.modelData.restantes > 0
                                                                Layout.fillWidth: true
                                                                spacing: 4
                                                                Repeater {
                                                                    model: root.t.bolas || []
                                                                    Rectangle {
                                                                        id: bl
                                                                        required property var modelData
                                                                        width: 32; height: 32; radius: 8
                                                                        color: blMa.containsMouse ? PokeTema.hover : PokeTema.card
                                                                        border.width: 1
                                                                        border.color: PokeTema.line
                                                                        Image { anchors.centerIn: parent; width: 26; height: 26; source: bl.modelData.sprite ? "file://" + bl.modelData.sprite : ""; smooth: false }
                                                                        MouseArea {
                                                                            id: blMa
                                                                            anchors.fill: parent
                                                                            hoverEnabled: true
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: ShellState.pokeEvento(["lancar", bl.modelData.id, "--lendario", String(lend.modelData.num)])
                                                                        }
                                                                        ToolTip.visible: blMa.containsMouse
                                                                        ToolTip.text: bl.modelData.nome + " ×" + bl.modelData.qtd
                                                                        ToolTip.delay: 300
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── Hall da Fama ──
                                    Card {
                                        visible: (pagLiga.lig ? pagLiga.lig.hall : []).length > 0
                                        Layout.fillWidth: true
                                        implicitHeight: hallCol.implicitHeight + 36
                                        ColumnLayout {
                                            id: hallCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 18
                                            spacing: 10
                                            Cabecalho { Layout.fillWidth: true; texto: "Hall da Fama" }
                                            Repeater {
                                                model: pagLiga.lig ? pagLiga.lig.hall.slice().reverse() : []
                                                RowLayout {
                                                    id: hf
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    spacing: 10
                                                    Txt { Layout.preferredWidth: 150; text: modelData.nome + (modelData.vez > 1 ? " #" + modelData.vez : ""); font.pixelSize: 14; font.weight: Font.DemiBold }
                                                    Num { Layout.preferredWidth: 90; text: modelData.data; color: PokeTema.dim; font.pixelSize: 12 }
                                                    Row {
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        Repeater {
                                                            model: hf.modelData.time
                                                            Image {
                                                                required property var modelData
                                                                width: 36; height: 36
                                                                source: "file://" + root.gifNum(modelData.num, modelData.shiny)
                                                                fillMode: Image.PreserveAspectFit
                                                                smooth: false
                                                            }
                                                        }
                                                    }
                                                    Botao {
                                                        pequeno: true
                                                        icone: 0xF0E51
                                                        texto: "Gerar cartão"
                                                        onClicked: root.gerarCartao(hf.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ BATALHAS: modos de desafio ═══════════
                    Item {
                        id: pagModos
                        readonly property var mo: root.t.modos || null
                        readonly property var corrida: mo ? mo.corrida : null
                        readonly property var desafio: root.t.desafio || null
                        readonly property bool livre: !!mo && !corrida && !mo.bloqueio && !ShellState.pokeBatalha
                        property string sub: "modos"
                        property int regIdx: 0
                        readonly property var regioes: mo ? mo.regioes : []
                        readonly property var regBoss: regioes[regIdx] || null
                        function iniciar(modo, formato, regiao) {
                            const a = ["modos", "iniciar", modo, formato];
                            if (regiao) a.push(regiao);
                            ShellState.pokeModoAcao(a);
                        }
                        readonly property var cartoes: [
                            { id: "tower", nome: "Battle Tower", ico: 0xF0A30, desc: "Séries de 7 lutas no nível 50, com cura total entre elas e chefes nas lutas 21 e 49.", formatos: true },
                            { id: "survival", nome: "Survival", ico: 0xF0238, desc: "Lutas sem fim no nível 50. O dano acumula, com 30% de cura a cada 5 vitórias.", formatos: false },
                            { id: "random", nome: "Random Battles", ico: 0xF0D2F, desc: "Os dois lados recebem 6 pokémon sorteados. Seu time real não é tocado.", formatos: true },
                            { id: "bossrush", nome: "Boss Rush", ico: 0xF0538, desc: "Os 8 líderes da região em sequência no nível 50, sem cura entre as lutas.", formatos: false },
                            { id: "diario", nome: "Desafio diário", ico: 0xF00ED, desc: "Uma luta por dia, com regra especial e prêmio único.", formatos: false }
                        ]
                        readonly property var nomesRecorde: [
                            ["tower:singles", "Battle Tower · Singles"], ["tower:duplas", "Battle Tower · Duplas"],
                            ["survival:singles", "Survival"], ["random:singles", "Random · Singles"],
                            ["random:duplas", "Random · Duplas"], ["bossrush:singles", "Boss Rush"],
                            ["diario:total", "Desafios diários vencidos"], ["avulso:total", "Treinadores avulsos vencidos"]
                        ]

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14
                            Cabecalho { Layout.fillWidth: true; texto: "Batalhas"; extra: pagModos.mo ? pagModos.mo.bp + " BP" : "" }
                            RowLayout {
                                spacing: 8
                                Repeater {
                                    model: [["modos", "Modos"], ["recordes", "Recordes"], ["loja", "Loja de BP"]]
                                    Botao {
                                        required property var modelData
                                        texto: modelData[1]
                                        selecionado: pagModos.sub === modelData[0]
                                        onClicked: pagModos.sub = modelData[0]
                                    }
                                }
                            }
                            // treinador avulso esperando resposta
                            Card {
                                visible: !!pagModos.desafio
                                Layout.fillWidth: true
                                implicitHeight: 72
                                border.color: PokeTema.tinta(PokeTema.acc, 0.6)
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12
                                    Image {
                                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                        source: pagModos.desafio && pagModos.desafio.sprite ? "file://" + pagModos.desafio.sprite : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Txt { text: pagModos.desafio ? pagModos.desafio.quien + " quer batalhar!" : ""; font.pixelSize: 16; font.weight: Font.DemiBold }
                                        Txt { text: pagModos.desafio ? (pagModos.desafio.formato === "duplas" ? "Duplas" : "Singles") + "  ·  Nv. " + pagModos.desafio.nivel : ""; color: PokeTema.sub }
                                    }
                                    Botao { texto: "Recusar"; onClicked: ShellState.pokeDesafioResponder(false) }
                                    Botao { primario: true; texto: "Aceitar"; onClicked: ShellState.pokeDesafioResponder(true) }
                                }
                            }
                            // sequência em andamento
                            Card {
                                visible: !!pagModos.corrida
                                Layout.fillWidth: true
                                implicitHeight: 72
                                border.color: PokeTema.tinta(PokeTema.acc, 0.6)
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 14
                                    spacing: 12
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Txt { text: pagModos.corrida ? pagModos.corrida.titulo + " em andamento" : ""; font.pixelSize: 16; font.weight: Font.DemiBold }
                                        Txt { text: pagModos.corrida ? pagModos.corrida.vitorias + " vitórias  ·  " + pagModos.corrida.bp + " BP ganhos  ·  time travado" : ""; color: PokeTema.sub }
                                    }
                                    Botao { texto: "Encerrar"; onClicked: ShellState.pokeModoAcao(["modos", "encerrar"]) }
                                    Botao { primario: true; texto: "Continuar"; onClicked: ShellState.pokeModoAcao(["modos", "continuar"]) }
                                }
                            }
                            Txt { visible: !!(pagModos.mo && pagModos.mo.bloqueio); text: pagModos.mo ? pagModos.mo.bloqueio : ""; color: PokeTema.warn }

                            // ── modos ──
                            GridLayout {
                                visible: pagModos.sub === "modos"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 3
                                rowSpacing: 12
                                columnSpacing: 12
                                Repeater {
                                    model: pagModos.cartoes
                                    Card {
                                        id: cartaoModo
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 1
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 8
                                            RowLayout {
                                                spacing: 10
                                                Icone { cp: cartaoModo.modelData.ico; color: PokeTema.acc; font.pixelSize: 22 }
                                                Txt { Layout.fillWidth: true; text: cartaoModo.modelData.nome; font.pixelSize: 17; font.weight: Font.DemiBold }
                                            }
                                            Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: cartaoModo.modelData.desc; color: PokeTema.sub; font.pixelSize: 13 }
                                            Txt {
                                                visible: cartaoModo.modelData.id === "diario"
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                                text: pagModos.mo ? "Hoje: " + pagModos.mo.diario.texto + (pagModos.mo.diario.feito ? "  ·  concluído" : "") : ""
                                                color: PokeTema.warn
                                                font.pixelSize: 13
                                            }
                                            RowLayout {
                                                visible: cartaoModo.modelData.id === "bossrush"
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Seta { icone: 0xF0141; onClicked: pagModos.regIdx = (pagModos.regIdx + pagModos.regioes.length - 1) % pagModos.regioes.length }
                                                Txt {
                                                    Layout.fillWidth: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: pagModos.regBoss ? pagModos.regBoss.nome + "  " + pagModos.regBoss.insignias + "/8" + (pagModos.regBoss.vencido ? "  ★" : "") : ""
                                                }
                                                Seta { icone: 0xF0142; onClicked: pagModos.regIdx = (pagModos.regIdx + 1) % pagModos.regioes.length }
                                            }
                                            Item { Layout.fillHeight: true }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Botao {
                                                    Layout.fillWidth: true
                                                    primario: true
                                                    texto: cartaoModo.modelData.formatos ? "Singles" : "Iniciar"
                                                    habilitado: pagModos.livre
                                                        && !(cartaoModo.modelData.id === "bossrush" && !(pagModos.regBoss && pagModos.regBoss.insignias >= 8))
                                                        && !(cartaoModo.modelData.id === "diario" && pagModos.mo && pagModos.mo.diario.feito)
                                                    onClicked: pagModos.iniciar(cartaoModo.modelData.id, "singles", cartaoModo.modelData.id === "bossrush" ? pagModos.regBoss.id : "")
                                                }
                                                Botao {
                                                    visible: cartaoModo.modelData.formatos
                                                    Layout.fillWidth: true
                                                    texto: "Duplas"
                                                    habilitado: pagModos.livre
                                                    onClicked: pagModos.iniciar(cartaoModo.modelData.id, "duplas", "")
                                                }
                                            }
                                        }
                                    }
                                }
                                Card {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 8
                                        RowLayout {
                                            spacing: 10
                                            Icone { cp: 0xF0004; color: PokeTema.acc; font.pixelSize: 22 }
                                            Txt { text: "Treinadores avulsos"; font.pixelSize: 17; font.weight: Font.DemiBold }
                                        }
                                        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Aparecem no notch enquanto você usa o PC, até 4 por dia, em singles ou duplas. Valem XP, dinheiro e amizade."; color: PokeTema.sub; font.pixelSize: 13 }
                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }

                            // ── recordes ──
                            ColumnLayout {
                                visible: pagModos.sub === "recordes"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 8
                                Repeater {
                                    model: pagModos.nomesRecorde
                                    Card {
                                        id: linhaRec
                                        required property var modelData
                                        readonly property var r: pagModos.mo ? pagModos.mo.recordes[modelData[0]] : null
                                        Layout.fillWidth: true
                                        implicitHeight: 56
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 18
                                            anchors.rightMargin: 16
                                            spacing: 12
                                            Txt { Layout.preferredWidth: 270; text: linhaRec.modelData[1]; font.pixelSize: 15 }
                                            Num { Layout.preferredWidth: 60; text: linhaRec.r ? linhaRec.r.melhor : "—"; font.pixelSize: 20; color: linhaRec.r ? PokeTema.warn : PokeTema.dim }
                                            Row {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Repeater {
                                                    model: linhaRec.r ? linhaRec.r.time : []
                                                    Image {
                                                        required property var modelData
                                                        width: 40; height: 40
                                                        source: "file://" + Quickshell.env("HOME") + "/.cache/pokeart/" + modelData.num + ".png"
                                                        fillMode: Image.PreserveAspectFit
                                                        smooth: false
                                                    }
                                                }
                                            }
                                            Txt { text: linhaRec.r ? linhaRec.r.data : ""; color: PokeTema.dim; font.pixelSize: 12 }
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }

                            // ── loja ──
                            Flickable {
                                visible: pagModos.sub === "loja"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentWidth: width
                                contentHeight: gradeLoja.implicitHeight
                                GridLayout {
                                    id: gradeLoja
                                    width: parent.width
                                    columns: 3
                                    rowSpacing: 10
                                    columnSpacing: 10
                                    Repeater {
                                        model: pagModos.mo ? pagModos.mo.loja : []
                                        Card {
                                            id: itemLoja
                                            required property var modelData
                                            readonly property bool pode: !!pagModos.mo && pagModos.mo.bp >= modelData.bp
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            implicitHeight: 66
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 10
                                                spacing: 8
                                                Image {
                                                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                                                    source: itemLoja.modelData.sprite ? "file://" + itemLoja.modelData.sprite : ""
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: false
                                                }
                                                Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: itemLoja.modelData.nome; font.pixelSize: 13 }
                                                Botao {
                                                    pequeno: true
                                                    texto: itemLoja.modelData.bp + " BP"
                                                    habilitado: itemLoja.pode
                                                    onClicked: ShellState.pokeEvento(["modos", "comprar", itemLoja.modelData.id])
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── componentes ─────────────────────────────────────────────────────────
    // ── fase 2: batalha e Liga ──────────────────────────────────────────────
    // um dos 4 quadros da inspeção do golpe
    component Quadro: Rectangle {
        default property alias conteudo: quadroRow.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        radius: 10
        color: PokeTema.card2
        border.width: 1
        border.color: PokeTema.line
        RowLayout {
            id: quadroRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
        }
    }
    // plataforma: uma Poké Bola achatada
    component Plataforma: Item {
        id: plat
        property real cx: 0
        property real cy: 0
        property real largura: 400
        x: cx - largura / 2
        y: cy - largura * 0.13
        width: largura
        height: largura * 0.26
        PokeBola {
            width: plat.largura
            height: plat.largura
            topo: "#1e2633"
            fundo: "#1e2633"
            traco: "#151b25"
            transform: Scale { yScale: 0.26 }
        }
    }
    // painel de HP com os cantos chanfrados (como no mockup)
    component BolasTime: Row {
        id: bt2
        property int total: 0
        property int vivos: 0
        property real lado: 17
        spacing: 3
        Repeater {
            model: bt2.total
            Image {
                required property int index
                width: bt2.lado
                height: bt2.lado
                source: "file://" + Quickshell.env("HOME") + "/.cache/pokeidle/itens/poke-ball.png"
                fillMode: Image.PreserveAspectFit
                smooth: false
                opacity: index < bt2.vivos ? 1 : 0.28
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
    // pokémon em campo, com as reações aos golpes
    component LutadorCampo: Item {
        id: lc
        property var dado: null
        property real cx: 0
        property real cy: 0
        property real lado: 190
        property bool costas: false
        property bool ativo: false
        readonly property bool caiu: !dado || !!dado.caiu
        readonly property int pisca: dado ? (dado.pisca || 0) : 0
        readonly property int atk: dado ? (dado.atk || 0) : 0
        readonly property int flash: dado ? (dado.flash || 0) : 0
        readonly property int brilho: dado ? (dado.brilho || 0) : 0
        readonly property int entra: dado ? (dado.entra || 0) : 0
        readonly property int avisoN: dado ? (dado.avisoN || 0) : 0
        readonly property real pe: lado * (costas ? 0.9 : 0.88)
        property real escala: 1
        onPiscaChanged: if (pisca > 0) { lcPisca.restart(); lcTreme.restart(); }
        onAtkChanged: if (atk > 0) lcAvanco.restart()
        onFlashChanged: if (flash > 0) { lcClarao.duracao = 320; lcClarao.restart(); }
        onBrilhoChanged: if (brilho > 0) { lcClarao.duracao = 620; lcClarao.restart(); }
        onEntraChanged: if (entra > 0) lcEntrada.restart()
        onAvisoNChanged: if (avisoN > 0) lcAviso.restart()
        width: lado
        height: lado
        x: cx - width / 2
        y: cy - pe

        // sombra no chão
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: lc.pe - height / 2
            width: lc.lado * 0.58
            height: lc.lado * 0.13
            radius: height / 2
            color: "#000000"
            opacity: lc.caiu ? 0 : 0.3 * lc.escala
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        AnimatedImage {
            id: lcSprite
            width: lc.lado
            height: lc.lado
            y: lc.caiu ? lc.lado * 0.5 : 0
            opacity: lc.caiu ? 0 : 1
            mirror: !!(lc.costas && lc.dado && lc.dado.lut && !lc.dado.lut.costas)
            source: lc.dado && lc.dado.lut && lc.dado.lut.gif ? "file://" + lc.dado.lut.gif : ""
            fillMode: Image.PreserveAspectFit
            smooth: false
            playing: lc.ativo
            transform: [
                Scale { origin.x: lc.lado / 2; origin.y: lc.pe; xScale: lc.escala; yScale: lc.escala },
                Translate { id: lcPasso },
                Translate { id: lcAbalo }
            ]
            Behavior on opacity { NumberAnimation { duration: 450 } }
            Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.InQuad } }
        }
        // clarão na cor do golpe
        Rectangle {
            id: lcLuz
            anchors.centerIn: parent
            width: lc.lado * 0.8
            height: width
            radius: width / 2
            color: lc.dado && lc.dado.flashCor ? lc.dado.flashCor : "#ffffff"
            opacity: 0
        }
        // Poké Bola entrando
        Image {
            id: lcBola
            visible: false
            width: 34
            height: 34
            source: "file://" + Quickshell.env("HOME") + "/.cache/pokeidle/itens/poke-ball.png"
            smooth: false
        }
        Text {
            id: lcTexto
            anchors.horizontalCenter: parent.horizontalCenter
            y: lc.lado * 0.1
            opacity: 0
            text: lc.dado && lc.dado.aviso ? lc.dado.aviso : ""
            color: lc.dado && lc.dado.avisoCor ? lc.dado.avisoCor : "#ffffff"
            style: Text.Outline
            styleColor: "#0b0f17"
            font.family: PokeTema.ui
            font.pixelSize: 20
            font.weight: Font.Black
        }
        SequentialAnimation {
            id: lcAvanco
            ParallelAnimation {
                NumberAnimation { target: lcPasso; property: "x"; to: lc.lado * (lc.costas ? 0.16 : -0.16); duration: 130; easing.type: Easing.OutQuad }
                NumberAnimation { target: lcPasso; property: "y"; to: lc.lado * (lc.costas ? -0.07 : 0.07); duration: 130; easing.type: Easing.OutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: lcPasso; property: "x"; to: 0; duration: 210; easing.type: Easing.InOutQuad }
                NumberAnimation { target: lcPasso; property: "y"; to: 0; duration: 210; easing.type: Easing.InOutQuad }
            }
        }
        SequentialAnimation {
            id: lcTreme
            NumberAnimation { target: lcAbalo; property: "x"; to: 8; duration: 45 }
            NumberAnimation { target: lcAbalo; property: "x"; to: -8; duration: 70 }
            NumberAnimation { target: lcAbalo; property: "x"; to: 5; duration: 60 }
            NumberAnimation { target: lcAbalo; property: "x"; to: 0; duration: 50 }
        }
        SequentialAnimation {
            id: lcPisca
            loops: 3
            PropertyAction { target: lcSprite; property: "visible"; value: false }
            PauseAnimation { duration: 70 }
            PropertyAction { target: lcSprite; property: "visible"; value: true }
            PauseAnimation { duration: 70 }
        }
        ParallelAnimation {
            id: lcClarao
            property int duracao: 320
            NumberAnimation { target: lcLuz; property: "opacity"; from: 0.75; to: 0; duration: lcClarao.duracao; easing.type: Easing.OutQuad }
            NumberAnimation { target: lcLuz; property: "scale"; from: 0.45; to: 1.3; duration: lcClarao.duracao; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            id: lcEntrada
            ScriptAction { script: { lc.escala = 0; lcBola.visible = true; } }
            ParallelAnimation {
                NumberAnimation { target: lcBola; property: "x"; from: lc.costas ? -170 : lc.lado + 130; to: lc.lado / 2 - 17; duration: 280; easing.type: Easing.OutQuad }
                NumberAnimation { target: lcBola; property: "y"; from: lc.lado * 0.1; to: lc.pe - 40; duration: 280; easing.type: Easing.InQuad }
                NumberAnimation { target: lcBola; property: "rotation"; from: 0; to: 720; duration: 280 }
            }
            ScriptAction { script: { lcBola.visible = false; lcClarao.duracao = 280; lcClarao.restart(); } }
            NumberAnimation { target: lc; property: "escala"; from: 0; to: 1; duration: 190; easing.type: Easing.OutBack }
        }
        SequentialAnimation {
            id: lcAviso
            PropertyAction { target: lcTexto; property: "opacity"; value: 1 }
            ParallelAnimation {
                NumberAnimation { target: lcTexto; property: "y"; from: lc.lado * 0.22; to: lc.lado * -0.02; duration: 950; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 620 }
                    NumberAnimation { target: lcTexto; property: "opacity"; to: 0; duration: 330 }
                }
            }
        }
    }
    component PainelHp: Item {
        id: ph
        property var lut: null
        property real hp: 0
        property bool inimigo: true
        property bool compacto: false
        property var est: ({})
        readonly property var chips: {
            const nomes = { atk: "ATQ", def: "DEF", spa: "AES", spd: "DES", spe: "VEL", acc: "PRE", eva: "EVA" };
            return Object.keys(nomes).filter(k => (est || {})[k]).map(k => ({ t: nomes[k], v: est[k] }));
        }
        readonly property real pct: lut ? hp / Math.max(1, lut.hp_max) : 0
        visible: !!lut
        height: compacto ? 66 : inimigo ? 90 : 116
        Behavior on hp { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                const w = width, h = height, k = 20;
                c.reset();
                c.beginPath();
                c.moveTo(k, 1); c.lineTo(w - k, 1); c.lineTo(w - 1, h / 2);
                c.lineTo(w - k, h - 1); c.lineTo(k, h - 1); c.lineTo(1, h / 2);
                c.closePath();
                c.fillStyle = "rgba(20, 26, 37, 0.92)";
                c.fill();
                c.strokeStyle = "rgba(255, 255, 255, 0.28)";
                c.lineWidth = 2;
                c.stroke();
            }
        }
        Text {
            text: ph.inimigo ? "◀" : "▶"
            color: PokeTema.sub
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            x: ph.inimigo ? -14 : ph.width + 2
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.topMargin: ph.compacto ? 8 : 14
            anchors.bottomMargin: ph.compacto ? 8 : 14
            spacing: ph.compacto ? 4 : 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: ph.lut ? ph.lut.nome : ""
                    color: PokeTema.text
                    font.family: PokeTema.ui
                    font.pixelSize: ph.compacto ? 15 : 20
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: !!(ph.lut && ph.lut.genero && ph.lut.genero !== "-")
                    text: ph.lut && ph.lut.genero === "f" ? "♀" : "♂"
                    color: ph.lut && ph.lut.genero === "f" ? "#f06292" : "#4ea4e6"
                    font.pixelSize: ph.compacto ? 15 : 20
                }
                Etiqueta {
                    visible: !!(ph.lut && ph.lut.status)
                    texto: ph.lut ? ({ par: "PAR", brn: "QUE", psn: "ENV", tox: "ENV", slp: "DOR", frz: "CON" })[ph.lut.status] || "" : ""
                    cor: ph.lut ? ({ par: "#f2c84b", brn: "#f0913a", psn: "#a552cc", tox: "#a552cc", slp: "#9ba4b4", frz: "#5fcfd0" })[ph.lut.status] || PokeTema.sub : PokeTema.sub
                }
                Repeater {
                    model: ph.chips
                    Etiqueta {
                        required property var modelData
                        texto: modelData.t + (modelData.v > 0 ? " +" : " −") + Math.abs(modelData.v)
                        cor: modelData.v > 0 ? PokeTema.ok : PokeTema.crit
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: ph.lut ? "Nv. " + ph.lut.nivel : ""
                    color: PokeTema.text
                    font.family: PokeTema.mono
                    font.pixelSize: ph.compacto ? 13 : 18
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text { text: "HP"; color: "#e8c46a"; font.family: PokeTema.ui; font.pixelSize: ph.compacto ? 12 : 15; font.weight: Font.Bold }
                Barra {
                    Layout.fillWidth: true
                    altura: ph.compacto ? 8 : 11
                    valor: ph.pct
                    cor: ph.pct > 0.5 ? PokeTema.ok : ph.pct > 0.2 ? PokeTema.warn : PokeTema.crit
                }
                Text {
                    visible: ph.compacto && !ph.inimigo
                    text: ph.lut ? Math.round(ph.hp) + "/" + ph.lut.hp_max : ""
                    color: PokeTema.text
                    font.family: PokeTema.mono
                    font.pixelSize: 12
                }
            }
            Text {
                visible: !ph.inimigo && !ph.compacto
                Layout.alignment: Qt.AlignRight
                text: ph.lut ? Math.round(ph.hp) + " / " + ph.lut.hp_max : ""
                color: PokeTema.text
                font.family: PokeTema.mono
                font.pixelSize: 18
            }
        }
    }
    component BotaoBatalha: Rectangle {
        id: bb
        property string texto: ""
        property int icone: 0
        property color corIcone: PokeTema.sub
        property string detalhe: ""
        property string imagem: ""
        property bool destaque: false
        property bool habilitado: true
        property bool temTipo: false
        property color corTipo: "#ffffff"
        property string imagem2: ""
        property string selo: ""
        property color corSelo: PokeTema.sub
        property color corDetalhe: PokeTema.sub
        signal clicked()
        signal hover(bool sim)
        readonly property bool aceso: (bbMa.containsMouse || destaque) && habilitado
        radius: 14
        color: bbMa.containsMouse && habilitado ? "#f02c3547" : "#ea1b2230"
        border.width: aceso ? 2 : 1
        border.color: aceso ? (temTipo ? corTipo : PokeTema.acc) : "#55ffffff"
        opacity: habilitado ? 1 : 0.45
        clip: true
        Rectangle {
            visible: bb.temTipo
            anchors.fill: parent
            radius: bb.radius
            color: PokeTema.tinta(bb.corTipo, bbMa.containsMouse ? 0.36 : 0.24)
        }
        Rectangle {
            visible: bb.temTipo
            width: 6
            height: parent.height
            color: bb.corTipo
        }
        scale: bbMa.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 14
            spacing: 14
            Text {
                visible: bb.imagem === ""
                text: PokeTema.ic(bb.icone)
                color: bb.corIcone
                font.family: PokeTema.mono
                font.pixelSize: 24
            }
            Image {
                visible: bb.imagem !== ""
                source: bb.imagem
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                sourceSize: Qt.size(64, 64)
                smooth: true
                mipmap: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: bb.texto
                    color: PokeTema.text
                    font.family: PokeTema.ui
                    font.pixelSize: 19
                }
                Text {
                    visible: bb.detalhe !== ""
                    text: bb.detalhe
                    color: bb.corDetalhe
                    font.family: PokeTema.mono
                    font.pixelSize: bb.temTipo ? 13 : 12
                    font.weight: bb.temTipo ? Font.DemiBold : Font.Normal
                }
            }
            ColumnLayout {
                visible: bb.temTipo
                spacing: 4
                Image {
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    source: bb.imagem2
                    sourceSize: Qt.size(48, 48)
                    smooth: true
                    mipmap: true
                }
                Rectangle {
                    visible: bb.selo !== ""
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: seloT.implicitWidth + 12
                    implicitHeight: 20
                    radius: 6
                    color: "#d90d1219"
                    Text {
                        id: seloT
                        anchors.centerIn: parent
                        text: bb.selo
                        color: bb.corSelo
                        font.family: PokeTema.mono
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }
        }
        MouseArea {
            id: bbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: bb.habilitado
            cursorShape: Qt.PointingHandCursor
            onClicked: bb.clicked()
            onContainsMouseChanged: bb.hover(containsMouse)
        }
    }
    // insígnia: o sprite recortado (cristal Z em Alola); sem cor e apagada
    // enquanto não ganha. Sem sprite, o losango na cor do tipo.
    component Insignia: Item {
        id: ins
        property string tipo: ""
        property string regiao: ""
        property string lider: ""
        property bool ganha: false
        property real lado: 32
        implicitWidth: lado
        implicitHeight: lado
        width: lado
        height: lado
        Image {
            id: insImg
            anchors.fill: parent
            source: PokeTema.imgInsignia(ins.regiao, ins.lider)
            sourceSize: Qt.size(160, 160)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: false
        }
        MultiEffect {
            anchors.fill: insImg
            source: insImg
            visible: insImg.status === Image.Ready
            saturation: ins.ganha ? 0 : -1
            brightness: 0
            opacity: ins.ganha ? 1 : 0.55
        }
        Rectangle {
            visible: insImg.status !== Image.Ready
            anchors.centerIn: parent
            width: ins.lado * 0.72
            height: width
            rotation: 45
            radius: ins.lado * 0.14
            color: ins.ganha ? PokeTema.cor(ins.tipo) : PokeTema.track
            border.width: 1
            border.color: ins.ganha ? Qt.lighter(PokeTema.cor(ins.tipo), 1.3) : PokeTema.line
        }
    }
    // texto da interface
    component Txt: Text {
        color: PokeTema.text
        font.family: PokeTema.ui
        font.pixelSize: 13
    }
    // números
    component Num: Text {
        color: PokeTema.text
        font.family: PokeTema.mono
        font.pixelSize: 13
    }
    // ícone da Nerd Font
    component Icone: Text {
        property int cp: 0
        text: PokeTema.ic(cp)
        color: PokeTema.sub
        font.family: PokeTema.mono
        font.pixelSize: 18
    }
    component Card: Rectangle {
        color: PokeTema.card
        radius: 16
        border.width: 1
        border.color: PokeTema.line
    }
    // título de seção com a linha que vai até a borda
    component Cabecalho: RowLayout {
        id: cab
        property string texto: ""
        property string extra: ""
        spacing: 14
        Text { text: cab.texto; color: PokeTema.text; font.family: PokeTema.ui; font.pixelSize: 20; font.weight: Font.DemiBold }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: PokeTema.line }
        Text { visible: cab.extra !== ""; text: cab.extra; color: PokeTema.dim; font.family: PokeTema.ui; font.pixelSize: 12 }
    }
    // "22 / 140": o primeiro claro, a barra e o segundo apagados
    component Par: Text {
        property var a: 0
        property var b: 0
        property bool alinharDireita: false
        horizontalAlignment: alinharDireita ? Text.AlignRight : Text.AlignLeft
        textFormat: Text.StyledText
        text: a + "<font color='" + PokeTema.dim + "'> / </font><font color='" + PokeTema.sub + "'>" + b + "</font>"
        color: PokeTema.text
        font.family: PokeTema.mono
        font.pixelSize: 16
    }
    component Barra: Rectangle {
        id: barra
        property real valor: 0
        property color cor: PokeTema.acc
        property int altura: 8
        implicitHeight: altura
        implicitWidth: 120
        radius: altura / 2
        color: PokeTema.track
        Rectangle {
            width: Math.max(barra.valor > 0 ? barra.height : 0, barra.width * Math.max(0, Math.min(1, barra.valor)))
            height: barra.height
            radius: barra.radius
            color: barra.cor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }
    // tipo: só o ícone redondo (o nome aparece ao passar o mouse)
    component TipoPill: Item {
        id: pill
        property string tipo: ""
        property bool pequeno: false
        property bool semIcone: false     // (compatível com o antigo; não muda nada)
        property real lado: pequeno ? 22 : 30
        visible: tipo !== ""
        implicitWidth: lado
        implicitHeight: lado
        Image {
            anchors.fill: parent
            source: PokeTema.imgTipo(pill.tipo)
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        HoverHandler { id: pillHover }
        ToolTip.visible: pillHover.hovered
        ToolTip.text: PokeTema.nomeTipo[tipo] || tipo
        ToolTip.delay: 250
    }
    // marcador pequeno ("LÍDER", "TM", "NO POKÉCENTER")
    component Etiqueta: Rectangle {
        id: etq
        property string texto: ""
        property color cor: PokeTema.acc
        implicitHeight: 20
        implicitWidth: etqT.implicitWidth + 14
        radius: 6
        color: PokeTema.tinta(cor, 0.16)
        border.width: 1
        border.color: PokeTema.tinta(cor, 0.45)
        Text {
            id: etqT
            anchors.centerIn: parent
            text: etq.texto
            color: Qt.lighter(etq.cor, 1.15)
            font.family: PokeTema.ui
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }
    }
    component Botao: Rectangle {
        id: bt
        property string texto: ""
        property int icone: 0
        property bool primario: false
        property bool selecionado: false
        property bool pequeno: false
        property bool habilitado: true
        property color acc: PokeTema.acc
        signal clicked()
        implicitHeight: pequeno ? 30 : 36
        implicitWidth: btRow.implicitWidth + (pequeno ? 22 : 30)
        radius: 10
        opacity: habilitado ? 1 : 0.5
        color: primario ? (btMa.containsMouse ? Qt.lighter(acc, 1.12) : acc)
             : selecionado ? PokeTema.tinta(acc, 0.18)
             : btMa.containsMouse ? PokeTema.hover : PokeTema.card2
        border.width: 1
        border.color: primario ? acc : selecionado ? PokeTema.tinta(acc, 0.7) : PokeTema.line
        scale: btMa.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: btRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: bt.icone !== 0
                anchors.verticalCenter: parent.verticalCenter
                text: PokeTema.ic(bt.icone)
                color: bt.primario ? "#10151d" : bt.selecionado ? Qt.lighter(bt.acc, 1.2) : PokeTema.sub
                font.family: PokeTema.mono
                font.pixelSize: bt.pequeno ? 14 : 16
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bt.texto
                color: bt.primario ? "#10151d" : bt.selecionado ? Qt.lighter(bt.acc, 1.25) : PokeTema.text
                font.family: PokeTema.ui
                font.pixelSize: bt.pequeno ? 12 : 13
                font.weight: bt.primario ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: btMa
            anchors.fill: parent
            enabled: bt.habilitado
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bt.clicked()
        }
    }
    // botão redondo só com ícone (setas, fechar, −/+)
    component Seta: Rectangle {
        id: seta
        property int icone: 0
        signal clicked()
        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: setaMa.containsMouse ? PokeTema.hover : PokeTema.card2
        border.width: 1
        border.color: PokeTema.line
        Text {
            anchors.centerIn: parent
            text: PokeTema.ic(seta.icone)
            color: PokeTema.sub
            font.family: PokeTema.mono
            font.pixelSize: 18
        }
        MouseArea {
            id: setaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: seta.clicked()
        }
    }
    // Poké Bola desenhada (vermelha e branca, ou apagada para fundo)
    component PokeBola: Canvas {
        id: bola
        property color topo: PokeTema.pokeRed
        property color fundo: "#eef0f3"
        property color traco: PokeTema.bg
        width: 24
        height: 24
        onTopoChanged: requestPaint()
        onFundoChanged: requestPaint()
        onTracoChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            const w = Math.min(width, height), r = w / 2, lw = Math.max(1.5, w * 0.085);
            c.reset();
            if (!(w > 2))
                return;              // ainda sem tamanho (antes do layout)
            c.translate((width - w) / 2, (height - w) / 2);
            c.fillStyle = bola.fundo;
            c.beginPath(); c.arc(r, r, r, 0, 2 * Math.PI); c.fill();
            c.fillStyle = bola.topo;
            c.beginPath(); c.arc(r, r, r, Math.PI, 2 * Math.PI); c.fill();
            c.fillStyle = bola.traco;
            c.fillRect(0, r - lw / 2, w, lw);
            c.beginPath(); c.arc(r, r, r * 0.34, 0, 2 * Math.PI); c.fill();
            c.fillStyle = bola.fundo;
            c.beginPath(); c.arc(r, r, r * 0.21, 0, 2 * Math.PI); c.fill();
        }
    }
    // sombra oval sob o sprite
    component Sombra: Rectangle {
        property real largura: 110
        width: largura
        height: Math.max(10, largura * 0.12)
        radius: height / 2
        color: PokeTema.sombra
        opacity: 0.4
    }
    // barra lateral: Poké Bola + título, conteúdo do chamador, bola decorativa
    component Lateral: Rectangle {
        id: lat
        property color acc: PokeTema.acc
        property string subtitulo: ""
        default property alias conteudo: latCol.data
        color: PokeTema.side
        clip: true
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: PokeTema.line }
        // bola gigante apagada no canto
        PokeBola {
            x: -70
            y: parent.height - 190
            width: 260; height: 260
            topo: "#1f2531"
            fundo: "#1f2531"
            traco: PokeTema.side
        }
        ColumnLayout {
            id: latCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 6
            RowLayout {
                Layout.leftMargin: 6
                spacing: 12
                PokeBola { width: 34; height: 34; traco: PokeTema.side }
                ColumnLayout {
                    spacing: 0
                    Text { text: "PokéIdle"; color: PokeTema.text; font.family: PokeTema.ui; font.pixelSize: 22; font.weight: Font.DemiBold }
                    Text { visible: lat.subtitulo !== ""; text: lat.subtitulo; color: PokeTema.sub; font.family: PokeTema.ui; font.pixelSize: 12 }
                }
            }
            // linha com o trecho colorido
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.bottomMargin: 18
                implicitHeight: 2
                Rectangle { width: parent.width; height: 1; y: 0.5; color: PokeTema.line }
                Rectangle { width: 64; height: 2; radius: 1; color: lat.acc }
            }
        }
    }
    component AbaLateral: Rectangle {
        id: aba
        property string rotulo: ""
        property int icone: 0
        property string numeral: ""
        property bool ativa: false
        property color acc: PokeTema.acc
        signal clicked()
        implicitHeight: 46
        radius: 12
        color: ativa ? PokeTema.tinta(acc, 0.17) : abaMa.containsMouse ? PokeTema.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            visible: aba.ativa
            width: 4; radius: 2
            height: parent.height - 14
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            color: aba.acc
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            spacing: 14
            Text {
                visible: aba.numeral !== "" || aba.icone !== 0
                Layout.preferredWidth: 24
                horizontalAlignment: Text.AlignHCenter
                text: aba.numeral !== "" ? aba.numeral : PokeTema.ic(aba.icone)
                color: aba.ativa ? Qt.lighter(aba.acc, 1.15) : PokeTema.dim
                font.family: PokeTema.mono
                font.pixelSize: aba.numeral !== "" ? 13 : 20
                font.weight: aba.numeral !== "" ? Font.Bold : Font.Normal
            }
            Text {
                Layout.fillWidth: true
                text: aba.rotulo
                color: aba.ativa ? Qt.lighter(aba.acc, 1.3) : PokeTema.sub
                font.family: PokeTema.ui
                font.pixelSize: 15
                font.weight: aba.ativa ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: abaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: aba.clicked()
        }
    }
}
