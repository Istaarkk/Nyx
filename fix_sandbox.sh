#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Correction de la sandbox et de l'analyse..."

# Arrêt des conteneurs
echo -e "${YELLOW}Arrêt des conteneurs existants...${NC}"
docker compose -f docker/compose.yml down

# Nettoyage des répertoires temporaires
echo -e "${YELLOW}Nettoyage des répertoires temporaires...${NC}"
rm -rf uploads/*
rm -rf results/*
mkdir -p uploads results

# Correction des permissions
echo -e "${YELLOW}Correction des permissions...${NC}"
sudo chmod -R 777 uploads
sudo chmod -R 777 results

# Redémarrage des services
echo -e "${YELLOW}Redémarrage des services...${NC}"
docker compose -f docker/compose.yml up -d

# Attente du démarrage
echo -e "${YELLOW}Attente du démarrage des services (15 secondes)...${NC}"
sleep 15

# Configuration de shellinabox dans le conteneur
echo -e "${YELLOW}Configuration de shellinabox...${NC}"
docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd 2>/dev/null || true"
docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background -s '/:nobody:nogroup:/:/bin/bash -l' --port=4200 --css=/etc/shellinabox/options-enabled/00_White\ On\ Black.css"

# Vérification finale
echo -e "${YELLOW}Vérification des services...${NC}"
BACKEND_RUNNING=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health || echo "0")
TERMINAL_RUNNING=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/ || echo "0")

if [ "$BACKEND_RUNNING" == "200" ]; then
    echo -e "${GREEN}Backend API est opérationnel.${NC}"
else 
    echo -e "${RED}Backend API n'est pas accessible. Code: $BACKEND_RUNNING${NC}"
fi

if [ "$TERMINAL_RUNNING" == "200" ]; then
    echo -e "${GREEN}Terminal web est opérationnel.${NC}"
else
    echo -e "${RED}Terminal web n'est pas accessible. Code: $TERMINAL_RUNNING${NC}"
fi

echo -e "${GREEN}Correction terminée.${NC}"
