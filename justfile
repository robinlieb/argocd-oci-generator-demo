NAMESPACE := "argocd-oci-generator-demo"
VERSION := "1.0.0"
REGISTRY := "ghcr.io/robinlieb"
ARGOCD_VERSION := "v3.6.0-rc1"
ARGOCD_INSTALL_URL := "https://raw.githubusercontent.com/argoproj/argo-cd/" + ARGOCD_VERSION + "/manifests/install.yaml"
HUB := "kind-argocd-oci-demo-hub"

# Default: show available recipes
default:
    @just --list

# Render all bundles into dist/
render:
    ./hack/render.sh

# Publish artifacts to GHCR
publish VERSION=VERSION:
    REGISTRY={{REGISTRY}} VERSION={{VERSION}} ./hack/publish.sh

# Create hub + 2 spoke clusters, install Argo CD on the hub
up:
    kind create cluster --config hack/kind/hub.yaml --wait 120s
    kind create cluster --config hack/kind/spoke1.yaml --wait 120s
    kind create cluster --config hack/kind/spoke2.yaml --wait 120s
    kubectl config use-context {{HUB}}
    kubectl create namespace argocd
    # server-side apply: some CRDs in install.yaml exceed the annotation size limit
    kubectl apply -n argocd -f "{{ARGOCD_INSTALL_URL}}" --server-side --force-conflicts
    kubectl -n argocd rollout status deploy/argocd-server --timeout=600s

# Delete all demo clusters
down:
    kind delete cluster --name argocd-oci-demo-hub
    kind delete cluster --name argocd-oci-demo-spoke1
    kind delete cluster --name argocd-oci-demo-spoke2

# Log in to Argo CD via port-forward (password from argocd-initial-admin-secret)
login:
    kubectl config use-context {{HUB}}
    kubectl -n argocd port-forward deploy/argocd-server 8080:8080 >/dev/null 2>&1 &
    sleep 3
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode | pbcopy
    open localhost:8080

# Register the spoke clusters in Argo CD with the env=spoke label.
register-clusters:
    #!/usr/bin/env bash
    set -euo pipefail
    export SECRET_NAME=spoke-1
    export SPOKE_API_PORT=$(docker inspect argocd-oci-demo-spoke1-control-plane --format='{{{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort}}')
    export CLIENT_CERT_DATA=$(kubectl config view --context=kind-argocd-oci-demo-spoke1 --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}')
    export CLIENT_KEY_DATA=$(kubectl config view --context=kind-argocd-oci-demo-spoke1 --minify --raw -o jsonpath='{.users[0].user.client-key-data}')
    envsubst '$SECRET_NAME $SPOKE_API_PORT $CLIENT_CERT_DATA $CLIENT_KEY_DATA' < templates/spoke-cluster-secret.yaml.tpl | kubectl apply -f -
    export SECRET_NAME=spoke-2
    export SPOKE_API_PORT=$(docker inspect argocd-oci-demo-spoke2-control-plane --format='{{{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort}}')
    export CLIENT_CERT_DATA=$(kubectl config view --context=kind-argocd-oci-demo-spoke2 --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}')
    export CLIENT_KEY_DATA=$(kubectl config view --context=kind-argocd-oci-demo-spoke2 --minify --raw -o jsonpath='{.users[0].user.client-key-data}')
    envsubst '$SECRET_NAME $SPOKE_API_PORT $CLIENT_CERT_DATA $CLIENT_KEY_DATA' < templates/spoke-cluster-secret.yaml.tpl | kubectl apply -f -

# Apply both ApplicationSets (expects: up, login, register-clusters, publish done)
apply-appsets:
    kubectl config use-context {{HUB}}
    kubectl apply -f applicationsets/platform.yaml
    kubectl apply -f applicationsets/security.yaml

# Tear down Argo CD-managed demo resources on the hub (clusters stay)
clean:
    kubectl config use-context {{HUB}}
    kubectl delete -f applicationsets/ --ignore-not-found
    kubectl -n argocd delete secret --ignore-not-found -l argocd.argoproj.io/secret-type=cluster
