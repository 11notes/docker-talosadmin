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

variable "k10_fqdn" {
  type = string
}

variable "wildcard_fqdn" {
  type = string
}

variable "k10_dashboard_admin_password" {
  type = string
  sensitive = true
}

resource "kubernetes_namespace_v1" "k10" {
  metadata {
    name = "k10"
  }
}

resource "kubernetes_secret_v1" "k10_basic_auth" {
  metadata {
    name = "k10-basic-auth"
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
  }

  data = {
    "auth" = "admin:${bcrypt(trimspace(var.k10_dashboard_admin_password))}"
  }

  type = "Opaque"
}

resource "kubernetes_service_account_v1" "k10_service_account" {
  metadata {
    name      = "k10-sa"
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "k10_rbac_cluster" {
  metadata {
    name = "${kubernetes_service_account_v1.k10_service_account.metadata[0].name}-cluster"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "k10-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.k10_service_account.metadata[0].name
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
  }
}

resource "kubernetes_role_binding_v1" "k10_rbac_ns" {
  metadata {
    name      = "${kubernetes_service_account_v1.k10_service_account.metadata[0].name}-ns"
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "k10-ns-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.k10_service_account.metadata[0].name
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "k10_service_account_token" {
  metadata {
    name      = "${kubernetes_service_account_v1.k10_service_account.metadata[0].name}-token"
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.k10_service_account.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
  depends_on = [kubernetes_service_account_v1.k10_service_account]
}

resource "helm_release" "k10" {
  name = "k10"
  repository = "https://charts.kasten.io/"
  chart = "k10"
  namespace = kubernetes_namespace_v1.k10.metadata[0].name

  wait = true
  wait_for_jobs = true
  timeout = 120

  values = [
    yamlencode({
      auth = {
        basicAuth = {
          enabled = true
          secretName = "k10-basic-auth"
        }
      }
    })
  ]

  depends_on = [kubernetes_secret_v1.k10_basic_auth]
}

resource "kubernetes_ingress_v1" "k10_ingress" {
  metadata {
    name = "k10-ingress"
    namespace = kubernetes_namespace_v1.k10.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.middlewares" = "traefik-default-http-to-https@kubernetescrd"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = [trimspace(var.k10_fqdn)]
      secret_name = trimspace(var.wildcard_fqdn)
    }

    rule {
      host = trimspace(var.k10_fqdn)

      http {
        path {
          path = "/k10"
          path_type = "Prefix"

          backend {
            service {
              name = "gateway"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.k10]
}