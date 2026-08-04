terraform {
  required_version = ">= 1.15.0"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

variable "wildcard_fqdn" {
  type = string
}

resource "kubernetes_manifest" "wildcard_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind = "Certificate"
    metadata = {
      name = "wildcard-${replace(trimspace(var.wildcard_fqdn), ".", "-")}"
      namespace = "traefik"
    }
    spec = {
      secretName = "wildcard-${replace(trimspace(var.wildcard_fqdn), ".", "-")}-tls"
      dnsNames = ["*.${var.wildcard_fqdn}", "${var.wildcard_fqdn}"]
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
    }
  }
}