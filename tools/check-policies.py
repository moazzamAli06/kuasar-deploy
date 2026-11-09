#!/usr/bin/env python3
"""Fails when a rendered manifest breaks a rule: images by digest, non-root, read-only filesystem, limits, no plain Secret."""
import sys, yaml

bad = []
for path in sys.argv[1:]:
    for d in yaml.safe_load_all(open(path)):
        if not d:
            continue
        kind, name = d["kind"], d["metadata"]["name"]
        if kind == "Secret":
            bad.append(f"{path}: plain Secret {name} (use SealedSecret)")
        spec = None
        if kind in ("Deployment", "StatefulSet"):
            spec = d["spec"]["template"]["spec"]
        elif kind == "Job":
            spec = d["spec"]["template"]["spec"]
        if not spec:
            continue
        if not spec.get("securityContext", {}).get("runAsNonRoot"):
            bad.append(f"{path}: {kind}/{name} not runAsNonRoot")
        for c in spec["containers"]:
            img = c["image"]
            if img.startswith("docker.io/") and "@sha256:" not in img:
                bad.append(f"{path}: {kind}/{name} image not pinned by digest: {img}")
            if ":latest" in img or ":dev" in img:
                bad.append(f"{path}: {kind}/{name} uses a floating tag: {img}")
            sc = c.get("securityContext", {})
            if not sc.get("readOnlyRootFilesystem") or sc.get("allowPrivilegeEscalation") is not False:
                bad.append(f"{path}: {kind}/{name} container {c['name']} not hardened")
            if "limits" not in c.get("resources", {}):
                bad.append(f"{path}: {kind}/{name} container {c['name']} has no limits")
print("\n".join(bad) or "policies ok")
sys.exit(1 if bad else 0)
