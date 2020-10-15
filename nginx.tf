####################################
### Reverse proxy the hostports  ###
####################################
resource "kubernetes_config_map" "nginx" {
  metadata {
    name      = "nginx"
    namespace = "kube-system"
  }

  data = {
    "nginx.conf" = <<EOT
events {}

stream {
  server {
    listen     80;
    proxy_pass traefik.kube-system.svc.cluster.local:80;
  }

  server {
    listen     443;
    proxy_pass traefik.kube-system.svc.cluster.local:443;
  }
}
EOT
  }
}
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = "kube-system"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          image = "nginx:1.19.3"
          name  = "nginx"

          # NOTE: Kubernetes _services_ can't claim node ports below 30000 without
          # special privileges, but deployments can, so we specify the host port
          # here. If we later have multiple nodes, wel'l need to make sure Traefik
          # runs as a DaemonSet, so it can take traefik on all nodes.
          port {
            name           = "web"
            container_port = 80
            host_port      = 80
          }
          port {
            name           = "web-secure"
            container_port = 443
            host_port      = 443
          }

          volume_mount {
            mount_path = "/etc/nginx/nginx.conf"
            name       = "config"
            sub_path   = "nginx.conf"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.nginx.metadata.0.name
          }
        }
      }
    }
  }
}
