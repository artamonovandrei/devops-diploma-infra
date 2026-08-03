variable "project_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "jenkins_home_volume_id" {
  description = "Istniejący EBS z /var/lib/jenkins (po pause). Puste = utwórz nowy."
  type        = string
  default     = ""
}

variable "jenkins_home_volume_size_gb" {
  type    = number
  default = 20
}
