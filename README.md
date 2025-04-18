# Plateforme d'Analyse de Malwares

Une plateforme d'analyse de fichiers binaires potentiellement malveillants, avec une interface web et un environnement isolé dans Docker.

## Prérequis

- Docker
- Docker Compose

## Installation et démarrage

1. Clonez ce dépôt
2. Exécutez le script de démarrage :

```bash
chmod +x run.sh
./run.sh
```

Le script va :
- Vérifier les prérequis
- Créer les répertoires nécessaires
- Construire l'image Docker
- Démarrer les services backend et frontend

## Accès à la plateforme

Une fois les services démarrés, vous pouvez accéder à :

- **Interface Web** : http://localhost:3000
- **API Backend** : http://localhost:8000

## Utilisation de la plateforme

### 1. Analyser un fichier

1. Accédez à l'interface web (http://localhost:3000)
2. Dans la section "Nouvelle analyse", cliquez sur la zone "Sélectionner un fichier à analyser"
3. Choisissez un fichier binaire sur votre ordinateur
4. Cliquez sur le bouton "Lancer l'analyse"
5. La plateforme va télécharger le fichier et lancer l'analyse
6. Vous pouvez suivre l'avancement dans la section "Analyses récentes"
7. Une fois l'analyse terminée (statut "completed"), cliquez sur l'analyse pour voir les résultats

### 2. Via l'API REST

Vous pouvez également utiliser l'API REST directement :

**Télécharger un fichier pour analyse :**
```bash
curl -X POST -F "file=@chemin/vers/votre/fichier" http://localhost:8000/upload
```

**Récupérer la liste des analyses :**
```bash
curl http://localhost:8000/files
```

**Récupérer les détails d'une analyse spécifique :**
```bash
curl http://localhost:8000/files/{id_analyse}
```

**Récupérer les résultats d'une analyse :**
```bash
curl http://localhost:8000/files/{id_analyse}/results
```

### 3. Démarrer une session interactive

Si vous souhaitez analyser un fichier de manière interactive :

1. Cliquez sur le bouton "Démarrer une session interactive"
2. Attendez que la session soit initialisée
3. Utilisez l'interface VNC dans votre navigateur (http://localhost:6080/vnc.html)
4. Vous pouvez maintenant analyser des fichiers dans un environnement Linux Mint isolé

## Format des résultats

Les résultats d'analyse comprennent :

- **Métadonnées** : nom du fichier, taille, date d'analyse, etc.
- **Hashes** : MD5, SHA1, SHA256
- **Résultats des outils** : 
  - Résultat de la commande `file`
  - Extraction des chaînes de caractères
  - Analyse avec Binwalk
  - Désassemblage basique avec Radare2

## Résolution des problèmes

Si vous rencontrez des problèmes lors de l'utilisation de la plateforme :

1. Vérifiez que les services Docker sont en cours d'exécution :
```bash
./status.sh
```

2. Consultez les logs pour identifier les erreurs :
```bash
docker compose -f docker/compose.yml logs
```

3. Redémarrez les services si nécessaire :
```bash
./shutdown.sh
./run.sh
```

## Arrêt de la plateforme

Pour arrêter tous les services :

```bash
./shutdown.sh
``` 