# Talos cluster configuration

locals {
  # Build subnet lists, filtering out empty IPv6 values
  pod_subnets     = compact([var.pod_cidr, var.pod_cidr_v6])
  service_subnets = compact([var.service_cidr, var.service_cidr_v6])

  # Cluster network config patch
  cluster_network_patch = yamlencode({
    cluster = {
      network = {
        podSubnets     = local.pod_subnets
        serviceSubnets = local.service_subnets
      }
      apiServer = {
        certSANs = compact([local.server_name])
      }
    }
    machine = {
      kubelet = {
        nodeIP = {
          validSubnets = compact([var.control_plane_cidr, var.control_plane_cidr_v6])
        }
      }
    }
  })

  # Machine features patch (enable host DNS)
  machine_features_patch = yamlencode({
    machine = {
      features = {
        hostDNS = {
          enabled              = true
          forwardKubeDNSToHost = true
        }
      }
    }
  })
}

# Generate Talos machine secrets
resource "talos_machine_secrets" "this" {}

# Generate control plane machine configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.server_name}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

# Generate worker machine configuration
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.server_name}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

# Generate client configuration for talosctl
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for vm in data.nutanix_virtual_machine.control_plane : vm.nic_list[0].ip_endpoint_list[0].ip]
}

# Apply configuration to control plane nodes
resource "talos_machine_configuration_apply" "controlplane" {
  count                       = var.controllers
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = data.nutanix_virtual_machine.control_plane[count.index].nic_list[0].ip_endpoint_list[0].ip
  config_patches = [
    local.cluster_network_patch,
    local.machine_features_patch,
    yamlencode({
      machine = {
        install = { disk = "/dev/sda" }
      }
    })
  ]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  count                       = var.workers
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = data.nutanix_virtual_machine.worker[count.index].nic_list[0].ip_endpoint_list[0].ip
  config_patches = [
    local.cluster_network_patch,
    local.machine_features_patch,
    yamlencode({
      machine = {
        install = { disk = "/dev/sda" }
      }
    })
  ]
}

# Bootstrap the first control plane node
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.nutanix_virtual_machine.control_plane[0].nic_list[0].ip_endpoint_list[0].ip
}

# Retrieve kubeconfig after bootstrap
resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.nutanix_virtual_machine.control_plane[0].nic_list[0].ip_endpoint_list[0].ip
}

# Nutanix CSI configuration
resource "local_sensitive_file" "nutanix_csi_secret" {
  content = templatefile("${local.directories.templates}/nutanix-csi-secret.yaml.tftpl", {
    prism_endpoint    = var.nutanix_prism_central
    nutanix_username  = var.nutanix_username
    nutanix_password  = var.nutanix_password
    storage_container = var.nutanix_storage_container
  })
  filename        = "${local.directories.work}/manifests/01-nutanix-csi-secret.yaml"
  file_permission = "0600"
}

resource "local_sensitive_file" "nutanix_storageclass" {
  content = templatefile("${local.directories.templates}/nutanix-storageclass.yaml.tftpl", {
    storage_container = var.nutanix_storage_container
  })
  filename        = "${local.directories.work}/manifests/02-nutanix-storageclass.yaml"
  file_permission = "0600"
}

resource "local_sensitive_file" "ip_address_pool" {
  content = templatefile("${local.directories.templates}/default-ipaddresspool.yaml.tftpl",
    {
      load_balancer_cidr = var.load_balancer_cidr
    }
  )
  filename = "${local.directories.work}/manifests/00-default-ipaddresspool.yaml"
}
