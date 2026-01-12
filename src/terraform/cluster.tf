# Talos cluster configuration

locals {
  # Cluster network config patch - IPv4 only
  cluster_network_patch = yamlencode({
    cluster = {
      network = {
        podSubnets     = [var.pod_cidr]
        serviceSubnets = [var.service_cidr]
      }
      apiServer = {
        certSANs = [local.server_name]
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
