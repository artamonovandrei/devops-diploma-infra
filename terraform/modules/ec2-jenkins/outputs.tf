output "instance_id" {
  value = aws_instance.jenkins.id
}

output "public_ip" {
  value = aws_eip.jenkins.public_ip
}

output "private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "jenkins_home_volume_id" {
  description = "Zapisz to ID przed destroy — po apply wklej do jenkins_home_volume_id"
  value       = local.jenkins_home_volume_id
}
