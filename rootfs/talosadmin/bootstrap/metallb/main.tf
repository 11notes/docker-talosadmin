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

resource "kubernetes_namespace_v1" "metallb" {
  metadata {
    name = "metallb-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "metallb" {
  name = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart = "metallb"
  namespace  = kubernetes_namespace_v1.metallb.metadata[0].name

  wait = true
  wait_for_jobs = true
  timeout = 120

  values = [
    yamlencode({
      speaker = {
        frr = {
          enabled = false
        }
      }
      frrk8s = {
        enabled = false
      }
      prometheus = {
        serviceMonitor = {
          enabled = true
        }
      }
    })
  ]
}