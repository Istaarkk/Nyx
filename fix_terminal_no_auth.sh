#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Configuration du terminal sans aucune authentification..."

# Arrêter toutes les instances existantes de shellinabox
echo -e "${YELLOW}Arrêt des instances existantes de shellinabox...${NC}"
docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd || true"
sleep 2

# Option 1: Utiliser la configuration la plus simple possible
echo -e "${YELLOW}Démarrage de shellinabox en mode sans authentification...${NC}"
docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background --service=/:root:root:/:/bin/bash --port=4200"

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
    echo -e "${YELLOW}Aucun login requis - accès automatique en tant que root${NC}"
else
    echo -e "${RED}Le service shellinabox n'a pas pu être démarré.${NC}"
    
    # Option 2: Dernière tentative avec NodeJS et ttyd (si disponible)
    echo -e "${YELLOW}Tentative alternative avec ttyd...${NC}"
    docker exec -u root docker-backend-1 bash -c "apt-get update && apt-get install -y npm git build-essential cmake libjson-c-dev libwebsockets-dev" || true
    docker exec -u root docker-backend-1 bash -c "npm install -g ttyd || git clone https://github.com/tsl0922/ttyd.git && cd ttyd && mkdir build && cd build && cmake .. && make && make install" || true
    docker exec -u root docker-backend-1 bash -c "which ttyd && ttyd -p 4200 bash &" || true
    
    sleep 2
    TTYD_STATUS=$(docker exec docker-backend-1 bash -c "ps aux | grep ttyd | grep -v grep")
    
    if [[ ! -z "$TTYD_STATUS" ]]; then
        echo -e "${GREEN}Le service ttyd est en cours d'exécution:${NC}"
        echo "$TTYD_STATUS"
        
        echo -e "${GREEN}Vous pouvez maintenant accéder au terminal via:${NC}"
        echo -e "http://localhost:4200/"
    else
        echo -e "${RED}Impossible de démarrer un terminal web. Configuration manuelle requise.${NC}"
        echo -e "${YELLOW}Exécutez cette commande pour accéder directement au conteneur:${NC}"
        echo -e "docker exec -it docker-backend-1 bash"
    fi
fi

# Mettre à jour la configuration dans main.py
cat > /tmp/update_config.py << 'EOF'
import re

# Lire le fichier
with open('backend/main.py', 'r') as file:
    content = file.read()

# Localiser le bloc de la fonction setup_session
pattern = r'def setup_session\(\):.*?# Start the setup in a thread'
setup_block = re.search(pattern, content, re.DOTALL)

if setup_block:
    old_setup = setup_block.group(0)
    
    # Créer la nouvelle version de la fonction
    new_setup = """def setup_session():
        try:
            # Install necessary packages
            logger.info("Installing necessary packages...")
            run_command(["apt-get", "update", "-y"])
            run_command(["apt-get", "install", "-y", "shellinabox"])
            
            # Kill any existing shellinabox instance
            run_command(["bash", "-c", "pkill shellinaboxd || true"])
            
            # Start shellinabox on port 4200 without authentication
            result = run_command([
                "shellinaboxd", 
                "--no-beep", 
                "--disable-ssl",
                "--background",
                "--service=/:root:root:/:/bin/bash",
                "--port=4200"
            ])
            
            if result["returncode"] != 0:
                logger.error(f"Failed to start shellinabox: {result['stderr']}")
                update_session_status(session_id, "error")
                return
                
            # Get server IP
            host_ip = "localhost"
            try:
                # Try to get the container's IP address
                host_info = run_command(["hostname", "-I"])
                if host_info["returncode"] == 0 and host_info["stdout"].strip():
                    host_ip = host_info["stdout"].strip().split()[0]
                else:
                    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    s.connect(("8.8.8.8", 80))
                    host_ip = s.getsockname()[0]
                    s.close()
            except:
                logger.warning("Could not determine container IP, falling back to localhost")
            
            # Check if shellinabox is running
            check_cmd = run_command(["bash", "-c", "ps aux | grep -v grep | grep shellinabox"])
            if "shellinabox" not in check_cmd["stdout"]:
                logger.error("shellinabox is not running")
                update_session_status(session_id, "error")
                return
                
            # Update session information
            logger.info(f"Interactive session ready with host IP: {host_ip}")
            update_session_info(session_id, host_ip, 4200, "")
            update_session_status(session_id, "running")
        except Exception as e:
            logger.error(f"Error setting up interactive session: {str(e)}")
            update_session_status(session_id, "error")
            
    # Start the setup in a thread"""
    
    # Remplacer l'ancien bloc par le nouveau
    updated_content = content.replace(old_setup, new_setup)
    
    # Écrire le contenu mis à jour dans le fichier
    with open('backend/main.py', 'w') as file:
        file.write(updated_content)
    
    print("Configuration mise à jour dans main.py")
else:
    print("Impossible de trouver le bloc à mettre à jour dans main.py")
EOF

python3 /tmp/update_config.py

echo -e "${GREEN}Configuration terminée.${NC}"
echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Terminal web sans authentification configuré." 