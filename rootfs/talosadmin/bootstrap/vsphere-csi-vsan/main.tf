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

variable "vsphere_cluster_id" {
  type = string
}

variable "vsphere_vcenter_fqdn" {
  type = string
}

variable "vsphere_vcenter_user" {
  type = string
}

variable "vsphere_vcenter_password" {
  type = string
  sensitive = true
}

variable "vsphere_datacenter" {
  type = string
}

variable "vsphere_vsan_policy" {
  type = string
}

resource "helm_release" "vsphere_cpi" {
  name = "vsphere-cpi"
  repository = "https://kubernetes.github.io/cloud-provider-vsphere"
  chart = "vsphere-cpi"
  namespace = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      config = {
        enabled = true
        vcenter = trimspace(var.vsphere_vcenter_fqdn)
        username = trimspace(var.vsphere_vcenter_user)
        password = trimspace(var.vsphere_vcenter_password)
        datacenter = trimspace(var.vsphere_datacenter)
        insecureFlag  = true
      }
    })
  ]
}

resource "kubernetes_labels" "kube_system_security" {
  api_version = "v1"
  kind = "Namespace"
  metadata {
    name = "kube-system"
  }

  labels = {
    "pod-security.kubernetes.io/enforce" = "privileged"
  }
}

resource "kubernetes_cluster_role_binding_v1" "vsphere_csi_rbac" {
  metadata {
    name = "vsphere-csi-controller-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "cluster-admin"
  }
  subject {
    kind = "ServiceAccount"
    name = "vsphere-csi-controller"
    namespace = "kube-system"
  }
}

resource "helm_release" "vsphere_csi" {
  name = "vsphere-csi"
  repository = "https://vsphere-tmm.github.io/helm-charts"
  chart = "vsphere-csi"
  namespace  = "kube-system"
  depends_on = [
    helm_release.vsphere_cpi,
    kubernetes_cluster_role_binding_v1.vsphere_csi_rbac,
    kubernetes_labels.kube_system_security
  ]
  values = [
  yamlencode({
    global = {
      config = {
        global = {
          insecure-flag = true
          cluster-id = trimspace(var.vsphere_cluster_id)
        }
        vcenter = {
          "${replace(replace(trimspace(var.vsphere_vcenter_fqdn), "https://", ""), "/", "")}" = {
            server = replace(replace(trimspace(var.vsphere_vcenter_fqdn), "https://", ""), "/", "")
            user = trimspace(var.vsphere_vcenter_user)
            password = trimspace(var.vsphere_vcenter_password)
            datacenters = [trimspace(var.vsphere_datacenter)]
          }
        }
      }
    }
  })
]
}

resource "kubernetes_storage_class_v1" "vsphere_default" {
  metadata {
    name = "vsphere-default"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "csi.vsphere.vmware.com"
  reclaim_policy = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    "storagepolicyname" = trimspace(var.vsphere_vsan_policy)
  }

  depends_on = [helm_release.vsphere_csi]
}