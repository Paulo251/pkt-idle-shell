"""Baixa para o cache tudo o que as Ligas usam (golpes, espécies, sprites)."""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pokeidle import api, golpes
d = json.loads((Path(__file__).parent / "dados" / "ligas.json").read_text())
for k in d["ordem"]:
    r = d["regioes"][k]
    for t in r["ginasios"] + r["elite4"] + [r["campeao"]]:
        api.sprite_treinador(t["sprite"])
        if t.get("tm"):
            api.golpe(t["tm"])
        for p in t["time"]:
            api.pokemon(p["num"]); api.especie(p["num"])
            for g in golpes.iniciais(p["num"], p["nivel"] + 15):
                api.golpe(g)
    for x in r["lendarios"]:
        api.pokemon(x["num"]); api.especie(x["num"])
    print(k, flush=True)
