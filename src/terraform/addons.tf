# Cluster addons installed via Helm and Kubernetes manifests

# =============================================================================
# MetalLB - Load Balancer for bare metal
# =============================================================================

resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  depends_on = [talos_cluster_kubeconfig.this]
}

# MetalLB configuration - deployed as a separate release after CRDs are ready
resource "time_sleep" "wait_for_metallb_crds" {
  depends_on      = [helm_release.metallb]
  create_duration = "30s"
}

resource "helm_release" "metallb_config" {
  name       = "metallb-config"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  namespace  = "metallb"
  wait       = true
  timeout    = 300

  # Skip deploying the controller/speaker, just apply the CRs
  set {
    name  = "controller.enabled"
    value = "false"
  }

  set {
    name  = "speaker.enabled"
    value = "false"
  }

  # Configure IPAddressPool and L2Advertisement via values
  values = [
    yamlencode({
      ipAddressPools = [{
        name = "default"
        spec = {
          addresses = compact([var.load_balancer_cidr, var.load_balancer_cidr_v6])
        }
      }]
      l2Advertisements = [{
        name = "default"
        spec = {
          ipAddressPools = ["default"]
        }
      }]
    })
  ]

  depends_on = [time_sleep.wait_for_metallb_crds]
}

# =============================================================================
# Contour - Ingress Controller
# =============================================================================

resource "helm_release" "contour" {
  name             = "contour"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "contour"
  namespace        = "projectcontour"
  create_namespace = true
  wait             = true
  timeout          = 600

  depends_on = [helm_release.metallb_config]
}

# =============================================================================
# cert-manager - TLS Certificate Management
# =============================================================================

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [helm_release.contour]
}

# Wait for cert-manager CRDs and webhooks to be ready
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# Cloudflare API token secret for DNS-01 challenges
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  depends_on = [time_sleep.wait_for_cert_manager]
}

# Let's Encrypt ClusterIssuer (staging - uses DNS-01 with Cloudflare)
resource "kubectl_manifest" "letsencrypt_clusterissuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-clusterissuer"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = "cloudflare-api-token"
                key  = "api-token"
              }
            }
          }
        }]
      }
    }
  })

  depends_on = [kubernetes_secret.cloudflare_api_token]
}

# Internal ACME ClusterIssuer (shortrib)
resource "kubectl_manifest" "shortrib_clusterissuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "shortrib-clusterissuer"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://certificates.shortrib.run/acme/acme/directory"
        caBundle = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJwRENDQVVxZ0F3SUJBZ0lRTXJqR2J2ZHp5RDYzL1dyRWlvYjI4REFLQmdncWhrak9QUVFEQWpBZ01SNHcKSEFZRFZRUURFeFZUYUc5eWRISnBZaUJNWVdKeklGSnZiM1FnUlRFd0hoY05Nakl3TlRBMk1ERXdOelV3V2hjTgpNekl3TlRBek1ERXdOelV3V2pBZ01SNHdIQVlEVlFRREV4VlRhRzl5ZEhKcFlpQk1ZV0p6SUZKdmIzUWdSVEV3CldUQVRCZ2NxaGtqT1BRSUJCZ2dxaGtqT1BRTUJCd05DQUFTSDN4ak1YMnhzbkRaN0cwZHh1VnVub0g3WlQ0cU8KeU53UWZZdk1JL1ppdXZOVjhLeVlMcXJjRDRjaWdpdVZXbWp2U0FxVDVUT2tJY0Q4czEwaVdaU0tvMll3WkRBTwpCZ05WSFE4QkFmOEVCQU1DQVFZd0VnWURWUjBUQVFIL0JBZ3dCZ0VCL3dJQkFUQWRCZ05WSFE0RUZnUVU2cW1qCklzeGowOEtzNW9NNGpOZk51LzBReGhjd0h3WURWUjBqQkJnd0ZvQVU2cW1qSXN4ajA4S3M1b000ak5mTnUvMFEKeGhjd0NnWUlLb1pJemowRUF3SURTQUF3UlFJZ0NzOWJNOEF4OFJuUHVIWldyZ1pvZGYvdko2ZGNlN09GZU9acgptZEhlS1A4Q0lRQy9LTE51U2NkOUZmcGF6RHpBWllZUEhSOXZuRFdDa1lzSisyTmFpS2RPZXc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
        privateKeySecretRef = {
          name = "shortrib-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              ingressClassName = "contour"
            }
          }
        }]
      }
    }
  })

  depends_on = [time_sleep.wait_for_cert_manager]
}

# =============================================================================
# Nutanix CSI - Storage Provisioning
# =============================================================================

resource "helm_release" "nutanix_csi" {
  name       = "nutanix-csi-storage"
  repository = "https://nutanix.github.io/helm-releases"
  chart      = "nutanix-csi-storage"
  version    = "3.3.9"
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  set {
    name  = "prismEndPoint"
    value = var.nutanix_prism_central
  }

  set_sensitive {
    name  = "username"
    value = var.nutanix_username
  }

  set_sensitive {
    name  = "password"
    value = var.nutanix_password
  }

  set {
    name  = "storageContainer"
    value = var.nutanix_storage_container
  }

  set {
    name  = "storageClass.isDefault"
    value = "true"
  }

  depends_on = [talos_cluster_kubeconfig.this]
}
