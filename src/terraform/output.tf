output "control_plane_ips" {
  value = [
    for controller in data.nutanix_virtual_machine.control_plane :
    controller.nic_list[0].ip_endpoint_list[0].ip
  ]
  description = "IP addresses of control plane nodes"
}

output "worker_ips" {
  value = [
    for worker in data.nutanix_virtual_machine.worker :
    worker.nic_list[0].ip_endpoint_list[0].ip
  ]
  description = "IP addresses of worker nodes"
}

output "talosconfig" {
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
  description = "Talos client configuration for talosctl"
}

output "kubeconfig" {
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
  description = "Kubernetes kubeconfig for cluster access"
}
