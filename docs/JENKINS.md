# Jenkins

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

1. New Item → Multibranch Pipeline → np. `webstrike`
2. Branch Source → GitHub → `artamonovandrei/Counter-Strike`
3. Script Path: `Jenkinsfile`
4. Scan / poll co 2 minuty (lub webhook)

## Agent (opcjonalnie)

Node SSH na EC2 k3s — patrz `ansible/playbooks/jenkins-agent.yml`.

## Weryfikacja

```powershell
cd Counter-Strike
git checkout -b feature/ci-test
# drobna zmiana → push → tylko CI
# merge do main → CI + deploy
```
