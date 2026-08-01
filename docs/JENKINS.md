# Jenkins Configuration Guide (po Ansible bootstrap)

## 1. Pierwsze logowanie

```powershell
$jenkinsIp = terraform -chdir=terraform/environments/dev output -raw jenkins_public_ip
Start-Process "http://${jenkinsIp}:8080"
ssh -i $env:USERPROFILE\.ssh\devops-diploma ubuntu@$jenkinsIp "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

## 2. Wymagane pluginy

- Git / GitHub Branch Source
- Pipeline / Docker Pipeline
- Email Extension Plugin
- Credentials Binding
- Configuration as Code (opcjonalnie — załaduj `jenkins/jenkins-casc.yaml`)
- SSH Build Agents

## 3. Credentials (Manage Jenkins → Credentials)

| ID | Typ | Opis |
|----|-----|------|
| `dockerhub-credentials` | Username/Password | Login Docker Hub + Access Token |
| `github-token` | Secret text | GitHub PAT (repo read) |
| `ses-smtp` | Username/Password | AWS SES SMTP (IAM access key + derived SMTP password) |

## 4. E-mail (AWS SES)

Już skonfigurowane na serwerze Jenkins (SMTP SES, recipient `artamonovandrei88@gmail.com`).

Manage Jenkins → System → Extended E-mail Notification:

- SMTP server: `email-smtp.eu-central-1.amazonaws.com`
- Port: `587`
- Use TLS: yes
- Credentials: `ses-smtp`
- Default Recipients: `artamonovandrei88@gmail.com`

Lokalne sekrety (nie commitować): `devops-diploma-infra/.secrets/ses-smtp.env`

## 5. Multibranch Pipeline

1. New Item → Multibranch Pipeline → `microservices-app`
2. Branch Sources → GitHub → repo `python-microservices-app`
3. Build Configuration → Script Path: `Jenkinsfile`
4. Scan periodically: 2 minutes (lub GitHub webhook)

## 6. Jenkins Agent (k3s)

1. Manage Jenkins → Nodes → New Node → `k3s-agent`
2. Remote root directory: `/opt/jenkins-agent`
3. Labels: `k3s-agent`
4. Launch method: SSH
5. Host: public IP k3s, User: `ubuntu`, Credentials: SSH key

## 7. Weryfikacja CI/CD

```powershell
# Feature branch → tylko CI
cd python-microservices-app
git checkout -b feature/ci-test
echo "# ci" >> README.md
git commit -am "ci: trigger pipeline"
git push -u origin feature/ci-test

# main → CI + CD
git checkout main
git merge feature/ci-test
git push origin main
```
