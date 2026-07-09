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

variable "cert_manager_email_address" {
  type = string
}

variable "cert_manager_rfc2136_key" {
  type = string
}


variable "cert_manager_rfc2136_nameserver" {
  type = string
}

variable "cert_manager_rfc2136_algorithm" {
  type = string
}

variable "cert_manager_rfc2136_secret" {
  type = string
  sensitive = true
}

resource "kubernetes_secret_v1" "rfc2136_tsig_secret" {
  metadata {
    name      = "rfc2136-tsig-secret"
    namespace = "cert-manager"
  }

  data = {
    "tsig-secret-key" = trimspace(var.cert_manager_rfc2136_secret)
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = trimspace(var.cert_manager_email_address)
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            dns01 = {
              rfc2136 = {
                nameserver = trimspace(var.cert_manager_rfc2136_nameserver)
                tsigKeyName = trimspace(var.cert_manager_rfc2136_key)
                tsigAlgorithm = trimspace(var.cert_manager_rfc2136_algorithm)
                tsigSecretSecretRef = {
                  name = kubernetes_secret_v1.rfc2136_tsig_secret.metadata[0].name
                  key  = "tsig-secret-key"
                }
              }
            }
          }
        ]
      }
    }
  }
}