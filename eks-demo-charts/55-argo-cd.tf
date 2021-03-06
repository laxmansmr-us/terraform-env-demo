# argo-cd & argo-rollouts

resource "helm_release" "argo-rollouts" {
  count = var.argo_cd_enabled ? 1 : 0

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = var.argo_argo_rollouts

  namespace = "argo-rollouts"
  name      = "argo-rollouts"

  values = [
    file("./values/argo/argo-rollouts.yaml")
  ]

  create_namespace = true
}

resource "helm_release" "argo-cd" {
  count = var.argo_cd_enabled ? 1 : 0

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argo_argo_cd

  namespace = "argo-cd"
  name      = "argocd"

  values = [
    file("./values/argo/argo-cd.yaml"),
    var.argo_cd_apps_enabled ? local.argocd_apps : "",
    var.sso == "keycloak" ? local.argocd_oidc_keycloak : "",
    var.sso == "google" ? local.argocd_oidc_google : "",
    var.sso == "github" ? local.argocd_oidc_github : "",
  ]

  wait = false

  create_namespace = true

  depends_on = [
    helm_release.prometheus-operator,
  ]
}

locals {
  argocd_apps = yamlencode(
    {
      server = {
        additionalApplications = [
          {
            name    = "apps-demo"
            project = "default"
            source = {
              repoURL        = "https://github.com/opspresso/argocd-env-demo"
              targetRevision = "HEAD"
              path           = format("%s/%s/%s", "cluster", var.region, var.cluster_name)
              directory = {
                recurse = true
              }
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "argo-cd"
            }
            syncPolicy = {
              automated = {
                prune    = true
                selfHeal = true
              }
            }
          }
        ]
      }
    }
  )

  argocd_oidc_keycloak = yamlencode(
    {
      server = {
        config = {
          "oidc.config" = yamlencode(
            {
              name         = "Keycloak"
              issuer       = "https://keycloak.bruce.spic.me/auth/realms/demo"
              clientID     = "argo-cd"
              clientSecret = "d91fdbbc-5dbb-43ab-b388-ce4170ff79c6"
            }
          )
        }
      }
    }
  )

  argocd_oidc_google = yamlencode(
    {
      server = {
        config = {
          "oidc.config" = yamlencode(
            {
              name         = "Google"
              issuer       = "https://accounts.google.com"
              clientID     = data.aws_ssm_parameter.google_client_id.value
              clientSecret = data.aws_ssm_parameter.google_client_secret.value
              requestedScopes = [
                "https://www.googleapis.com/auth/userinfo.profile",
                "https://www.googleapis.com/auth/userinfo.email",
              ]
            }
          )
        }
        rbacConfig = {
          scopes = "[profile email]"
        }
      }
    }
  )

  argocd_oidc_github = yamlencode(
    {
      server = {
        config = {
          "oidc.config" = yamlencode(
            {
              name         = "Github"
              issuer       = "https://accounts.google.com"
              clientID     = data.aws_ssm_parameter.github_client_id.value
              clientSecret = data.aws_ssm_parameter.github_client_secret.value
            }
          )
        }
      }
    }
  )
}
