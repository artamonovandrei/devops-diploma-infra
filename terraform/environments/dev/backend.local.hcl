# Lokalny backend (bez S3) — użyj gdy bootstrap jeszcze nie został uruchomiony:
# terraform init -backend-config=backend.hcl
# lub skopiuj ten plik jako nadpisanie:
# rename main.tf backend section temporarily
#
# Preferowany produkcyjny sposób: terraform/bootstrap + S3 backend w main.tf

path = "terraform.tfstate"
