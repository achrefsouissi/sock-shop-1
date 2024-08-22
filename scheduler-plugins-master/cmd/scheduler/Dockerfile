# Étape de construction
FROM golang:1.19 AS builder

# Définir le répertoire de travail
WORKDIR /workspace

# Copier les fichiers go.mod et go.sum
COPY go.mod go.sum ./

# Télécharger les dépendances
RUN go mod download

# Copier le reste du code source
COPY . .

# Construire l'application
RUN go build -o scheduler-custom ./cmd/scheduler/main.go

# Étape de runtime
FROM debian:bullseye-slim

# Copier l'exécutable depuis l'étape de construction
COPY --from=builder /workspace/scheduler-custom /usr/local/bin/scheduler-custom

# Définir la commande d'entrée
ENTRYPOINT ["/usr/local/bin/scheduler-custom"]
