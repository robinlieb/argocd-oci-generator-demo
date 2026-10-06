# argocd-oci-generator-demo

Demo of the [Argo CD OCI generator](https://argo-cd.readthedocs.io/en/release-3.6/operator-manual/applicationset/Generators-OCI/): pre-rendered platform components distributed as versioned OCI artifacts and deployed by ApplicationSets.

```mermaid
flowchart LR
    subgraph local [Local machine]
        UC[components/<br/>umbrella charts] -->|helm template| R[dist/<br/>pre-rendered]
        R -->|oras push| GHCR[(ghcr.io<br/>platform:1.0.0<br/>security:1.0.0)]
    end

    GHCR -->|oci dir generator| HUB
    GHCR -->|matrix: cluster x oci| S1 & S2

    subgraph hub [kind hub]
        HUB[Argo CD<br/>AppSet: platform] --> P1[cert-manager]
        HUB --> P2[external-dns]
        HUB --> P3[external-secrets]
        HUB --> P4[traefik]
    end

    subgraph spokes [kind spokes]
        S1[spoke1<br/>AppSet: security] --> C1[cert-manager<br/>external-secrets]
        S2[spoke2<br/>AppSet: security] --> C2[cert-manager<br/>external-secrets]
    end
```

## Bundles

| Artifact | Contents | Deployed to |
|---|---|---|
| `ghcr.io/robinlieb/argocd-oci-generator-demo/platform:1.0.0` | cert-manager, external-dns, external-secrets, traefik | hub (OCI dir generator) |
| `ghcr.io/robinlieb/argocd-oci-generator-demo/security:1.0.0` | cert-manager, external-secrets | spokes (Matrix: cluster × OCI) |

Each `components/<name>/` is a Helm umbrella chart wrapping the upstream chart with a pinned version. `hack/render.sh` pre-renders them into a flat manifest per component; `hack/publish.sh` pushes each bundle as a single-layer OCI artifact.
