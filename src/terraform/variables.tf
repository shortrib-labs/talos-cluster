variable "project_root" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "controllers" {
  type    = string
  default = 1
}

variable "workers" {
  type    = string
  default = 0
}

variable "cluster_image_name" {
  type = string
}

variable "kubernetes_cidr" {
  type        = string
  description = "CIDR for the Kubernetes management network (used for etcd and kubelet node IP)"
}

variable "load_balancer_cidr" {
  type        = string
  description = "CIDR for the workload network (used for etcd and kubelet node IP)"
}

# Cluster networking
variable "pod_cidr" {
  type        = string
  default     = "10.244.0.0/16"
  description = "IPv4 CIDR for pod network"
}

variable "pod_cidr_v6" {
  type        = string
  default     = "fd00:10:244::/48"
  description = "IPv6 CIDR for pod network"
}

variable "service_cidr" {
  type        = string
  default     = "10.96.0.0/12"
  description = "IPv4 CIDR for service network"
}

variable "service_cidr_v6" {
  type        = string
  default     = "fd00:10:96::/112"
  description = "IPv6 CIDR for service network"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 52
}

# Nutanix Authentication
variable "nutanix_username" {
  type        = string
  description = "Nutanix Prism Central username"
}

variable "nutanix_password" {
  type        = string
  description = "Nutanix Prism Central password"
  sensitive   = true
}

variable "nutanix_prism_central" {
  type        = string
  description = "Nutanix Prism Central endpoint (IP or FQDN)"
}

# Nutanix Infrastructure
variable "nutanix_cluster_name" {
  type        = string
  description = "Nutanix cluster name for VM placement"
}

variable "nutanix_storage_container" {
  type        = string
  description = "Storage container for VM disks"
}

variable "kubernetes_subnet" {
  type        = string
  description = "Nutanix subnet for Kubernetes management network"
}

variable "workload_subnet" {
  type        = string
  description = "Nutanix subnet for workload network"
}

variable "control_plane_mac" {
  type        = list(string)
  description = "MAC addresses for control plane nodes"
}

# Nutanix Files (NFS)
variable "nutanix_files_server" {
  type        = string
  description = "Nutanix Files server hostname or IP"
}

variable "nutanix_files_export" {
  type        = string
  description = "NFS export path on Nutanix Files"
}

# Tailscale
variable "tailscale_client_id" {
  type        = string
  description = "Tailscale OAuth client ID for the operator"
}

variable "tailscale_client_secret" {
  type        = string
  description = "Tailscale OAuth client secret for the operator"
  sensitive   = true
}

locals {
  vm_prefix   = var.cluster_name
  server_name = "${var.cluster_name}.${var.domain}"
  directories = {
    secrets   = "${var.project_root}/secrets"
    templates = "${var.project_root}/src/terraform/templates"
  }
}
