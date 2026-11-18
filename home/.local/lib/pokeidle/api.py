"""Cache da PokeAPI (https://pokeapi.co) para o PokéIdle.

Tudo é baixado SOB DEMANDA e guardado compacto em ~/.cache/pokeidle/:
  pokemon/<n>.json   {"vg": version group usado, "nivel": [[nível, golpe], ...], "tm": [golpe, ...]}
  golpes/<nome>.json {"nome", "tipo", "classe", "poder", "precisao", "pp", "prioridade", "efeito"}
  itens/<nome>.png   sprite oficial do item

Sem rede nada quebra: quem pede recebe None/{} e a interface diz que ainda
não baixou. Nunca baixa a mesma coisa duas vezes.
"""
from __future__ import annotations

import json
import urllib.request
from pathlib import Path

BASE = "https://pokeapi.co/api/v2"
SPRITE_ITEM = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/{}.png"
CACHE = Path.home() / ".cache" / "pokeidle"
UA = {"User-Agent": "pokeidle/1.0 (+pkt-idle-shell)"}

# Do mais novo para o mais antigo. Ficam de fora os jogos com movesets
# esquisitos (Legends, Let's Go, Colosseum/XD, Champions).
VERSION_GROUPS = [
    "scarlet-violet", "sword-shield", "brilliant-diamond-shining-pearl",
    "ultra-sun-ultra-moon", "sun-moon", "omega-ruby-alpha-sapphire", "x-y",
    "black-2-white-2", "black-white", "heartgold-soulsilver", "platinum",
    "diamond-pearl", "emerald", "firered-leafgreen", "ruby-sapphire",
    "crystal", "gold-silver", "yellow", "red-blue",
]


def _get(url: str, timeout: int = 20) -> bytes | None:
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
            return r.read()
    except Exception:
        return None


def _salvar(destino: Path, dados: bytes) -> None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    tmp = destino.with_suffix(destino.suffix + ".tmp")
    tmp.write_bytes(dados)
    tmp.replace(destino)


def _ler(destino: Path) -> dict | None:
    try:
        return json.loads(destino.read_text())
    except (OSError, ValueError):
        return None


# --- pokémon: golpes que aprende -------------------------------------------
def pokemon(num: int, baixar: bool = True) -> dict | None:
    destino = CACHE / "pokemon" / f"{num}.json"
    d = _ler(destino)
    if d is not None or not baixar:
        return d
    cru = _get(f"{BASE}/pokemon/{num}")
    if not cru:
        return None
    try:
        p = json.loads(cru)
    except ValueError:
        return None
    por_vg: dict[str, dict] = {}
    for m in p.get("moves", []):
        nome = m["move"]["name"]
        for v in m["version_group_details"]:
            vg = v["version_group"]["name"]
            met = v["move_learn_method"]["name"]
            g = por_vg.setdefault(vg, {"nivel": [], "tm": []})
            if met == "level-up":
                g["nivel"].append([int(v["level_learned_at"]), nome])
            elif met == "machine":
                g["tm"].append(nome)
    escolhido = next((vg for vg in VERSION_GROUPS if por_vg.get(vg, {}).get("nivel")), None)
    if escolhido is None and por_vg:
        escolhido = max(por_vg, key=lambda k: len(por_vg[k]["nivel"]))
    g = por_vg.get(escolhido, {"nivel": [], "tm": []})
    # nível 0 nos jogos novos = "ao evoluir"; tratamos como nível 1
    nivel = sorted({(max(1, n), nome) for n, nome in g["nivel"]})
    d = {"vg": escolhido, "nivel": [list(x) for x in nivel], "tm": sorted(set(g["tm"])),
         "stats": [s["base_stat"] for s in p.get("stats", [])]}
    _salvar(destino, json.dumps(d).encode())
    return d


# --- golpes ------------------------------------------------------------------
GOLPE_V = 2      # v2: + meta da batalha (status, estágios, dreno, multi-hit…)


def golpe(nome: str, baixar: bool = True) -> dict | None:
    """Dados do golpe. A v2 traz o que a batalha precisa; um cache v1 continua
    servindo para a interface, e é refeito quando houver rede."""
    destino = CACHE / "golpes" / f"{nome}.json"
    d = _ler(destino)
    if d is not None and (d.get("v") == GOLPE_V or not baixar):
        return d
    if d is None and not baixar:
        return None
    cru = _get(f"{BASE}/move/{nome}")
    if not cru:
        return d
    try:
        m = json.loads(cru)
    except ValueError:
        return d
    rotulo = next((n["name"] for n in m.get("names", []) if n["language"]["name"] == "en"), nome)
    efeito = next((e.get("short_effect", "") for e in m.get("effect_entries", [])
                   if e["language"]["name"] == "en"), "")
    chance = m.get("effect_chance")
    if chance is not None:
        efeito = efeito.replace("$effect_chance", str(chance))
    meta = m.get("meta") or {}
    d = {"v": GOLPE_V, "id": nome, "nome": rotulo, "tipo": (m.get("type") or {}).get("name", "normal"),
         "classe": (m.get("damage_class") or {}).get("name", "status"),
         "poder": m.get("power"), "precisao": m.get("accuracy"), "pp": m.get("pp") or 0,
         "prioridade": m.get("priority") or 0, "efeito": efeito,
         "alvo": (m.get("target") or {}).get("name", "selected-pokemon"),
         "categoria": (meta.get("category") or {}).get("name", ""),
         "ailment": (meta.get("ailment") or {}).get("name", "none"),
         "ailment_chance": meta.get("ailment_chance") or 0,
         "drain": meta.get("drain") or 0, "healing": meta.get("healing") or 0,
         "crit_rate": meta.get("crit_rate") or 0, "flinch_chance": meta.get("flinch_chance") or 0,
         "stat_chance": meta.get("stat_chance") or 0,
         "min_hits": meta.get("min_hits"), "max_hits": meta.get("max_hits"),
         "stat_changes": [{"stat": c["stat"]["name"], "change": c["change"]}
                          for c in m.get("stat_changes", [])]}
    _salvar(destino, json.dumps(d, ensure_ascii=False).encode())
    return d


# --- espécie: o que a batalha e a captura precisam --------------------------
def especie(num: int, baixar: bool = True) -> dict:
    """{base_exp, capture_rate, gender_rate} — gender_rate: -1 sem gênero,
    0..8 = oitavos de chance de ser fêmea. Sem rede, valores médios."""
    destino = CACHE / "especie" / f"{num}.json"
    d = _ler(destino)
    if d is not None or not baixar:
        return d or {"base_exp": 100, "capture_rate": 45, "gender_rate": 4}
    sp, pk = _get(f"{BASE}/pokemon-species/{num}"), _get(f"{BASE}/pokemon/{num}")
    try:
        sp = json.loads(sp) if sp else {}
        pk = json.loads(pk) if pk else {}
    except ValueError:
        sp, pk = {}, {}
    if not sp or not pk:
        return {"base_exp": 100, "capture_rate": 45, "gender_rate": 4}
    d = {"base_exp": pk.get("base_experience") or 100,
         "capture_rate": sp.get("capture_rate") or 45,
         "gender_rate": sp.get("gender_rate", 4)}
    _salvar(destino, json.dumps(d).encode())
    return d


# --- sprites de batalha --------------------------------------------------------
_SPR = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"


def sprite_costas(num: int, shiny: bool = False, baixar: bool = True) -> str:
    """Gif de costas (gen5 animado; senão o do Showdown). '' se não houver."""
    pasta = CACHE / ("costas-shiny" if shiny else "costas")
    destino = pasta / f"{num}.gif"
    if destino.exists():
        return str(destino)
    falhou = pasta / f"{num}.falhou"
    if not baixar or falhou.exists():
        return ""
    sub = "back/shiny" if shiny else "back"
    for url in (f"{_SPR}versions/generation-v/black-white/animated/{sub}/{num}.gif",
                f"{_SPR}other/showdown/{sub}/{num}.gif"):
        cru = _get(url)
        if cru and cru[:3] == b"GIF":
            _salvar(destino, cru)
            return str(destino)
    _salvar(falhou, b"")
    return ""


def sprite_treinador(nomes: list[str], baixar: bool = True) -> str:
    """Sprite do treinador do Pokémon Showdown (tenta cada nome na ordem)."""
    pasta = CACHE / "treinadores"
    for n in nomes:
        destino = pasta / f"{n}.png"
        if destino.exists():
            return str(destino)
    if not baixar or not nomes or (pasta / f"{nomes[0]}.falhou").exists():
        return ""
    for n in nomes:
        cru = _get(f"https://play.pokemonshowdown.com/sprites/trainers/{n}.png")
        if cru and cru[:4] == b"\x89PNG":
            destino = pasta / f"{n}.png"
            _salvar(destino, cru)
            return str(destino)
    _salvar(pasta / f"{nomes[0]}.falhou", b"")
    return ""


# --- itens: só o sprite (nomes, preços e efeitos vêm do catálogo em itens.py)
def sprite_item(nome: str, baixar: bool = True) -> str:
    destino = CACHE / "itens" / f"{nome}.png"
    if destino.exists() or not baixar:
        return str(destino) if destino.exists() else ""
    # TMs usam o sprite genérico do tipo; aqui um só, o "tm-normal"
    remoto = "tm-normal" if nome.startswith("tm-") else nome
    cru = _get(SPRITE_ITEM.format(remoto))
    if not cru:
        return ""
    _salvar(destino, cru)
    return str(destino)
