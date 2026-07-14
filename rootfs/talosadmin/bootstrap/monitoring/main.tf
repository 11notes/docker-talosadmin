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

variable "grafana_admin_password" {
  type = string
  sensitive = true
}

variable "monitoring_storage_class_name" {
  type = string
}

variable "prometheus_retention" {
  type = string
  default = "30d"
}

variable "prometheus_storage_size" {
  type = string
  default = "256Gi"
}

variable "alertmanager_storage_size" {
  type = string
  default = "16Gi"
}

variable "grafana_storage_size" {
  type = string
  default = "32Gi"
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  namespace = "monitoring"
  create_namespace = false

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = var.prometheus_retention
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.monitoring_storage_class_name
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues = false
        }
      }

      kubeEtcd = {
        service = {
          enabled = true
          port = 2381
          targetPort = 2381
        }
        serviceMonitor = {
          scheme = "http"
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.monitoring_storage_class_name
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
              }
            }
          }
        }
      }

      grafana = {
        enabled = true
        persistence = {
          enabled = true
          storageClassName = var.monitoring_storage_class_name
          size = var.grafana_storage_size
        }
        adminPassword = var.grafana_admin_password
      }

      "prometheus-node-exporter" = {
        service = {
          port = 9110
          targetPort = 9110
        }
        affinity = {}
        tolerations = [
          {
            operator = "Exists"
            effect = "NoSchedule"
          }
        ]
      }
    })
  ]
}
