output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "jenkins_security_group_id" {
  value = aws_security_group.jenkins.id
}

output "k3s_security_group_id" {
  value = aws_security_group.k3s.id
}

output "key_name" {
  value = aws_key_pair.main.key_name
}
