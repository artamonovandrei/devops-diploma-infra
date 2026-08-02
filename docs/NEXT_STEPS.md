# Status

## Zrobione w kodzie

- [x] Aplikacja: Counter-Strike / WebStrike + Jenkinsfile
- [x] Infra: Terraform, Ansible, k8s (namespace webstrike), docs
- [x] Runtimes: Python 3.12 + Node 22

## Po `terraform apply`

- [ ] Ansible bootstrap
- [ ] Jenkins Multibranch → Counter-Strike
- [ ] Docker Hub + SES credentials
- [ ] kubeconfig na Jenkinsie
- [ ] Smoke: `http://K3S_IP:30080/healthz`

## Koszty

`terraform destroy` w `terraform/environments/dev` gdy nie pracujesz.
