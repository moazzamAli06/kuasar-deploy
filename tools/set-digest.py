#!/usr/bin/env python3
"""Set the image digest of one service in an overlay.

  set-digest.py overlays/staging identity docker.io/<org>/kuasar-identity@sha256:<digest>

Edits only the block between "BEGIN images" and "END images" in <overlay>/kustomization.yaml.
"""
import re, sys

overlay, name, ref = sys.argv[1:4]
m = re.fullmatch(r"((?:docker\.io/[\w.-]+|localhost:\d+)/kuasar-[\w-]+)@(sha256:[0-9a-f]{64})", ref)
if not m or not m.group(1).endswith("kuasar-" + name):
    sys.exit(f"bad image reference for {name}: {ref}")
new_name, digest = m.groups()
path = f"{overlay}/kustomization.yaml"
text = open(path).read()
pattern = re.compile(
    r"(- name: docker\.io/[^\n]*/kuasar-" + re.escape(name) + r"\n)  newName: [^\n]*\n  digest: [^\n]*\n")
if not pattern.search(text):
    sys.exit(f"{name} not found in {path}")
text = pattern.sub(lambda mm: f"{mm.group(1)}  newName: {new_name}\n  digest: {digest}\n", text, count=1)
open(path, "w").write(text)
print(f"{path}: {name} -> {digest[:19]}")
