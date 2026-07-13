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

resource "kubernetes_manifest" "traefik_redirect_scheme_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "Middleware"
    metadata = {
      name = "default-http-to-https"
      namespace = "traefik"
    }
    spec = {
      redirectScheme = {
        scheme = "https"
        permanent = true
      }
    }
  }
}

resource "kubernetes_manifest" "traefik_security_headers" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "Middleware"
    metadata = {
      name = "default-security-headers"
      namespace = "traefik"
    }
    spec = {
      headers = {
        stsSeconds = 31536000
        stsIncludeSubdomains = true
        stsPreload = true
        forceSTSHeader = true

        browserXssFilter = true
        contentTypeNosniff = true
        frameDeny = true
        referrerPolicy = "same-origin"
      }
    }
  }
}

resource "kubernetes_manifest" "traefik_tls_options" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind = "TLSOption"
    metadata = {
      name = "default-tls-profile"
      namespace = "traefik"
    }
    spec = {
      minVersion = "VersionTLS12"

      cipherSuites = [
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
        "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
      ]

      preferServerCipherSuites = true
    }
  }
}