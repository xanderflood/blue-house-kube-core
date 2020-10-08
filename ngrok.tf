locals {
  drone_webhook_domain = "${var.drone_ngrok_subdomain}.ngrok.io"
}

resource "kubernetes_deployment" "drone-webhook-proxy" {
  metadata {
    name      = "drone-webhook-proxy"
    namespace = "drone"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "drone-webhook-proxy"
      }
    }

    template {
      metadata {
        namespace = "drone"
        labels    = { app = "drone-webhook-proxy" }
      }

      spec {
        container {
          image = "wernight/ngrok"
          name  = "drone"

          command = [
            "ngrok", "http", "http://drone-server:80",
            "--subdomain", var.drone_ngrok_subdomain,
            "--authtoken", var.ngrok_auth_token,
            "--log-format", "json",
          ]
        }
      }
    }
  }
}
