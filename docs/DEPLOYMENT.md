# Deployment — jedna ścieżka

## Narzędzia

- Windows: AWS CLI, Terraform, klucz `~/.ssh/devops-diploma`
- WSL: Ansible
- CI/CD: **tylko Jenkins** (repo aplikacji)

## 1. Terraform (PowerShell)

Pierwszy raz (bootstrap S3 — tylko raz na konto):

```powershell
cd terraform\bootstrap
terraform init
terraform apply -auto-approve
```

Środowisko:

```powershell
cd terraform\environments\dev
# terraform.tfvars: admin_cidr, ssh_public_key, jenkins_home_volume_id
terraform init
terraform apply -auto-approve
terraform output
```

Po pauzie: `.\scripts\aws-resume.ps1` (z katalogu głównego repo).

## 2. Ansible (WSL)

```bash
cd ansible
# inventory/hosts ← jenkins_public_ip, k3s_public_ip
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

## 3. Jenkins (przeglądarka, raz)

1. `http://<jenkins-ip>:8080`
2. Credentials: `github-token`, `dockerhub-credentials`, `ses-smtp`
3. Multibranch → `artamonovandrei/Counter-Strike`, Script Path: `Jenkinsfile`
4. Gałęzie: `main`, `develop`

## 4. Sprawdzenie

```text
http://<k3s-ip>:30080/api/health
http://<k3s-ip>:30090/targets     → webstrike-backend UP
http://<k3s-ip>:30300             → dashboard WebStrike
```

## Pauza

```powershell
.\scripts\aws-pause.ps1
```
