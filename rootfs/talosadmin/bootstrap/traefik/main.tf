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

variable "traefik_ingress_ip" {
  type = string
}

resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "traefik" {
  name = "traefik"
  repository = "https://traefik.github.io/charts"
  chart = "traefik"
  namespace  = "traefik"

  set = [
    {
      name  = "deployment.kind"
      value = "DaemonSet"
    },
    {
      name  = "hostNetwork"
      value = "true"
    },
    {
      name  = "updateStrategy.rollingUpdate.maxUnavailable"
      value = "1"
    },
    {
      name  = "updateStrategy.rollingUpdate.maxSurge"
      value = "0"
    },
    {
      name  = "deployment.dnsPolicy" 
      value = "ClusterFirstWithHostNet"
    },
    {
      name  = "service.spec.externalTrafficPolicy"
      value = "Local"
    },
    {
      name  = "service.spec.loadBalancerIP"
      value = trimspace(var.traefik_ingress_ip)
    },
    {
      name  = "ingressRoute.dashboard.enabled"
      value = "false"
    },
    {
      name  = "providers.kubernetesIngress.publishedService.pathOverride"
      value = "traefik/traefik"
    }
  ]
}