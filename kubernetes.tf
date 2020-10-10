provider "kubernetes" {
  load_config_file = false
}
provider "kubernetes-alpha" {}

terraform {
  backend "kubernetes" {
    secret_suffix     = "kube-system"
    in_cluster_config = true
  }
}
