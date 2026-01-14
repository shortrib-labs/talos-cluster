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
  yaml_body = file("manifests/metallb-config/l2advertisement.yaml")
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

  set = [
    {
      name = "crds.enabled"
      type = "auto"
      value = true
    }
  ]
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

  set = [
    {
      name = "crds.enabled"
      type = "auto"
      value = true
    }
  ]
}

resource "kubectl_manifest" "shortrib-clusterissuer" {
  yaml_body = file("manifests/acme/00-shortrib-clusterissuer.yaml")
  depends_on = [helm_release.cert-manager]
}

resource "kubectl_manifest" "letsencrypt-clusterissuer" {
  yaml_body = file("manifests/acme/01-letsencrypt-clusterissuer.yaml")
  depends_on = [helm_release.cert-manager]
}

# NFS CSI Driver (for Nutanix Files)
resource "helm_release" "csi-driver-nfs" {
  name             = "csi-driver-nfs"
  repository       = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart            = "csi-driver-nfs"
  namespace        = "kube-system"
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  depends_on = [data.talos_cluster_health.this]
}

resource "kubectl_manifest" "nfs-storageclass" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: nutanix-files
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: nfs.csi.k8s.io
    parameters:
      server: ${var.nutanix_files_server}
      share: ${var.nutanix_files_export}
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
    mountOptions:
      - nfsvers=4.1
  YAML

  depends_on = [helm_release.csi-driver-nfs]
}


