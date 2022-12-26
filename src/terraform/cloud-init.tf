data "carvel_ytt" "user_data" {
  files = [
    "${var.project_root}/src/cloud-init"
  ]
  values = {
    "domain" = var.domain
    "ssh.authorized_key" = var.ssh_authorized_keys.0
  }

  ignore_unknown_comments = true
}
