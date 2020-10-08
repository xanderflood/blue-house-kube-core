# This file informs Kubernetes about the custom Kubernetes
# resources that are controlled by Traefik, allowing us
# to manipulate them through the K8s API. Since The K8s
# Terraform provider doesn't support CRDs _or_ the resources
# declared by them, we need to use the kubernetes-alpha
# Terraform provider.

resource "kubernetes_manifest" "traefik_ingress_route_http_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutes.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRoute
    plural: ingressroutes
    singular: ingressroute
  scope: Namespaced
EOT
  )
}

resource "kubernetes_manifest" "traefik_ingress_route_tcp_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutetcps.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteTCP
    plural: ingressroutetcps
    singular: ingressroutetcp
  scope: Namespaced
EOT
  )
}

resource "kubernetes_manifest" "traefik_middleware_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: middlewares.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: Middleware
    plural: middlewares
    singular: middleware
  scope: Namespaced
EOT
  )
}

resource "kubernetes_manifest" "traefik_ingress_route_udp_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressrouteudps.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteUDP
    plural: ingressrouteudps
    singular: ingressrouteudp
  scope: Namespaced
EOT
  )
}

resource "kubernetes_manifest" "traefik_tls_option_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsoptions.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSOption
    plural: tlsoptions
    singular: tlsoption
  scope: Namespaced
EOT
  )
}

resource "kubernetes_manifest" "traefik_tls_store_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsstores.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSStore
    plural: tlsstores
    singular: tlsstore
  scope: Namespaced
EOT
  )
}

resource "kubernetes_manifest" "traefik_traefik_service_crd" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: traefikservices.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TraefikService
    plural: traefikservices
    singular: traefikservice
  scope: Namespaced
EOT
  )
}
