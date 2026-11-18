"""Motor de batalha por turnos (singles e duplas, troca livre), no estilo dos jogos.

Escopo ("essencial completo"):
  dano Gen 5+, STAB, tabela de tipos, crítico, precisão/evasão, prioridade,
  PP, estágios −6..+6, dreno/recuo/cura, multi-hit, flinch, confusão e os
  5 status (queimado, envenenado/tóxico, paralisado, dormindo, congelado).
Fora: clima, habilidades, itens segurados, golpes de dois turnos.

O estado é um dict comum (vai inteiro para o save). Cada turno devolve uma
lista de EVENTOS que a interface toca em sequência:
  {"t": "txt", "txt"}               texto da caixa de mensagens
  {"t": "hp", "lado", "pos", "hp", "hp_max", "golpe": bool}   barra de HP (golpe: pisca o sprite)
  {"t": "status", "lado", "pos", "status"}
  {"t": "entra", "lado", "pos", "i"}  pokémon entrando (i = índice na lista do lado)
  {"t": "desmaia", "lado", "pos"}
  {"t": "pede_troca", "pos"}        o jogador escolhe quem entra nessa posição
  {"t": "fim", "resultado"}         "vitoria" | "derrota"
Só para a animação (não mudam nada na luta):
  {"t": "inicio"}                   abertura da batalha
  {"t": "golpe", "lado", "pos", "tipo", "classe", "alvos": [[lado, pos], ...]}
  {"t": "efeito", "lado", "pos", "mult", "critico"}   resultado no alvo
  {"t": "estagio", "lado", "pos", "est"}              atributos alterados
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from . import api, stats, tipos

TIPOS_JSON = Path.home() / ".cache" / "pokepalette" / "tipos.json"
_tipos_cache: dict | None = None

ESTAGIO = {"attack": "atk", "defense": "def", "special-attack": "spa",
           "special-defense": "spd", "speed": "spe", "accuracy": "acc", "evasion": "eva"}
NOME_ESTAGIO = {"atk": "Ataque", "def": "Defesa", "spa": "Ataque Especial",
                "spd": "Defesa Especial", "spe": "Velocidade", "acc": "Precisão", "eva": "Evasão"}
IDX = {"atk": 1, "def": 2, "spa": 3, "spd": 4, "spe": 5}
AILMENT = {"paralysis": "par", "burn": "brn", "poison": "psn", "sleep": "slp", "freeze": "frz"}
STATUS_TXT = {"par": "foi paralisado", "brn": "foi queimado", "psn": "foi envenenado",
              "tox": "foi gravemente envenenado", "slp": "adormeceu", "frz": "foi congelado"}
IMUNE = {"brn": {"fire"}, "par": {"electric"}, "frz": {"ice"},
         "psn": {"poison", "steel"}, "tox": {"poison", "steel"}}
# golpes sem 'poder' mas que causam dano
DANO_FIXO = {"seismic-toss": "nivel", "night-shade": "nivel", "dragon-rage": 40,
             "sonic-boom": 20, "super-fang": "metade", "nature-s-madness": "metade",
             "endeavor": "metade", "psywave": "nivel"}
# campo 'alvo' da PokeAPI
ALVO_PROPRIO = {"user", "users-field"}
ALVO_AREA = {"all-opponents", "all-other-pokemon", "all-pokemon"}
DANO_AREA = 0.75


def tipos_da_especie(num: int) -> list[str]:
    global _tipos_cache
    if _tipos_cache is None:
        try:
            _tipos_cache = json.loads(TIPOS_JSON.read_text()).get("pokemon", {})
        except (OSError, ValueError):
            _tipos_cache = {}
    return _tipos_cache.get(str(num)) or ["normal"]


def sortear_genero(num: int) -> str:
    gr = api.especie(num, baixar=False).get("gender_rate", 4)
    if gr is None or gr < 0:
        return "-"
    return "f" if random.random() < gr / 8 else "m"


# --- lutadores ------------------------------------------------------------------
def novo_lutador(num: int, nivel: int, natureza: str, nome: str, golpes_ids: list[str],
                 hp: int | None = None, shiny: bool = False, genero: str = "-",
                 puesto: int | None = None, pp: dict | None = None) -> dict:
    st = stats.calcular(num, nivel, natureza)
    valores = st["valores"] if st else [nivel * 3 + 10] + [nivel * 2 + 5] * 5
    gs = []
    for g in golpes_ids[:4]:
        inf = api.golpe(g) or {}
        mx = int(inf.get("pp") or 10)
        gs.append({"id": g, "pp": int((pp or {}).get(g, mx)), "pp_max": mx})
    if not gs:
        gs = [{"id": "tackle", "pp": 35, "pp_max": 35}]
    return {"num": num, "nome": nome, "nivel": nivel, "natureza": natureza,
            "tipos": tipos_da_especie(num), "stats": valores,
            "hp_max": valores[0], "hp": valores[0] if hp is None else max(0, min(valores[0], int(hp))),
            "golpes": gs, "status": None, "sono": 0, "tox_n": 0,
            "shiny": shiny, "genero": genero, "puesto": puesto}


def _vol() -> dict:
    return {"est": {k: 0 for k in NOME_ESTAGIO}, "confuso": 0, "recuou": False, "repete": {}}


# --- posições em campo --------------------------------------------------------------
def _lut(b: dict, lado: str, pos: int) -> dict | None:
    i = b["campo"][lado][pos]
    return None if i is None else b[lado][i]


def _vivo(b: dict, lado: str, pos: int) -> bool:
    l = _lut(b, lado, pos)
    return bool(l and l["hp"] > 0)


def _posicoes(b: dict, lado: str) -> list[int]:
    return [p for p in range(b["n"]) if _vivo(b, lado, p)]


def _banco(b: dict, lado: str) -> list[int]:
    return [i for i, l in enumerate(b[lado]) if l["hp"] > 0 and i not in b["campo"][lado]]


def _outro(lado: str) -> str:
    return "ini" if lado == "meu" else "meu"


def _nome(b: dict, lado: str, pos: int) -> str:
    return _lut(b, lado, pos)["nome"] + (" inimigo" if lado == "ini" else "")


def _entra(b: dict, lado: str, pos: int) -> dict:
    i = b["campo"][lado][pos]
    lut = b[lado][i]
    return {"t": "entra", "lado": lado, "pos": pos, "i": i, "hp": lut["hp"], "hp_max": lut["hp_max"],
            "status": lut["status"]}


def normalizar(b: dict | None) -> dict | None:
    """Converte uma batalha salva antes das duplas."""
    if not b or "campo" in b:
        return b
    b["formato"], b["n"] = "singles", 1
    b["campo"] = {"meu": [b.pop("a_meu", 0)], "ini": [b.pop("a_ini", 0)]}
    b["vol"] = {"meu": [b.pop("v_meu", None) or _vol()], "ini": [b.pop("v_ini", None) or _vol()]}
    b["pendentes"] = [0] if b.get("aguardando_troca") else []
    return b


def nova(meu: list[dict], inimigos: list[dict], extra: dict, potions: int = 0) -> tuple[dict, list]:
    """Cria a batalha. 'meu' já vem só com quem pode lutar."""
    b = dict(extra)
    n = 2 if extra.get("formato") == "duplas" else 1
    b.update({"formato": "duplas" if n == 2 else "singles", "n": n, "meu": meu, "ini": inimigos,
              "campo": {"meu": [i if i < len(meu) else None for i in range(n)],
                        "ini": [i if i < len(inimigos) else None for i in range(n)]},
              "vol": {"meu": [_vol() for _ in range(n)], "ini": [_vol() for _ in range(n)]},
              "potions": potions, "turno": 0, "participou": {}, "xp": {}, "pendentes": [],
              "aguardando_troca": False, "fim": None})
    meus = [i for i in b["campo"]["meu"] if i is not None]
    for i in b["campo"]["ini"]:
        if i is not None:
            b["participou"][str(i)] = list(meus)
    quem = b.get("treinador", "O treinador")
    ev = [{"t": "inicio"}, {"t": "txt", "txt": f"{quem} quer batalhar!"}]
    ev += [_entra(b, "ini", p) for p in _posicoes(b, "ini")]
    ev.append({"t": "txt", "txt": f"{quem} enviou {' e '.join(_lut(b, 'ini', p)['nome'] for p in _posicoes(b, 'ini'))}!"})
    ev += [_entra(b, "meu", p) for p in _posicoes(b, "meu")]
    ev.append({"t": "txt", "txt": f"Vai, {' e '.join(_lut(b, 'meu', p)['nome'] for p in _posicoes(b, 'meu'))}!"})
    ev.append({"t": "txt", "txt": "O que você vai fazer?"})
    return b, ev


# --- contas -----------------------------------------------------------------------
def _mult_est(s: int) -> float:
    return (2 + s) / 2 if s >= 0 else 2 / (2 - s)


def _mult_acc(s: int) -> float:
    s = max(-6, min(6, s))
    return (3 + s) / 3 if s >= 0 else 3 / (3 - s)


def _stat(lut: dict, vol: dict, chave: str, critico: bool = False, atacando: bool = True) -> float:
    s = vol["est"][chave]
    if critico:
        s = max(0, s) if atacando else min(0, s)
    v = lut["stats"][IDX[chave]] * _mult_est(s)
    if chave == "spe" and lut["status"] == "par":
        v *= 0.5
    return v


def dano_base(b: dict, lado: str, pos: int, alvo_lado: str, alvo_pos: int, g: dict, critico: bool,
              rnd: float = None, area: bool = False) -> tuple[int, float]:
    """Dano de um acerto do golpe 'g'. -> (dano, efetividade)."""
    a, d = _lut(b, lado, pos), _lut(b, alvo_lado, alvo_pos)
    va, vd = b["vol"][lado][pos], b["vol"][alvo_lado][alvo_pos]
    ef = tipos.efetividade(g["tipo"], d["tipos"])
    fixo = DANO_FIXO.get(g["id"])
    if fixo is not None:
        if ef == 0:
            return 0, 0
        if fixo == "nivel":
            return a["nivel"], 1
        if fixo == "metade":
            return max(1, d["hp"] // 2), 1
        return int(fixo), 1
    poder = g.get("poder") or 60
    fisico = g["classe"] == "physical"
    A = _stat(a, va, "atk" if fisico else "spa", critico, True)
    D = _stat(d, vd, "def" if fisico else "spd", critico, False)
    base = ((2 * a["nivel"] / 5 + 2) * poder * A / max(1, D)) / 50 + 2
    mult = (rnd if rnd is not None else random.uniform(0.85, 1.0))
    if area:
        mult *= DANO_AREA
    if g["tipo"] in a["tipos"]:
        mult *= 1.5
    mult *= ef
    if critico:
        mult *= 1.5
    if fisico and a["status"] == "brn":
        mult *= 0.5
    dano = int(base * mult)
    if ef > 0:
        dano = max(1, dano)
    return dano, ef


def _alvos(b: dict, lado: str, pos: int, g: dict, alvo: tuple | None) -> list[tuple[str, int]]:
    """Quem o golpe atinge agora (alvo desmaiado redireciona para o outro oponente)."""
    t = g.get("alvo")
    outro = _outro(lado)
    ops = [(outro, p) for p in _posicoes(b, outro)]
    parceiro = [(lado, p) for p in _posicoes(b, lado) if p != pos]
    if t in ALVO_PROPRIO:
        return [(lado, pos)]
    if t == "user-and-allies":
        return [(lado, pos)] + parceiro
    if t in ("ally", "all-allies"):
        return parceiro
    if t == "user-or-ally":
        return [alvo] if alvo in parceiro else [(lado, pos)]
    if t == "all-opponents":
        return ops
    if t in ("all-other-pokemon", "all-pokemon"):
        return ops + parceiro
    if t == "random-opponent":
        return [random.choice(ops)] if ops else []
    if alvo and alvo != (lado, pos) and _vivo(b, alvo[0], alvo[1]):
        return [alvo]
    return ops[:1]


# --- efeitos ------------------------------------------------------------------------
def _hp_ev(b: dict, lado: str, pos: int, golpe: bool = False) -> dict:
    lut = _lut(b, lado, pos)
    return {"t": "hp", "lado": lado, "pos": pos, "hp": lut["hp"], "hp_max": lut["hp_max"], "golpe": golpe}


def _aplicar_status(b: dict, lado: str, pos: int, st: str, ev: list, avisar_falha: bool) -> None:
    lut = _lut(b, lado, pos)
    if st == "confusion":
        v = b["vol"][lado][pos]
        if v["confuso"]:
            if avisar_falha:
                ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} já está confuso!"})
            return
        v["confuso"] = random.randint(2, 5)
        ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} ficou confuso!"})
        return
    if lut["status"] or lut["hp"] <= 0 or set(lut["tipos"]) & IMUNE.get(st, set()):
        if avisar_falha:
            ev.append({"t": "txt", "txt": "Mas falhou!"})
        return
    lut["status"] = st
    if st == "slp":
        lut["sono"] = random.randint(1, 3)
    if st == "tox":
        lut["tox_n"] = 1
    ev.append({"t": "status", "lado": lado, "pos": pos, "status": st})
    ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} {STATUS_TXT[st]}!"})


def _mudar_estagios(b: dict, lado: str, pos: int, mudancas: list, ev: list) -> None:
    v = b["vol"][lado][pos]
    for c in mudancas:
        k = ESTAGIO.get(c["stat"])
        if not k:
            continue
        antes = v["est"][k]
        v["est"][k] = max(-6, min(6, antes + c["change"]))
        nome = f"{NOME_ESTAGIO[k]} de {_nome(b, lado, pos)}"
        if v["est"][k] == antes:
            ev.append({"t": "txt", "txt": f"{nome} não pode {'subir' if c['change'] > 0 else 'cair'} mais!"})
        elif c["change"] > 0:
            ev.append({"t": "txt", "txt": f"{nome} subiu{' muito' if c['change'] >= 2 else ''}!"})
        else:
            ev.append({"t": "txt", "txt": f"{nome} caiu{' muito' if c['change'] <= -2 else ''}!"})
    ev.append({"t": "estagio", "lado": lado, "pos": pos, "est": dict(v["est"])})


def _chance(p: int) -> bool:
    return random.random() * 100 < (p or 100)


def _efeito_status(b: dict, lado: str, pos: int, al: str, ap: int, g: dict, cat: str, ev: list) -> None:
    d = _lut(b, al, ap)
    if cat == "ailment":
        st = AILMENT.get(g.get("ailment"), g.get("ailment"))
        if g["id"] == "toxic":
            st = "tox"
        if st in ("par", "brn", "psn", "slp", "frz", "tox", "confusion"):
            if st == "par" and g["tipo"] == "electric" and "ground" in d["tipos"]:
                ev.append({"t": "txt", "txt": f"Não afeta {_nome(b, al, ap)}…"})
                return
            _aplicar_status(b, al, ap, st, ev, True)
        else:
            ev.append({"t": "txt", "txt": "Mas não aconteceu nada!"})
    elif cat == "net-good-stats":
        _mudar_estagios(b, al, ap, g.get("stat_changes", []), ev)
    elif cat == "heal":
        if d["hp"] >= d["hp_max"]:
            ev.append({"t": "txt", "txt": f"O HP de {_nome(b, al, ap)} está cheio!"})
        else:
            d["hp"] = min(d["hp_max"], d["hp"] + max(1, d["hp_max"] * (g.get("healing") or 50) // 100))
            ev.append(_hp_ev(b, al, ap))
            ev.append({"t": "txt", "txt": f"{_nome(b, al, ap)} recuperou HP!"})
    elif cat == "swagger":
        _mudar_estagios(b, al, ap, g.get("stat_changes", []), ev)
        _aplicar_status(b, al, ap, "confusion", ev, False)
    elif g["id"] == "rest":
        d["hp"] = d["hp_max"]
        d["status"] = "slp"
        d["sono"] = 2
        ev.append(_hp_ev(b, al, ap))
        ev.append({"t": "status", "lado": al, "pos": ap, "status": "slp"})
        ev.append({"t": "txt", "txt": f"{_nome(b, al, ap)} dormiu e recuperou a saúde!"})
    else:
        ev.append({"t": "txt", "txt": "Mas não aconteceu nada!"})


def _acertar(b: dict, lado: str, pos: int, al: str, ap: int, g: dict, cat: str, area: bool,
             agiram: set, ev: list) -> int:
    """Um golpe de dano em UM alvo. -> dano total causado."""
    a, d = _lut(b, lado, pos), _lut(b, al, ap)
    if cat == "ohko":
        if tipos.efetividade(g["tipo"], d["tipos"]) == 0 or a["nivel"] < d["nivel"] or random.random() >= 0.3:
            ev.append({"t": "txt", "txt": f"O ataque de {_nome(b, lado, pos)} errou!"})
            return 0
        d["hp"] = 0
        ev.append(_hp_ev(b, al, ap, True))
        ev.append({"t": "txt", "txt": "Nocaute em um golpe!"})
        return 0
    hits = 1
    if g.get("min_hits") and g.get("max_hits"):
        lo, hi = g["min_hits"], g["max_hits"]
        hits = random.choices([2, 3, 4, 5], [35, 35, 15, 15])[0] if (lo, hi) == (2, 5) else random.randint(lo, hi)
    total, ef, n, houve_critico = 0, 1.0, 0, False
    for _ in range(hits):
        if d["hp"] <= 0:
            break
        estagio_crit = min(3, (g.get("crit_rate") or 0))
        critico = random.random() < (1 / 24, 1 / 8, 1 / 2, 1)[estagio_crit]
        dano, ef = dano_base(b, lado, pos, al, ap, g, critico, area=area)
        if ef == 0:
            ev.append({"t": "efeito", "lado": al, "pos": ap, "mult": 0, "critico": False})
            ev.append({"t": "txt", "txt": f"Não afeta {_nome(b, al, ap)}…"})
            return 0
        houve_critico = houve_critico or critico
        dano = min(dano, d["hp"])
        d["hp"] -= dano
        total += dano
        n += 1
        ev.append(_hp_ev(b, al, ap, True))
        if critico:
            ev.append({"t": "txt", "txt": "Um golpe crítico!"})
    ev.append({"t": "efeito", "lado": al, "pos": ap, "mult": ef, "critico": houve_critico})
    contra = f" contra {_nome(b, al, ap)}" if b["n"] > 1 else ""
    if ef > 1:
        ev.append({"t": "txt", "txt": f"É super efetivo{contra}!"})
    elif 0 < ef < 1:
        ev.append({"t": "txt", "txt": f"Não é muito efetivo{contra}…"})
    if hits > 1:
        ev.append({"t": "txt", "txt": f"Acertou {n} vez{'es' if n > 1 else ''}!"})
    if d["status"] == "frz" and g["tipo"] == "fire" and d["hp"] > 0:
        d["status"] = None
        ev.append({"t": "status", "lado": al, "pos": ap, "status": None})
        ev.append({"t": "txt", "txt": f"{_nome(b, al, ap)} descongelou!"})
    if d["hp"] > 0:
        if cat == "damage+ailment":
            st = "tox" if g["id"] == "poison-fang" else AILMENT.get(g.get("ailment"), g.get("ailment"))
            if st in ("par", "brn", "psn", "slp", "frz", "tox", "confusion") and _chance(g.get("ailment_chance")):
                _aplicar_status(b, al, ap, st, ev, False)
        elif cat == "damage+lower" and _chance(g.get("stat_chance")):
            _mudar_estagios(b, al, ap, g.get("stat_changes", []), ev)
        if (g.get("flinch_chance") or 0) and (al, ap) not in agiram and random.random() * 100 < g["flinch_chance"]:
            b["vol"][al][ap]["recuou"] = True
    return total


def _usar_golpe(b: dict, lado: str, pos: int, slot: int, alvo: tuple | None, agiram: set, ev: list) -> None:
    a = _lut(b, lado, pos)
    va = b["vol"][lado][pos]
    gs = a["golpes"][slot] if slot is not None and 0 <= slot < len(a["golpes"]) else None
    if gs is None or gs["pp"] <= 0:
        # sem PP em nada: Struggle
        g = {"id": "struggle", "nome": "Struggle", "tipo": "normal", "classe": "physical",
             "poder": 50, "precisao": None, "categoria": "damage", "drain": -25}
    else:
        g = dict(api.golpe(gs["id"]) or {"id": gs["id"], "nome": gs["id"], "tipo": "normal",
                                         "classe": "physical", "poder": 40, "precisao": 100})
        gs["pp"] -= 1
    atingidos = _alvos(b, lado, pos, g, alvo)
    ev.append({"t": "golpe", "lado": lado, "pos": pos, "tipo": g["tipo"], "classe": g["classe"],
               "alvos": [list(x) for x in atingidos]})
    ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} usou {g['nome']}!"})
    va["repete"][g["id"]] = va["repete"].get(g["id"], 0) + 1

    cat = g.get("categoria") or ("damage" if g["classe"] != "status" else "unique")
    if not atingidos:
        ev.append({"t": "txt", "txt": "Mas falhou!"})
        return
    area = len(atingidos) > 1 and g["classe"] != "status"
    total = 0
    for al, ap in atingidos:
        if not _vivo(b, al, ap):
            continue
        # precisão (golpes no próprio usuário nunca erram)
        if g.get("precisao") and (al, ap) != (lado, pos) and cat != "ohko":
            acc = g["precisao"] * _mult_acc(va["est"]["acc"] - b["vol"][al][ap]["est"]["eva"])
            if random.random() * 100 >= acc:
                ev.append({"t": "txt", "txt": f"O ataque de {_nome(b, lado, pos)} errou!"})
                continue
        if g["classe"] == "status":
            _efeito_status(b, lado, pos, al, ap, g, cat, ev)
        else:
            total += _acertar(b, lado, pos, al, ap, g, cat, area, agiram, ev)
    if g["classe"] == "status":
        return

    # dreno (+) ou recuo (−)
    dr = g.get("drain") or 0
    if dr > 0 and total > 0 and a["hp"] < a["hp_max"]:
        a["hp"] = min(a["hp_max"], a["hp"] + max(1, total * dr // 100))
        ev.append(_hp_ev(b, lado, pos))
        ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} drenou energia!"})
    elif dr < 0 and total > 0:
        rec = max(1, (a["hp_max"] if g["id"] == "struggle" else total) * -dr // 100)
        a["hp"] = max(0, a["hp"] - rec)
        ev.append(_hp_ev(b, lado, pos, True))
        ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} sofreu o recuo!"})
    if cat == "damage+raise" and a["hp"] > 0 and total > 0 and _chance(g.get("stat_chance")):
        _mudar_estagios(b, lado, pos, g.get("stat_changes", []), ev)


def _pode_agir(b: dict, lado: str, pos: int, ev: list) -> bool:
    lut, v = _lut(b, lado, pos), b["vol"][lado][pos]
    nome = _nome(b, lado, pos)
    if v["recuou"]:
        v["recuou"] = False
        ev.append({"t": "txt", "txt": f"{nome} recuou e não pôde atacar!"})
        return False
    if lut["status"] == "slp":
        lut["sono"] -= 1
        if lut["sono"] > 0:
            ev.append({"t": "txt", "txt": f"{nome} está dormindo."})
            return False
        lut["status"] = None
        ev.append({"t": "status", "lado": lado, "pos": pos, "status": None})
        ev.append({"t": "txt", "txt": f"{nome} acordou!"})
    if lut["status"] == "frz":
        if random.random() < 0.2:
            lut["status"] = None
            ev.append({"t": "status", "lado": lado, "pos": pos, "status": None})
            ev.append({"t": "txt", "txt": f"{nome} descongelou!"})
        else:
            ev.append({"t": "txt", "txt": f"{nome} está congelado!"})
            return False
    if v["confuso"]:
        v["confuso"] -= 1
        if v["confuso"] == 0:
            ev.append({"t": "txt", "txt": f"{nome} não está mais confuso!"})
        else:
            ev.append({"t": "txt", "txt": f"{nome} está confuso!"})
            if random.random() < 1 / 3:
                A = _stat(lut, v, "atk")
                D = _stat(lut, v, "def")
                dano = max(1, int(((2 * lut["nivel"] / 5 + 2) * 40 * A / max(1, D)) / 50 + 2))
                lut["hp"] = max(0, lut["hp"] - dano)
                ev.append(_hp_ev(b, lado, pos, True))
                ev.append({"t": "txt", "txt": "Ele se atingiu na confusão!"})
                return False
    if lut["status"] == "par" and random.random() < 0.25:
        ev.append({"t": "txt", "txt": f"{nome} está paralisado! Não consegue se mover!"})
        return False
    return True


def _fim_de_turno(b: dict, lado: str, pos: int, ev: list) -> None:
    if not _vivo(b, lado, pos):
        return
    lut = _lut(b, lado, pos)
    if lut["status"] == "brn":
        perda, txt = max(1, lut["hp_max"] // 16), "sofreu com a queimadura"
    elif lut["status"] == "psn":
        perda, txt = max(1, lut["hp_max"] // 8), "sofreu com o veneno"
    elif lut["status"] == "tox":
        perda, txt = max(1, lut["hp_max"] * lut["tox_n"] // 16), "sofreu com o veneno"
        lut["tox_n"] = min(15, lut["tox_n"] + 1)
    else:
        return
    lut["hp"] = max(0, lut["hp"] - perda)
    ev.append(_hp_ev(b, lado, pos, True))
    ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} {txt}!"})


# --- IA -------------------------------------------------------------------------------
def _estimar(b: dict, pos: int, al: str, ap: int, g: dict, area: bool) -> float:
    """Dano esperado da IA nesse alvo, com bônus para quem ela consegue derrubar."""
    if not (g.get("poder") or g.get("id") in DANO_FIXO):
        return 1
    dano, _ = dano_base(b, "ini", pos, al, ap, g, False, 0.925, area)
    d = _lut(b, al, ap)
    return min(dano, d["hp"]) * (g.get("precisao") or 100) / 100 * (1.3 if dano >= d["hp"] else 1)


def acao_ia(b: dict, pos: int, foco: int | None = None) -> dict:
    """foco: posição que o parceiro já deve derrubar neste turno."""
    a = _lut(b, "ini", pos)
    alvos = _posicoes(b, "meu")
    if a["hp"] < a["hp_max"] * 0.25 and b.get("potions", 0) > 0 and a["hp"] > 0:
        return {"tipo": "potion", "pos": pos}
    if not alvos:
        return {"tipo": "nada", "pos": pos}
    parceiro = [p for p in _posicoes(b, "ini") if p != pos]
    opcoes = []
    for i, gs in enumerate(a["golpes"]):
        if gs["pp"] <= 0:
            continue
        g = api.golpe(gs["id"], baixar=False) or {"id": gs["id"], "classe": "status"}
        cat = g.get("categoria", "")
        t = g.get("alvo")
        alvo, mata = None, False
        if g.get("classe") != "status" and t in ALVO_AREA:
            area = len(alvos) + (len(parceiro) if t != "all-opponents" else 0) > 1
            score = sum(_estimar(b, pos, "meu", p, g, area) for p in alvos)
            if t != "all-opponents":
                score -= sum(_estimar(b, pos, "ini", p, g, area) * 1.5 for p in parceiro)
        elif g.get("classe") != "status":
            nota = []
            for p in alvos:
                s = _estimar(b, pos, "meu", p, g, False)
                nota.append((s * (0.6 if p == foco and len(alvos) > 1 else 1), p))
            score, p = max(nota)
            alvo = ("meu", p)
            mata = dano_base(b, "ini", pos, "meu", p, g, False, 0.925)[0] >= _lut(b, "meu", p)["hp"] \
                if g.get("poder") else False
        else:
            ja = b["vol"]["ini"][pos]["repete"].get(g.get("id"), 0)
            score = 0
            d = _lut(b, "meu", alvos[0])
            if ja < 2:
                livres = [p for p in alvos if not _lut(b, "meu", p)["status"]]
                if cat == "ailment" and g.get("ailment") != "confusion" and livres:
                    alvo = ("meu", livres[0])
                    score = _lut(b, "meu", livres[0])["hp_max"] * 0.25
                elif cat == "ailment" and g.get("ailment") == "confusion":
                    soltos = [p for p in alvos if not b["vol"]["meu"][p]["confuso"]]
                    if soltos:
                        alvo = ("meu", soltos[0])
                        score = _lut(b, "meu", soltos[0])["hp_max"] * 0.12
                elif cat == "net-good-stats":
                    alvo = ("meu", alvos[0])
                    score = d["hp_max"] * 0.15
                elif cat == "heal" and a["hp"] < a["hp_max"] * 0.5:
                    score = d["hp_max"] * 0.3
        opcoes.append((score, i, alvo, mata))
    if not opcoes:
        return {"tipo": "golpe", "pos": pos, "slot": -1, "alvo": ("meu", alvos[0])}
    opcoes.sort(key=lambda o: (o[0], o[1]), reverse=True)
    x = opcoes[0]
    if random.random() >= 0.8 and len(opcoes) > 1:
        x = random.choices(opcoes, [max(1, o[0]) for o in opcoes])[0]
    return {"tipo": "golpe", "pos": pos, "slot": x[1], "alvo": x[2], "mata": x[3]}


# --- XP -------------------------------------------------------------------------------
def _dar_xp(b: dict, i_ini: int, ev: list) -> None:
    """Um inimigo caiu: XP para quem lutou contra ele e ainda está de pé."""
    if b.get("sem_xp"):
        return
    ini = b["ini"][i_ini]
    base = api.especie(ini["num"], baixar=False).get("base_exp", 100)
    total = int(base * (b.get("xp_nivel") or ini["nivel"]) / 7 * 1.5)
    quem = [i for i in b["participou"].get(str(i_ini), []) if b["meu"][i]["hp"] > 0]
    if not quem:
        return
    parte = max(1, total // len(quem))
    for i in quem:
        p = str(b["meu"][i]["puesto"])
        b["xp"][p] = b["xp"].get(p, 0) + parte
        ev.append({"t": "txt", "txt": f"{b['meu'][i]['nome']} ganhou {parte} pontos de experiência!"})


def _vivos(b: dict, lado: str) -> list[int]:
    return [i for i, l in enumerate(b[lado]) if l["hp"] > 0]


def _checar_desmaios(b: dict, ev: list) -> None:
    """Depois de cada golpe: desmaios e XP."""
    if b["fim"]:
        return
    for lado in ("ini", "meu"):
        for pos in range(b["n"]):
            l = _lut(b, lado, pos)
            if l and l["hp"] <= 0 and not l.get("_caiu"):
                l["_caiu"] = True
                ev.append({"t": "desmaia", "lado": lado, "pos": pos})
                ev.append({"t": "txt", "txt": f"{_nome(b, lado, pos)} desmaiou!"})
                if lado == "ini":
                    _dar_xp(b, b["campo"]["ini"][pos], ev)


def _entrar_ini(b: dict, pos: int, i: int, ev: list) -> None:
    b["campo"]["ini"][pos] = i
    b["vol"]["ini"][pos] = _vol()
    b["participou"][str(i)] = [x for x in b["campo"]["meu"] if x is not None and b["meu"][x]["hp"] > 0]
    ev.append(_entra(b, "ini", pos))
    ev.append({"t": "txt", "txt": f"{b.get('treinador', 'O treinador')} enviou {b['ini'][i]['nome']}!"})


def _entrar_meu(b: dict, pos: int, i: int, ev: list) -> None:
    b["campo"]["meu"][pos] = i
    b["vol"]["meu"][pos] = _vol()
    for x in b["campo"]["ini"]:
        if x is not None and b["ini"][x]["hp"] > 0:
            lst = b["participou"].setdefault(str(x), [])
            if i not in lst:
                lst.append(i)
    ev.append(_entra(b, "meu", pos))
    ev.append({"t": "txt", "txt": f"Vai, {b['meu'][i]['nome']}!"})


def _depois_do_turno(b: dict, ev: list) -> None:
    if not _vivos(b, "ini"):
        b["fim"] = "vitoria"
        ev.append({"t": "txt", "txt": f"Você derrotou {b.get('treinador', 'o treinador')}!"})
        ev.append({"t": "fim", "resultado": "vitoria"})
        return
    if not _vivos(b, "meu"):
        b["fim"] = "derrota"
        ev.append({"t": "txt", "txt": "Você não tem mais pokémon que possam lutar…"})
        ev.append({"t": "fim", "resultado": "derrota"})
        return
    for pos in range(b["n"]):
        if not _vivo(b, "ini", pos):
            banco = _banco(b, "ini")
            if banco:
                _entrar_ini(b, pos, banco[0], ev)
            else:
                b["campo"]["ini"][pos] = None
    caidos = [p for p in range(b["n"]) if b["campo"]["meu"][p] is not None and not _vivo(b, "meu", p)]
    vagas = len(_banco(b, "meu"))
    b["pendentes"] = caidos[:vagas]
    for p in caidos[vagas:]:
        b["campo"]["meu"][p] = None
    if b["pendentes"]:
        b["aguardando_troca"] = True
        ev.append({"t": "pede_troca", "pos": b["pendentes"][0]})
        ev.append({"t": "txt", "txt": "Escolha o próximo pokémon."})
        return
    ev.append({"t": "txt", "txt": "O que você vai fazer?"})


def _ler_alvo(x) -> tuple | None:
    """'ini:1' ou ['ini', 1] -> ('ini', 1)."""
    if isinstance(x, str) and ":" in x:
        lado, pos = x.split(":", 1)
        return lado, int(pos)
    if isinstance(x, (list, tuple)) and len(x) == 2:
        return x[0], int(x[1])
    return None


def _prioridade(lut: dict, slot) -> int:
    gs = lut["golpes"]
    if slot is None or not (0 <= slot < len(gs)):
        return 0
    return (api.golpe(gs[slot]["id"], baixar=False) or {}).get("prioridade", 0)


def turno(b: dict, acoes) -> list:
    """Ações do jogador (uma por posição viva) -> eventos. Cada ação:
       {"tipo": "golpe", "pos", "slot", "alvo"} | {"tipo": "trocar", "pos", "i"} |
       {"tipo": "item", "pos", "i", "cura", "nome"} | {"tipo": "desistir"}"""
    ev: list = []
    if b["fim"]:
        return ev
    acoes = [acoes] if isinstance(acoes, dict) else list(acoes)
    if any(a["tipo"] == "desistir" for a in acoes):
        b["fim"] = "derrota"
        ev.append({"t": "txt", "txt": "Você desistiu da batalha."})
        ev.append({"t": "fim", "resultado": "derrota"})
        return ev
    if b["aguardando_troca"]:
        a = acoes[0]
        if a["tipo"] != "trocar":
            return [{"t": "txt", "txt": "Escolha quem entra."}]
        i = a["i"]
        if i not in _banco(b, "meu"):
            return [{"t": "txt", "txt": "Esse pokémon não pode lutar."}]
        _entrar_meu(b, b["pendentes"].pop(0), i, ev)
        if b["pendentes"]:
            ev.append({"t": "pede_troca", "pos": b["pendentes"][0]})
            ev.append({"t": "txt", "txt": "Escolha o próximo pokémon."})
            return ev
        b["aguardando_troca"] = False
        ev.append({"t": "txt", "txt": "O que você vai fazer?"})
        return ev

    por_pos = {int(a.get("pos", 0)): a for a in acoes}
    vivas = _posicoes(b, "meu")
    if any(p not in por_pos for p in vivas):
        return [{"t": "txt", "txt": "Escolha o que cada pokémon vai fazer."}]
    destinos = [por_pos[p]["i"] for p in vivas if por_pos[p]["tipo"] == "trocar"]
    if len(set(destinos)) != len(destinos) or any(i not in _banco(b, "meu") for i in destinos):
        return [{"t": "txt", "txt": "Esse pokémon não pode entrar agora."}]

    b["turno"] += 1
    ias, foco = [], None
    for p in _posicoes(b, "ini"):
        x = acao_ia(b, p, foco)
        if x.get("mata") and x.get("alvo"):
            foco = x["alvo"][1]
        ias.append(x)

    # trocas e itens vêm antes de qualquer golpe
    for p in vivas:
        a = por_pos[p]
        if a["tipo"] == "trocar":
            ev.append({"t": "txt", "txt": f"Volte, {_lut(b, 'meu', p)['nome']}!"})
            _entrar_meu(b, p, a["i"], ev)
        elif a["tipo"] == "item":
            alvo = b["meu"][a["i"]]
            alvo["hp"] = min(alvo["hp_max"], alvo["hp"] + int(a["cura"]))
            if a["i"] in b["campo"]["meu"]:
                ev.append(_hp_ev(b, "meu", b["campo"]["meu"].index(a["i"])))
            ev.append({"t": "txt", "txt": f"Você usou {a['nome']} em {alvo['nome']}!"})
    for x in ias:
        if x["tipo"] == "potion" and b.get("potions", 0) > 0:
            b["potions"] -= 1
            lut = _lut(b, "ini", x["pos"])
            lut["hp"] = min(lut["hp_max"], lut["hp"] + 120)
            ev.append(_hp_ev(b, "ini", x["pos"]))
            ev.append({"t": "txt", "txt": f"{b.get('treinador', 'O treinador')} usou uma Hyper Potion!"})

    # golpes: prioridade, depois velocidade, empate no sorteio
    fila = []
    for p in vivas:
        a = por_pos[p]
        if a["tipo"] == "golpe":
            fila.append(("meu", p, a.get("slot"), _ler_alvo(a.get("alvo"))))
    for x in ias:
        if x["tipo"] == "golpe":
            fila.append(("ini", x["pos"], x.get("slot"), x.get("alvo")))
    fila.sort(key=lambda f: (-_prioridade(_lut(b, f[0], f[1]), f[2]),
                             -_stat(_lut(b, f[0], f[1]), b["vol"][f[0]][f[1]], "spe"), random.random()))
    agiram: set = set()
    for lado, pos, slot, alvo in fila:
        if not _vivo(b, lado, pos) or not _posicoes(b, _outro(lado)):
            continue
        if _pode_agir(b, lado, pos, ev):
            _usar_golpe(b, lado, pos, slot, alvo, agiram, ev)
        agiram.add((lado, pos))
        _checar_desmaios(b, ev)
    for lado in ("meu", "ini"):
        for pos in range(b["n"]):
            _fim_de_turno(b, lado, pos, ev)
    _checar_desmaios(b, ev)
    for lado in ("meu", "ini"):
        for v in b["vol"][lado]:
            v["recuou"] = False
    _depois_do_turno(b, ev)
    return ev
