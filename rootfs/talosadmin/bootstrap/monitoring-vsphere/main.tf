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

resource "kubernetes_secret_v1" "vsphere_credentials" {
  metadata {
    name = "vsphere-credentials"
    namespace = "monitoring"
  }

  data = {
    for vc in var.vcenter_endpoints : vc.env_var => trimspace(vc.password)
  }

  type = "Opaque"
}

# ╔═════════════════════════════════════════════════════╗
# ║                     EXPORTER                        ║
# ╚═════════════════════════════════════════════════════╝
resource "kubernetes_deployment_v1" "vcenter_exporter" {
  for_each = { for vc in var.vcenter_endpoints : vc.name => vc }

  metadata {
    name = "vcenter-exporter-${replace(lower(each.value.name), ".", "-")}"
    namespace = "monitoring"
    labels = {
      app = "vcenter-exporter"
      "app.kubernetes.io/instance" = replace(lower(each.value.name), ".", "-")
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vcenter-exporter"
        "app.kubernetes.io/instance" = replace(lower(each.value.name), ".", "-")
      }
    }

    template {
      metadata {
        labels = {
          app = "vcenter-exporter"
          "app.kubernetes.io/instance" = replace(lower(each.value.name), ".", "-")
        }
      }

      spec {
        container {
          name = "vmware-exporter"
          image = "docker.io/pryorda/vmware_exporter:latest"

          env {
            name = "VSPHERE_HOST"
            value = replace(replace(replace(each.value.endpoint, "https://", ""), "http://", ""), "/sdk", "")
          }
          env {
            name = "VSPHERE_USER"
            value = each.value.username
          }
          env {
            name = "VSPHERE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.vsphere_credentials.metadata[0].name
                key = each.value.env_var
              }
            }
          }
          env {
            name = "VSPHERE_IGNORE_SSL"
            value = "True"
          }
          env {
            name = "VSPHERE_SPECS_SIZE"
            value = "50"
          }
          env {
            name = "VSPHERE_COLLECT_VMS"
            value = "True"
          }
          env {
            name = "VSPHERE_FETCH_TAGS"
            value = "True"
          }
          env {
            name = "VSPHERE_FETCH_CUSTOM_ATTRIBUTES"
            value = "True"
          }
          env {
            name = "VSPHERE_COLLECT_HOSTS"
            value = "False"
          }
          env {
            name = "VSPHERE_COLLECT_DATASTORES"
            value = "False"
          }
          env {
            name = "VSPHERE_COLLECT_VMGUESTS"
            value = "False"
          }
          env {
            name = "VSPHERE_COLLECT_SNAPSHOTS"
            value = "False"
          }

          port {
            name = "http-metrics"
            container_port = 9272
          }

          resources {
            limits = {
              cpu = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu = "100m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "vcenter_exporter" {
  for_each = { for vc in var.vcenter_endpoints : vc.name => vc }

  metadata {
    name = "vcenter-exporter-${replace(lower(each.value.name), ".", "-")}"
    namespace = "monitoring"
    labels = {
      app = "vcenter-exporter"
      "app.kubernetes.io/instance" = replace(lower(each.value.name), ".", "-")
    }
  }

  spec {
    selector = {
      app = "vcenter-exporter"
      "app.kubernetes.io/instance" = replace(lower(each.value.name), ".", "-")
    }

    port {
      name = "http-metrics"
      port = 9272
      target_port = "http-metrics"
    }
  }
}

# ╔═════════════════════════════════════════════════════╗
# ║                       ALLOY                         ║
# ╚═════════════════════════════════════════════════════╝
resource "helm_release" "grafana_alloy" {
  name = "grafana-alloy-vsphere"
  repository = "https://grafana.github.io/helm-charts"
  chart = "alloy"
  namespace = "monitoring"
  create_namespace = false

  depends_on = [
    kubernetes_secret_v1.vsphere_credentials,
    kubernetes_service_v1.vcenter_exporter,
  ]

  values = [
    yamlencode({
      controller = {
        type = "deployment"
        replicas = 1
      }
      alloy = {
        extraArgs = [
          "--stability.level=experimental"
        ]
        extraEnv = [
          for vc in var.vcenter_endpoints : {
            name = vc.env_var
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret_v1.vsphere_credentials.metadata[0].name
                key = vc.env_var
              }
            }
          }
        ]

        configMap = {
          content = <<EOT
prometheus.remote_write "k8s_prometheus" {
  endpoint {
    url = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/write"
  }
}

otelcol.exporter.prometheus "vsphere" {
  forward_to = [prometheus.remote_write.k8s_prometheus.receiver]
}

%{ for vc in var.vcenter_endpoints ~}
prometheus.scrape "vcenter_tags_${replace(vc.name, ".", "_")}" {
  targets = [{
    __address__ = "vcenter-exporter-${replace(lower(vc.name), ".", "-")}.monitoring.svc.cluster.local:9272",
    vcenter = "${vc.name}",
    "__metrics_path__" = "/metrics",
  }]
  forward_to = [prometheus.relabel.vcenter_tags_${replace(vc.name, ".", "_")}.receiver]
  scrape_interval = "5m"
}

prometheus.relabel "vcenter_tags_${replace(vc.name, ".", "_")}" {
  forward_to = [prometheus.remote_write.k8s_prometheus.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "vmware_(.*)"
    replacement   = "vcenter_exporter_$1"
    target_label  = "__name__"
    action        = "replace"
  }
}

otelcol.receiver.vcenter "${replace(vc.name, ".", "_")}" {
  endpoint = "${vc.endpoint}"
  username = "${vc.username}"
  password = sys.env("${vc.env_var}")
  collection_interval = "1m"

  tls {
    insecure_skip_verify = true
  }

  output {
    metrics = [otelcol.processor.transform.${replace(vc.name, ".", "_")}.input]
  }
}

otelcol.processor.transform "${replace(vc.name, ".", "_")}" {
  error_mode = "ignore"
  metric_statements {
    context = "metric"
    statements = [
      "set(name, ToLowerCase(name))",
    ]
  }
  metric_statements {
    context = "datapoint"
    statements = [
      "set(attributes[\"job\"], \"vsphere\")",
      "set(attributes[\"vcenter\"], \"${vc.name}\")",
      "set(attributes[\"datacenter\"], resource.attributes[\"vcenter.datacenter.name\"]) where resource.attributes[\"vcenter.datacenter.name\"] != nil",
      "set(attributes[\"cluster\"], resource.attributes[\"vcenter.cluster.name\"]) where resource.attributes[\"vcenter.cluster.name\"] != nil",
      "set(attributes[\"host\"], resource.attributes[\"vcenter.host.name\"]) where resource.attributes[\"vcenter.host.name\"] != nil",
      "set(attributes[\"vm\"], resource.attributes[\"vcenter.vm.name\"]) where resource.attributes[\"vcenter.vm.name\"] != nil",
      "set(attributes[\"datastore\"], resource.attributes[\"vcenter.datastore.name\"]) where resource.attributes[\"vcenter.datastore.name\"] != nil",
      "set(attributes[\"resource_pool\"], resource.attributes[\"vcenter.resource_pool.name\"]) where resource.attributes[\"vcenter.resource_pool.name\"] != nil",
    ]
  }

  output {
    metrics = [otelcol.processor.batch.${replace(vc.name, ".", "_")}.input]
  }
}

otelcol.processor.batch "${replace(vc.name, ".", "_")}" {
  output {
    metrics = [otelcol.exporter.prometheus.vsphere.input]
  }
}
%{ endfor ~}
EOT
        }
      }
    })
  ]
}