# Status

CI/CD: **tylko Jenkins** (GitHub Actions usunięte).  
Monitoring: **Prometheus + Grafana** (`kubernetes/monitoring/stack.yaml`).

## Po `aws-resume`

```powershell
terraform -chdir=terraform/environments/dev output
```

| Co | Output / URL |
|----|----------------|
| Gra | `app_url` |
| Jenkins | `jenkins_url` |
| Prometheus | `prometheus_url` → `/targets` |
| Grafana | `grafana_url` (`admin` / `devops-diploma`) |

## Ansible

```bash
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

## Pauza

```powershell
.\scripts\aws-pause.ps1
```
