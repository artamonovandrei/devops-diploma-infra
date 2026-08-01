# NEXT STEPS — aktualny status

Ostatnia aktualizacja: 2026-08-01

## Zrobione

- [x] AWS credentials + Terraform (VPC, 2× EC2, S3 state)
- [x] Ansible: Jenkins, k3s, UFW, Python 3.10 + Node 22
- [x] Aplikacja na k3s (NodePorts 30001 / 30002)
- [x] Monitoring lite: Prometheus, Grafana, Loki, Alertmanager
- [x] Jenkins Multibranch CI/CD → Docker Hub → deploy k3s
- [x] AWS SES: zweryfikowany e-mail + SMTP credentials
- [x] Powiadomienia e-mail z pipeline (`SES_EMAIL_SENT_OK`)
- [x] Push na GitHub (app + infra)

## Do sprawdzenia ręcznie (2–5 min)

1. Skrzynka **artamonovandrei88@gmail.com** — mail `[DevOps Diploma] ...` (także folder Spam)
2. Jenkins UI: http://63.180.87.102:8080 — ostatni build `main` = SUCCESS
3. Aplikacja:
   - http://18.197.236.46:30001/health
   - http://18.197.236.46:30002/health
4. Grafana: http://18.197.236.46:30300 — `admin` / `devops-diploma`

## Opcjonalne (więcej punktów)

- [ ] Domena + SSL
- [ ] Jenkins agent na k3s
- [ ] Jenkins Configuration as Code (pełne wdrożenie)
- [ ] Szerszy scope GitHub PAT (statuses) — teraz tylko warning 403

## Koszty

Gdy nie pracujesz: `terraform destroy` w `terraform/environments/dev` albo Stop EC2 w konsoli AWS.

## Sekrety (nie commitować)

- `devops-diploma-infra/.secrets/ses-smtp.env` — lokalne SMTP SES
