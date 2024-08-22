# Utiliser l'image Go pour construire le plugin
FROM golang:1.23 as builder

# Définir le répertoire de travail
WORKDIR /workspace

# Copier les fichiers sources du plugin
COPY . .

# Construire le plugin
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o topologicalsort .

# Utiliser une image de base minimale pour exécuter le plugin
FROM gcr.io/distroless/static:nonroot

# Définir le répertoire de travail
WORKDIR /

# Copier le binaire construit depuis l'étape précédente
COPY --from=builder /workspace/topologicalsort .

# Définir l'utilisateur pour l'exécution
USER nonroot:nonroot

# Spécifier le point d'entrée pour le conteneur
ENTRYPOINT ["/topologicalsort"]
