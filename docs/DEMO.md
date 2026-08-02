# Scenariusz obrony (demo)

## Wstęp (3–5 min)

- Aplikacja: WebStrike (browser FPS) w repo Counter-Strike
- IaC: Terraform + Ansible
- CI/CD: Jenkins → Docker Hub → k3s
- Monitoring: Prometheus, Grafana, Loki

## Demonstracja (10–12 min)

1. Pokaż kod / Docker Compose lokalnie albo UI na `http://K3S_IP:30080`
2. Jenkins: ostatni zielony build na `main` (testy → push → deploy)
3. `kubectl get pods -n webstrike`
4. Zmiana w README / drobny commit → pipeline → e-mail SES
5. Grafana + Loki: logi namespace `webstrike`

## Checklist przed obroną

- [ ] Terraform state w S3, infra wstała
- [ ] Jenkins Multibranch na Counter-Strike
- [ ] Docker Hub R/W token
- [ ] E-mail z ostatniego buildu w skrzynce
- [ ] Gra odpowiada na `:30080`
- [ ] Grafana `:30300`

## Przykładowe pytania

| Pytanie | Odpowiedź |
|---------|-----------|
| Dlaczego osobne repo infra? | Kod gry oddzielony od IaC; dwa projekty na GitHub |
| Jak działa proxy? | Caddy w podzie `web` serwuje klienta i proxy `/api` + `/socket.io` do Service `backend` |
| Powiadomienia? | Jenkins → AWS SES SMTP |
