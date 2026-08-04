# Deployment — jedna ścieżka (Jenkins EBS safe)

## Zasada

Nigdy nie odpalaj gołego `terraform apply` z pustym `jenkins_home_volume_id` — powstanie **nowy pusty dysk** i Jenkins straci credentials/joby.

Źródło prawdy o dysku:

1. `.secrets/jenkins-home-volume-id.txt`
2. `terraform/environments/dev/terraform.tfvars` → `jenkins_home_volume_id`

## Narzędzia

- Windows: AWS CLI, Terraform, klucz `~/.ssh/devops-diploma`
- WSL: Ansible
- CI/CD: **tylko Jenkins**

## A) Start od zera (zachowaj ustawienia)

Masz już `vol-…` (po wcześniejszej pracy / pause):

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\start-from-zero.ps1
```

Pierwszy bootstrap w życiu (świadomie nowy dysk):

```powershell
.\scripts\start-from-zero.ps1 -AllowNewJenkinsVolume
```

Albo w WSL:

```bash
./scripts/deploy.sh
# pierwszy raz: ALLOW_NEW_JENKINS_VOLUME=1 ./scripts/deploy.sh
```

Co robi automatycznie:

1. Wymusza reuse EBS (albo tworzy nowy tylko z flagą)
2. Terraform bootstrap + apply + zapis `vol-` do `.secrets`
3. `ansible/inventory/hosts` z aktualnych IP
4. Ansible `site.yml` (montuje EBS → `/var/lib/jenkins`)
5. Kubeconfig na Jenkins (prywatne IP k3s)
6. Deploy app + monitoring

**Jenkins UI (tylko gdy dysk był pusty):** credentials + Multibranch — patrz `docs/JENKINS.md`.  
Gdy EBS miał już dane — joby wracają bez setup wizard.

## B) Po pauzie (codziennie)

```powershell
.\scripts\aws-pause.ps1    # destroy EC2, dysk zostaje, ID w .secrets
.\scripts\aws-resume.ps1   # apply + ten sam EBS + sync inventory
```

Potem WSL Ansible + `.\scripts\wire-jenkins-kubeconfig.ps1`.

## C) Ręczne pomoce

| Skrypt | Rola |
|--------|------|
| `ensure-jenkins-volume.ps1` | Guard / sync `vol-` ↔ tfvars |
| `sync-inventory.ps1` | IP → `ansible/inventory/hosts` |
| `wire-jenkins-kubeconfig.ps1` | kubeconfig → Jenkins |

## Sprawdzenie

```text
http://<k3s-ip>:30080/api/health
http://<k3s-ip>:30090/targets     → webstrike-backend UP
http://<jenkins-ip>:8080          → te same joby co przed pauzą
```
