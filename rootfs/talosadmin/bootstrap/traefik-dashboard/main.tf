terraform {
  required_version = ">= 1.15.0"
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
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

variable "traefik_dashboard_admin_password" {
  type = string
  sensitive = true
}

variable "traefik_fqdn" {
  type = string
}

variable "wildcard_fqdn" {
  type = string
}

resource "kubernetes_secret_v1" "dashboard_auth" {
  metadata {
    name = "traefik-dashboard-auth"
    namespace = "traefik"
  }

  data = {
    users = "admin:${bcrypt(trimspace(var.traefik_dashboard_admin_password))}"
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "basic_auth_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "Middleware"
    metadata = {
      name = "dashboard-auth"
      namespace = "traefik"
    }
    spec = {
      basicAuth = {
        secret = kubernetes_secret_v1.dashboard_auth.metadata[0].name
      }
    }
  }
}

resource "kubernetes_ingress_v1" "traefik_dashboard_ingress" {
  metadata {
    name = "traefik-dashboard"
    namespace = "traefik"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-default-http-to-https@kubernetescrd,traefik-dashboard-auth@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = [trimspace(var.traefik_fqdn)]
      secret_name = "wildcard-${replace(trimspace(var.wildcard_fqdn), ".", "-")}-tls"
    }

    rule {
      host = trimspace(var.traefik_fqdn)

      http {
        path {
          path = "/dashboard"
          path_type = "Prefix"

          backend {
            service {
              name = "traefik-dashboard"
              port {
                name = "traefik"
              }
            }
          }
        }

        path {
          path = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = "traefik-dashboard"
              port {
                name = "traefik"
              }
            }
          }
        }
      }
    }
  }
}