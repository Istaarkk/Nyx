# Guide d'Utilisation de la Plateforme d'Analyse de Malwares

## Prérequis

Avant de commencer, assurez-vous d'avoir installé les éléments suivants :

- **Docker** et **Docker Compose**
- **Python** et **pip** (pour le backend FastAPI)
- **Node.js** et **npm** (pour le frontend React)

## Installation et Configuration

### 1. Cloner le dépôt

Clonez le dépôt contenant le code source de la plateforme :

```bash
git clone <URL_DU_DEPOT>
cd <NOM_DU_DEPOT>
```

### 2. Construire les images Docker

Accédez au répertoire `docker` et construisez l'image Docker pour le conteneur d'analyse :

```bash
cd docker
docker build -t mint-analyzer:latest -f mint-analyzer.Dockerfile .
```

### 3. Démarrer les services

Utilisez Docker Compose pour démarrer le backend et le frontend :

```bash
docker-compose up --build
```

Cela lancera le backend FastAPI sur le port **8000** et le frontend React sur le port **3000**.

## Utilisation de la Plateforme

### 1. Accéder à l'Interface Web

Ouvrez votre navigateur et allez à l'adresse suivante :

http://localhost:3000

### 2. Télécharger un Fichier à Analyser

1. Cliquez sur le bouton **"Sélectionner un fichier à analyser"**.
2. Choisissez un fichier binaire (par exemple, `.bin`, `.exe`, `.elf`).
3. Cliquez sur le bouton **"Lancer l'analyse"**.

### 3. Suivre l'Analyse

- Une fois le fichier téléchargé, vous pourrez suivre le statut de l'analyse dans la liste des analyses récentes.
- Les statuts possibles incluent : **pending**, **running**, **completed**, et **failed**.

### 4. Consulter les Résultats

1. Cliquez sur une analyse dans la liste pour voir les détails.
2. Les résultats de l'analyse, y compris les métadonnées et les résultats des outils, seront affichés.
3. Si l'analyse est terminée, vous pourrez télécharger les logs et les résultats.

### 5. Démarrer une Session Interactive

1. Cliquez sur le bouton **"Démarrer une session interactive"**.
2. Une nouvelle session sera lancée dans un environnement Linux Mint accessible via VNC.
3. Vous pourrez interagir avec l'environnement directement depuis votre navigateur.

### 6. Accéder à l'Environnement VNC

- Une fois la session interactive démarrée, un iframe affichera l'interface VNC.
- Vous pouvez également vous connecter à l'environnement via un client VNC en utilisant l'adresse suivante :

```
localhost:<PORT_VNC>
```

Remplacez `<PORT_VNC>` par le port affiché dans les détails de la session.

## Arrêter les Services

Pour arrêter les services, utilisez la commande suivante dans le terminal où Docker Compose est en cours d'exécution :

```bash
docker-compose down
```

## Dépannage

- **Problèmes de connexion** : Assurez-vous que les ports 8000 (backend) et 3000 (frontend) ne sont pas bloqués par un pare-feu.
- **Logs** : Consultez les logs du backend et des conteneurs Docker pour identifier les erreurs.

## Conclusion

Vous avez maintenant une plateforme d'analyse de malwares fonctionnelle. N'hésitez pas à explorer les différentes fonctionnalités et à tester divers fichiers binaires pour évaluer leur sécurité.
