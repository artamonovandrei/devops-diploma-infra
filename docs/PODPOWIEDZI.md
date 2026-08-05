# Podpowiedzi — jak to robić (dla juniora)

Prosta ściąga: co odpalać, w jakiej kolejności, bez teorii.

Masz dwa katalogi:

| Katalog | Co to |
|---------|--------|
| `C:\Users\artam\Documents\DevOps\Counter-Strike` | **Gra** (kod) |
| `C:\Users\artam\Documents\DevOps\devops-diploma-infra` | **Infra** (AWS, Jenkins, k3s) |

Masz dwa terminale:

| Terminal | Po co |
|----------|--------|
| **PowerShell** | Terraform, skrypty AWS, git gry czasem też |
| **WSL** (`devops@ANAR:...`) | Ansible |

---

## A. Wypchnąć zmiany w grze (push → Jenkins → deploy)

### 1. Wejdź na `develop` i pobierz najnowsze

```powershell
cd C:\Users\artam\Documents\DevOps\Counter-Strike
git checkout develop
git pull origin develop
```

### 2. Zmień pliki gry

Edytuj np. `frontend/`, `backend/`, `assets/`…

### 3. Commit i push

```powershell
git status
git add .
git -c user.name="artamonovandrei" -c user.email="artamonovandrei88@gmail.com" commit -m "Opis zmian w grze"
git push origin develop
```

### 4. Co robi Jenkins (sam)

| Gałąź | Co się dzieje |
|-------|----------------|
| `develop` | testy → Docker build → Docker Hub → mail → **auto-merge do main** |
| `main` | to samo + **wdrożenie na k3s** (gra się aktualizuje) |

Otwórz Jenkins (`terraform output -raw jenkins_url`) i patrz na job **webstrike**.

W logu maila szukaj: `SES_EMAIL_SENT_OK`.

---

## B. Uruchomić całą infrastrukturę (po pauzie / rano)

**Kolejność obowiązkowa — nie pomijaj kroków.**

### Krok 1 — PowerShell: wznów AWS

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\aws-resume.ps1
```

Poczekaj aż skończy. Skrypt sam uzupełni `ansible/inventory/hosts` (IP).

### Krok 2 — WSL: zainstaluj / dopnij serwery

```bash
cd /mnt/c/Users/artam/Documents/DevOps/devops-diploma-infra/ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

### Krok 3 — PowerShell: podłącz Jenkins do k3s

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\wire-jenkins-kubeconfig.ps1
```

Musisz zobaczyć node **Ready**.

### Krok 4 — Sprawdź adresy

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra\terraform\environments\dev
terraform output
```

| Output | Co otworzyć |
|--------|-------------|
| `jenkins_url` | Jenkins |
| `app_url` | Gra (`/api/health` = ok) |
| `prometheus_url` | Prometheus (`/targets`) |
| `grafana_url` | Grafana (`admin` / `devops-diploma`) |

### Krok 5 — Jeśli gra nie działa

Po resume k3s jest **pusty** — Jenkins musi wdrożyć appę, albo zrób Rebuild:

1. Jenkins → job **webstrike** → gałąź **main** → **Build Now** / Rebuild  
2. Albo poczekaj na push na `develop` (auto-merge → deploy z `main`)

Szybki test gry:

```powershell
# zamień IP na wynik: terraform output -raw k3s_public_ip
curl.exe http://IP:30080/api/health
```

---

## C. Wstrzymać wszystko BEZ utraty Jenkinsa

To jest **jedyna bezpieczna pauza**:

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
.\scripts\aws-pause.ps1
```

### Co zostaje / co znika

| Zostaje | Znika (odtworzysz przy resume) |
|---------|--------------------------------|
| Dysk Jenkins (joby, credentials, pluginy) | Serwery EC2 |
| Obrazy na Docker Hub | Gra na k3s (trzeba znów wdrożyć) |
| Kod na GitHub | Monitoring na klastrze |
| ID dysku w `.secrets` | Stare publiczne IP |

### Czego NIE używać do pauzy

```text
❌  terraform destroy          (goły, bez skryptu)
❌  kasowanie volume w AWS
❌  terraform apply z pustym jenkins_home_volume_id
```

Twój dysk Jenkins (przykład): `vol-0168fdcfb41544f6e`  
Plik: `.secrets\jenkins-home-volume-id.txt`

---

## D. Push zmian w infra (to repo)

```powershell
cd C:\Users\artam\Documents\DevOps\devops-diploma-infra
git checkout develop
git pull origin develop
# edycja plików…
git status
git add .
git -c user.name="artamonovandrei" -c user.email="artamonovandrei88@gmail.com" commit -m "Opis zmian w infra"
git push origin develop
```

Jenkins (job infra) sprawdzi layout / dry-run i może zmergować do `main`.

---

## E. Typowe problemy (szybka ściąga)

| Objaw | Co zrobić |
|-------|-----------|
| `.\scripts\...` nie znaleziony | Jesteś w złym folderze — `cd` do `devops-diploma-infra` |
| WSL: `InvalidClientTokenId` przy `terraform output` | AWS w WSL nie działa — odpal `terraform output` w **PowerShell** |
| Gra nie ładuje się, ale Jenkins OK | Brak podów — Rebuild `webstrike` / `main` |
| Jenkins build: Docker permission denied | Na Jenkinsie: `sudo systemctl restart jenkins` |
| Jenkins deploy: no route to host | `.\scripts\wire-jenkins-kubeconfig.ps1` |
| Ansible: `python3.12: not found` | Inventory ma mieć `/usr/bin/python3` (nie 3.12 na świeżym AMI) |

---

## F. Mini-checklist przed obroną

1. `.\scripts\aws-resume.ps1` → Ansible → `wire-jenkins-kubeconfig.ps1`  
2. `terraform output` — otwórz wszystkie URL  
3. Gra: `/api/health` = ok  
4. Prometheus: target `webstrike-backend` = UP  
5. Grafana: wykresy  
6. Mały push na `develop` → zielony Jenkins + mail  
7. Po wszystkim: `.\scripts\aws-pause.ps1`

---

## G. Hasła / maile (przypomnienie)

| Co | Wartość |
|----|---------|
| Grafana | `admin` / `devops-diploma` |
| Mail CI i alertów | `a.artamonov@wp.pl` |
| SSH | `~/.ssh/devops-diploma` |

Sekrety SES: `.secrets/ses-smtp.env` — **nie na GitHub**.
