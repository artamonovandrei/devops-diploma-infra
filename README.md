# DevOps Diploma Infrastructure

Infrastruktura IaC pod pracę dyplomową: Terraform (AWS EC2 + k3s), Ansible, Jenkins CI/CD, Kubernetes, Prometheus/Grafana/Loki.

## Repozytoria

| Repo | Zawartość |
|------|-----------|
| [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike) | Aplikacja WebStrike (FastAPI + Three.js) |
| `devops-diploma-infra` (to repo) | Terraform, Ansible, K8s, Jenkins, monitoring, docs |

## Szybki start (Windows 11)

```powershell
.\scripts\setup-windows.ps1
aws configure
gh auth login

cd terraform\bootstrap
terraform init
terraform apply -auto-approve

cd ..\environments\dev
# uzupełnij terraform.tfvars (admin_cidr, ssh_public_key)
terraform init
terraform apply -auto-approve
terraform output
```

Ansible (WSL):

```bash
cd ansible
# inventory/hosts — IP z terraform output
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

Szczegóły: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Struktura

```
terraform/     # VPC, SG, 2× EC2, S3 state (bootstrap)
ansible/       # Jenkins, k3s, ufw, Python 3.12, Node 22
kubernetes/    # WebStrike + monitoring
jenkins/       # przykładowe Jenkinsfile / Casc
docs/          # ARCHITECTURE, DEPLOYMENT, DEMO
scripts/       # helpery
```

## CI/CD

Pipeline w repo aplikacji (`Counter-Strike/Jenkinsfile`):

- dowolna gałąź: testy → build Docker → push Docker Hub → e-mail (SES)
- `main`: dodatkowo deploy na k3s

## Dostęp po wdrożeniu

- Gra: `http://<k3s-ip>:30080`
- Health: `http://<k3s-ip>:30080/healthz` oraz `/api/health`
- Jenkins: `http://<jenkins-ip>:8080`
- Grafana: `http://<k3s-ip>:30300` (admin / devops-diploma)

## Autor

artamonovandrei
