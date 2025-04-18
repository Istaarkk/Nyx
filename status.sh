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
