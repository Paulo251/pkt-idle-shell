"""Pokécenter: o tempo internado é proporcional ao HP perdido.

  ferido   -> 2 h × (HP perdido / HP máx), mínimo 5 min
  derrotado (HP 0) -> 24 h
Lá dentro o pokémon não ganha XP nem luta. Não dá para tirar antes.
"""
from __future__ import annotations

import time

MAX_FERIDO = 2 * 3600
DERROTADO = 24 * 3600
MINIMO = 5 * 60


def duracao(hp: int, hp_max: int) -> int:
    if hp <= 0:
        return DERROTADO
    perdido = max(0, hp_max - hp)
    if perdido == 0:
        return 0
    seg = MAX_FERIDO * perdido / max(1, hp_max)
    return max(MINIMO, int(round(seg / 60)) * 60)


def internado(m: dict) -> bool:
    return bool(m.get("centro")) and time.time() < m["centro"].get("sai", 0)


def restante(m: dict) -> int:
    c = m.get("centro")
    return max(0, int(c["sai"] - time.time())) if c else 0


def internar(m: dict, hp_max: int) -> int:
    seg = duracao(int(m.get("hp", hp_max)), hp_max)
    if seg <= 0:
        return 0
    m["centro"] = {"entrou": time.time(), "sai": time.time() + seg,
                   "derrotado": int(m.get("hp", 1)) <= 0}
    return seg


def formatar(seg: int) -> str:
    h, r = divmod(int(seg), 3600)
    m = r // 60
    return f"{h}h{m:02d}" if h else f"{m} min"
