#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Configuration du terminal sans authentification..."

# Arrêter toutes les instances existantes de shellinabox
echo -e "${YELLOW}Arrêt des instances existantes de shellinabox...${NC}"
docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd || true"
sleep 2

# Créer un utilisateur sans mot de passe si nécessaire
echo -e "${YELLOW}Création d'un utilisateur sandbox sans mot de passe...${NC}"
docker exec -u root docker-backend-1 bash -c "id -u sandbox &>/dev/null || useradd -m sandbox"
docker exec -u root docker-backend-1 bash -c "echo 'sandbox:sandbox' | chpasswd"
docker exec -u root docker-backend-1 bash -c "mkdir -p /home/sandbox && chown sandbox:sandbox /home/sandbox"

# Configurer shellinabox pour démarrer sans demander d'authentification
echo -e "${YELLOW}Configuration et démarrage de shellinabox...${NC}"
docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background --user-css Normal:+/etc/shellinabox/options-enabled/00_White\ On\ Black.css -s '/login:sandbox:sandbox:/home/sandbox:/bin/bash' --port=4200"

# Vérifier que le service est en cours d'exécution
echo -e "${YELLOW}Vérification du service...${NC}"
sleep 2
SERVICE_STATUS=$(docker exec docker-backend-1 bash -c "ps aux | grep shellinabox | grep -v grep")

if [[ ! -z "$SERVICE_STATUS" ]]; then
    echo -e "${GREEN}Le service shellinabox est en cours d'exécution:${NC}"
    echo "$SERVICE_STATUS"
    
    # Obtenir l'adresse IP du conteneur
    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' docker-backend-1)
    
    echo -e "${GREEN}Vous pouvez maintenant accéder au terminal via:${NC}"
    echo -e "http://localhost:4200/ ou http://${CONTAINER_IP}:4200/"
    echo -e "${YELLOW}Login: ${NC}sandbox"
    echo -e "${YELLOW}Mot de passe: ${NC}sandbox"
else
    echo -e "${RED}Le service shellinabox n'a pas pu être démarré.${NC}"
    echo -e "${YELLOW}Tentative avec une configuration alternative...${NC}"
    docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background -s '/login:USER:GROUP:HOME:/bin/bash' --port=4200"
    sleep 2
    
    SERVICE_STATUS=$(docker exec docker-backend-1 bash -c "ps aux | grep shellinabox | grep -v grep")
    if [[ ! -z "$SERVICE_STATUS" ]]; then
        echo -e "${GREEN}Le service shellinabox est maintenant en cours d'exécution avec la configuration alternative:${NC}"
        echo "$SERVICE_STATUS"
        
        echo -e "${GREEN}Vous pouvez maintenant accéder au terminal via:${NC}"
        echo -e "http://localhost:4200/"
        echo -e "${YELLOW}Utilisez les identifiants du système (généralement root sans mot de passe dans un conteneur)${NC}"
    else
        echo -e "${RED}Échec du démarrage avec la configuration alternative.${NC}"
        echo -e "${YELLOW}Tentative avec une configuration minimale...${NC}"
        docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background --port=4200"
        sleep 2
        
        SERVICE_STATUS=$(docker exec docker-backend-1 bash -c "ps aux | grep shellinabox | grep -v grep")
        if [[ ! -z "$SERVICE_STATUS" ]]; then
            echo -e "${GREEN}Le service shellinabox est maintenant en cours d'exécution avec la configuration minimale:${NC}"
            echo "$SERVICE_STATUS"
            
            echo -e "${GREEN}Vous pouvez maintenant accéder au terminal via:${NC}"
            echo -e "http://localhost:4200/"
        else
            echo -e "${RED}Impossible de démarrer shellinabox. Vérifiez les logs du conteneur pour plus de détails.${NC}"
        fi
    fi
fi

# Modifier le fichier main.py pour mettre à jour la configuration dans le code
echo -e "${YELLOW}Mise à jour de la configuration dans le code...${NC}"
PYTHON_FIX=$(cat <<'EOF'
import re

# Lire le fichier
with open('backend/main.py', 'r') as file:
    content = file.read()

# Modifier la configuration shellinabox
updated_content = re.sub(
    r'shellinaboxd", *\n.*"--no-beep",.*\n.*"--disable-ssl",.*\n.*"--port=4200",.*\n.*"--css=.*"', 
    'shellinaboxd",\n                "--no-beep",\n                "--disable-ssl",\n                "--background",\n                "--port=4200"\n                # Aucune authentification pour permettre un accès direct', 
    content
)

# Écrire le contenu mis à jour
with open('backend/main.py', 'w') as file:
    file.write(updated_content)

print("Configuration shellinabox mise à jour dans main.py")
EOF
)

echo "$PYTHON_FIX" > /tmp/update_shellinabox_config.py
python3 /tmp/update_shellinabox_config.py

echo -e "${GREEN}Configuration terminée. Le terminal web devrait maintenant être accessible.${NC}"
echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Configuration terminée." 