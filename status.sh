#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Vérification de l'état des services..."

echo -e "${YELLOW}Services Docker:${NC}"
docker compose -f docker/compose.yml ps

echo -e "\n${YELLOW}Logs récents:${NC}"
docker compose -f docker/compose.yml logs --tail=20

# Vérification de shellinabox
echo -e "\n${YELLOW}État de shellinabox:${NC}"
docker exec docker-backend-1 ps aux | grep shellinabox || echo "shellinabox n'est pas en cours d'exécution"

# Possibilité de redémarrer shellinabox
if [ "$1" == "--fix-shellinabox" ]; then
    echo -e "\n${YELLOW}Redémarrage de shellinabox...${NC}"
    docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd || true"
    docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background -s '/:nobody:nogroup:/:/bin/bash -l' --port=4200 --css=/etc/shellinabox/options-enabled/00_White\ On\ Black.css"
    echo -e "${GREEN}Shellinabox redémarré.${NC}"
fi
