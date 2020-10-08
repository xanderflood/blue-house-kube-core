provider "kubernetes" {
  # load_config_file = false
  config_context = "blue-house"
}
provider "kubernetes-alpha" {
  config_path    = "~/.kube/config"
  config_context = "blue-house"
}

terraform {
  backend "kubernetes" {
    secret_suffix    = "kube-system"
    load_config_file = true
    config_context   = "blue-house"
    # in_cluster_config = true
  }
}
