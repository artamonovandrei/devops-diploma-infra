# Status (WebStrike)

## Live endpoints

| Usługa | URL |
|--------|-----|
| Gra | http://52.58.172.254:30080 |
| API health | http://52.58.172.254:30080/api/health |
| Jenkins | http://63.179.217.130:8080 |
| Grafana | http://52.58.172.254:30300 (admin / devops-diploma) |

## Zrobione

- [x] Repo aplikacji: Counter-Strike + Jenkinsfile
- [x] Repo infra: devops-diploma-infra na GitHub
- [x] Terraform apply (Jenkins + k3s)
- [x] Ansible (Jenkins, k3s, Python 3.12, Node 22)
- [x] Deploy WebStrike na k3s (NodePort 30080)
- [x] Monitoring lite

## Do dokończenia w UI Jenkins (raz)

1. Wejdź na http://63.179.217.130:8080 — hasło initialAdminPassword na EC2
2. Zainstaluj pluginy: GitHub Branch Source, Pipeline, Docker Pipeline, Credentials Binding
3. Dodaj credentials: `dockerhub-credentials`, GitHub PAT, `ses-smtp` (jeśli brak)
4. Multibranch Pipeline → `artamonovandrei/Counter-Strike`, Script Path `Jenkinsfile`
5. Po pierwszym pushu na `main` pipeline zrobi build/push/deploy

## Koszty — pauza z zachowaniem Jenkinsa

**Nie** używaj gołego `terraform destroy`, jeśli chcesz mieć te same joby/credentials po starcie.

1. **Pierwszy raz** (gdy infra jeszcze działa) — dołóż dysk EBS i zmigruj home:
   ```powershell
   cd terraform\environments\dev
   terraform apply -auto-approve
   # Ansible (WSL): playbooks/jenkins.yml / site.yml
   ```
2. **Wyłączanie kosztów** (dysk Jenkins zostaje w AWS):
   ```powershell
   .\scripts\aws-pause.ps1
   ```
3. **Ponowny start** (ten sam EBS → te same ustawienia Jenkins):
   ```powershell
   .\scripts\aws-resume.ps1
   # potem Ansible site.yml z nowymi IP
   ```

Volume ID jest w `.secrets/jenkins-home-volume-id.txt` (nie commituj).
