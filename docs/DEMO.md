# Scenariusz demonstracji (obrona projektu)

Czas: 10–12 minut

## 1. Wprowadzenie (3 min)

- **Projekt:** Microserwisy Python (User + Order) z pełnym pipeline DevOps
- **Narzędzia:** Terraform, Ansible, Docker, k3s, Jenkins, Prometheus, Grafana, Loki, AWS SES
- **Rezultat:** Automatyczne wdrożenie od commita do działającej aplikacji z monitoringiem

## 2. Demonstracja live (10 min)

### 2.1 Architektura (1 min)
Pokaż diagram z `docs/ARCHITECTURE.md` — 2 EC2, 2 repozytoria GitHub, przepływ CI/CD.

### 2.2 Infrastruktura jako Kod (2 min)
```bash
cd terraform/environments/dev
terraform plan
# Pokaż: infrastruktura zdefiniowana w kodzie, idempotentna
terraform output
```

### 2.3 Pipeline CI — commit na branch (3 min)
```bash
git checkout -b feature/demo
echo "# demo" >> README.md
git add . && git commit -m "demo: trigger CI pipeline"
git push origin feature/demo
```
- Pokaż Jenkins: stages Checkout → Tests → Build → Push Docker Hub
- Pokaż e-mail z wynikiem CI (AWS SES)
- **Bez deploy** — branch != main

### 2.4 Pipeline CD — merge do main (3 min)
```bash
git checkout main
git merge feature/demo
git push origin main
```
- Pokaż Jenkins CD: deploy na k3s
- Pokaż rollout: `kubectl get pods -n microservices`
- Test API:
  ```bash
  curl http://K3S_IP/users/1
  curl http://K3S_IP/orders/1
  ```

### 2.5 Monitoring (2 min)
- Grafana: dashboard z metrykami podów
- Loki: logi z order-service i user-service
- Alertmanager: reguła PodCrashLooping

### 2.6 Docker lokalnie (1 min, opcjonalnie)
```powershell
docker compose up -d
pytest tests/ -v
docker compose down
```

## 3. Pytania — przygotowane odpowiedzi

| Pytanie | Odpowiedź |
|---------|-----------|
| Dlaczego k3s zamiast EKS? | Koszt: EKS ~72 USD/mies. sam control plane; k3s ~0 USD |
| Jak zapewniasz idempotentność? | Terraform + Ansible z `creates`/`until`; `terraform plan` = no changes |
| Jak chronisz serwery? | SG ograniczone do mojego IP, UFW, sekrety w Jenkins Credentials |
| Co robi Order Service? | Woła User Service przez HTTP, waliduje użytkownika przed utworzeniem zamówienia |
| Jak działają powiadomienia? | Jenkins Email Extension → AWS SES SMTP → mój e-mail |

## Checklist przed obroną

- [ ] Oba EC2 uruchomione
- [ ] Jenkins pipeline zielony
- [ ] Aplikacja odpowiada na curl
- [ ] Grafana dostępna
- [ ] E-mail z ostatniego buildu w skrzynce
- [ ] `terraform plan` bez zmian
- [ ] Docker compose lokalnie działa (backup demo)
