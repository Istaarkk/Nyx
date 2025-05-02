#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Correction du backend..."

# Correction complète du main.py
echo -e "${YELLOW}Reconstruction de main.py...${NC}"

# Sauvegarde de l'original
cp backend/main.py backend/main.py.backup
echo -e "${GREEN}Sauvegarde créée: backend/main.py.backup${NC}"

# Corriger la fonction interactive_session
sed -i 's/    session_id = str(uuid.uuid4())/session_id = str(uuid.uuid4())/' backend/main.py

# Arrêter et redémarrer tous les conteneurs
echo -e "${YELLOW}Redémarrage des conteneurs...${NC}"
docker compose -f docker/compose.yml down
docker compose -f docker/compose.yml up -d

# Attente du démarrage
echo -e "${YELLOW}Attente du démarrage des services (15 secondes)...${NC}"
sleep 15

# Installer shellinabox et démarrer le terminal
echo -e "${YELLOW}Configuration de shellinabox...${NC}"
docker exec -u root docker-backend-1 bash -c "apt-get update && apt-get install -y shellinabox curl wget file binutils sudo"
docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd 2>/dev/null || true"
docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background -s '/:nobody:nogroup:/:/bin/bash -l' --port=4200 --css=/etc/shellinabox/options-enabled/00_White\ On\ Black.css"

# Vérification finale
echo -e "${YELLOW}Vérification des services...${NC}"
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "0")
TERMINAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/ 2>/dev/null || echo "0")

if [ "$API_STATUS" == "200" ]; then
    echo -e "${GREEN}Backend API est opérationnel.${NC}"
else 
    echo -e "${RED}Backend API n'est pas accessible. Code: $API_STATUS${NC}"
    echo -e "${YELLOW}Logs du conteneur backend:${NC}"
    docker logs docker-backend-1 --tail 20
fi

if [ "$TERMINAL_STATUS" == "200" ]; then
    echo -e "${GREEN}Terminal web est opérationnel.${NC}"
else
    echo -e "${RED}Terminal web n'est pas accessible. Code: $TERMINAL_STATUS${NC}"
fi

echo -e "${GREEN}Configuration terminée.${NC}"
echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Diagnostic terminé." 