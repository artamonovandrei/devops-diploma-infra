# Wdrożenie od zera

Instrukcja wdrożenia całego projektu w kilku krokach.

## Wymagania wstępne

- Konto AWS z aktywnym kredytem
- AWS CLI skonfigurowany:
  ```powershell
  aws configure
  # Access Key ID / Secret / region: eu-central-1
  aws sts get-caller-identity
  ```
- Terraform >= 1.5 (`winget install Hashicorp.Terraform`)
- Ansible >= 2.14 (najłatwiej przez WSL Ubuntu: `sudo apt install ansible`)
- Klucz SSH: `.\scripts\setup-windows.ps1` lub `.\scripts\generate-tfvars.ps1`
- Docker Desktop uruchomiony
- Konto Docker Hub
- E-mail zweryfikowany w AWS SES
- GitHub: `gh auth login`

## Krok 1: Przygotowanie AWS SES

```bash
aws ses verify-email-identity --email-address twoj@email.com --region eu-central-1
# Potwierdź link w skrzynce e-mail
```

Wygeneruj SMTP credentials w konsoli AWS SES (SMTP settings).

## Krok 2: Bootstrap Terraform State (jednorazowo)

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

## Krok 3: Wdróż infrastrukturę

```bash
# Pobierz swoje publiczne IP
curl ifconfig.me

cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edytuj: admin_cidr, ssh_public_key

terraform init
terraform apply -auto-approve

# Zapisz outputy
terraform output
```

## Krok 4: Ansible bootstrap

```bash
cd ansible
cp inventory/hosts.example inventory/hosts
# Uzupełnij IP z terraform output

ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/jenkins-agent.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

## Krok 5: Konfiguracja Jenkins

1. Otwórz `http://JENKINS_IP:8080`
2. Hasło początkowe: `ssh ubuntu@JENKINS_IP "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"`
3. Zainstaluj: Git, Docker Pipeline, Email Extension, Credentials Binding, Configuration as Code
4. Dodaj credentials:
   - `dockerhub-credentials` (Username/Password)
   - `github-token` (Secret text — PAT GitHub)
5. Skonfiguruj SMTP (AWS SES):
   - Host: `email-smtp.eu-central-1.amazonaws.com`
   - Port: 587, TLS
   - Credentials z SES SMTP
6. Utwórz Multibranch Pipeline wskazujący na repo aplikacji
7. Dodaj node `k3s-agent` (SSH do EC2 k3s)

## Krok 6: Wdróż aplikację

```bash
# Na serwerze k3s lub przez Jenkins CD pipeline
kubectl apply -f kubernetes/apps/
```

## Krok 7: Weryfikacja

```bash
# Health check
curl http://K3S_IP/users/1
curl http://K3S_IP/orders/1

# Monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Grafana: admin / devops-diploma

# Idempotentność Terraform
terraform plan  # powinno pokazać: No changes
```

## Czyszczenie (oszczędność kosztów)

```bash
cd terraform/environments/dev
terraform destroy -auto-approve
```

## Rozwiązywanie problemów

| Problem | Rozwiązanie |
|---------|-------------|
| Jenkins nie startuje | `sudo systemctl status jenkins` na EC2 |
| k3s nie gotowy | `sudo k3s kubectl get nodes` |
| Pipeline nie pushuje | Sprawdź credentials Docker Hub |
| Brak e-maili | SES sandbox — tylko zweryfikowane adresy |
| OOM na t3.small | Zmniejsz repliki do 1 w manifestach K8s |
