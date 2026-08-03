# Jenkins

## Trwałe ustawienia (przeżywa destroy)

`/var/lib/jenkins` leży na osobnym EBS (`*-jenkins-home`).  
Pauza/wznowienie: `scripts/aws-pause.ps1` → `scripts/aws-resume.ps1` (nie zwykły `terraform destroy`).

## Logowanie

```powershell
$jenkinsIp = terraform -chdir=terraform/environments/dev output -raw jenkins_public_ip
Start-Process "http://${jenkinsIp}:8080"
```

## Credentials

| ID | Typ | Opis |
|----|-----|------|
| `dockerhub-credentials` | Username/Password | Docker Hub |
| `github-token` / Username+PAT | GitHub Branch Source | odczyt repo |
| `ses-smtp` | Username/Password | AWS SES SMTP |

## E-mail (SES)

- SMTP: `email-smtp.eu-central-1.amazonaws.com:587`, TLS
- Credentials: `ses-smtp`
- Recipient: `artamonovandrei88@gmail.com`

Pipeline w aplikacji wysyła maila przez Python SMTP (`SES_EMAIL_SENT_OK` w logu).

## Multibranch Pipeline

### Aplikacja (główny CI/CD)

1. New Item → Multibranch Pipeline → np. `webstrike`
2. Branch Source → GitHub → `artamonovandrei/Counter-Strike`
3. Script Path: `Jenkinsfile`
4. Scan / poll co 2 minuty (lub webhook)

**Gałęzie (wymagane na pokaz):**

| Gałąź | Pipeline |
|-------|----------|
| `develop` | CI → po SUCCESS automatyczny merge do `main` |
| `main` | CI + CD (deploy na k3s) |

Credential `github-token` musi mieć prawo **zapisu** do repo (PAT scope `repo`), inaczej stage `Promote develop to main` padnie.

Po utworzeniu `develop` na GitHub: w jobie Multibranch → **Scan Multibranch Pipeline Now**.  
W Branch Sources nie filtruj tylko `main` (Discover branches → all / regex `main\|develop`).

### Infra

1. New Item → Multibranch Pipeline → np. `devops-diploma-infra`
2. Branch Source → GitHub → `artamonovandrei/devops-diploma-infra`
3. Script Path: `jenkins/Jenkinsfile.ci` (walidacja layout + kubectl dry-run)
4. Opcjonalnie osobny job z Script Path `jenkins/Jenkinsfile.cd` (apply manifestów na `main`)

## Agent (opcjonalnie)

Node SSH na EC2 k3s — patrz `ansible/playbooks/jenkins-agent.yml`.

## Weryfikacja

```powershell
cd Counter-Strike
git checkout -b feature/ci-test
# drobna zmiana → push → tylko CI
# merge do main → CI + deploy
```
