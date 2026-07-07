# Cluster addons installed via Helm

# MetalLB namespace - needs privileged PodSecurity for speaker pods
resource "kubectl_manifest" "metallb" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: metallb
      labels:
        pod-security.kubernetes.io/enforce: privileged
        pod-security.kubernetes.io/warn: privileged
        pod-security.kubernetes.io/audit: privileged
  YAML

  depends_on = [data.talos_cluster_health.this]
}

# MetalLB - Load Balancer for bare metal
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb"
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  depends_on = [kubectl_manifest.metallb]
}

resource "kubectl_manifest" "l2_advertisement" {
  yaml_body  = file("manifests/metallb-config/l2advertisement.yaml")
  depends_on = [helm_release.metallb]
}

resource "kubectl_manifest" "ipaddresspool" {
  yaml_body = templatefile("${local.directories.templates}/default-ipaddresspool.yaml.tftpl",
    {
      load_balancer_cidr = var.load_balancer_cidr
    }
  )

  depends_on = [helm_release.metallb]
}

# Traefik
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "oci://ghcr.io/traefik/helm"
  chart            = "traefik"
  namespace        = "traefik"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
}


# cert-manager
resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [<<-YAML
    crds:
      enabled: true
  YAML
  ]
}

resource "kubectl_manifest" "shortrib-clusterissuer" {
  yaml_body  = file("manifests/acme/00-shortrib-clusterissuer.yaml")
  depends_on = [helm_release.cert-manager]
}

resource "kubectl_manifest" "letsencrypt-clusterissuer" {
  yaml_body  = file("manifests/acme/01-letsencrypt-clusterissuer.yaml")
  depends_on = [helm_release.cert-manager]
}

resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  namespace        = "tailscale"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [<<-YAML
    operatorConfig:
      hostname: ${var.cluster_name}-operator
    oauth:
      clientId: ${var.tailscale_client_id}
      clientSecret: ${var.tailscale_client_secret}
    apiServerProxyConfig:
      mode: "true"
  YAML
  ]

  depends_on = [data.talos_cluster_health.this]
}

locals {
  # The CSI driver runs whenever a filer address is set. Mutual gRPC TLS is
  # layered on when a pre-issued client cert is supplied. The seaweed CA lives
  # on the storage cluster; this cluster only holds a client cert it presents.
  seaweedfs_enabled         = var.seaweedfs_filer_address != ""
  seaweedfs_tls_secret_name = "seaweedfs-csi-tls"

  seaweedfs_use_tls = (
    local.seaweedfs_enabled &&
    var.seaweedfs_client_tls_crt != "" &&
    var.seaweedfs_client_tls_key != "" &&
    var.seaweedfs_client_ca_crt != ""
  )
}

# Pre-issued client cert for mutual gRPC TLS, signed by the seaweed CA on the
# storage cluster. ca.crt and tls.crt are public; tls.key is SOPS-encrypted.
# Params hold raw PEM; the Makefile base64-encodes each (yq @base64) so these
# values drop straight into the Secret's data.
resource "kubectl_manifest" "seaweedfs_client_tls" {
  count = local.seaweedfs_use_tls ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: ${local.seaweedfs_tls_secret_name}
      namespace: kube-system
    type: Opaque
    data:
      ca.crt: ${var.seaweedfs_client_ca_crt}
      tls.crt: ${var.seaweedfs_client_tls_crt}
      tls.key: ${var.seaweedfs_client_tls_key}
  YAML

  depends_on = [data.talos_cluster_health.this]
}

# SeaweedFS CSI driver - provides RWX (ReadWriteMany) volumes backed by an
# external SeaweedFS filer running on a separate storage cluster. The SeaweedFS
# servers and operator live on that storage cluster, not here; this cluster is
# only a consumer. Skipped entirely unless a filer address is configured.
#
# Runs in kube-system: the node and mount DaemonSets are privileged (FUSE +
# hostPID), and kube-system is not Pod-Security enforced. Provides the default
# "seaweedfs" StorageClass (SeaweedFS replaces the removed Nutanix Files/NFS).
#
# With TLS enabled, the driver presents the client cert for mutual gRPC TLS to
# the filer (WEED_GRPC_CLIENT_CERT/KEY/CA), reading tls.crt/tls.key/ca.crt from
# the secret above.
resource "helm_release" "seaweedfs_csi_driver" {
  count = local.seaweedfs_enabled ? 1 : 0

  name          = "seaweedfs-csi-driver"
  repository    = "https://seaweedfs.github.io/seaweedfs-csi-driver/helm"
  chart         = "seaweedfs-csi-driver"
  namespace     = "kube-system"
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [yamlencode(merge(
    {
      seaweedfsFiler        = var.seaweedfs_filer_address
      storageClassName      = "seaweedfs"
      isDefaultStorageClass = true
    },
    local.seaweedfs_use_tls ? { tlsSecret = local.seaweedfs_tls_secret_name } : {}
  ))]

  depends_on = [data.talos_cluster_health.this, kubectl_manifest.seaweedfs_client_tls]
}
