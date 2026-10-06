#!/usr/bin/env bash
# Push rendered bundles as OCI artifacts.
#
#   REGISTRY=ttl.sh hack/publish.sh          -> ttl.sh/argocd-oci-generator-demo/<bundle>:<tag>
#   REGISTRY=ghcr.io/robinlieb hack/publish.sh  -> ghcr.io/robinlieb/argocd-oci-generator-demo/<bundle>:<tag>

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${ROOT}/dist"
NAMESPACE="argocd-oci-generator-demo"
VERSION="${VERSION:-1.0.0}"
REGISTRY="${REGISTRY:-ttl.sh}"

command -v oras >/dev/null || { echo "oras is required" >&2; exit 1; }
[[ -d "${DIST}" ]] || { echo "nothing to push - run hack/render.sh first" >&2; exit 1; }

TAG="${VERSION}"
GIT_SHA="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

for bundle_dir in "${DIST}"/*/; do
    bundle="$(basename "${bundle_dir}")"
    ref="${REGISTRY}/${NAMESPACE}/${bundle}:${TAG}"

    echo "==> Pushing ${ref}"
    (
        cd "${bundle_dir}" &&
        oras push \
            -a "org.opencontainers.image.title=${bundle} bundle" \
            -a "org.opencontainers.image.description=Pre-rendered Kubernetes manifests: $(yq -r '.components | join(", ")' "${ROOT}/bundles/${bundle}/bundle.yaml")" \
            -a "org.opencontainers.image.version=${VERSION}" \
            -a "org.opencontainers.image.revision=${GIT_SHA}" \
            -a "org.opencontainers.image.created=${CREATED}" \
            -a "org.opencontainers.image.source=https://github.com/robinlieb/argocd-oci-generator-demo" \
            -a "org.opencontainers.image.authors=robinlieb" \
            "${ref}" \
            ".:application/vnd.oci.image.layer.v1.tar+gzip"
    )
done

echo "==> Done. Pushed:"
echo "    REGISTRY=${REGISTRY} VERSION=${VERSION} TAG=${TAG}"
