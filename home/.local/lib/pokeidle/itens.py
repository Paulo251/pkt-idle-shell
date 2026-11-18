"""Catálogo de itens do PokéIdle: nomes, categorias, efeitos, preços e prêmios.

Os nomes internos são os da PokeAPI (para o sprite); o que aparece é 'nome'.
'preco' = vendido na PokéMart; None = só vem de missões (e, na fase 2, da Liga).
"""
from __future__ import annotations

import random
from datetime import datetime

from . import api

CATALOGO: dict[str, dict] = {
    # --- cura ----------------------------------------------------------------
    "potion":       {"nome": "Poção", "cat": "cura", "cura": 20, "preco": 200, "raridade": "comum",
                     "desc": "Recupera 20 HP."},
    "super-potion": {"nome": "Super Poção", "cat": "cura", "cura": 60, "preco": 700, "raridade": "comum",
                     "desc": "Recupera 60 HP."},
    "hyper-potion": {"nome": "Hiper Poção", "cat": "cura", "cura": 120, "preco": 1200, "raridade": "incomum",
                     "desc": "Recupera 120 HP."},
    "max-potion":   {"nome": "Poção Máxima", "cat": "cura", "cura": 9999, "preco": None, "raridade": "raro",
                     "desc": "Recupera todo o HP."},
    "full-restore": {"nome": "Restauração Total", "cat": "cura", "cura": 9999, "preco": None, "raridade": "raro",
                     "desc": "Recupera todo o HP (e, na fase 2, os problemas de status)."},
    # --- bolas ---------------------------------------------------------------
    "poke-ball":   {"nome": "Poké Bola", "cat": "bola", "preco": 200, "raridade": "comum",
                    "desc": "A bola padrão (×1)."},
    "great-ball":  {"nome": "Great Ball", "cat": "bola", "preco": 600, "raridade": "comum",
                    "desc": "Melhor que a Poké Bola (×1,5)."},
    "ultra-ball":  {"nome": "Ultra Ball", "cat": "bola", "preco": 800, "raridade": "incomum",
                    "desc": "Ótima taxa de captura (×2)."},
    "quick-ball":  {"nome": "Quick Ball", "cat": "bola", "preco": 1000, "raridade": "incomum",
                    "desc": "×5 se for a primeira bola jogada no encontro; ×1 depois."},
    "timer-ball":  {"nome": "Timer Ball", "cat": "bola", "preco": 1000, "raridade": "incomum",
                    "desc": "Melhora a cada tentativa: ×1 + 0,3 por bola já jogada (até ×4)."},
    "dusk-ball":   {"nome": "Dusk Ball", "cat": "bola", "preco": 1000, "raridade": "incomum",
                    "desc": "×3 à noite (20h às 6h)."},
    "net-ball":    {"nome": "Net Ball", "cat": "bola", "preco": 1000, "raridade": "incomum",
                    "desc": "×3,5 em pokémon de tipo Água ou Inseto."},
    "nest-ball":   {"nome": "Nest Ball", "cat": "bola", "preco": 1000, "raridade": "incomum",
                    "desc": "Melhor quanto menor o nível do selvagem (até ×4)."},
    "master-ball": {"nome": "Master Ball", "cat": "bola", "preco": None, "raridade": "lendario",
                    "desc": "Captura sem falhar."},
    # --- evolução ------------------------------------------------------------
    "fire-stone":    {"nome": "Pedra de Fogo", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "water-stone":   {"nome": "Pedra da Água", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "thunder-stone": {"nome": "Pedra Trovão", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "leaf-stone":    {"nome": "Pedra da Folha", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "moon-stone":    {"nome": "Pedra da Lua", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "sun-stone":     {"nome": "Pedra do Sol", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "shiny-stone":   {"nome": "Pedra Brilhante", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "dusk-stone":    {"nome": "Pedra Sombria", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "dawn-stone":    {"nome": "Pedra da Alvorada", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "ice-stone":     {"nome": "Pedra de Gelo", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Faz certos pokémon evoluírem."},
    "linking-cord":  {"nome": "Cabo de Conexão", "cat": "evolucao", "preco": None, "raridade": "raro",
                      "desc": "Evolui pokémon que nos jogos evoluem por troca."},
    # --- amizade --------------------------------------------------------------
    "grepa-berry": {"nome": "Fruta Grepa", "cat": "amizade", "amizade": 10, "preco": 800, "raridade": "incomum",
                    "desc": "Aumenta a amizade em 10 pontos."},
    "soothe-bell": {"nome": "Sino Calmante", "cat": "amizade", "sino": True, "preco": 6000, "raridade": "raro",
                    "desc": "Fica com o pokémon para sempre e dobra a amizade que ele ganha."},
    # --- outros --------------------------------------------------------------
    "rare-candy": {"nome": "Rare Candy", "cat": "outros", "preco": None, "raridade": "incomum",
                   "desc": "Sobe 1 nível na hora."},
}

CATEGORIAS = {"cura": "Cura", "bola": "Bolas", "evolucao": "Evolução", "amizade": "Amizade",
              "tm": "TMs", "outros": "Outros"}
TIPOS_NET = {"water", "bug"}


def info(item: str) -> dict:
    if item.startswith("tm-"):
        from . import golpes
        g = golpes.info(item[3:])
        return {"id": item, "nome": f"TM {g['nome']}", "cat": "tm", "preco": None,
                "raridade": "raro", "desc": f"Ensina {g['nome']} ({g['tipo']}).",
                "golpe": item[3:], "sprite": api.sprite_item(item, baixar=False)}
    c = CATALOGO.get(item)
    if not c:
        return {"id": item, "nome": item, "cat": "outros", "preco": None, "raridade": "comum",
                "desc": "", "sprite": ""}
    return dict(c, id=item, sprite=api.sprite_item(item, baixar=False))


def mart() -> list[dict]:
    return [info(k) for k, v in CATALOGO.items() if v["preco"]]


def fator_bola(bola: str, tentativas: int, nivel_selvagem: int, tipos_selvagem: list) -> float:
    if bola == "great-ball":
        return 1.5
    if bola == "ultra-ball":
        return 2.0
    if bola == "quick-ball":
        return 5.0 if tentativas == 0 else 1.0
    if bola == "timer-ball":
        return min(4.0, 1.0 + 0.3 * tentativas)
    if bola == "dusk-ball":
        h = datetime.now().hour
        return 3.0 if h >= 20 or h < 6 else 1.0
    if bola == "net-ball":
        return 3.5 if set(tipos_selvagem) & TIPOS_NET else 1.0
    if bola == "nest-ball":
        return max(1.0, min(4.0, (41 - nivel_selvagem) / 10))
    return 1.0


def sortear_premio(tms_possiveis: list[str]) -> str:
    """Item de prêmio de missão: 70% comum, 25% incomum, 5% raro (Master 0,5%)."""
    r = random.random()
    if r < 0.005:
        return "master-ball"
    if r < 0.05:
        raros = [k for k, v in CATALOGO.items() if v["raridade"] == "raro"]
        if tms_possiveis:
            raros += [f"tm-{random.choice(tms_possiveis)}"] * 3
        return random.choice(raros)
    if r < 0.30:
        return random.choice([k for k, v in CATALOGO.items() if v["raridade"] == "incomum"])
    return random.choice([k for k, v in CATALOGO.items() if v["raridade"] == "comum"])
