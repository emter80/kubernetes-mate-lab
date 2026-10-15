# Architecture

Overview of the Multipass + Terraform + K3s lab (`multipass/k3s`). The Vagrant variants are independent and not shown.

## 1. Layers and deployment flow

```mermaid
flowchart TB
    subgraph HOST["Windows 11 host (Intel NUC, Git Bash)"]
        direction TB
        SCRIPT["main_bootstrap.sh<br/>--build / --rebuild / --destroy<br/>--backup / --restore / --recover-secrets"]
        CONSUL[("Consul KV 127.0.0.1:8500<br/>terraform/ = state + locks<br/>topsecret/ = sealed-secrets key,<br/>root CA, OAuth secrets")]
        TRUST["Windows Root store<br/>(install-root-ca.sh)"]
        KCFG["~/.kube/config.multipass.k3s"]
    end

    subgraph L1["Layer 1 - 01-infra (Terraform + Multipass)"]
        direction LR
        MASTER["k3s-master<br/>10.20.0.10<br/>control plane"]
        W1["k3s-worker-1<br/>10.20.0.11"]
        W2["k3s-worker-2<br/>10.20.0.12"]
    end

    subgraph L2["Layer 2 - 02-bootstrap (Terraform modules 00..09)"]
        direction TB
        M0["00 CoreDNS custom rewrite"]
        M1["01 cert-manager"]
        M2["02 Root CA + ClusterIssuer multipass-ca"]
        M3["03 Sealed Secrets controller"]
        M4["04 Argo CD (+ GitHub OAuth)"]
        M5["05 Ingress + cert for Argo CD"]
        M6["06 GitOps ApplicationSet platform-apps"]
        M7["07 Seal secrets from Consul"]
        M8["08 trust-manager CA Bundle"]
        M9["09 K3s API server OIDC (Dex)"]
        M0 --> M1 --> M2 --> M3 --> M4 --> M5 --> M6 --> M7 --> M8 --> M9
    end

    subgraph L3["Layer 3 - 03-apps (delivered by Argo CD from Git)"]
        direction LR
        DEX["dex<br/>OIDC broker"]
        HL["headlamp<br/>dashboard"]
        PI["podinfo"]
        WH["whoami"]
        RB["rbac<br/>ClusterRoleBindings"]
        RL["reloader"]
    end

    GIT[("GitHub repo<br/>03-apps/**/app.yaml<br/>+ SealedSecrets")]
    GH["GitHub OAuth"]

    SCRIPT -->|"terraform apply"| L1
    SCRIPT -->|"terraform apply"| L2
    SCRIPT <-->|"state, secrets"| CONSUL
    L1 -->|"writes"| KCFG
    L2 -->|"kubeconfig"| MASTER
    M6 -.->|"git generator"| GIT
    GIT ==>|"auto-sync, prune, selfHeal"| L3
    CONSUL -.->|"root CA"| TRUST
    DEX <-->|"login"| GH
```

## 2. Runtime view (inside the cluster)

```mermaid
flowchart LR
    USER(["User / browser"])

    subgraph K3S["K3s cluster (1 control plane + 2 workers)"]
        direction TB
        TRAEFIK["Traefik<br/>IngressRoutes *.multipass.k3s"]

        subgraph APPS["Applications"]
            ARGO["Argo CD"]
            DEX["Dex"]
            HEAD["Headlamp"]
            POD["podinfo"]
            WHO["whoami"]
        end

        subgraph PLAT["Platform services"]
            CM["cert-manager<br/>ClusterIssuer multipass-ca"]
            TM["trust-manager<br/>Bundle -> ConfigMaps ca.crt"]
            SS["Sealed Secrets<br/>controller"]
            RLD["Reloader"]
            DNS["CoreDNS<br/>dex.multipass.k3s -> traefik"]
        end

        API["kube-apiserver<br/>OIDC -> Dex"]
        RBAC["Kubernetes RBAC"]
    end

    GITHUB["GitHub<br/>OAuth + repo"]

    USER -->|"HTTPS"| TRAEFIK
    TRAEFIK --> ARGO & DEX & HEAD & POD & WHO
    CM -->|"issues TLS certs"| TRAEFIK
    CM --> TM
    TM -->|"trust internal CA"| APPS
    SS -->|"decrypts SealedSecrets"| APPS
    RLD -->|"restarts on Secret/ConfigMap change"| APPS
    DNS -.->|"in-cluster resolution"| DEX
    ARGO -->|"SSO"| DEX
    HEAD -->|"OIDC"| DEX
    DEX -->|"GitHub connector"| GITHUB
    ARGO -->|"pull manifests"| GITHUB
    DEX -->|"ID token"| API
    API --> RBAC
```

## 3. Secrets flow

```mermaid
flowchart LR
    TPL["Templates<br/>07-secrets/templates"] --> PLAIN["Plain Secret manifests<br/>Consul topsecret/"]
    PLAIN -->|"kubeseal with controller public key"| SEALED["SealedSecret YAML<br/>committed to Git"]
    SEALED -->|"Argo CD sync"| CTRL["Sealed Secrets controller<br/>(key from Consul)"]
    CTRL -->|"decrypt"| SECRET["Kubernetes Secret"]
    SECRET --> RELOAD["Reloader restarts pods"]
```
