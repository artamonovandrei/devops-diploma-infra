# Deployment — jedna ścieżka

## Zasada

Nigdy nie odpalaj `terraform apply` z pustym `jenkins_home_volume_id` — powstanie nowy pusty dysk i Jenkins straci credentials.

ID dysku:
1. `.secrets/jenkins-home-volume-id.txt`
2. `terraform/environments/dev/terraform.tfvars` → `jenkins_home_volume_id`

## Narzędzia

- Windows (PowerShell): AWS CLI, Terraform, skrypty
- WSL: Ansible
- CI/CD: tylko Jenkins

## Codziennie: pauza / wznowienie

**Pauza** (EC2 znika, dysk Jenkins zostaje):

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\aws-pause.ps1
```

**Wznowienie:**

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\aws-resume.ps1
```

Potem WSL:

```bash
cd /mnt/c/Users/artam/Documents/DevOps/devops-diploma-infra/ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

Potem PowerShell:

```powershell
.\scripts\wire-jenkins-kubeconfig.ps1
```

Jeśli gra nie działa: Jenkins → job `webstrike` → gałąź `main` → Rebuild.

## Skrypty (tylko te)

| Skrypt | Po co |
|--------|--------|
| `aws-pause.ps1` | Zatrzymaj AWS, zachowaj Jenkins |
| `aws-resume.ps1` | Wznów AWS + ten sam dysk Jenkins |
| `wire-jenkins-kubeconfig.ps1` | Podłącz Jenkins do k3s |
| `ensure-jenkins-volume.ps1` | Guard — używany przez resume |
| `sync-inventory.ps1` | IP → Ansible inventory (używany przez resume) |
| `install-monitoring-lite.sh` | Prometheus/Grafana/Alertmanager (Ansible) |

## Sprawdzenie

```powershell
cd terraform\environments\dev
terraform output
```

## Credentials Jenkins (raz, na EBS)

Patrz `docs/JENKINS.md`: `github-token`, `dockerhub-credentials`, `ses-smtp`.
