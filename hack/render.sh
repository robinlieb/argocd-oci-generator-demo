#!/usr/bin/env bash
# Render every bundle defined in bundles/ into dist/.
#
# Output layout (this is what the Argo CD OCI directory generator discovers):
#   dist/<bundle>/components/<component>/*.yaml

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${ROOT}/dist"

command -v helm >/dev/null || { echo "helm is required" >&2; exit 1; }
command -v yq >/dev/null || { echo "yq is required" >&2; exit 1; }

rm -rf "${DIST}"
mkdir -p "${DIST}"

for bundle_dir in "${ROOT}"/bundles/*/; do
    bundle="$(basename "${bundle_dir}")"
    bundle_file="${bundle_dir}/bundle.yaml"

    echo "==> Bundle: ${bundle}"
    for component in $(yq -r '.components[]' "${bundle_file}"); do
        chart_dir="${ROOT}/components/${component}"
        out_dir="${DIST}/${bundle}/components/${component}"

        [[ -f "${chart_dir}/Chart.yaml" ]] || { echo "missing chart: ${chart_dir}" >&2; exit 1; }

        echo "    -> ${component}"
        helm dependency update "${chart_dir}" >/dev/null
        mkdir -p "${out_dir}"
        helm template "${component}" "${chart_dir}" \
            --namespace "${component}" \
            --include-crds > "${out_dir}/manifest.yaml"
    done
done

echo "==> Rendered:"
find "${DIST}" -type f | sort
