# DevOps Diploma — infrastruktura WebStrike

Prosty stos: **Terraform → Ansible → Jenkins → k3s → Prometheus/Grafana**.

CI/CD jest tylko w **Jenkins** (bez GitHub Actions).

## Repo

| Repo | Rola |
|------|------|
| [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike) | Gra + `Jenkinsfile` |
| to repo | Terraform, Ansible, K8s, monitoring |

## Start (codziennie / po pauzie)

**1. PowerShell — AWS**

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
# w terraform\environments\dev\terraform.tfvars musi być jenkins_home_volume_id
.\scripts\aws-resume.ps1
cd terraform\environments\dev
terraform output
```

**2. WSL — Ansible**

```bash
cd /mnt/c/Users/artam/Documents/DevOps/devops-diploma-infra/ansible
# inventory/hosts = IP z terraform output
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

**3. Sprawdź**

| Co | URL |
|----|-----|
| Gra | `http://<k3s-ip>:30080` |
| Jenkins | `http://<jenkins-ip>:8080` |
| Prometheus | `http://<k3s-ip>:30090/targets` |
| Grafana | `http://<k3s-ip>:30300` (`admin` / `devops-diploma`) |

## CI/CD (Jenkins)

- `develop` — testy, Docker build/push, mail, auto-merge → `main`
- `main` — to samo + deploy na k3s

## Pauza (koszty ↓, Jenkins zachowany)

```powershell
.\scripts\aws-pause.ps1
```

## Monitoring

Jeden plik: `kubernetes/monitoring/stack.yaml`  
Tylko **Prometheus + Grafana** (stabilnie na t3.small).  
Metryki gry: endpoint backend `/metrics` (`webstrike_players`, `webstrike_rooms`).

## Autor

artamonovandrei
