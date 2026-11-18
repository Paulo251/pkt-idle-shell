"""Status no estilo dos jogos, sem IV nem EV.

  HP     = ⌊2·base·nível/100⌋ + nível + 10
  outros = ⌊(⌊2·base·nível/100⌋ + 5) × natureza⌋      (natureza: 1,1 / 0,9 / 1,0)

As chaves das naturezas são as que já estão no save (nomes em espanhol do
shell). Cada uma aponta para a natureza REAL dos jogos.
"""
from __future__ import annotations

import json
from pathlib import Path

from . import api

DEX = Path.home() / ".cache" / "pokepalette" / "dex"
NOMES_STATS = ["HP", "Ataque", "Defesa", "At. Esp.", "Def. Esp.", "Velocidade"]
CHAVES_STATS = ["hp", "atk", "def", "spa", "spd", "spe"]

# chave no save: (status que sobe, status que desce, nome em português)
# índices: 0 hp, 1 atk, 2 def, 3 spa, 4 spd, 5 spe
NATUREZAS: dict[str, tuple[int | None, int | None, str]] = {
    "Fuerte": (None, None, "Resistente"), "Dócil": (None, None, "Dócil"),
    "Seria": (None, None, "Séria"), "Tímida": (None, None, "Envergonhada"),
    "Rara": (None, None, "Peculiar"),
    "Miedosa": (5, 1, "Tímida"), "Alegre": (5, 3, "Alegre"), "Ingenua": (5, 4, "Ingênua"),
    "Activa": (5, 2, "Apressada"), "Alocada": (3, 4, "Imprudente"),
    "Huraña": (1, 2, "Solitária"), "Audaz": (1, 5, "Corajosa"), "Firme": (1, 3, "Firme"),
    "Pícara": (1, 4, "Travessa"), "Osada": (2, 1, "Ousada"), "Pirata": (2, 5, "Relaxada"),
    "Agitada": (2, 3, "Inquieta"), "Floja": (2, 4, "Displicente"),
    "Modesta": (3, 1, "Modesta"), "Afable": (3, 2, "Branda"), "Mansa": (3, 5, "Quieta"),
    "Calmada": (4, 1, "Calma"), "Amable": (4, 2, "Gentil"), "Grosera": (4, 5, "Atrevida"),
    "Cauta": (4, 3, "Cuidadosa"),
}


def base(num: int) -> list[int] | None:
    """[hp, atk, def, spa, spd, spe] — do dex já baixado pelo poke-dex."""
    try:
        s = json.loads((DEX / f"{num}.json").read_text()).get("stats")
        if s and len(s) == 6:
            return [int(x) for x in s]
    except (OSError, ValueError):
        pass
    p = api.pokemon(num)
    s = (p or {}).get("stats")
    return [int(x) for x in s] if s and len(s) == 6 else None


def natureza_info(chave: str) -> dict:
    sobe, desce, nome = NATUREZAS.get(chave, (None, None, chave or "?"))
    return {"chave": chave, "nome": nome,
            "sobe": NOMES_STATS[sobe] if sobe is not None else None,
            "desce": NOMES_STATS[desce] if desce is not None else None}


def calcular(num: int, nivel: int, natureza: str) -> dict | None:
    b = base(num)
    if not b:
        return None
    sobe, desce, _ = NATUREZAS.get(natureza, (None, None, ""))
    valores = []
    for i, bs in enumerate(b):
        if i == 0:
            v = (2 * bs * nivel) // 100 + nivel + 10
            if bs == 1:          # Shedinja: sempre 1 HP
                v = 1
        else:
            v = (2 * bs * nivel) // 100 + 5
            mult = 1.1 if i == sobe else 0.9 if i == desce else 1.0
            v = int(v * mult)
        valores.append(v)
    return {"base": b, "valores": valores,
            "lista": [{"chave": CHAVES_STATS[i], "nome": NOMES_STATS[i], "base": b[i],
                       "valor": valores[i],
                       "natureza": "+" if i == sobe else "-" if i == desce else ""}
                      for i in range(6)]}


def hp_max(num: int, nivel: int, natureza: str) -> int:
    c = calcular(num, nivel, natureza)
    return c["valores"][0] if c else max(10, nivel * 3)
