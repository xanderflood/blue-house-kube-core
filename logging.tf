resource "kubernetes_daemonset" "logizio-fluentd" {
  metadata {
    name      = "fluentd-logzio"
    namespace = "kube-system"
    labels = {
      k8s-app                         = "fluentd-logzio"
      version                         = "v1"
      kubernetes.io / cluster-service = "true"
    }
  }

  spec {
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
