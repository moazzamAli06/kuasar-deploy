#!/usr/bin/env python3
"""Fails when local/secrets.sh and secrets/catalog.yaml disagree about which Secrets exist (and about their keys).

Local-only: postgres-init. Not created locally on purpose: cloudflared (no tunnel), dockerhub-pull (public images),
kuasar-sandbox (runs outside the cluster), otel-collector (opt-in component).
"""
import re
import sys
import yaml

root = __file__.rsplit("/tools/", 1)[0] if "/tools/" in __file__ else "."
secrets = yaml.safe_load(open(f"{root}/secrets/catalog.yaml"))["secrets"]
cat = {s["name"]: {k["key"] for k in s["keys"]} for s in secrets}
required = {s["name"]: {k["key"] for k in s["keys"] if k["required"] == "yes"} for s in secrets}
script = open(f"{root}/local/secrets.sh").read()

LOCAL_ONLY = {"postgres-init"}
NOT_LOCAL = {"cloudflared", "dockerhub-pull", "kuasar-sandbox", "otel-collector"}

# names passed to the secret() helper:  secret NAME key=... ; keys are the left side of key=value on the call (logical lines)
logical = re.sub(r"\\\n\s*", " ", script)
created = {}
for m in re.finditer(r"(?m)^secret ([a-z0-9-]+)(.*)$", logical):
    created[m.group(1)] = set(re.findall(r'"([A-Za-z_][A-Za-z0-9_.]*)=', m.group(2)))

bad = []
for n in sorted(set(cat) - NOT_LOCAL - set(created)):
    bad.append(f"catalog has Secret {n} but local/secrets.sh does not create it")
for n in sorted(set(created) - set(cat) - LOCAL_ONLY):
    bad.append(f"local/secrets.sh creates {n}, which is not in secrets/catalog.yaml")
for n, keys in created.items():
    if n in cat and keys:
        for k in sorted(keys - cat[n]):
            bad.append(f"{n}: local/secrets.sh sets key {k} that the catalog does not list")
        for k in sorted(required[n] - keys):
            bad.append(f"{n}: catalog marks key {k} as required but local/secrets.sh does not set it")
print("\n".join(bad) or "local secrets match the catalog")
sys.exit(1 if bad else 0)
