data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_resource_pool" "resource_pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_host" "host" {
  name          = var.vsphere_host
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

resource "random_pet" "default_password" {
  length = 4
}

locals {
  user_data = <<-DATA
  #cloud-config
  ${data.carvel_ytt.user_data.result}
  DATA
}

resource "vsphere_virtual_machine" "node" {
  name             = local.server_name
  datacenter_id    = data.vsphere_datacenter.datacenter.id
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  host_system_id   = data.vsphere_host.host.id
  folder           = var.vsphere_folder

  num_cpus = var.cpus
  memory   = var.memory
  guest_id = "ubuntu64Guest"

  network_interface {
    network_id     = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    unit_number      = 0

    thin_provisioned = true
  }

  cdrom {
    client_device = true
  }

  vapp {
    properties = {
      "instance-id" = "id-${var.hostname}"
      "hostname"    = local.server_name
      "password"    = random_pet.default_password.id
      "user-data"   = base64encode(local.user_data)
    }
  }

  ovf_deploy { 
    remote_ovf_url = var.remote_ovf_url 
    allow_unverified_ssl_cert = true

    ip_protocol          = "IPV4"
    ip_allocation_policy = "DHCP"
    disk_provisioning    = "thin"
  }

  extra_config = {
    "isolation.tools.copy.disable"         = false
    "isolation.tools.paste.disable"        = false
    "isolation.tools.SetGUIOptions.enable" = true
  }

  provisioner "remote-exec" { 
    inline = [ 
      var.kurl_script, 
      "echo '# limit who can use SSH\nAllowGroups ssher' | sudo tee /etc/ssh/sshd_config.d/02-limit-to-ssher.conf"
    ] 
    connection {
      user = "ubuntu"
      host = self.default_ip_address
    }
  }
}

