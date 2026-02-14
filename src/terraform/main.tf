# Nutanix cluster reference using v1 API (more compatible)
data "nutanix_cluster" "cluster" {
  name = var.nutanix_cluster_name
}

# Kubernetes management network using v1 API
data "nutanix_subnet" "kubernetes_subnet" {
  subnet_name = var.kubernetes_subnet
}

# Workload network using v1 API
data "nutanix_subnet" "workload_subnet" {
  subnet_name = var.workload_subnet
}

# Talos Linux ISO for cluster nodes
data "nutanix_image" "talos_iso" {
  image_name = var.cluster_image_name
}

# Wait for DHCP to assign IPs to VMs before querying them
resource "time_sleep" "wait_for_dhcp" {
  depends_on = [
    nutanix_virtual_machine.control_plane,
    nutanix_virtual_machine.worker
  ]
  create_duration = "90s"
}
