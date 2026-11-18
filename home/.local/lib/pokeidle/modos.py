"""Modos de batalha: avulsos, Battle Tower, Survival, Random, Boss Rush e Desafio diário.

No save:
  d["bp"]         pontos de batalha
  d["corrida"]    sequência em andamento (Tower, Survival, Boss Rush)
  d["recordes"]   {"tower:singles": {"melhor", "data", "time"}, ...}
  d["desafio"]    treinador avulso esperando resposta
  d["diario"]     {"dia", "feito"}
"""
from __future__ import annotations

import json
import random
from datetime import date
from pathlib import Path

from . import api, golpes, itens, ligas
from . import batalha as motor

DADOS = Path(__file__).parent / "dados" / "treinadores.json"
DEX = Path.home() / ".cache" / "pokepalette" / "dex"
EVOLUCOES = Path.home() / ".cache" / "pokepalette" / "evoluciones.json"

NIVEL = 50
MAX_ESPECIE = 649                # até a Gen 5 há sprite animado de costas
LENDARIOS = {144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251, *range(377, 387), *range(480, 495),
             *range(638, 650)}
TAM_TOWER = {"singles": 3, "duplas": 4}
SERIE = 7
SURVIVAL_CURA_A_CADA = 5
SURVIVAL_CURA = 0.30
DESAFIOS_DIA = 4
DESAFIO_CHANCE = 1 / 60
DESAFIO_DURA = 180
PREMIO_NIVEL = 30                # dinheiro por luta = nível do ás × isso
REGRAS = [("trio", "Só os 3 primeiros do time"), ("sem_itens", "Sem itens"),
          ("monotipo", "Inimigos de um só tipo"), ("duplas", "Batalha em duplas")]
TITULOS = {"tower": "Battle Tower", "survival": "Survival", "random": "Random Battle",
           "bossrush": "Boss Rush", "diario": "Desafio diário", "avulso": "Treinador avulso"}
TMS_LOJA = {"earthquake": 80, "ice-beam": 70, "thunderbolt": 70, "flamethrower": 70, "surf": 70,
            "psychic": 70, "energy-ball": 60, "shadow-ball": 60, "dragon-pulse": 60, "sludge-bomb": 60,
            "flash-cannon": 60, "dark-pulse": 60, "brick-break": 50, "rock-slide": 50, "air-slash": 50,
            "bug-buzz": 60, "dazzling-gleam": 60}

_dados: dict | None = None
_pool: list | None = None


def dados() -> dict:
    global _dados
    if _dados is None:
        _dados = json.loads(DADOS.read_text())
    return _dados


def _bst(num: int) -> int:
    try:
        return sum(json.loads((DEX / f"{num}.json").read_text()).get("stats") or [])
    except (OSError, ValueError):
        return 0


def pool() -> list[dict]:
    """Formas finais, sem lendários: [{"num", "bst", "tipos"}]."""
    global _pool
    if _pool is None:
        origens = {int(k) for k in json.loads(EVOLUCOES.read_text())}
        _pool = [{"num": n, "bst": _bst(n), "tipos": motor.tipos_da_especie(n)}
                 for n in range(1, MAX_ESPECIE + 1) if n not in origens and n not in LENDARIOS]
        _pool = [x for x in _pool if x["bst"] > 0]
    return _pool


def sortear_especies(rng, n: int, lo: int, hi: int, tipos: list | None = None) -> list[int]:
    base = [x for x in pool() if lo <= x["bst"] <= hi and (not tipos or set(tipos) & set(x["tipos"]))]
    if len(base) < n:
        base = [x for x in pool() if not tipos or set(tipos) & set(x["tipos"])] or pool()
    return [x["num"] for x in rng.sample(base, min(n, len(base)))]


def moveset(num: int, nivel: int, rng) -> list[str]:
    """Até 4 golpes: ataques fortes de tipos diferentes e, às vezes, um de status."""
    ts = motor.tipos_da_especie(num)
    danos, status = [], []
    for g in golpes.por_nivel(num, nivel):
        i = api.golpe(g) or {}
        if i.get("classe") in ("physical", "special") and (i.get("poder") or 0) >= 40 and i.get("categoria") != "ohko":
            nota = i["poder"] * (i.get("precisao") or 100) / 100 * (1.5 if i["tipo"] in ts else 1)
            danos.append((nota + rng.random() * 10, g, i["tipo"]))
        elif i.get("classe") == "status" and i.get("categoria") in ("ailment", "net-good-stats", "heal"):
            status.append(g)
    danos.sort(reverse=True)
    fora, vistos = [], set()
    for _, g, t in danos:
        if t not in vistos:
            fora.append(g)
            vistos.add(t)
        if len(fora) == 3:
            break
    if status and rng.random() < 0.6:
        fora.append(rng.choice(status))
    for _, g, _t in danos:
        if len(fora) >= 4:
            break
        if g not in fora:
            fora.append(g)
    return fora[:4] or golpes.iniciais(num, nivel)


def lutador(x: dict, nome: str, rng, puesto=None) -> dict:
    api.pokemon(x["num"])
    api.especie(x["num"])
    gs = x.get("golpes") or moveset(x["num"], x["nivel"], rng)
    for g in gs:
        api.golpe(g)
    return motor.novo_lutador(x["num"], x["nivel"], "Seria", nome, gs,
                              genero=motor.sortear_genero(x["num"]), puesto=puesto)


def _time(rng, n: int, nivel: int, lo: int, hi: int, tipos=None) -> list[dict]:
    return [{"num": num, "nivel": nivel} for num in sortear_especies(rng, n, lo, hi, tipos)]


def _classe(rng) -> dict:
    return rng.choice(dados()["classes"])


def _nome_treinador(rng, c: dict) -> str:
    return f"{c['nome']} {rng.choice(dados()['nomes'])}"


def faixa(vitorias: int) -> tuple[int, int]:
    return min(500, 400 + vitorias * 5), min(600, 470 + vitorias * 8)


# --- progresso ------------------------------------------------------------------------
def premio(ace: int) -> int:
    return ace * PREMIO_NIVEL


def diario_regra(dia: date | None = None) -> tuple[str, str]:
    return REGRAS[(dia or date.today()).toordinal() % len(REGRAS)]


def _bloqueio(d: dict) -> str:
    if d.get("liga_inscricao"):
        return "Com uma equipe inscrita na Liga, os modos ficam fechados."
    return ""


def adversario(d: dict, modo: str, formato: str, regiao: str | None = None) -> dict:
    """O próximo oponente do modo. -> {"treinador", "sprite", "time", ...}."""
    c = d.get("corrida") or {}
    v = int(c.get("vitorias", 0))
    rng = random.Random()
    if modo == "tower":
        chefe = next((x for x in dados()["chefes"] if x["vitoria"] == v + 1), None)
        n = TAM_TOWER[formato]
        if chefe:
            return {"treinador": chefe["nome"], "sprite": chefe["sprite"], "chefe": True,
                    "time": _time(rng, n, NIVEL, 520, 600)}
        cl = _classe(rng)
        lo, hi = faixa(v)
        return {"treinador": _nome_treinador(rng, cl), "sprite": cl["sprite"], "time": _time(rng, n, NIVEL, lo, hi)}
    if modo == "survival":
        cl = _classe(rng)
        lo, hi = faixa(v)
        nivel = min(70, NIVEL + v // 4)
        return {"treinador": _nome_treinador(rng, cl), "sprite": cl["sprite"],
                "time": _time(rng, 3 if v < 10 else 4, nivel, lo, hi)}
    if modo == "random":
        cl = _classe(rng)
        return {"treinador": _nome_treinador(rng, cl), "sprite": cl["sprite"], "time": _time(rng, 6, NIVEL, 400, 600)}
    if modo == "bossrush":
        t = ligas.regiao(regiao)["ginasios"][v]
        return {"treinador": f"Líder {t['nome']}", "sprite": t["sprite"], "time": ligas.escalar(t, NIVEL)}
    if modo == "diario":
        hoje = date.today()
        rng = random.Random(hoje.isoformat())
        regra = diario_regra(hoje)[0]
        cl = _classe(rng)
        tipo = [rng.choice(motor.tipos_da_especie(rng.choice(pool())["num"]))] if regra == "monotipo" else None
        return {"treinador": _nome_treinador(rng, cl), "sprite": cl["sprite"], "regra": regra,
                "time": _time(rng, 4 if regra == "duplas" else 3, NIVEL, 450, 560, tipo)}
    raise SystemExit("modo desconhecido")


def validar(d: dict, modo: str, formato: str, regiao: str | None) -> None:
    motivo = _bloqueio(d)
    if motivo:
        raise SystemExit(motivo)
    if modo not in TITULOS or modo == "avulso":
        raise SystemExit("Esse modo não existe.")
    if formato not in ("singles", "duplas"):
        raise SystemExit("Formato inválido.")
    if modo in ("survival", "bossrush") and formato != "singles":
        raise SystemExit("Esse modo é só em singles.")
    if modo == "bossrush":
        if regiao not in ligas.regioes():
            raise SystemExit("Escolha uma região.")
        if len(ligas.prog(d, regiao)["insignias"]) < 8:
            raise SystemExit("O Boss Rush exige as 8 insígnias da região.")
    if modo == "diario" and (d.get("diario") or {}).get("dia") == date.today().isoformat() \
            and d["diario"].get("feito"):
        raise SystemExit("O Desafio de hoje já foi vencido. Volte amanhã!")


def time_resumo(b: dict) -> list[dict]:
    return [{"num": l["num"], "nome": l["nome"], "shiny": bool(l.get("shiny"))} for l in b["meu"]]


def _recorde(d: dict, chave: str, valor: int, b: dict) -> bool:
    r = d.setdefault("recordes", {})
    if valor <= int((r.get(chave) or {}).get("melhor", 0)):
        return False
    r[chave] = {"melhor": valor, "data": date.today().isoformat(), "time": time_resumo(b)}
    return True


def vitoria(d: dict, b: dict) -> dict:
    """Registra a vitória. -> {"bp", "continua", "sequencia", "item", "recorde", "cura"}."""
    modo, formato = b["modo"], b["formato"]
    fora = {"bp": 0, "continua": False, "sequencia": 1, "item": None, "recorde": False, "cura": False}
    c = d.get("corrida")
    if c:
        c["vitorias"] = v = int(c["vitorias"]) + 1
        fora["sequencia"] = v
        fora["continua"] = True
        if modo == "tower":
            if v % SERIE == 0:
                fora["bp"] += min(10, 3 + v // SERIE)
            if any(x["vitoria"] == v for x in dados()["chefes"]):
                fora["bp"] += 10
        elif modo == "survival" and v % SURVIVAL_CURA_A_CADA == 0:
            fora["bp"] += 2 + v // SURVIVAL_CURA_A_CADA
            fora["cura"] = True
        elif modo == "bossrush" and v >= 8:
            fora["continua"] = False
            fora["bp"] += 10
            feitos = d.setdefault("bossrush_ok", [])
            if c["regiao"] not in feitos:
                feitos.append(c["regiao"])
                fora["bp"] += 20
        c["bp"] = int(c.get("bp", 0)) + fora["bp"]
        fora["recorde"] = _recorde(d, f"{modo}:{formato}", v, b)
    elif modo == "random":
        d["random_seq"] = fora["sequencia"] = int(d.get("random_seq", 0)) + 1
        fora["bp"] = 2
        fora["recorde"] = _recorde(d, f"random:{formato}", d["random_seq"], b)
    elif modo == "diario":
        rng = random.Random(date.today().isoformat() + "premio")
        fora["bp"] = 5
        fora["item"] = rng.choice([k for k, x in itens.CATALOGO.items() if x["cat"] == "evolucao"])
        d["diario"] = {"dia": date.today().isoformat(), "feito": True}
        t = int((d.get("recordes", {}).get("diario:total") or {}).get("melhor", 0)) + 1
        _recorde(d, "diario:total", t, b)
    elif modo == "avulso":
        t = int((d.get("recordes", {}).get("avulso:total") or {}).get("melhor", 0)) + 1
        _recorde(d, "avulso:total", t, b)
    d["bp"] = int(d.get("bp", 0)) + fora["bp"]
    return fora


# --- loja ---------------------------------------------------------------------------
def loja() -> dict[str, int]:
    fora = {k: (40 if k == "linking-cord" else 30) for k, x in itens.CATALOGO.items() if x["cat"] == "evolucao"}
    fora.update({f"tm-{k}": v for k, v in TMS_LOJA.items()})
    return fora


def resumo(d: dict) -> dict:
    hoje = date.today().isoformat()
    regra = diario_regra()
    c = d.get("corrida")
    return {
        "bp": int(d.get("bp", 0)), "corrida": dict(c, titulo=TITULOS[c["modo"]]) if c else None,
        "bloqueio": _bloqueio(d), "recordes": d.get("recordes", {}), "titulos": TITULOS,
        "loja": [dict(itens.info(k), bp=v) for k, v in loja().items()],
        "diario": {"regra": regra[0], "texto": regra[1],
                   "feito": bool((d.get("diario") or {}).get("dia") == hoje and d["diario"].get("feito"))},
        "regioes": [{"id": r, "nome": ligas.regiao(r)["nome"], "insignias": len(ligas.prog(d, r)["insignias"]),
                     "vencido": r in d.get("bossrush_ok", [])} for r in ligas.regioes()],
    }
