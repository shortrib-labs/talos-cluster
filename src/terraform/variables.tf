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

variable "control_plane_cidr" {
  type        = string
  description = "IPv4 CIDR for control plane nodes"
}

variable "control_plane_cidr_v6" {
  type        = string
  default     = ""
  description = "IPv6 CIDR for control plane nodes (optional)"
}

variable "load_balancer_cidr" {
  type = string
}

variable "load_balancer_cidr_v6" {
  type        = string
  default     = ""
  description = "IPv6 CIDR for load balancer addresses (optional)"
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

# cert-manager / ACME configuration
variable "acme_email" {
  type        = string
  description = "Email address for ACME certificate notifications"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token for DNS-01 challenges"
  sensitive   = true
}

locals {
  vm_prefix   = var.cluster_name
  server_name = "${var.cluster_name}.${var.domain}"
  directories = {
    secrets   = "${var.project_root}/secrets"
    manifests = "${var.project_root}/manifests"
    templates = "${path.module}/templates"
    work      = "${var.project_root}/work"
  }
}
