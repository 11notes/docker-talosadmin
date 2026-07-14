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

variable "monitoring_fqdn" {
  type = string
}

resource "kubernetes_ingress_v1" "monitoring_ingress" {
  metadata {
    name = "monitoring-ingress"
    namespace = "monitoring"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-default-http-to-https@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = ["${trimspace(var.monitoring_fqdn)}"]
      secret_name = trimspace(var.monitoring_fqdn)
    }

    rule {
      host = trimspace(var.monitoring_fqdn)

      http {
        path {
          path = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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