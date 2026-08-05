# DevOps Diploma — infrastruktura

Infra pod grę [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike): Terraform → Ansible → Jenkins → k3s → Prometheus/Grafana/Alertmanager.

CI/CD tylko w **Jenkins** (bez GitHub Actions).

| Repo | Rola |
|------|------|
| [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike) | Gra + `Jenkinsfile` |
| to repo | Terraform, Ansible, K8s, monitoring, `jenkins/Jenkinsfile.ci` |

Szczegóły: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md), [docs/JENKINS.md](docs/JENKINS.md).

## Jenkins i dysk EBS

`/var/lib/jenkins` jest na osobnym EBS — pauza nie kasuje jobów ani credentials.

ID dysku (musi być ustawione przed `apply`):

- `.secrets/jenkins-home-volume-id.txt` (lokalnie, gitignore)
- `terraform/environments/dev/terraform.tfvars` → `jenkins_home_volume_id`

Skrypty odmawiają `terraform apply` bez tego ID. Flaga `-AllowNewJenkinsVolume` / `ALLOW_NEW_JENKINS_VOLUME=1` — **tylko pierwszy bootstrap w życiu**.

## Codziennie: pauza / wznowienie

**Pauza** (EC2 znika, dysk Jenkins zostaje):

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\aws-pause.ps1
```

**Wznowienie:**

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\aws-resume.ps1
```

Potem w **WSL** (Ansible):

```bash
cd /mnt/c/Users/artam/Documents/DevOps/devops-diploma-infra/ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

Z powrotem w **PowerShell** (nowe private IP k3s → kubeconfig na Jenkins):

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\wire-jenkins-kubeconfig.ps1
```

`aws-resume.ps1` sam woła `sync-inventory.ps1` (IP → `ansible/inventory/hosts`).

## Start od zera

Gdy masz już `vol-…` w `.secrets` / tfvars:

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\start-from-zero.ps1
```

**Tylko pierwszy raz w życiu** (świadomie nowy pusty dysk):

```powershell
.\scripts\start-from-zero.ps1 -AllowNewJenkinsVolume
```

## Sprawdź (bez sztywnych IP)

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra\terraform\environments\dev
terraform output
# albo konkretnie:
terraform output -raw jenkins_url
terraform output -raw app_url
terraform output -raw prometheus_url
terraform output -raw grafana_url
```

| Co | Port / dostęp |
|----|----------------|
| Gra | `:30080` (k3s) |
| Jenkins | `:8080` |
| Prometheus | `:30090` (`/targets`, `/alerts`) |
| Grafana | `:30300` — `admin` / `devops-diploma` |
| Alertmanager | `:30903` |

## CI/CD

| Repo | Gałąź | Co robi |
|------|-------|---------|
| Counter-Strike | `develop` | testy, Docker build/push, mail, auto-merge → `main` |
| Counter-Strike | `main` | to samo + deploy na k3s |
| to repo | `jenkins/Jenkinsfile.ci` | walidacja infra (layout + kubectl dry-run) |

## Monitoring

Lite stack: `kubernetes/monitoring/stack.yaml` — Prometheus + Grafana + Alertmanager (bez Loki jako głównej ścieżki).

- Grafana: `admin` / `devops-diploma`
- Alerty e-mail (SES) → `a.artamonov@wp.pl` (SMTP w `.secrets/ses-smtp.env`, nie w gicie)

## Czego NIE robić

| Nie | Dlaczego |
|-----|----------|
| `terraform apply` z pustym `jenkins_home_volume_id` | powstanie nowy pusty dysk → strata Jenkinsa |
| Goły `terraform destroy` zamiast `aws-pause.ps1` | ryzyko utraty EBS / jobów |
| Usuwać dysk EBS Jenkins w AWS | trwała utrata credentials i jobów |
| Commitować `.secrets/`, `terraform.tfvars` | sekrety i lokalne ID |

## Autor

artamonovandrei
