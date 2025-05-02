# Plateforme d'Analyse de Malware (Nyx)

Cette plateforme permet d'analyser des fichiers potentiellement malveillants et d'interagir avec un environnement sandbox via un terminal web.

## Prérequis

- Docker et Docker Compose
- Git
- Un environnement Linux (Ubuntu/Debian recommandé)

## Installation rapide

Clonez le dépôt et naviguez dans le répertoire du projet :

```bash
git clone <URL_DU_REPO> nyx
cd nyx
```

## Démarrage des services

### 1. Démarrage complet (méthode recommandée)

Utilisez le script `run.sh` pour démarrer tous les services en une seule étape :

```bash
chmod +x run.sh
./run.sh
```

Ce script :
- Arrête les conteneurs existants
- Démarre les services backend et frontend
- Configure le terminal interactif
- Vérifie que tous les services sont opérationnels

### 2. Démarrage manuel

Si vous préférez démarrer les services manuellement :

```bash
# Démarrage des conteneurs
docker compose -f docker/compose.yml down
docker compose -f docker/compose.yml up -d

# Configuration du terminal interactif (sans authentification)
chmod +x fix_terminal_no_auth.sh
./fix_terminal_no_auth.sh
```

## URL des services

Une fois les services démarrés, vous pouvez accéder aux différentes interfaces :

- **Frontend** : http://localhost:3000
- **API Backend** : http://localhost:8000
- **Terminal Web** : http://localhost:4200

## Utilisation des fonctionnalités

### Analyser un fichier

1. Accédez à l'interface web via http://localhost:3000
2. Utilisez le formulaire d'upload pour charger un fichier
3. Attendez que l'analyse soit terminée
4. Consultez les résultats dans l'interface

### API REST

L'API expose plusieurs endpoints :

- `GET /health` - Vérification de l'état de l'API
- `POST /upload` - Upload de fichier pour analyse
- `GET /files` - Liste des analyses
- `GET /files/{file_id}` - Détails d'une analyse
- `GET /files/{file_id}/results` - Résultats d'une analyse
- `GET /files/{file_id}/assembly` - Code assembleur d'un fichier analysé
- `POST /files/{file_id}/restart` - Redémarrer une analyse

### Session interactive

#### Méthode 1 : Via l'interface web

1. Accédez à l'interface web via http://localhost:3000
2. Cliquez sur "Session interactive"
3. Un terminal web s'ouvrira automatiquement

#### Méthode 2 : Accès direct au terminal

Accédez directement au terminal web via http://localhost:4200

**Note:** Le terminal web est configuré sans authentification pour un accès direct. Vous obtenez automatiquement les droits root dans le conteneur.

#### Méthode 3 : Via l'API

Vous pouvez démarrer une session interactive via l'API :

```bash
curl -X POST http://localhost:8000/interactive
```

Ensuite, récupérez les informations de connexion :

```bash
curl http://localhost:8000/files/{session_id}/vnc
```

## Résolution des problèmes

### Si le terminal web ne fonctionne pas

Exécutez le script de réparation du terminal :

```bash
./fix_terminal_no_auth.sh
```

### Si le backend ne démarre pas

Exécutez le script de réparation du backend :

```bash
./fix_all.sh
```

### Accès direct au conteneur backend

```bash
docker exec -it docker-backend-1 bash
```

### Vérifier les logs

```bash
# Logs du backend
docker logs docker-backend-1

# Logs du frontend
docker logs docker-frontend-1
```

## Structure des fichiers

- `backend/` - Code du service backend (FastAPI)
- `frontend/` - Code du service frontend (React)
- `docker/` - Fichiers Docker et Docker Compose
- `uploads/` - Dossier pour les fichiers téléchargés
- `results/` - Dossier pour les résultats d'analyse

## Information de sécurité

Cette plateforme est conçue pour un environnement de test. Pour une utilisation en production :

1. Configurez correctement les authentifications
2. Limitez les accès réseau
3. Isolez davantage les conteneurs avec une configuration Docker appropriée 