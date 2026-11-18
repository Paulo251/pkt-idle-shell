"""Golpes: o que cada pokémon pode aprender e o que tem equipado (máx. 4).

Aprendíveis = golpes por nível até o nível atual (como um Move Reminder
livre) + golpes de TM que a espécie aceita E cujo TM está na mochila.
"""
from __future__ import annotations

from . import api

MAX_GOLPES = 4


def por_nivel(num: int, nivel: int) -> list[str]:
    """Golpes por nível já liberados, na ordem em que são aprendidos."""
    p = api.pokemon(num) or {}
    vistos, fora = set(), []
    for lv, nome in p.get("nivel", []):
        if lv <= nivel and nome not in vistos:
            vistos.add(nome)
            fora.append(nome)
    return fora


def novos_no_nivel(num: int, nivel: int) -> list[str]:
    p = api.pokemon(num) or {}
    antes = set(por_nivel(num, nivel - 1))
    return [nome for lv, nome in p.get("nivel", []) if lv == nivel and nome not in antes]


def aceita_tm(num: int, golpe: str) -> bool:
    return golpe in set((api.pokemon(num) or {}).get("tm", []))


def aprendiveis(num: int, nivel: int, mochila: dict) -> list[dict]:
    fora = [{"id": g, "via": "nivel"} for g in por_nivel(num, nivel)]
    ja = {g["id"] for g in fora}
    for item, qtd in (mochila or {}).items():
        if qtd > 0 and item.startswith("tm-"):
            g = item[3:]
            if g not in ja and aceita_tm(num, g):
                fora.append({"id": g, "via": "tm"})
                ja.add(g)
    return fora


def iniciais(num: int, nivel: int) -> list[str]:
    """Os 4 últimos golpes por nível que já pode ter (como um pokémon selvagem)."""
    return por_nivel(num, nivel)[-MAX_GOLPES:]


def info(nome: str) -> dict:
    return api.golpe(nome) or {"id": nome, "nome": nome.replace("-", " ").title(),
                               "tipo": "normal", "classe": "status", "poder": None,
                               "precisao": None, "pp": 0, "prioridade": 0, "efeito": ""}
