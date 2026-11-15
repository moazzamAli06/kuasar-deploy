#!/usr/bin/env python3
"""Fails when a rendered manifest breaks a rule: every image pinned by digest, non-root, hardened containers,
resource requests and limits, no plain Secret. Covers Deployment, StatefulSet, DaemonSet, Job, CronJob and RabbitmqCluster.

  kubectl kustomize overlays/staging > /tmp/staging.yaml && python3 tools/check-policies.py /tmp/staging.yaml
Images from localhost:<port>/ (developer registry, overlays/local-registry) are exempt from the digest rule only if they still carry a digest.
"""
import sys
import yaml

POD_KINDS = {"Deployment", "StatefulSet", "DaemonSet", "Job"}
bad = []


def pod_spec(d):
    kind = d["kind"]
    if kind == "CronJob":
        return d["spec"]["jobTemplate"]["spec"]["template"]["spec"]
    if kind in POD_KINDS:
        return d["spec"]["template"]["spec"]
    return None


def check_image(where, img):
    if "@sha256:" not in img:
        bad.append(f"{where}: image not pinned by digest: {img}")
    if ":latest" in img or ":dev" in img:
        bad.append(f"{where}: uses a floating tag: {img}")


for path in sys.argv[1:]:
    with open(path) as fh:
        docs = list(yaml.safe_load_all(fh))
    for d in docs:
        if not d:
            continue
        kind, name = d.get("kind"), d.get("metadata", {}).get("name", "?")
        where = f"{path}: {kind}/{name}"
        if kind == "Secret":
            bad.append(f"{where}: plain Secret (use SealedSecret or an external secret store)")
        if kind == "RabbitmqCluster" and d.get("spec", {}).get("image"):
            check_image(where, d["spec"]["image"])
        spec = pod_spec(d)
        if not spec:
            continue
        if not spec.get("securityContext", {}).get("runAsNonRoot"):
            bad.append(f"{where}: not runAsNonRoot")
        for c in spec.get("containers", []) + spec.get("initContainers", []):
            check_image(f"{where} container {c['name']}", c["image"])
            sc = c.get("securityContext", {})
            if not sc.get("readOnlyRootFilesystem") or sc.get("allowPrivilegeEscalation") is not False:
                bad.append(f"{where} container {c['name']}: not hardened")
            res = c.get("resources") or {}
            if "limits" not in res:
                bad.append(f"{where} container {c['name']}: no limits")
            if "requests" not in res:
                bad.append(f"{where} container {c['name']}: no requests")
print("\n".join(bad) or "policies ok")
sys.exit(1 if bad else 0)
