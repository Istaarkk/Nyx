#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Arrêt des services..."

docker compose -f docker/compose.yml down

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Services arrêtés avec succès."
else
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Problème lors de l'arrêt des services."
fi
