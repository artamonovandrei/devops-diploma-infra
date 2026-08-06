# DevOps Diploma — infrastruktura (prosty przewodnik)

Ten katalog to **infra** pod grę WebStrike.  
Gra (kod) jest w osobnym repo: [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike).

## Co tu jest (w jednym zdaniu)

```text
Terraform (AWS) → Ansible (instalacja) → Jenkins (CI/CD) → k3s (gra) → Prometheus/Grafana (monitoring)
```

| Repo | Po co |
|------|--------|
| [Counter-Strike](https://github.com/artamonovandrei/Counter-Strike) | Kod gry + `Jenkinsfile` |
| **to repo** (`devops-diploma-infra`) | Terraform, Ansible, Kubernetes, monitoring |

CI/CD jest **tylko w Jenkins** (bez GitHub Actions).

Więcej „krok po kroku”: **[docs/PODPOWIEDZI.md](docs/PODPOWIEDZI.md)** ← zacznij stąd, jeśli jesteś juniorem.

---

## Dwa programy na komputerze

| Gdzie | Do czego |
|-------|----------|
| **PowerShell** | Terraform, AWS, skrypty `pause` / `resume`, kubeconfig |
| **WSL** | Ansible (`ansible-playbook`) |

Zawsze wchodź najpierw do katalogu infra:

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
```

---

## Najważniejsze: Jenkins nie ginie przy pauzie

Jenkins trzyma joby i hasła na **osobnym dysku AWS (EBS)**:

- plik: `.secrets/jenkins-home-volume-id.txt`
- oraz: `terraform/environments/dev/terraform.tfvars` → `jenkins_home_volume_id`

**Pauza** = wyłączasz serwery (nie płacisz za EC2), dysk zostaje.  
**Resume** = włączasz serwery + ten sam dysk → Jenkins wraca z ustawieniami.

---

## 1) Zatrzymaj wszystko (bez utraty Jenkinsa)

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\aws-pause.ps1
```

Po sukcesie zobaczysz: `PAUSE OK` i ID dysku `vol-...`.

## 2) Uruchom z powrotem

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\aws-resume.ps1
```

Potem **WSL**:

```bash
cd /mnt/c/Users/artam/Documents/DevOps/devops-diploma-infra/ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

Potem znowu **PowerShell**:

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\wire-jenkins-kubeconfig.ps1
```

Jeśli gra nie działa — w Jenkinsie Rebuild gałęzi `main` (job `webstrike`) albo patrz [PODPOWIEDZI](docs/PODPOWIEDZI.md).

## 3) Adresy stron (zawsze świeże IP)

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra\terraform\environments\dev
terraform output
```

| Co | Port |
|----|------|
| Gra | `:30080` |
| Jenkins | `:8080` |
| Prometheus | `:30090` |
| Grafana | `:30300` — login `admin` / hasło `devops-diploma` |
| Alertmanager | `:30903` |

---

## Jak wypchnąć zmianę w grze (CI/CD)

Praca na gałęzi **develop** w repo gry:

```powershell
cd C:\Users\artam\Documents\DevOps\Counter-Strike
git checkout develop
git pull origin develop
```

Edytujesz pliki (`frontend/`, `backend/`, …), potem:

```powershell
git status
git add .
git -c user.name="artamonovandrei" -c user.email="artamonovandrei88@gmail.com" commit -m "Opis zmian w grze"
git push origin develop
```

Co się dzieje dalej (Jenkins):

1. `develop` — testy, budowa obrazów Docker, push na Docker Hub, mail  
2. automatyczny merge → `main`  
3. `main` — to samo + **wdrożenie gry na k3s**

---

## Monitoring (krótko)

Jeden plik: `kubernetes/monitoring/stack.yaml` (+ skrypt SES przy Ansible).

- Prometheus zbiera metryki gry (`/metrics`)
- Grafana pokazuje wykresy (`admin` / `devops-diploma`)
- Alertmanager wysyła alerty e-mail (SES) na `a.artamonov@wp.pl`

SMTP: `.secrets/ses-smtp.env` — **nie commituj**.

## Skrypty (zapamiętaj 3)

| Skrypt | Po co |
|--------|--------|
| `aws-pause.ps1` | Stop AWS, Jenkins zostaje na EBS |
| `aws-resume.ps1` | Start AWS + ten sam Jenkins |
| `wire-jenkins-kubeconfig.ps1` | Jenkins → k3s po zmianie IP |

---

## Czego NIGDY nie rób

| Nie rób | Dlaczego |
|---------|----------|
| `terraform apply` z pustym `jenkins_home_volume_id` | Nowy pusty dysk = strata Jenkinsa |
| Zwykły `terraform destroy` zamiast `aws-pause.ps1` | Możesz stracić dysk / joby |
| Usuwać volume `vol-...` w konsoli AWS | Trwała utrata credentials |
| Commitować `.secrets/` lub `terraform.tfvars` | Sekrety w gicie |

---

## Dokumenty

| Plik | Treść |
|------|--------|
| [docs/PODPOWIEDZI.md](docs/PODPOWIEDZI.md) | Krok po kroku dla juniora |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Wdrożenie |
| [docs/JENKINS.md](docs/JENKINS.md) | Jenkins, credentials |

## Autor

artamonovandrei
