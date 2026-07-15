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

resource "helm_release" "csi_driver_smb" {
  name             = "csi-driver-smb"
  repository       = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts"
  chart            = "csi-driver-smb"
  namespace        = "kube-system"
  create_namespace = false
}