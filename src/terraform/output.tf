output "password" {
  value     = random_pet.default_password.id
  sensitive = true
}

output "node_ip" {
  value     = vsphere_virtual_machine.node.default_ip_address
}
