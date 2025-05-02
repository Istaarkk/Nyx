#!/bin/bash
set -e

echo "Démarrage du conteneur d'analyse..."

# Variables d'environnement
export USER=root
export HOME=/root

# Installation de binutils s'il n'est pas déjà installé
if ! command -v objdump &> /dev/null; then
    echo "Installation de binutils pour l'analyse des binaires..."
    apt-get update && apt-get install -y binutils
fi

# On essaie de démarrer le serveur VNC, mais on continue même en cas d'échec
echo "Tentative de démarrage du serveur VNC..."
mkdir -p ~/.vnc
echo "password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# On tente de lancer le serveur VNC mais on continue en cas d'échec
(vncserver :1 -geometry 1280x800 -depth 24 -localhost no || echo "Erreur de démarrage VNC, mais on continue...") &

# Tentative de démarrage de noVNC
echo "Tentative de démarrage de noVNC..."
(/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 || echo "Erreur de démarrage noVNC...") &

# On laisse un peu de temps pour le démarrage des services
sleep 2

# On change pour le répertoire /app
cd /app || cd /opt

# Vérification et installation des dépendances Python
if [ -f "requirements.txt" ]; then
    echo "Installation des dépendances Python..."
    pip install --no-cache-dir -r requirements.txt
fi

# Démarrage du serveur FastAPI
echo "Démarrage du serveur FastAPI..."
if [ -f "main.py" ]; then
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload
else
    echo "Le fichier main.py n'a pas été trouvé, mode conteneur passif..."
    # Si un fichier à analyser est passé en argument, on lance l'analyse
    if [ "$1" != "" ]; then
        echo "Démarrage de l'analyse pour le fichier: $1"
        python3 /opt/analyze.py "$1" &
    else
        echo "Mode interactif: aucun fichier à analyser spécifié"
    fi
    # Maintient le conteneur en vie
    tail -f /dev/null
fi
