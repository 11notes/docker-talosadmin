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

variable "metallb_ingress_ip_pool" {
  type = string
}

resource "kubernetes_manifest" "ip_pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind = "IPAddressPool"
    metadata = {
      name = "ingress-ip-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [
        "${var.metallb_ingress_ip_pool}"
      ]
    }
  }
}

resource "kubernetes_manifest" "l2_advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind = "L2Advertisement"
    metadata = {
      name = "l2-advertisement"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = [
        "ingress-ip-pool"
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.ip_pool
  ]
}