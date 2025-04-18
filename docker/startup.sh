#!/bin/bash
set -e

echo "Démarrage du conteneur d'analyse..."

# Variables d'environnement
export USER=root
export HOME=/root

# On essaie de démarrer le serveur VNC, mais on continue même en cas d'échec
echo "Tentative de démarrage du serveur VNC..."
mkdir -p ~/.vnc
echo "password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# On tente de lancer le serveur VNC mais on continue en cas d'échec
(vncserver :1 -geometry 1280x800 -depth 24 || echo "Erreur de démarrage VNC, mais on continue...") &

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
    # Maintient le conteneur en vie
    tail -f /dev/null
fi
