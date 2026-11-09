#!/usr/bin/env python3
"""Copy the image digests of one overlay to another:  promote.py overlays/staging overlays/production"""
import re, sys

src, dst = sys.argv[1:3]
block = re.compile(r"- name: (docker\.io/[^\n]*/kuasar-([\w-]+))\n  newName: ([^\n]*)\n  digest: ([^\n]*)\n")
src_text = open(f"{src}/kustomization.yaml").read()
digests = {m.group(2): (m.group(3), m.group(4)) for m in block.finditer(src_text)}
path = f"{dst}/kustomization.yaml"
text = open(path).read()

def swap(m):
    new_name, digest = digests[m.group(2)]
    return f"- name: {m.group(1)}\n  newName: {new_name}\n  digest: {digest}\n"

text = block.sub(swap, text)
open(path, "w").write(text)
print(f"{path}: {len(digests)} digests copied from {src}")
