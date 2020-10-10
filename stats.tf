resource "kubernetes_namespace" "stats" {
  metadata {
    name = "stats"
  }
}

# TODO
# helm upgrade --namespace stats --install loki loki/loki-stack \
# --set fluent-bit.enabled=true,promtail.enabled=false,grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false

# resource "helm_release" "loki" {
#   name       = "loki"
#   namespace  = kubernetes_namespace.stats.metadata.0.name
#   repository = "https://grafana.github.io/loki/charts"
#   chart      = "loki/loki-stack"
#   # version    = "0.41.1"

#   # set {
#   #   name  = "fluent-bit.enabled"
#   #   value = true
#   # }
#   # set {
#   #   name  = "promtail.enabled"
#   #   value = false
#   # }
#   # set {
#   #   name  = "grafana.enabled"
#   #   value = true
#   # }
#   # set {
#   #   name  = "prometheus.enabled"
#   #   value = true
#   # }
#   # set {
#   #   name  = "prometheus.alertmanager.persistentVolume.enabled"
#   #   value = false
#   # }
#   # set {
#   #   name  = "prometheus.server.persistentVolume.enabled"
#   #   value = false
#   # }
# }

resource "kubernetes_ingress" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.stats.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"

      "traefik.ingress.kubernetes.io/router.entrypoints" = "web-secure"
    }
  }

  spec {
    rule {
      host = "grafana.${var.services_domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = "loki-grafana"
            service_port = 80
          }
        }
      }
    }
  }
}

data "kubernetes_secret" "grafana_password" {
  metadata {
    name      = "loki-grafana"
    namespace = "stats"
  }
}

output "grafana_password" {
  value = base64decode(data.kubernetes_secret.grafana_password.data["admin-password"])
}
