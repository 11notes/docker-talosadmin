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

resource "helm_release" "loki" {
  name = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart = "loki"
  namespace = "monitoring"
  create_namespace = false
  values = [yamlencode({
    loki = {
      auth_enabled = false
      commonConfig = {
        replication_factor = 1
      }
      storage = {
        type = "filesystem"
      }
      schemaConfig = {
        configs = [
          {
            from = "2024-01-01"
            store = "tsdb"
            object_store = "filesystem"
            schema = "v13"
            index = {
              prefix = "loki_index_"
              period = "24h"
            }
          }
        ]
      }
      limits_config = {
        retention_period = "90d"
      }
      compactor = {
        retention_enabled = true
        delete_request_store = "filesystem"
      }
    }
    deploymentMode = "SingleBinary"
    singleBinary = {
      replicas = 1
      persistence = {
        enabled = true
        size = "32Gi"
      }
    }
    backend = { replicas = 0 }
    read = { replicas = 0 }
    write = { replicas = 0 }
  })]
}

resource "helm_release" "alloy" {
  name = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart = "alloy"
  namespace = "monitoring"
  create_namespace = false
  values = [yamlencode({
    alloy = {
      extraEnv = [
        {
          name = "NODE_NAME"
          valueFrom = {
            fieldRef = {
              fieldPath = "spec.nodeName"
            }
          }
        }
      ]
      configMap = {
        content = <<-EOT
          discovery.kubernetes "pods" {
            role = "pod"
          }
          discovery.relabel "scoped_pod_logs" {
            targets = discovery.kubernetes.pods.targets

            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              regex = "traefik"
              action = "keep"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_node_name"]
              regex = sys.env("NODE_NAME")
              action = "keep"
            }
            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label = "namespace"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              target_label = "pod"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label = "container"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label = "app"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_uid"]
              target_label = "__path__"
              replacement = "/var/log/pods/*$1/*/*.log"
            }
          }
          local.file_match "pod_logs" {
            path_targets = discovery.relabel.scoped_pod_logs.output
          }

          loki.source.file "pod_logs" {
            targets = local.file_match.pod_logs.targets
            forward_to = [loki.process.pod_logs.receiver]
          }
          loki.process "pod_logs" {
            stage.cri {}
            forward_to = [loki.write.default.receiver]
          }
          loki.write "default" {
            endpoint {
              url = "http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push"
            }
          }
        EOT
      }
      mounts = {
        varlog = true
      }
    }
    controller = {
      type = "daemonset"
    }
  })]
  depends_on = [helm_release.loki]
}