# DevOps Diploma — infrastruktura WebStrike

Prosty stos: **Terraform → Ansible → Jenkins → k3s → Prometheus/Grafana**.

CI/CD jest tylko w **Jenkins** (bez GitHub Actions).

## Repo

| Repo | Rola |
|------|------|
| [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike) | Gra + `Jenkinsfile` |
| to repo | Terraform, Ansible, K8s, monitoring |

## Jenkins nie traci ustawień

`/var/lib/jenkins` leży na **osobnym EBS**. ID dysku:

- `.secrets/jenkins-home-volume-id.txt` (lokalnie, gitignore)
- `terraform.tfvars` → `jenkins_home_volume_id`

Skrypty **odmawiają** `terraform apply` bez tego ID (inaczej powstałby pusty dysk).  
Pierwszy bootstrap w życiu: `-AllowNewJenkinsVolume` / `ALLOW_NEW_JENKINS_VOLUME=1`.

## Start od zera (zachowaj credentials)

**PowerShell** (zalecane na Windows):

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
# reuse istniejącego vol (masz już w .secrets / tfvars):
.\scripts\start-from-zero.ps1
# ALBO pierwszy raz w życiu (pusty dysk):
# .\scripts\start-from-zero.ps1 -AllowNewJenkinsVolume
```

Skrypt: Terraform → zapis volume ID → inventory → (WSL) Ansible → kubeconfig na Jenkins → deploy app.

**WSL / bash** (to samo):

```bash
./scripts/deploy.sh
# pierwszy raz: ALLOW_NEW_JENKINS_VOLUME=1 ./scripts/deploy.sh
```

## Codziennie / po pauzie

```powershell
.\scripts\aws-resume.ps1          # attach TEN SAM EBS + sync inventory
# WSL:
cd ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
# PowerShell — nowe private IP k3s:
.\scripts\wire-jenkins-kubeconfig.ps1
```

## Pauza (koszty ↓, Jenkins zachowany)

```powershell
.\scripts\aws-pause.ps1
```

## Sprawdź

| Co | URL |
|----|-----|
| Gra | `http://<k3s-ip>:30080` |
| Jenkins | `http://<jenkins-ip>:8080` |
| Prometheus | `http://<k3s-ip>:30090/targets` |
| Grafana | `http://<k3s-ip>:30300` (`admin` / `devops-diploma`) |

## CI/CD (Jenkins)

- `develop` — testy, Docker build/push, mail, auto-merge → `main`
- `main` — to samo + deploy na k3s

## Monitoring

`kubernetes/monitoring/stack.yaml` — **Prometheus + Grafana + Alertmanager**.  
Alerty e-mail (SES) na `a.artamonov@wp.pl` — SMTP z `.secrets/ses-smtp.env` (nie w gicie).  
UI Alertmanager: `:30903` | Prometheus Alerts: `:30090/alerts`

## Autor

artamonovandrei
