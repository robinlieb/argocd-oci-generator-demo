apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    env: spoke
stringData:
  name: ${SECRET_NAME}
  server: https://host.docker.internal:${SPOKE_API_PORT}
  config: |
    {
      "tlsClientConfig": {
        "insecure": true,
        "certData": "${CLIENT_CERT_DATA}",
        "keyData": "${CLIENT_KEY_DATA}"
      }
    }