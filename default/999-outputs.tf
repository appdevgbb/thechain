output "jumpbox" {
  value = {
    public_ip_address = module.jumpbox.ip_address
    username          = module.jumpbox.admin_username
    ssh               = "${module.jumpbox.admin_username}@${module.jumpbox.ip_address}"
  }
}