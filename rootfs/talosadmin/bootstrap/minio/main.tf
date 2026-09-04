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

variable "minio_fqdns" {
  type = list(string)
}

variable "minio_ips" {
  type = list(string)
}

variable "minio_wildcard_fqdn" {
  type = string
}

variable "minio_prometheus_token" {
  type = string
  sensitive = true
}

resource "kubernetes_service_v1" "minio" {
  metadata {
    name = "minio"
    namespace = "external-services"
    labels = {
      "app" = "minio"
    }
  }

  spec {
    port {
      name = "s3-api"
      port = 9000
      target_port = 9000
    }
  }
}

resource "kubernetes_manifest" "wildcard_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind = "Certificate"
    metadata = {
      name = trimspace(var.minio_wildcard_fqdn)
      namespace = kubernetes_service_v1.minio.metadata[0].namespace
    }
    spec = {
      secretName = trimspace(var.minio_wildcard_fqdn)
      dnsNames = ["*.${var.minio_wildcard_fqdn}", "${var.minio_wildcard_fqdn}"]
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
    }
  }
}

resource "kubernetes_secret_v1" "minio_prometheus_token" {
  metadata {
    name = "minio-prometheus-token"
    namespace = kubernetes_service_v1.minio.metadata[0].namespace
  }
  data = {
    token = var.minio_prometheus_token
  }
  type = "Opaque"
}

resource "kubernetes_endpoints_v1" "minio" {
  metadata {
    name = "minio"
    namespace = kubernetes_service_v1.minio.metadata[0].namespace
  }

  subset {
    dynamic "address" {
      for_each = var.minio_ips
      content {
        ip = address.value
      }
    }
    port {
      name = "s3-api"
      port = 9000
    }
  }
}

resource "kubernetes_manifest" "minio_transport" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "ServersTransport"
    metadata = {
      name = "minio-transport"
      namespace = "traefik"
    }
    spec = {
      insecureSkipVerify = true
      disableHTTP2 = true
      forwardingTimeouts = {
        dialTimeout = "30s"
        responseHeaderTimeout = "30s"
        idleConnTimeout = "90s"
      }
    }
  }
}

resource "kubernetes_ingress_v1" "minio" {
  metadata {
    name = "minio"
    namespace = kubernetes_service_v1.minio.metadata[0].namespace
    annotations = {
      "traefik.ingress.kubernetes.io/service.serverstransport" = "traefik-minio-transport@kubernetescrd"
      "traefik.ingress.kubernetes.io/service.healthcheck.path" = "/minio/health/live"
      "traefik.ingress.kubernetes.io/service.healthcheck.interval" = "10s"
      "traefik.ingress.kubernetes.io/service.healthcheck.timeout" = "3s"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts = var.minio_fqdns
      secret_name = trimspace(var.minio_wildcard_fqdn)
    }

    dynamic "rule" {
      for_each = var.minio_fqdns
      content {
        host = rule.value
        http {
          path {
            path = "/"
            path_type = "Prefix"
            backend {
              service {
                name = "minio"
                port {
                  number = 9000
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "minio_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = "minio"
      namespace = kubernetes_service_v1.minio.metadata[0].namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "app" = "minio"
        }
      }
      namespaceSelector = {
        matchNames = [kubernetes_service_v1.minio.metadata[0].namespace]
      }
      endpoints = [
        {
          port = "s3-api"
          path = "/minio/v2/metrics/cluster"
          scheme = "http"
          interval = "60s"
          bearerTokenSecret = {
            name = kubernetes_secret_v1.minio_prometheus_token.metadata[0].name
            key = "token"
          }
        }
      ]
    }
  }
}