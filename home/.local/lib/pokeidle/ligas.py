"""Ginásios, Ligas, level cap, revanches, Hall da Fama e lendários.

Regiões LIVRES: cada uma tem a sua sequência de 8 ginásios e começa do zero.
  cap do desafio = nível do ás do próximo líder (Liga: o ás do Campeão)
  cap de XP      = o MAIOR cap entre as regiões (acima dele a XP vai à reserva)

No save:
  d["liga"][regiao]          {"insignias": [ids], "campeao": n vitórias, "revanches": {id: n}}
  d["liga_inscricao"][reg]   {"puestos": [...], "etapa": 0..4, "pp": {puesto: {golpe: pp}}, "desde"}
  d["hall"]                  [{"regiao", "data", "time": [...]}]
  d["lendarios"][reg][num]   {"capturado", "dia", "tentativas"}
"""
from __future__ import annotations

import json
from datetime import date
from pathlib import Path

from . import api, evolucao

DADOS = Path(__file__).parent / "dados" / "ligas.json"
EVOLUCOES = Path.home() / ".cache" / "pokepalette" / "evoluciones.json"
_dados: dict | None = None
_evos: dict | None = None

REVANCHE_GINASIO = 5     # revanche de ginásio: ás do Campeão + 5
REVANCHE_LIGA = 10       # Liga depois do 1º título: +10 níveis
LENDARIO_TENTATIVAS = 3
LENDARIO_CHANCE = 0.05


def dados() -> dict:
    global _dados
    if _dados is None:
        _dados = json.loads(DADOS.read_text())
    return _dados


def regioes() -> list[str]:
    return dados()["ordem"]


def regiao(reg: str) -> dict:
    r = dados()["regioes"].get(reg)
    if not r:
        raise SystemExit(f"região desconhecida: {reg}")
    return r


def ace(t: dict) -> int:
    return max(p["nivel"] for p in t["time"])


def prog(d: dict, reg: str) -> dict:
    p = d.setdefault("liga", {}).setdefault(reg, {})
    p.setdefault("insignias", [])
    p.setdefault("campeao", 0)
    p.setdefault("revanches", {})
    return p


def treinador(reg: str, tid: str) -> dict | None:
    r = regiao(reg)
    for t in r["ginasios"] + r["elite4"] + [r["campeao"]]:
        if t["id"] == tid:
            return t
    return None


# --- níveis das revanches -----------------------------------------------------------
def _evoluir_por_nivel(num: int, nivel: int) -> int:
    global _evos
    if _evos is None:
        try:
            _evos = {int(k): v for k, v in json.loads(EVOLUCOES.read_text()).items()}
        except (OSError, ValueError):
            _evos = {}
    for _ in range(3):
        # treinadores não têm amizade: essas evoluções valem a partir do nível 30
        ramos = [r for r in _evos.get(num, [])
                 if (evolucao.regra(r)["tipo"] == "nivel" and (evolucao.regra(r)["nivel"] or 101) <= nivel)
                 or (evolucao.regra(r)["tipo"] == "amizade" and nivel >= 30)]
        if len(ramos) != 1:
            break
        num = ramos[0]["a"]
    return num


def escalar(t: dict, alvo_ace: int) -> list[dict]:
    """O mesmo time, com o ás no nível 'alvo_ace' e o resto na mesma proporção."""
    fator = alvo_ace / max(1, ace(t))
    fora = []
    for p in t["time"]:
        lv = max(2, min(100, round(p["nivel"] * fator)))
        fora.append({"num": _evoluir_por_nivel(p["num"], lv), "nivel": lv})
    return fora


def ace_campeao(reg: str) -> int:
    return ace(regiao(reg)["campeao"])


def liga_bonus(d: dict, reg: str) -> int:
    return REVANCHE_LIGA if prog(d, reg)["campeao"] > 0 else 0


# --- o que vem agora ----------------------------------------------------------------
def proximo_ginasio(d: dict, reg: str) -> dict | None:
    feitos = set(prog(d, reg)["insignias"])
    return next((g for g in regiao(reg)["ginasios"] if g["id"] not in feitos), None)


def desafio(d: dict, reg: str, alvo: str) -> dict:
    """-> {"tipo", "treinador", "time", "cap", "etapa"} ou SystemExit com o motivo.
    alvo: id do líder | "liga" | "revanche:<id>"."""
    r = regiao(reg)
    p = prog(d, reg)
    if alvo == "liga":
        if len(p["insignias"]) < 8:
            raise SystemExit(f"A Liga de {r['nome']} exige as 8 insígnias ({len(p['insignias'])}/8).")
        insc = (d.get("liga_inscricao") or {}).get(reg)
        if not insc:
            raise SystemExit("Inscreva uma equipe na Liga antes de desafiar.")
        etapa = int(insc.get("etapa", 0))
        t = r["elite4"][etapa] if etapa < 4 else r["campeao"]
        bonus = liga_bonus(d, reg)
        time_ = escalar(t, ace(t) + bonus) if bonus else [dict(x) for x in t["time"]]
        return {"tipo": "liga", "treinador": t, "time": time_,
                "cap": ace_campeao(reg) + bonus, "etapa": etapa}
    if alvo.startswith("revanche:"):
        tid = alvo.split(":", 1)[1]
        if p["campeao"] <= 0:
            raise SystemExit("Revanches só depois de vencer a Liga da região.")
        t = treinador(reg, tid)
        if not t or t not in r["ginasios"]:
            raise SystemExit("Esse líder não existe nessa região.")
        alvo_ace = min(100, ace_campeao(reg) + REVANCHE_GINASIO)
        return {"tipo": "revanche", "treinador": t, "time": escalar(t, alvo_ace),
                "cap": alvo_ace, "etapa": None}
    t = treinador(reg, alvo)
    if not t or t not in r["ginasios"]:
        raise SystemExit("Esse líder não existe nessa região.")
    if t["id"] in p["insignias"]:
        raise SystemExit(f"Você já tem a {t['insignia']}. Revanches abrem depois da Liga.")
    prox = proximo_ginasio(d, reg)
    if prox is None or prox["id"] != t["id"]:
        raise SystemExit(f"Antes, vença {prox['nome']} em {prox['cidade']}." if prox else "Sem ginásios.")
    return {"tipo": "ginasio", "treinador": t, "time": [dict(x) for x in t["time"]],
            "cap": ace(t), "etapa": None}


def cap_regiao(d: dict, reg: str) -> int:
    """O cap do próximo desafio da região."""
    p = prog(d, reg)
    if p["campeao"] > 0:
        return min(100, ace_campeao(reg) + REVANCHE_LIGA)
    g = proximo_ginasio(d, reg)
    return ace(g) if g else ace_campeao(reg)


def cap_xp(d: dict) -> int:
    return max(cap_regiao(d, reg) for reg in regioes())


def premio(t: dict, time_: list, tipo: str) -> int:
    base = int(t.get("premio_base", 100)) * max(p["nivel"] for p in time_)
    return int(base * 1.5) if tipo == "revanche" else base


# --- lendários ----------------------------------------------------------------------
def lendario(d: dict, num: int) -> tuple[str, dict] | None:
    for reg in regioes():
        for x in regiao(reg)["lendarios"]:
            if x["num"] == num:
                return reg, x
    return None


def estado_lendario(d: dict, reg: str, num: int) -> dict:
    e = d.setdefault("lendarios", {}).setdefault(reg, {}).setdefault(
        str(num), {"capturado": False, "dia": "", "tentativas": 0})
    if e["dia"] != date.today().isoformat():
        e["dia"], e["tentativas"] = date.today().isoformat(), 0
    return e


# --- para a interface ------------------------------------------------------------------
def resumo(d: dict, nome_de, gif_de) -> dict:
    """Tudo o que a aba Liga desenha (não grava nada)."""
    fora = {"ordem": regioes(), "regioes": {}, "cap_xp": cap_xp(d)}
    insc_todas = d.get("liga_inscricao") or {}
    for reg in regioes():
        r, p = regiao(reg), prog(d, reg)
        prox = proximo_ginasio(d, reg)

        def tr(t, extra=None):
            x = {"id": t["id"], "nome": t["nome"], "cidade": t.get("cidade", ""), "tipo": t["tipo"],
                 "insignia": t.get("insignia", ""), "ace": ace(t),
                 "sprite": api.sprite_treinador(t["sprite"], baixar=False),
                 "time": [{"num": q["num"], "nivel": q["nivel"], "nome": nome_de(q["num"]),
                           "gif": gif_de(q["num"])} for q in t["time"]]}
            if t.get("tm"):
                x["tm"] = t["tm"]
                x["tm_nome"] = (api.golpe(t["tm"], baixar=False) or {}).get("nome", t["tm"])
            x.update(extra or {})
            return x

        gins = [tr(g, {"vencido": g["id"] in p["insignias"],
                       "proximo": bool(prox and prox["id"] == g["id"])}) for g in r["ginasios"]]
        insc = insc_todas.get(reg)
        bonus = liga_bonus(d, reg)
        lend = []
        for x in r["lendarios"]:
            e = (d.get("lendarios") or {}).get(reg, {}).get(str(x["num"])) or {}
            hoje_ = e.get("dia") == date.today().isoformat()
            lend.append({"num": x["num"], "nivel": x["nivel"], "nome": nome_de(x["num"]),
                         "gif": gif_de(x["num"]), "capturado": bool(e.get("capturado")),
                         "restantes": LENDARIO_TENTATIVAS - (e.get("tentativas", 0) if hoje_ else 0)})
        fora["regioes"][reg] = {
            "nome": r["nome"], "jogo": r.get("jogo", ""), "selos": bool(r.get("selos")),
            "insignias": len(p["insignias"]), "campeao": p["campeao"],
            "cap": cap_regiao(d, reg), "ginasios": gins,
            "liga": {"liberada": len(p["insignias"]) >= 8, "cap": ace_campeao(reg) + bonus,
                     "elite4": [tr(t) for t in r["elite4"]], "campeao": tr(r["campeao"]),
                     "inscricao": insc, "etapa": (insc or {}).get("etapa", 0)},
            "lendarios": lend if p["campeao"] > 0 else [],
            "revanche_ace": min(100, ace_campeao(reg) + REVANCHE_GINASIO) if p["campeao"] > 0 else None,
        }
    fora["hall"] = d.get("hall", [])
    return fora
