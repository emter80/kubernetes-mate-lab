resource "kubernetes_manifest" "platform_applicationset" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "platform-apps"
      namespace = "argocd"
    }
    spec = {
      generators = [
        {
          git = {
            repoURL  = "https://github.com/emter80/kubernetes-mate-lab.git"
            revision = "main"
            files = [
              {
                path = "multipass/k3s/03-apps/applications/**/app.yaml"
              }
            ]
          }
        }
      ]

      template = {
        metadata = {
          name = "{{name}}"
        }

        spec = {
          project = "default"
          sources = [
            {
              repoURL        = "{{helm.repoURL}}"
              chart          = "{{helm.chart}}"
              targetRevision = "{{helm.targetRevision}}"
              helm = {
                valueFiles = [
                  "$values/{{values.file}}"
                ]
              }
            },
            {
              repoURL        = "https://github.com/emter80/kubernetes-mate-lab.git"
              targetRevision = "main"
              ref            = "values"
            }
          ]
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{namespace}}"
          }

          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }

            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    }
  }
}
