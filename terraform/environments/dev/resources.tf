locals {
  common_tags = {
    Project = var.project_name
  }
}

module "network" {
  source = "../../modules/network"

  project_name   = var.project_name
  aws_region     = var.aws_region
  admin_cidr     = var.admin_cidr
  ssh_public_key = var.ssh_public_key
  tags           = local.common_tags
}

module "jenkins" {
  source = "../../modules/ec2-jenkins"

  project_name                = var.project_name
  instance_type               = var.jenkins_instance_type
  subnet_id                   = module.network.public_subnet_id
  security_group_ids          = [module.network.jenkins_security_group_id]
  key_name                    = module.network.key_name
  tags                        = local.common_tags
  jenkins_home_volume_id      = var.jenkins_home_volume_id
  jenkins_home_volume_size_gb = var.jenkins_home_volume_size_gb
}

module "k3s" {
  source = "../../modules/ec2-k3s"

  project_name       = var.project_name
  instance_type      = var.k3s_instance_type
  subnet_id          = module.network.public_subnet_id
  security_group_ids = [module.network.k3s_security_group_id]
  key_name           = module.network.key_name
  tags               = local.common_tags
}

# Terraform state bucket is created once via terraform/bootstrap (S3 backend)
