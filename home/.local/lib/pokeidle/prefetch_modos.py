"""Baixa para o cache o que os modos de batalha usam (golpes, espécies, sprites)."""
import random, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pokeidle import api, golpes, modos
faltam = []
for c in modos.dados()["classes"] + modos.dados()["chefes"]:
    if not api.sprite_treinador(c["sprite"]):
        faltam.append(c["sprite"])
print("sprites sem arquivo:", faltam, flush=True)
for k in modos.loja():
    api.sprite_item(k)
rng = random.Random(1)
for n, x in enumerate(modos.pool()):
    api.pokemon(x["num"]); api.especie(x["num"]); api.sprite_costas(x["num"], False)
    for g in golpes.por_nivel(x["num"], 70):
        api.golpe(g)
    if n % 25 == 0:
        print(n, len(modos.pool()), flush=True)
print("fim", flush=True)
