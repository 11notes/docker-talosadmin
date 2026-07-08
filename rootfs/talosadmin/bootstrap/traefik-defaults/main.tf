terraform {
  required_version = ">= 1.15.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.0"
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

resource "kubernetes_manifest" "traefik_redirect_scheme_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "default-http-to-https"
      namespace = "traefik"
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }
}