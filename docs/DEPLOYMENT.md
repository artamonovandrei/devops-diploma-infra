# Deployment

## Wymagania

- Konto AWS, AWS CLI (`aws configure`, region `eu-central-1`)
- Terraform >= 1.5
- Ansible (WSL na Windows)
- Klucz SSH `~/.ssh/devops-diploma`
- Docker Hub + e-mail zweryfikowany w SES

## SES

```powershell
aws ses verify-email-identity --email-address artamonovandrei88@gmail.com --region eu-central-1
```

SMTP credentials: IAM user z `ses:SendEmail` / `ses:SendRawEmail`, hasło SMTP wyliczone z secret key (SigV4).

## Terraform

```powershell
cd terraform\bootstrap
terraform init
terraform apply -auto-approve

cd ..\environments\dev
terraform init
terraform apply -auto-approve
terraform output
```

## Ansible

```bash
cd ansible
cp inventory/hosts.example inventory/hosts
# wstaw jenkins_public_ip i k3s_public_ip

ansible-playbook -i inventory/hosts playbooks/site.yml
# site.yml: Jenkins, k3s, Python 3.12 + Node 22
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

Runtimes na hostach: **Python 3.12** (deadsnakes, obok systemowego 3.10) + **Node.js 22**.  
Obrazy gry: `python:3.12-slim` i `node:22-alpine` (build) / Caddy.

## Jenkins

1. `http://JENKINS_IP:8080`
2. Pluginy: Git, GitHub Branch Source, Pipeline, Docker Pipeline, Email Extension
3. Credentials: `dockerhub-credentials`, GitHub PAT, `ses-smtp`
4. Multibranch Pipeline → repo `artamonovandrei/Counter-Strike`, Script Path: `Jenkinsfile`
5. Skopiuj kubeconfig k3s do `/var/lib/jenkins/.kube/config` (API na prywatnym IP k3s)

## Aplikacja

```bash
kubectl apply -f kubernetes/apps/
```

Sprawdzenie:

- `http://K3S_IP:30080/healthz`
- `http://K3S_IP:30080/api/health`

## Koszty

Gdy nie pracujesz: `terraform destroy` w `environments/dev` albo Stop EC2.
