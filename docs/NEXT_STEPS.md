# Status

CI/CD: **tylko Jenkins**.  
Monitoring: **Prometheus + Grafana**.  
Jenkins home: **trwały EBS** (`.secrets/jenkins-home-volume-id.txt`).

## Po `aws-resume` / `start-from-zero`

```powershell
terraform -chdir=terraform/environments/dev output
.\scripts\wire-jenkins-kubeconfig.ps1   # jeśli Ansible już był
```

| Co | Output / URL |
|----|----------------|
| Gra | `app_url` |
| Jenkins | `jenkins_url` (te same credentials) |
| Prometheus | `prometheus_url` → `/targets` |
| Grafana | `grafana_url` |

## Ansible

```bash
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

## Pauza

```powershell
.\scripts\aws-pause.ps1
```
