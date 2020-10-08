resource "kubernetes_namespace" "drone" {
  metadata {
    name = "drone"
  }
}

#####################################################
### Create a role for the drone server and runner ###
#####################################################
resource "kubernetes_cluster_role" "drone" {
  metadata {
    name = "drone"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "create", "delete", "list", "watch", "update"]
  }
}
resource "kubernetes_service_account" "drone" {
  metadata {
    name      = "drone"
    namespace = "drone"
  }
}
resource "kubernetes_cluster_role_binding" "drone" {
  metadata {
    name = "drone"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.drone.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.drone.metadata.0.name
    namespace = "drone"
  }
}

###############################
### Deploy the drone server ###
###############################
resource "random_password" "drone_rpc_secret" {
  length = 128
}
resource "kubernetes_deployment" "drone-server" {
  metadata {
    name      = "drone-server"
    namespace = "drone"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "drone-server"
      }
    }

    template {
      metadata {
        namespace = "drone"
        labels    = { app = "drone-server" }
      }

      spec {
        service_account_name            = kubernetes_service_account.drone.metadata.0.name
        automount_service_account_token = true

        container {
          image = "drone/drone:1.9.0"
          name  = "drone"

          env {
            name  = "DRONE_AGENTS_ENABLED"
            value = "true"
          }
          env {
            name  = "DRONE_GITHUB_SERVER"
            value = "https://github.com"
          }
          env {
            name  = "DRONE_GITHUB_CLIENT_ID"
            value = var.drone_github_client_id
          }
          env {
            name  = "DRONE_GITHUB_CLIENT_SECRET"
            value = var.drone_github_client_secret
          }
          env {
            name  = "DRONE_RPC_SECRET"
            value = random_password.drone_rpc_secret.result
          }
          env {
            name  = "DRONE_SERVER_HOST"
            value = local.drone_webhook_domain
            # TODO remove? value = "infra.${var.services_domain}"
          }
          env {
            name  = "DRONE_SERVER_PROTO"
            value = "https"
          }
          env {
            name  = "DRONE_USER_CREATE"
            value = "username:${var.drone_initial_admin_github_username},admin:true"
          }

          port {
            name           = "web"
            container_port = 80
          }

          volume_mount {
            mount_path = "/data"
            name       = "data"
          }
        }

        volume {
          name = "data"
          host_path {
            path = "/var/run/drone-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

####################################
### Ingress for the drone server ###
####################################
resource "kubernetes_service" "drone" {
  metadata {
    name      = "drone"
    namespace = "drone"
  }

  spec {
    selector = {
      app = "drone-server"
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }
  }
}
resource "kubernetes_ingress" "drone" {
  metadata {
    name      = "drone"
    namespace = "drone"
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"

      "traefik.ingress.kubernetes.io/router.entrypoints"        = "web-secure"
      "traefik.ingress.kubernetes.io/router.tls.certresolver"   = "main"
      "traefik.ingress.kubernetes.io/router.tls.domains.0.main" = "infra.${var.services_domain}"

      # TODO configure SANs for TLS
      # "traefik.ingress.kubernetes.io/router.tls.domains.0.sans" = "dashboard.${san}"
    }
  }

  spec {
    rule {
      host = "infra.${var.services_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.drone.metadata.0.name
            service_port = 80
          }
        }
      }
    }
  }
}

########################################################
### A namespace and ServiceAccount for the TF builds ###
########################################################
resource "kubernetes_namespace" "terraform" {
  metadata {
    name = "terraform"
  }
}
resource "kubernetes_cluster_role_binding" "terraform" {
  metadata {
    name = "terraform"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "terraform"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "terraform"
  }
}

###############################
### Deploy the drone runner ###
###############################
resource "kubernetes_deployment" "drone-runner" {
  metadata {
    name      = "drone-runner"
    namespace = "drone"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "drone-runner"
      }
    }

    template {
      metadata {
        namespace = "drone"
        labels    = { app = "drone-runner" }
      }

      spec {
        service_account_name            = kubernetes_service_account.drone.metadata.0.name
        automount_service_account_token = true

        container {
          image = "drone/drone-runner-kube:latest"
          name  = "drone"

          env {
            name  = "DRONE_RPC_HOST"
            value = "drone.drone.svc.cluster.local"
          }

          env {
            name  = "DRONE_RPC_PROTO"
            value = "http"
          }
          env {
            name  = "DRONE_RPC_SECRET"
            value = random_password.drone_rpc_secret.result
          }
          env {
            name  = "DRONE_NAMESPACE_DEFAULT"
            value = "terraform"
          }
          env {
            # For some reason, the pods launched by Drone aren't getting these
            # two variables set. These variables are used by Terraform to detect
            # and in-cluster environment.
            name  = "DRONE_RUNNER_ENVIRON"
            value = "KUBERNETES_SERVICE_HOST:${var.kubernetes_service_host},KUBERNETES_SERVICE_PORT:${var.kubernetes_service_port}"
          }

          port {
            container_port = 3000
          }
        }
      }
    }
  }
}
