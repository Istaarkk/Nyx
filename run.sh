#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Démarrage de Nyx - Plateforme d'Analyse de Malware"

# Vérifier les prérequis
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker n'est pas installé. Veuillez installer Docker pour continuer.${NC}"; exit 1; }
command -v docker compose >/dev/null 2>&1 || { echo -e "${RED}Docker Compose n'est pas installé. Veuillez installer Docker Compose pour continuer.${NC}"; exit 1; }

# Créer les répertoires nécessaires
echo -e "${YELLOW}Création des répertoires nécessaires...${NC}"
mkdir -p uploads results db

# Nettoyer les conteneurs existants
echo -e "${YELLOW}Arrêt des conteneurs existants...${NC}"
docker compose -f docker/compose.yml down

# Démarrer les services
echo -e "${YELLOW}Démarrage des services...${NC}"
docker compose -f docker/compose.yml up -d

# Attendre que les services démarrent
echo -e "${YELLOW}Attente du démarrage des services (15 secondes)...${NC}"
sleep 15

# Configurer le terminal interactif sans authentification
echo -e "${YELLOW}Configuration du terminal interactif...${NC}"
docker exec -u root docker-backend-1 bash -c "apt-get update && apt-get install -y shellinabox curl wget file binutils sudo" >/dev/null 2>&1
docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd || true" >/dev/null 2>&1
docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background --service=/:root:root:/:/bin/bash --port=4200" >/dev/null 2>&1

# Vérifier que tous les services sont opérationnels
echo -e "${YELLOW}Vérification des services...${NC}"

# Vérifier le backend
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "0")
if [ "$BACKEND_STATUS" == "200" ]; then
    echo -e "${GREEN}✅ API Backend opérationnelle${NC}"
else
    echo -e "${RED}❌ API Backend non disponible (code: $BACKEND_STATUS)${NC}"
    echo -e "${YELLOW}Logs du backend:${NC}"
    docker logs docker-backend-1 --tail 10
fi

# Vérifier le frontend
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "0")
if [ "$FRONTEND_STATUS" == "200" ]; then
    echo -e "${GREEN}✅ Frontend opérationnel${NC}"
else
    echo -e "${RED}❌ Frontend non disponible (code: $FRONTEND_STATUS)${NC}"
    echo -e "${YELLOW}Logs du frontend:${NC}"
    docker logs docker-frontend-1 --tail 10
fi

# Vérifier le terminal web
TERMINAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/ 2>/dev/null || echo "0")
if [ "$TERMINAL_STATUS" == "200" ]; then
    echo -e "${GREEN}✅ Terminal web opérationnel${NC}"
else
    echo -e "${RED}❌ Terminal web non disponible. Tentative de redémarrage...${NC}"
    docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd || true" >/dev/null 2>&1
    docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background --service=/:root:root:/:/bin/bash --port=4200" >/dev/null 2>&1
    sleep 2
    
    # Vérifier à nouveau
    TERMINAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/ 2>/dev/null || echo "0")
    if [ "$TERMINAL_STATUS" == "200" ]; then
        echo -e "${GREEN}✅ Terminal web opérationnel après redémarrage${NC}"
    else
        echo -e "${RED}❌ Terminal web toujours non disponible. Exécutez ./fix_terminal_no_auth.sh manuellement.${NC}"
    fi
fi

# Créer un fichier de test pour vérifier l'upload
echo -e "${YELLOW}Test d'upload de fichier...${NC}"
echo 'test file content' > /tmp/testfile.txt
UPLOAD_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -F "file=@/tmp/testfile.txt" http://localhost:8000/upload 2>/dev/null || echo "0")

if [ "$UPLOAD_RESULT" == "200" ]; then
    echo -e "${GREEN}✅ Upload de fichier fonctionnel${NC}"
else
    echo -e "${RED}❌ Upload de fichier non fonctionnel (code: $UPLOAD_RESULT)${NC}"
fi

# Afficher les informations d'accès
echo -e "\n${BLUE}═════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Nyx est prêt à être utilisé!${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "Accès aux interfaces:"
echo -e "  - Interface web: ${YELLOW}http://localhost:3000${NC}"
echo -e "  - API backend: ${YELLOW}http://localhost:8000${NC}"
echo -e "  - Terminal web: ${YELLOW}http://localhost:4200${NC} (sans authentification)"
echo -e "\nEn cas de problème:"
echo -e "  - Réparer le backend: ${YELLOW}./fix_all.sh${NC}"
echo -e "  - Réparer le terminal: ${YELLOW}./fix_terminal_no_auth.sh${NC}"
echo -e "  - Logs backend: ${YELLOW}docker logs docker-backend-1${NC}"
echo -e "  - Logs frontend: ${YELLOW}docker logs docker-frontend-1${NC}"
echo -e "${BLUE}═════════════════════════════════════════════════════════════════════════════${NC}"

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Démarrage terminé."
