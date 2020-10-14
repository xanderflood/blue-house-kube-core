########################################################
### Create a Kuberenetes Service Account for Traefik ###
########################################################
resource "kubernetes_cluster_role" "fluentd" {
  metadata {
    name = "fluentd"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}
resource "kubernetes_service_account" "fluentd" {
  metadata {
    name      = "fluentd"
    namespace = "kube-system"
  }
}
resource "kubernetes_cluster_role_binding" "fluentd" {
  metadata {
    name = "fluentd"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluentd.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluentd.metadata.0.name
    namespace = "kube-system"
  }
}

#############################################
### Create one log-collector pod per node ###
#############################################
resource "kubernetes_daemonset" "logizio-fluentd" {
  metadata {
    name      = "fluentd-logzio"
    namespace = "kube-system"
    labels = {
      "k8s-app"                       = "fluentd-logzio"
      "version"                       = "v1"
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector {
      match_labels = {
        "k8s-app" = "fluentd-logzio"
      }
    }

    template {
      metadata {
        labels = {
          "k8s-app"                       = "fluentd-logzio"
          "version"                       = "v1"
          "kubernetes.io/cluster-service" = "true"
        }
      }

      spec {
        service_account_name            = kubernetes_service_account.fluentd.metadata.0.name
        automount_service_account_token = true

        toleration {
          key    = "node-role.kubernetes.io/master"
          effect = "NoSchedule"
        }

        container {
          image = "logzio/logzio-k8s:1.0.0"
          name  = "fluentd"

          resources {
            limits {
              memory = "200Mi"
            }
            requests {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          env {
            name  = "LOGZIO_TOKEN"
            value = var.logzio_token
          }
          env {
            name  = "LOGZIO_url"
            value = var.logzio_url
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }
          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }
        }

        termination_grace_period_seconds = 30

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
      }
    }
  }
}
