# NEXT STEPS — co musisz zrobić ręcznie

Kod projektu jest gotowy lokalnie. Aby dokończyć wdrożenie na AWS:

## 1. Skonfiguruj AWS credentials (blokuje Terraform)

```powershell
aws configure
# AWS Access Key ID: z konsoli AWS → IAM → Security credentials
# AWS Secret Access Key: ...
# Default region: eu-central-1
# Default output: json

aws sts get-caller-identity   # musi zwrócić Twoje Account ID
```

## 2. Zaloguj się do GitHub

```powershell
gh auth login
cd c:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\create-github-repos.ps1
```

## 3. Wdróż infrastrukturę

```powershell
cd c:\Users\artam\Documents\DevOps\devops-diploma-infra

# tfvars już wygenerowany (scripts\generate-tfvars.ps1)
# Przywróć S3 backend w terraform/environments/dev/main.tf jeśli był zmieniony na local

cd terraform\bootstrap
terraform init
terraform apply -auto-approve

cd ..\environments\dev
# Upewnij się, że backend to S3 (patrz main.tf)
terraform init
terraform apply -auto-approve
terraform output
```

## 4. Ansible (przez WSL Ubuntu)

```bash
sudo apt update && sudo apt install -y ansible
cd /mnt/c/Users/artam/Documents/DevOps/devops-diploma-infra/ansible
cp inventory/hosts.example inventory/hosts
# wstaw IP z terraform output
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/monitoring.yml
ansible-playbook playbooks/jenkins-agent.yml
```

## 5. Jenkins + SES

Patrz [docs/JENKINS.md](JENKINS.md) i [docs/DEPLOYMENT.md](DEPLOYMENT.md).

## 6. SES — zweryfikuj e-mail

```powershell
aws ses verify-email-identity --email-address TWOJ@EMAIL.com --region eu-central-1
```

## Status lokalny (już zrobione)

- [x] Aplikacja microserwisów + Docker Compose (lokalnie działa)
- [x] Repo `devops-diploma-infra` z Terraform/Ansible/K8s/Jenkins/docs
- [x] Klucz SSH `~/.ssh/devops-diploma`
- [x] `terraform.tfvars` wygenerowany
- [x] Terraform / AWS CLI / gh zainstalowane
- [ ] AWS credentials (`aws configure`)
- [ ] `terraform apply` na AWS
- [ ] Ansible bootstrap na EC2
- [ ] Jenkins pipeline + Docker Hub + SES
- [ ] Push na GitHub
