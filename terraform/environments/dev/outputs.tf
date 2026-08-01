output "jenkins_public_ip" {
  description = "Public IP of Jenkins EC2"
  value       = module.jenkins.public_ip
}

output "k3s_public_ip" {
  description = "Public IP of k3s EC2"
  value       = module.k3s.public_ip
}

output "jenkins_private_ip" {
  value = module.jenkins.private_ip
}

output "k3s_private_ip" {
  value = module.k3s.private_ip
}

output "terraform_state_bucket" {
  value = "devops-diploma-terraform-state"
}

output "ssh_command_jenkins" {
  value = "ssh -i ~/.ssh/devops-diploma ubuntu@${module.jenkins.public_ip}"
}

output "ssh_command_k3s" {
  value = "ssh -i ~/.ssh/devops-diploma ubuntu@${module.k3s.public_ip}"
}

output "jenkins_url" {
  value = "http://${module.jenkins.public_ip}:8080"
}

output "app_url" {
  value = "http://${module.k3s.public_ip}"
}
