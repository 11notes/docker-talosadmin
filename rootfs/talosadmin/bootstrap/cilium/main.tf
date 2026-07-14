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

resource "helm_release" "cilium" {
  name = "cilium"
  repository = "https://helm.cilium.io/"
  chart = "cilium"
  version = "1.19.5"
  namespace = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }

      ipam = {
        mode = "kubernetes"
      }

      kubeProxyReplacement = false

      cgroup = {
        autoMount = {
          enabled = false
        }
        hostRoot = "/sys/fs/cgroup"
      }

      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK",
            "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER",
            "SETGID", "SETUID"
          ]
          cleanCiliumState = [
            "NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"
          ]
        }
      }

      hubble = {
        enabled = true
        relay = {
          enabled = true
        }
        ui = {
          enabled = true
        }
        metrics = {
          enabled = [
            "dns",
            "drop",
            "tcp",
            "flow",
            "icmp",
            "http",
          ]
        }
        serviceMonitor = {
          enabled = true
        }
      }
    })
  ]
}