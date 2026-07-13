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

variable "headlamp_fqdn" {
  type = string
}

resource "helm_release" "headlamp" {
  name = "headlamp"
  repository = "https://kubernetes-sigs.github.io/headlamp"
  chart = "headlamp"
  namespace = "kube-system"
  create_namespace = false

  set = [
    {
      name  = "ingress.enabled"
      value = "false"
    }
  ]
}

resource "kubernetes_ingress_v1" "headlamp_ingress" {
  metadata {
    name = "headlamp-ingress"
    namespace = "kube-system"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-default-http-to-https@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = ["${trimspace(var.headlamp_fqdn)}"]
      secret_name = trimspace(var.headlamp_fqdn)
    }

    rule {
      host = trimspace(var.headlamp_fqdn)

      http {
        path {
          path = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "headlamp"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.headlamp]
}

resource "kubernetes_service_account_v1" "headlamp_admin" {
  metadata {
    name = "headlamp-admin"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "headlamp_admin_binding" {
  metadata {
    name = "headlamp-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }

  subject {
    kind = "ServiceAccount"
    name = kubernetes_service_account_v1.headlamp_admin.metadata[0].name
    namespace = kubernetes_service_account_v1.headlamp_admin.metadata[0].namespace
  }
}