########################################################
### Create a Kuberenetes Service Account for Traefik ###
########################################################
resource "kubernetes_cluster_role" "traefik" {
  metadata {
    name = "traefik-ingress-controller"
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "secrets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }
  rule {
    api_groups = ["traefik.containo.us"]
    resources = [
      "middlewares",
      "ingressroutes",
      "traefikservices",
      "ingressroutetcps",
      "ingressrouteudps",
      "tlsoptions",
      "tlsstores",
    ]
    verbs = ["get", "list", "watch"]
  }
}
resource "kubernetes_service_account" "traefik" {
  metadata {
    name      = "traefik-ingress-controller"
    namespace = "kube-system"
  }
}
resource "kubernetes_cluster_role_binding" "traefik" {
  metadata {
    name = "traefik-ingress-controller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.traefik.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.traefik.metadata.0.name
    namespace = "kube-system"
  }
}

#################################################
### Create mountable config files for Traefik ###
#################################################
resource "random_password" "admin_basic_auth" {
  length  = 64
  special = false
}
resource "kubernetes_config_map" "traefik-static" {
  metadata {
    name      = "traefik-static"
    namespace = "kube-system"
  }

  data = {
    "traefik.toml" = templatefile(
      "templates/traefik.toml",
      {
        lets_encrypt_email = var.lets_encrypt_email
      },
    )
  }
}
resource "null_resource" "encrypted_admin_password" {
  triggers = {
    pw = bcrypt(random_password.admin_basic_auth.result)
  }

  lifecycle {
    ignore_changes = [triggers]
  }
}
resource "kubernetes_config_map" "traefik-dynamic" {
  metadata {
    name      = "traefik-dynamic"
    namespace = "kube-system"
  }

  data = {
    "traefik.dynamic.toml" = templatefile(
      "templates/traefik.dynamic.toml",
      {
        admin_basic_auth_enrcypted_password = null_resource.encrypted_admin_password.triggers["pw"]
        api_gateway_url                     = "http://api-gateway.api-gateway.svc.cluster.local"
      }
    )
  }
}

###################################################################
### Launch the actual Traefik containers and bind to host ports ###
###################################################################
locals {
  # We want to trigger a Kubernetes roll-out each time the static
  # config file is updated
  traefik_restart_trigger = md5(kubernetes_config_map.traefik-static.data["traefik.toml"])
}

resource "kubernetes_deployment" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "kube-system"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "traefik"
      }
    }

    template {
      metadata {
        labels      = { app = "traefik" }
        annotations = { "${var.services_domain}/trigger" = local.traefik_restart_trigger }
      }

      spec {
        service_account_name            = kubernetes_service_account.traefik.metadata.0.name
        automount_service_account_token = true

        container {
          image = "traefik:v2.2"
          name  = "traefik"

          # NOTE: Kubernetes _services_ can't claim node ports below 30000 without
          # special privileges, but deployments can, so we specify the host port
          # here. If we later have multiple nodes, wel'l need to make sure Traefik
          # runs as a DaemonSet, so it can take traefik on all nodes.
          port {
            name           = "web"
            container_port = 80
          }
          port {
            name           = "web-secure"
            container_port = 443
          }

          port {
            name           = "dashboard"
            container_port = 8080
          }

          volume_mount {
            mount_path = "/acme"
            name       = "acme"
          }
          volume_mount {
            mount_path = "/traefik.toml"
            name       = "traefik-static"
            sub_path   = "traefik.toml"
          }
          volume_mount {
            mount_path = "/traefik.dynamic.toml"
            name       = "traefik-dynamic"
            sub_path   = "traefik.dynamic.toml"
          }
        }

        volume {
          name = "acme"
          host_path {
            path = "/var/run/traefik-acme"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "traefik-static"
          config_map {
            name = kubernetes_config_map.traefik-static.metadata.0.name
          }
        }
        volume {
          name = "traefik-dynamic"
          config_map {
            name = kubernetes_config_map.traefik-dynamic.metadata.0.name
          }
        }
      }
    }
  }
}

###############################################################
### Create Traefik ingress for the Traefik dashboard itself ###
###############################################################
resource "kubernetes_service" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "kube-system"
  }

  spec {
    selector = {
      app = "traefik"
    }
    session_affinity = "ClientIP"
    port {
      name = "http"
      port = 80
    }
    port {
      name = "https"
      port = 443
    }
    port {
      name = "dashboard"
      port = 8080
    }
  }
}
resource "kubernetes_ingress" "traefik-dashboard" {
  metadata {
    name      = "traefik-dashboard"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"

      "traefik.ingress.kubernetes.io/router.entrypoints" = "web-secure"
      "traefik.ingress.kubernetes.io/router.middlewares" = "admin-auth@file"
    }
  }

  spec {
    rule {
      host = "dashboard.${var.services_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.traefik.metadata.0.name
            service_port = 8080
          }
        }
      }
    }
  }
}
