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

resource "kubernetes_manifest" "traefik_dashboard_redirect_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "Middleware"
    metadata = {
      name = "traefik-dashboard-redirect"
      namespace = "traefik"
    }
    spec = {
      redirectRegex = {
        regex = "^(https?://[^/]+)/?$"
        replacement = "$${1}/dashboard/"
        permanent = true
      }
    }
  }
}

resource "kubernetes_manifest" "traefik_dashboard_ingress" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "IngressRoute"
    metadata = {
      name = "traefik-dashboard"
      namespace = "traefik"
    }
    spec = {
      routes = [
        {
          match = "Host(`${trimspace(var.traefik_fqdn)}`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
          kind = "Rule"
          services = [
            {
              name = "api@internal"
              kind = "TraefikService"
            }
          ]
          middlewares = [
            {
              name = kubernetes_manifest.basic_auth_middleware.manifest.metadata.name
              namespace = "traefik"
            }
          ]
        },
        {
          match = "Host(`${trimspace(var.traefik_fqdn)}`) && Path(`/`)"
          kind = "Rule"
          services = [
            {
              name = "api@internal"
              kind = "TraefikService"
            }
          ]
          middlewares = [
            {
              name = kubernetes_manifest.traefik_dashboard_redirect_middleware.manifest.metadata.name
              namespace = "traefik"
            }
          ]
        }
      ]
      tls = {
        secretName = trimspace(var.wildcard_fqdn)
      }
    }
  }
}