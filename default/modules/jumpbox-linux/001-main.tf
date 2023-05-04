locals {
  prefix    = var.prefix
  suffix    = var.suffix
  workspace = terraform.workspace

  hostname = "${local.prefix}${local.workspace}${local.suffix}"
}

data "http" "myip" {
  url = "https://api.ipify.org/"
}