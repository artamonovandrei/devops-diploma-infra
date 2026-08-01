# DevOps Diploma Infrastructure

Infrastruktura IaC dla pracy dyplomowej DevOps: **Terraform** (AWS EC2 + k3s), **Ansible**, **Jenkins CI/CD**, **Kubernetes**, **Prometheus/Grafana/Loki**.

## Repozytoria

| Repo | Zawartość |
|------|-----------|
| `python-microservices-app` | Fork aplikacji: User Service (FastAPI) + Order Service (Flask) |
| `devops-diploma-infra` (to repo) | Terraform, Ansible, K8s, Jenkins, monitoring, docs |

## Szybki start (Windows 11)

```powershell
# 1. Przygotuj narzędzia
.\scripts\setup-windows.ps1
# Restart PowerShell, potem:
aws configure
gh auth login

# 2. Utwórz repozytoria GitHub i wypchnij kod
.\scripts\create-github-repos.ps1

# 3. Skonfiguruj Terraform
cd terraform\environments\dev
copy terraform.tfvars.example terraform.tfvars
# Edytuj: admin_cidr (TwojeIP/32), ssh_public_key

# 4. Bootstrap S3 state + infrastruktura
cd ..\..\bootstrap
terraform init
terraform apply -auto-approve
cd ..\environments\dev
terraform init
terraform apply -auto-approve

# 5. Ansible
cd ..\..\..\ansible
# Uzupełnij IP w inventory\hosts
ansible-playbook playbooks\site.yml
ansible-playbook playbooks\monitoring.yml
```

Szczegóły: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Struktura

```
terraform/     # IaC — VPC, SG, 2× EC2, S3 state (bootstrap)
ansible/       # Bootstrap Jenkins, k3s, ufw, Helm, agent
kubernetes/    # Manifesty aplikacji + monitoring
jenkins/       # Pipeline CI / CD + Configuration as Code
docs/          # ARCHITECTURE, DEPLOYMENT, DEMO
scripts/       # setup-windows, deploy, e2e-checklist
```

## CI/CD

- **Dowolna gałąź:** testy → build Docker → push Docker Hub → e-mail (SES)
- **main:** dodatkowo deploy na k3s + weryfikacja → e-mail (SES)

## Kryteria oceny — pokrycie

| Obowiązkowe | Status |
|-------------|--------|
| GIT + GitHub (2 projekty) | Tak |
| Terraform (moduły, reużywalność) | Tak |
| AWS EC2 + bezpieczeństwo SG | Tak |
| Ubuntu + UFW | Tak (Ansible) |
| Docker (obrazy, sieci, wolumeny) | Tak |
| Docker Hub | Tak (Jenkins) |
| CI/CD Jenkins + powiadomienia | Tak |
| Dokumentacja Markdown | Tak |

| Opcjonalne | Status |
|------------|--------|
| Terraform state S3 | Tak |
| Kubernetes (k3s) | Tak |
| Ansible | Tak |
| Prometheus + Grafana + Alertmanager | Tak |
| Loki | Tak |
| Jenkins agents | Tak |
| Unit testy | Tak |
| Jenkins CaC | Tak (`jenkins-casc.yaml`) |

## Koszt AWS

~25–35 USD/mies. (2× t3.small). Po pracy: `terraform destroy` lub stop instancji.

## Dokumentacja

- [Architektura](docs/ARCHITECTURE.md)
- [Wdrożenie od zera](docs/DEPLOYMENT.md)
- [Scenariusz obrony](docs/DEMO.md)
- [Konfiguracja Jenkins](docs/JENKINS.md)

## Zanim uruchomisz Terraform

```powershell
aws configure   # wymagane — Access Key z AWS Console
.\scripts\generate-tfvars.ps1
gh auth login
.\scripts\create-github-repos.ps1
```
