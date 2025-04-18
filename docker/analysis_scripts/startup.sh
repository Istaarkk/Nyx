#!/bin/bash
set -e

# Démarrage du serveur VNC
vncserver :1 -geometry 1280x800 -depth 24 -localhost no

# Démarrage de noVNC (accès web)
/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 &

# Si un fichier à analyser est passé en argument, on lance l'analyse
if [ "$1" != "" ]; then
    echo "Démarrage de l'analyse pour le fichier: $1"
    python3 /opt/analyze.py "$1" &
else
    echo "Mode interactif: aucun fichier à analyser spécifié"
fi

# Maintient le conteneur en vie
tail -f /dev/null 