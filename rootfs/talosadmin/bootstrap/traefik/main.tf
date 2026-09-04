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

variable "traefik_ingress_ip" {
  type = string
}

resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "traefik" {
  name = "traefik"
  repository = "https://traefik.github.io/charts"
  chart = "traefik"
  namespace = "traefik"

  values = [
    yamlencode({
      # daemonSet config
      deployment = {
        kind = "DaemonSet"
        dnsPolicy = "ClusterFirstWithHostNet"
      }

      hostNetwork = true

      updateStrategy = {
        rollingUpdate = {
          maxUnavailable = 1
          maxSurge = 0
        }
      }

      # expose via static metallb IP
      service = {
        spec = {
          externalTrafficPolicy = "Local"
          loadBalancerIP = trimspace(var.traefik_ingress_ip)
        }
      }

      # disable insecure dashboard
      ingressRoute = {
        dashboard = {
          enabled = false
        }
      }

      # traefik namespace for k8s ingress as well as allowing external services
      providers = {
        kubernetesIngress = {
          publishedService = {
            pathOverride = "traefik/traefik"
          }
          allowExternalNameServices = true
        }
      }

      # allow malformed SSL self-signed certificates from IIS
      env = [
        {
          name = "GODEBUG"
          value = "x509negativeserial=1"
        }
      ]

      # enable global prometheus
      metrics = {
        prometheus = {
          serviceMonitor = {
            enabled = true
          }
        }
      }


      # better defaults, longer timeouts and more connections per node
      ports = {
        web = {
          transport = {
            respondingTimeouts = {
              readTimeout = "0s"
              writeTimeout = "0s"
              idleTimeout = "180s"
            }
          }

          http = {
            redirections = {
              entryPoint = {
                to = "websecure"
                scheme = "https"
                permanent = true
              }
            }
          }
        }

        websecure = {
          asDefault = true
          transport = {
            respondingTimeouts = {
              readTimeout = "0s"
              writeTimeout = "0s"
              idleTimeout = "180s"
            }
          }

          http = {
            middlewares = [
              "traefik-default-security-headers@kubernetescrd"
            ]
            tls = {
              options = "traefik-default-tls-profile@kubernetescrd"
            }
          }
        }
      }

      additionalArguments = [
        "--serversTransport.maxIdleConnsPerHost=256",
      ]
    })
  ]
}