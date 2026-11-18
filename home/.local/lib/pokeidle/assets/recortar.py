#!/usr/bin/env python3
"""Recorta as folhas de originais/ em sprites individuais com fundo transparente.

    python3 ~/.local/lib/pokeidle/assets/recortar.py [--conferir saida.png]

Como funciona (PIL + numpy, sem scipy):
  1. fundo = pixels claros e sem cor ligados à borda (flood fill), então o
     branco de DENTRO das insígnias continua opaco;
  2. o resto é rotulado em componentes conectados; os pequenos (ruído do JPEG,
     as letras dos nomes em Galar) são descartados;
  3. as peças grandes são ordenadas em linhas/colunas e recebem o nome da
     tabela FOLHAS; a borda ganha alpha suave sem o halo branco.
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

BASE = Path(__file__).resolve().parent
ORIG = BASE / "originais"
MAX_LADO = 160

# arquivo, linhas (quantas peças por linha), limiar do fundo, nomes (na ordem
# da folha) -> destino relativo (None = não salvar)
FOLHAS = [
    ("badges/kanto-badges.jpg", [4, 4], (215, 40), "insignias/kanto",
     ["brock", "misty", "ltsurge", "erika", "sabrina", "koga", "blaine", "giovanni"]),
    ("badges/johto-badges.jpg", [4, 4], (215, 40), "insignias/johto",
     ["falkner", "bugsy", "whitney", "morty", "chuck", "jasmine", "pryce", "clair"]),
    ("badges/hoenn-badges.jpg", [4, 4], (170, 45, {"abrir": 2}), "insignias/hoenn",
     ["roxanne", "brawly", "wattson", "flannery", "norman", "winona", "tateliza", "wallace"]),
    ("badges/sinnoh-badges.jpg", [4, 4], (215, 40), "insignias/sinnoh",
     ["roark", "gardenia", "maylene", "crasherwake", "fantina", "byron", "candice", "volkner"]),
    ("badges/unova-badges.png", [5, 5], (215, 40), "insignias/unova",
     ["cilan", "lenora", "extra-toxic", "burgh", "elesa", "clay", "skyla", "brycen", "drayden", "extra-wave"]),
    ("badges/kalos-badges.png", [4, 4], (215, 40), "insignias/kalos",
     ["viola", "grant", "korrina", "ramos", "clemont", "valerie", "olympia", "wulfric"]),
    ("badges/alola-badges.jpg", [3, 3, 3, 3, 3, 3], (215, 40), "insignias/alola",
     ["z-normal", "z-poison", "z-psychic", "mallow", "hapu", "z-ice", "kiawe", "olivia", "z-dragon",
      "lana", "z-bug", "nanu", "hala", "z-ghost", "z-steel", "z-flying", "sophocles", "z-fairy"]),
    ("badges/galar-badges.jpg", [5, 5], (215, 40, {"juntar": False}), "insignias/galar",
     ["milo", "nessa", "kabu", "bea", "extra-phantom", "opal", "gordie", "extra-shiver", "piers", "raihan"]),
    ("badges/paldeia-badges.jpg", [4, 4], (225, 35), "insignias/paldea",
     ["katy", "brassius", "iono", "kofu", "larry", "ryme", "tulip", "grusha"]),
    ("icons/type-icons.jpg", [6, 6, 6], (215, 40), "tipos",
     ["bug", "grass", "fairy", "normal", "dragon", "psychic",
      "ghost", "ground", "steel", "fire", "flying", "ice",
      "electric", "rock", "dark", "water", "fighting", "poison"]),
]
# Alola: os cristais Z dos treinadores também ficam com o nome do tipo
Z_DOS_TREINADORES = {"hala": "fighting", "lana": "water", "kiawe": "fire", "mallow": "grass",
                     "olivia": "rock", "sophocles": "electric", "nanu": "dark", "hapu": "ground"}


def fundo_externo(rgb: np.ndarray, claro: int, sat: int) -> np.ndarray:
    mn, mx = rgb.min(2), rgb.max(2)
    cand = (mn >= claro) & ((mx - mn) <= sat)
    f = np.zeros_like(cand)
    f[0, :], f[-1, :], f[:, 0], f[:, -1] = cand[0, :], cand[-1, :], cand[:, 0], cand[:, -1]
    while True:
        n = f.copy()
        n[1:, :] |= f[:-1, :]
        n[:-1, :] |= f[1:, :]
        n[:, 1:] |= f[:, :-1]
        n[:, :-1] |= f[:, 1:]
        n &= cand
        if (n == f).all():
            return f
        f = n


def componentes(fg: np.ndarray) -> tuple[np.ndarray, list[dict]]:
    h, w = fg.shape
    rot = np.zeros((h, w), dtype=np.int32)
    comps = []
    ys, xs = np.nonzero(fg)
    for y0, x0 in zip(ys, xs):
        if rot[y0, x0]:
            continue
        k = len(comps) + 1
        rot[y0, x0] = k
        q = deque([(y0, x0)])
        area, y1, y2, x1, x2, sy, sx = 0, y0, y0, x0, x0, 0, 0
        while q:
            y, x = q.popleft()
            area += 1; sy += y; sx += x
            y1, y2, x1, x2 = min(y1, y), max(y2, y), min(x1, x), max(x2, x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and fg[yy, xx] and not rot[yy, xx]:
                        rot[yy, xx] = k
                        q.append((yy, xx))
        comps.append({"k": k, "area": area, "bbox": [y1, x1, y2, x2], "cy": sy / area, "cx": sx / area})
    return rot, comps


def recortar_folha(arquivo: str, linhas: list[int], limiar, destino: str, nomes: list[str]) -> list[Path]:
    img = Image.open(ORIG / arquivo).convert("RGB")
    rgb = np.asarray(img).astype(np.int16)
    opc = limiar[2] if len(limiar) > 2 else {}
    fundo = fundo_externo(rgb, limiar[0], limiar[1])
    bg = np.median(rgb[fundo], axis=0) if fundo.any() else np.array([255, 255, 255])
    fg = ~fundo
    # abertura: some com linhas finas (a grade da textura de Hoenn)
    for _ in range(opc.get("abrir", 0)):
        e = fg.copy()
        e[1:, :] &= fg[:-1, :]; e[:-1, :] &= fg[1:, :]; e[:, 1:] &= fg[:, :-1]; e[:, :-1] &= fg[:, 1:]
        fg = e
    for _ in range(opc.get("abrir", 0)):
        d = fg.copy()
        d[1:, :] |= fg[:-1, :]; d[:-1, :] |= fg[1:, :]; d[:, 1:] |= fg[:, :-1]; d[:, :-1] |= fg[:, 1:]
        fg = d & ~fundo
    rot, comps = componentes(fg)
    n = sum(linhas)
    comps.sort(key=lambda c: -c["area"])
    grandes = comps[:n]
    if len(grandes) < n or grandes[-1]["area"] < 0.2 * grandes[0]["area"]:
        print(f"!! {arquivo}: peças grandes estranhas: {[c['area'] for c in comps[:n + 3]]}")
    # pedacinhos perto de uma peça grande (≤ 6 px da caixa) entram nela; o resto sai
    for c in comps[n:] if opc.get("juntar", True) else []:
        if c["area"] < 12:
            continue
        y1, x1, y2, x2 = c["bbox"]
        for g in grandes:
            gy1, gx1, gy2, gx2 = g["bbox"]
            if y1 >= gy1 - 6 and y2 <= gy2 + 6 and x1 >= gx1 - 6 and x2 <= gx2 + 6:
                g.setdefault("extra", []).append(c["k"])
                break
    # ordem: linhas pelo Y, colunas pelo X
    grandes.sort(key=lambda c: c["cy"])
    ordem, i = [], 0
    for qtd in linhas:
        ordem += sorted(grandes[i:i + qtd], key=lambda c: c["cx"])
        i += qtd
    pasta = BASE / destino
    pasta.mkdir(parents=True, exist_ok=True)
    feitos = []
    # distância à cor do fundo, para o alpha da borda
    dist = np.abs(rgb - bg).max(2).astype(np.float32)
    perto_fundo = fundo.copy()
    for _ in range(2):
        p = perto_fundo.copy()
        p[1:, :] |= perto_fundo[:-1, :]; p[:-1, :] |= perto_fundo[1:, :]
        p[:, 1:] |= perto_fundo[:, :-1]; p[:, :-1] |= perto_fundo[:, 1:]
        perto_fundo = p
    for c, nome in zip(ordem, nomes):
        if not nome:
            continue
        ks = [c["k"]] + c.get("extra", [])
        mask = np.isin(rot, ks)
        y1, x1, y2, x2 = c["bbox"]
        y1, x1 = max(0, y1 - 4), max(0, x1 - 4)
        y2, x2 = min(rgb.shape[0] - 1, y2 + 4), min(rgb.shape[1] - 1, x2 + 4)
        m = mask[y1:y2 + 1, x1:x2 + 1]
        sub = rgb[y1:y2 + 1, x1:x2 + 1].astype(np.float32)
        a = np.where(m, 255.0, 0.0)
        borda = m & perto_fundo[y1:y2 + 1, x1:x2 + 1]
        a = np.where(borda, np.clip(dist[y1:y2 + 1, x1:x2 + 1] * 255 / 70, 0, 255), a)
        # tira a cor do fundo da borda (sem halo branco)
        af = np.maximum(a / 255.0, 1e-3)[..., None]
        cor = np.clip((sub - (1 - af) * bg) / af, 0, 255)
        out = np.dstack([cor, a]).astype(np.uint8)
        im = Image.fromarray(out, "RGBA")
        lado = max(im.size)
        if lado > MAX_LADO:
            f = MAX_LADO / lado
            im = im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)
        caminho = pasta / f"{nome}.png"
        im.save(caminho)
        feitos.append(caminho)
        if destino.endswith("alola") and nome in Z_DOS_TREINADORES:
            im.save(pasta / f"z-{Z_DOS_TREINADORES[nome]}.png")
    print(f"{arquivo}: {len(feitos)} recortes -> {destino}")
    return feitos


# Categorias do golpe (físico/especial/status): a folha é símbolo BRANCO sobre
# azul-marinho, de cima para baixo. Viram um círculo colorido com o símbolo
# branco no meio, no mesmo estilo dos ícones de tipo.
CATEGORIAS = ("icons/attack-types.jpeg", [("physical", (226, 92, 58)), ("special", (79, 127, 224)),
                                          ("status", (138, 147, 163))])


def recortar_categorias() -> list[Path]:
    arquivo, saidas = CATEGORIAS
    rgb = np.asarray(Image.open(ORIG / arquivo).convert("RGB")).astype(np.int16)
    claro = rgb.min(2)
    fg = claro > 150
    rot, comps = componentes(fg)
    comps = sorted(sorted(comps, key=lambda c: -c["area"])[:len(saidas)], key=lambda c: c["cy"])
    pasta = BASE / "categorias"
    pasta.mkdir(parents=True, exist_ok=True)
    feitos = []
    for c, (nome, cor) in zip(comps, saidas):
        y1, x1, y2, x2 = c["bbox"]
        sub = claro[y1:y2 + 1, x1:x2 + 1].astype(np.float32)
        a = np.clip((sub - 70) * 255 / (215 - 70), 0, 255)
        simbolo = Image.fromarray(np.dstack([np.full(sub.shape + (3,), 255), a]).astype(np.uint8), "RGBA")
        lado = 256
        fundo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        from PIL import ImageDraw
        ImageDraw.Draw(fundo).ellipse((4, 4, lado - 5, lado - 5), fill=cor + (255,))
        simbolo.thumbnail((int(lado * 0.62), int(lado * 0.62)), Image.LANCZOS)
        fundo.alpha_composite(simbolo, ((lado - simbolo.width) // 2, (lado - simbolo.height) // 2))
        fundo = fundo.resize((128, 128), Image.LANCZOS)
        caminho = pasta / f"{nome}.png"
        fundo.save(caminho)
        feitos.append(caminho)
    print(f"{arquivo}: {len(feitos)} recortes -> categorias")
    return feitos


def folha_conferencia(arquivos: list[Path], destino: Path) -> None:
    cel = 96
    cols = 12
    linhas = (len(arquivos) + cols - 1) // cols
    folha = Image.new("RGBA", (cols * cel, linhas * cel), (21, 26, 36, 255))
    for i, p in enumerate(arquivos):
        im = Image.open(p)
        im.thumbnail((cel - 12, cel - 12))
        x = (i % cols) * cel + (cel - im.width) // 2
        y = (i // cols) * cel + (cel - im.height) // 2
        folha.alpha_composite(im, (x, y))
    folha.save(destino)


if __name__ == "__main__":
    todos = []
    for folha in FOLHAS:
        todos += recortar_folha(*folha)
    todos += recortar_categorias()
    if "--conferir" in sys.argv:
        folha_conferencia(todos, Path(sys.argv[sys.argv.index("--conferir") + 1]))
