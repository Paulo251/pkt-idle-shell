"""Regras de evolução como nos jogos.

evoluciones.json (do poke-evolutions) traz em cada ramo {"a", "nivel", "como"}:
  'nivel' / 'level-up'  -> automática ao chegar no nível (como sempre foi)
  '*-stone'             -> só usando a pedra (qualquer nível)
  'intercambio'         -> só com o Cabo de Conexão (linking-cord)
  amizade (AMIZADE)     -> botão Evoluir com amizade alta, às vezes com horário
  o resto (maçãs, moedas, 3 críticos...) -> automática no nível 36
"""
from __future__ import annotations

import os
from datetime import datetime

NIVEL_ESTRANHO = 36
CABO = "linking-cord"

AMIZADE_MIN = 160
HORA_DIA = 6             # dia: das 6h às 20h (o mesmo critério da Dusk Ball)
HORA_NOITE = 20

# Espécie de destino -> condição extra. O evoluciones.json não guarda a amizade
# (esses ramos vêm só como 'level-up'), por isso a tabela fixa.
AMIZADE: dict[int, str] = {
    169: "", 242: "", 25: "", 35: "", 39: "", 176: "", 183: "", 428: "", 143: "",
    528: "", 542: "", 773: "",
    196: "dia", 315: "dia", 448: "dia",
    197: "noite", 358: "noite", 873: "noite",
    700: "fada",
}


def regra(ramo: dict) -> dict:
    como = ramo.get("como") or "nivel"
    if como == "level-up" and ramo.get("a") in AMIZADE:
        return {"tipo": "amizade", "nivel": None, "item": None, "condicao": AMIZADE[ramo["a"]]}
    if como in ("nivel", "level-up"):
        return {"tipo": "nivel", "nivel": int(ramo.get("nivel") or 1), "item": None}
    if como.endswith("-stone"):
        return {"tipo": "item", "nivel": None, "item": como}
    if como == "intercambio":
        return {"tipo": "item", "nivel": None, "item": CABO}
    return {"tipo": "nivel", "nivel": NIVEL_ESTRANHO, "item": None}


def automaticas(ramos: list, nivel: int) -> list:
    """Ramos que acontecem sozinhos neste nível."""
    return [r for r in ramos if regra(r)["tipo"] == "nivel" and nivel >= regra(r)["nivel"]]


def por_item(ramos: list, item: str) -> list:
    return [r for r in ramos if regra(r)["item"] == item]


def hora_agora() -> int:
    """A hora local. POKE_HORA existe só para os testes."""
    return int(os.environ.get("POKE_HORA") or datetime.now().hour)


def de_dia(hora: int) -> bool:
    return HORA_DIA <= hora < HORA_NOITE


def motivo_amizade(ramo: dict, amizade: int, hora: int, tipos_golpes) -> str:
    """Por que esse ramo de amizade não pode acontecer agora ('' = pode)."""
    if amizade < AMIZADE_MIN:
        return f"amizade {amizade}/{AMIZADE_MIN}"
    cond = regra(ramo).get("condicao")
    if cond == "dia" and not de_dia(hora):
        return "só de dia"
    if cond == "noite" and de_dia(hora):
        return "só de noite"
    if cond == "fada" and "fairy" not in tipos_golpes:
        return "precisa de golpe Fada"
    return ""


def disponiveis(ramos: list, nivel: int, amizade: int, hora: int, tipos_golpes) -> list:
    """Tudo o que o botão Evoluir pode fazer agora."""
    return [r for r in ramos
            if r in automaticas(ramos, nivel)
            or (regra(r)["tipo"] == "amizade" and not motivo_amizade(r, amizade, hora, tipos_golpes))]


def texto_condicao(ramo: dict) -> str:
    """'amizade alta, de noite', para a interface."""
    cond = regra(ramo).get("condicao")
    extra = {"dia": ", de dia", "noite": ", de noite", "fada": " e golpe Fada"}.get(cond or "", "")
    return "amizade alta" + extra
