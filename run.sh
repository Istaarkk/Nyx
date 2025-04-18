#!/bin/bash

# startup.sh - Script de démarrage de la plateforme d'analyse de malwares
# Auteur: Claude Mentor
# Date: 2023-10-20

# Définition des couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher des messages
print_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    print_message "Vérification des prérequis..."
    
    # Vérification de Docker
    if command -v docker >/dev/null 2>&1; then
        print_success "Docker est installé: $(docker --version)"
    else
        print_error "Docker n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
    
    # Vérification de Docker Compose
    if command -v docker compose >/dev/null 2>&1; then
        print_success "Docker Compose est installé: $(docker compose --version)"
    else
        print_error "Docker Compose n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
    
    print_success "Tous les prérequis sont satisfaits."
}

# Fonction pour créer les répertoires nécessaires
create_directories() {
    print_message "Création des répertoires nécessaires..."
    
    mkdir -p uploads results db frontend/public
    
    print_success "Répertoires créés avec succès."
}

# Fonction pour construire l'image Docker Mint-analyzer
build_docker_image() {
    print_message "Construction de l'image Docker Mint-analyzer..."
    
    # Vérifier si le répertoire docker existe, sinon le créer
    if [ ! -d "docker" ]; then
        mkdir -p docker
    fi
    
    # Vérifier ou créer le répertoire analysis_scripts
    if [ ! -d "docker/analysis_scripts" ]; then
        print_message "Création du répertoire analysis_scripts..."
        mkdir -p docker/analysis_scripts
    fi
    
    # Créer le script analyze.py s'il n'existe pas
    if [ ! -f "docker/analysis_scripts/analyze.py" ]; then
        print_message "Création du script analyze.py..."
        cat > docker/analysis_scripts/analyze.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import json
import hashlib
import subprocess
import argparse
import time
from datetime import datetime
from pathlib import Path

# Configuration
OUTPUT_DIR = "/output"
INPUT_DIR = "/input"

def calculate_hashes(file_path):
    """Calcule différents hashes pour le fichier."""
    with open(file_path, 'rb') as f:
        content = f.read()
    
    return {
        "md5": hashlib.md5(content).hexdigest(),
        "sha1": hashlib.sha1(content).hexdigest(),
        "sha256": hashlib.sha256(content).hexdigest()
    }

def run_command(command, timeout=60):
    """Exécute une commande et renvoie le résultat."""
    try:
        result = subprocess.run(
            command, 
            capture_output=True, 
            text=True,
            timeout=timeout,
            check=False
        )
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": "Command timed out after {} seconds".format(timeout),
            "returncode": -1
        }

def analyze_file(file_path):
    """Analyse complète du fichier avec tous les outils disponibles."""
    results = {
        "metadata": {
            "filename": os.path.basename(file_path),
            "filesize": os.path.getsize(file_path),
            "hashes": calculate_hashes(file_path),
            "analysis_timestamp": datetime.now().isoformat()
        },
        "tools": {}
    }
    
    # Analyse avec 'file'
    results["tools"]["file"] = run_command(["file", file_path])
    
    # Extraction de strings
    results["tools"]["strings"] = run_command(["strings", file_path])
    
    # Analyse avec binwalk
    results["tools"]["binwalk"] = run_command(["binwalk", "-B", file_path])
    
    # Désassemblage avec radare2 (basique)
    results["tools"]["radare2"] = run_command(["r2", "-q", "-c", "aaa;pdf@main;quit", file_path])
    
    return results

def main():
    parser = argparse.ArgumentParser(description="Analyse de fichiers binaires potentiellement malveillants")
    parser.add_argument("filepath", help="Chemin du fichier à analyser")
    args = parser.parse_args()
    
    filepath = args.filepath
    if not os.path.exists(filepath):
        print(f"Erreur: Le fichier {filepath} n'existe pas.")
        sys.exit(1)
    
    print(f"[+] Démarrage de l'analyse pour: {filepath}")
    
    # Création du répertoire de sortie
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Analyse du fichier
    results = analyze_file(filepath)
    
    # Génération du nom de sortie basé sur le hash SHA256
    output_filename = f"{results['metadata']['hashes']['sha256']}.json"
    output_path = os.path.join(OUTPUT_DIR, output_filename)
    
    # Écriture des résultats
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"[+] Analyse terminée. Résultats écrits dans: {output_path}")
    
    # Créer un fichier 'completed' pour indiquer que l'analyse est terminée
    with open(os.path.join(OUTPUT_DIR, "completed"), 'w') as f:
        f.write(output_filename)

if __name__ == "__main__":
    main()
EOF
        chmod +x docker/analysis_scripts/analyze.py
    fi
    
    # Créer le script startup.sh s'il n'existe pas
    if [ ! -f "docker/startup.sh" ]; then
        print_message "Création du script startup.sh..."
        cat > docker/startup.sh << 'EOF'
#!/bin/bash
set -e

# Démarrage du serveur VNC
mkdir -p ~/.vnc
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
EOF
        chmod +x docker/startup.sh
    fi
    
    # Création ou mise à jour du Dockerfile mint-analyzer
    print_message "Création/Mise à jour du Dockerfile mint-analyzer..."
    cat > docker/mint-analyzer.Dockerfile << 'EOF'
FROM linuxmintd/mint20-amd64

# Mise à jour du système et installation des dépendances
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    binutils binwalk file \
    radare2 \
    xxd util-linux \
    unzip p7zip-full \
    curl wget \
    git build-essential \
    # Nouveaux packages pour VNC/NoVNC
    xfce4 xfce4-goodies \
    tightvncserver novnc websockify \
    firefox \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installation des outils Python
RUN pip3 install --no-cache-dir \
    lief \
    pyelftools \
    pefile \
    yara-python \
    colorama \
    pyyaml \
    r2pipe

# Configuration du VNC
RUN mkdir -p /root/.vnc
RUN echo "password" | vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Configuration de noVNC pour l'accès web
RUN mkdir -p /opt/novnc
RUN ln -s /usr/share/novnc /opt/novnc/lib

# Création du répertoire de travail
WORKDIR /opt

# Copie des scripts d'analyse et de démarrage
COPY analysis_scripts/ /opt/
COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh
RUN chmod +x /opt/analyze.py

# Port exposés pour VNC et NoVNC
EXPOSE 5901
EXPOSE 6080
EXPOSE 8000

# Point d'entrée modifié pour démarrer VNC et les outils d'analyse
ENTRYPOINT ["/opt/startup.sh"]
EOF
    
    # Construction de l'image
    docker build -t mint-analyzer:latest -f docker/mint-analyzer.Dockerfile docker/
    
    if [ $? -eq 0 ]; then
        print_success "Image Docker construite avec succès."
    else
        print_error "Échec de la construction de l'image Docker."
        return 1
    fi
    
    return 0
}

# Fonction pour démarrer les services avec Docker Compose
start_services() {
    print_message "Démarrage des services avec Docker Compose..."
    
    # Vérification si le fichier docker-compose.yml existe
    if [ ! -f "docker/compose.yml" ]; then
        print_message "Le fichier docker/compose.yml n'existe pas, création..."
        
        mkdir -p docker
        cat > docker/compose.yml << 'EOF'
services:
  backend:
    image: mint-analyzer:latest
    ports:
      - "8000:8000"
      - "5901:5901"
      - "6080:6080"
    volumes:
      - ../uploads:/input
      - ../results:/output
      - ../backend:/app
    command: ["sh", "-c", "cd /app && pip install -r requirements.txt && uvicorn main:app --host 0.0.0.0 --port 8000 --reload"]
    restart: unless-stopped
    networks:
      - app-network

  frontend:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ../frontend:/app
    ports:
      - "3000:3000"
    command: sh -c "npm install && npm start"
    environment:
      - NODE_ENV=development
      - CHOKIDAR_USEPOLLING=true
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
EOF
    fi
    
    # Démarrage des services
    docker compose -f docker/compose.yml up -d
    
    if [ $? -eq 0 ]; then
        print_success "Services démarrés avec succès."
    else
        print_error "Échec du démarrage des services."
        return 1
    fi
    
    return 0
}

# Fonction pour vérifier que les services sont opérationnels
check_services() {
    print_message "Vérification que les services sont opérationnels..."
    
    # Attente de 10 secondes pour laisser le temps aux services de démarrer
    print_warning "Attente de 10 secondes pour le démarrage des services..."
    sleep 10
    
    # Vérification du backend
    if curl -s http://localhost:8000/health 2>/dev/null; then
        print_success "Backend API est opérationnel."
    else
        print_warning "Le backend API n'est pas accessible. Vérifiez les logs pour plus d'informations."
    fi
    
    # Vérification du frontend
    if curl -s http://localhost:3000 | grep -q "React"; then
        print_success "Frontend est opérationnel."
    else
        print_warning "Le frontend n'est pas accessible. Vérifiez les logs pour plus d'informations."
    fi
}

# Fonction pour afficher les informations d'accès
show_access_info() {
    echo ""
    print_message "=================================================================="
    print_message "    PLATEFORME D'ANALYSE DE MALWARES - INFORMATIONS D'ACCÈS"
    print_message "=================================================================="
    print_message "Frontend (Interface Web): http://localhost:3000"
    print_message "Backend API: http://localhost:8000"
    print_message "Interface VNC (si session interactive): http://localhost:6080/vnc.html"
    print_message "=================================================================="
    print_message "Pour arrêter les services: ./shutdown.sh"
    print_message "Pour voir les logs: docker compose -f docker/compose.yml logs -f"
    print_message "=================================================================="
    echo ""
}

# Fonction pour créer un script de shutdown
create_shutdown_script() {
    cat > shutdown.sh << 'EOF'
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
EOF

    chmod +x shutdown.sh
    print_success "Script de shutdown créé: ./shutdown.sh"
}

# Fonction pour créer un script de vérification de l'état des services
create_status_script() {
    cat > status.sh << 'EOF'
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
EOF

    chmod +x status.sh
    print_success "Script de vérification d'état créé: ./status.sh"
}

# Fonction principale
main() {
    echo ""
    print_message "=================================================================="
    print_message "    DÉMARRAGE DE LA PLATEFORME D'ANALYSE DE MALWARES"
    print_message "=================================================================="
    echo ""
    
    # Vérification des prérequis
    check_prerequisites
    
    # Création des répertoires
    create_directories
    
    # Construction de l'image Docker
    build_docker_image
    if [ $? -ne 0 ]; then
        print_error "Arrêt du démarrage en raison d'erreurs."
        exit 1
    fi
    
    # Démarrage des services
    start_services
    if [ $? -ne 0 ]; then
        print_error "Arrêt du démarrage en raison d'erreurs."
        exit 1
    fi
    
    # Vérification que les services sont opérationnels
    check_services
    
    # Création des scripts utilitaires
    create_shutdown_script
    create_status_script
    
    # Affichage des informations d'accès
    show_access_info
}

# Exécution de la fonction principale
main
