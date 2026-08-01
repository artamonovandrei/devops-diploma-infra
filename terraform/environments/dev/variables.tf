variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "devops-diploma"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR notation (e.g. 1.2.3.4/32)"
  type        = string
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key file"
  type        = string
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.small"
}

variable "k3s_instance_type" {
  type    = string
  default = "t3.small"
}
