terraform {
  required_version = ">= 1.15.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

variable "hubble_fqdn" {
  type = string
}

variable "hubble_dashboard_admin_password" {
  type = string
  sensitive = true
}

resource "kubernetes_secret_v1" "dashboard_auth" {
  metadata {
    name = "hubble-dashboard-auth"
    namespace = "traefik"
  }

  data = {
    users = "admin:${bcrypt(trimspace(var.hubble_dashboard_admin_password))}"
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "basic_auth_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "Middleware"
    metadata = {
      name = "hubble-dashboard-auth"
      namespace = "traefik"
    }
    spec = {
      basicAuth = {
        secret = kubernetes_secret_v1.dashboard_auth.metadata[0].name
      }
    }
  }
}

resource "kubernetes_ingress_v1" "hubble_ingress" {
  metadata {
    name = "hubble-ingress"
    namespace = "kube-system"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-default-http-to-https@kubernetescrd,traefik-hubble-dashboard-auth@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = ["${trimspace(var.hubble_fqdn)}"]
      secret_name = trimspace(var.hubble_fqdn)
    }

    rule {
      host = trimspace(var.hubble_fqdn)

      http {
        path {
          path = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "hubble-ui"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}