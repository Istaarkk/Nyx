#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Réparation complète du backend..."

# Sauvegarde du fichier original
cp backend/main.py backend/main.py.original
echo -e "${GREEN}Sauvegarde créée: backend/main.py.original${NC}"

# Création des versions corrigées des fonctions problématiques
echo -e "${YELLOW}Création des fonctions corrigées...${NC}"

# Fonction upload_file corrigée
cat > /tmp/upload_fix.py << 'EOL'
@app.post("/upload", response_model=FileAnalysis)
async def upload_file(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    try:
        # Création d'un ID unique pour cette analyse
        file_id = str(uuid.uuid4())
    
        # Création du répertoire pour ce fichier
        upload_dir = os.path.join(UPLOAD_DIR, file_id)
        os.makedirs(upload_dir, exist_ok=True)
        
        # Sauvegarde du fichier
        file_path = os.path.join(upload_dir, file.filename)
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        
        # Enregistrement dans la BDD
        save_analysis(file_id, file.filename)
    
        # Lancement de l'analyse en arrière-plan
        background_tasks.add_task(run_analysis, file_id, file_path)
    
        return get_analysis(file_id)
    except Exception as e:
        logger.error(f"Erreur lors de l'upload: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
EOL

# Fonction interactive_session corrigée
cat > /tmp/interactive_fix.py << 'EOL'
@app.post("/interactive", response_model=FileAnalysis)
async def start_interactive_session(background_tasks: BackgroundTasks):
    """Starts an interactive session with a browser terminal in the backend container."""
    
    session_id = str(uuid.uuid4())
    
    # Save to database
    with Session() as session:
        interactive_session = InteractiveSession(
            id=session_id,
            status="starting",
            start_time=datetime.now(),
        )
        session.add(interactive_session)
        session.commit()
    
    # Launch an interactive terminal session
    logger.info(f"Starting interactive session with ID: {session_id}")
    
    # Launch in a separate thread to avoid blocking
    def setup_session():
        try:
            # Install necessary packages
            logger.info("Installing necessary packages...")
            run_command(["apt-get", "update", "-y"])
            run_command(["apt-get", "install", "-y", "shellinabox"])
            
            # Kill any existing shellinabox instance
            run_command(["bash", "-c", "pkill shellinaboxd || true"])
            
            # Start shellinabox on port 4200
            result = run_command([
                "shellinaboxd", 
                "--no-beep", 
                "--disable-ssl",
                "--port=4200",
                "--css=/etc/shellinabox/options-enabled/00_White On Black.css"
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
    
    # Start the setup in a thread
    setup_thread = threading.Thread(target=setup_session)
    setup_thread.daemon = True
    setup_thread.start()
    
    # Create the file analysis record
    save_analysis(session_id, "interactive_session.txt", analysis_type="interactive")
    
    # Update file analysis container info
    container_info = {
        'container_id': "backend-terminal",
        'terminal_host': "localhost",  # Will be updated by the thread
        'terminal_port': 4200,
        'info': "Terminal web interactif"
    }
    update_container_info(session_id, "backend-terminal", container_info)
    
    # Return response
    return {
        "id": session_id,
        "filename": "interactive_session.txt",
        "status": "starting",
        "upload_time": datetime.now().isoformat(),
        "container_id": "backend-terminal",
        "analysis_type": "interactive",
    }
EOL

# Créer un script Python pour reconstruire main.py
cat > /tmp/fix_python.py << 'EOL'
import re
import sys

def main():
    # Lire le fichier original
    with open('backend/main.py', 'r') as f:
        content = f.read()
    
    # Lire les fonctions corrigées
    with open('/tmp/upload_fix.py', 'r') as f:
        upload_function = f.read()
    
    with open('/tmp/interactive_fix.py', 'r') as f:
        interactive_function = f.read()
    
    # Remplacer la fonction upload_file
    pattern_upload = r'@app\.post\("/upload".*?@app\.get\("/files"'
    replacement_upload = upload_function + '\n@app.get("/files"'
    content = re.sub(pattern_upload, replacement_upload, content, flags=re.DOTALL)
    
    # Remplacer la fonction start_interactive_session
    pattern_interactive = r'@app\.post\("/interactive".*?def update_session_status'
    replacement_interactive = interactive_function + '\n\ndef update_session_status'
    content = re.sub(pattern_interactive, replacement_interactive, content, flags=re.DOTALL)
    
    # Écrire dans le nouveau fichier
    with open('backend/main.py', 'w') as f:
        f.write(content)
    
    print("Fichier main.py reconstruit avec succès!")

if __name__ == "__main__":
    main()
EOL

# Exécuter le script Python pour reconstruire main.py
echo -e "${YELLOW}Reconstruction du fichier main.py...${NC}"
python3 /tmp/fix_python.py

# Vérifier la syntaxe Python
echo -e "${YELLOW}Vérification de la syntaxe Python...${NC}"
python3 -m py_compile backend/main.py
if [ $? -eq 0 ]; then
    echo -e "${GREEN}La syntaxe Python est correcte!${NC}"
else
    echo -e "${RED}Erreurs de syntaxe Python détectées.${NC}"
fi

# Arrêter et redémarrer les conteneurs
echo -e "${YELLOW}Redémarrage des conteneurs...${NC}"
docker compose -f docker/compose.yml down
docker compose -f docker/compose.yml up -d

# Attente du démarrage
echo -e "${YELLOW}Attente du démarrage des services (15 secondes)...${NC}"
sleep 15

# Configuration de shellinabox
echo -e "${YELLOW}Configuration de shellinabox...${NC}"
docker exec -u root docker-backend-1 bash -c "apt-get update && apt-get install -y shellinabox curl wget file binutils sudo"
docker exec -u root docker-backend-1 bash -c "pkill shellinaboxd 2>/dev/null || true" 
docker exec -u root docker-backend-1 bash -c "shellinaboxd --no-beep --disable-ssl --background -s '/:nobody:nogroup:/:/bin/bash -l' --port=4200"

# Test de l'API
echo -e "${YELLOW}Test de l'API...${NC}"
sleep 5
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "0")

if [ "$API_STATUS" == "200" ]; then
    echo -e "${GREEN}API backend opérationnelle!${NC}"
    
    # Test d'upload
    echo -e "${YELLOW}Test d'upload de fichier...${NC}"
    echo 'test file' > /tmp/testfile.txt
    UPLOAD_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -F "file=@/tmp/testfile.txt" http://localhost:8000/upload 2>/dev/null || echo "0")
    
    if [ "$UPLOAD_RESULT" == "200" ]; then
        echo -e "${GREEN}Upload de fichier fonctionnel!${NC}"
    else
        echo -e "${RED}Problème avec l'upload de fichier (code: $UPLOAD_RESULT)${NC}"
    fi
    
    # Test de session interactive
    echo -e "${YELLOW}Test de création de session interactive...${NC}"
    INTERACTIVE_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8000/interactive 2>/dev/null || echo "0")
    
    if [ "$INTERACTIVE_RESULT" == "200" ]; then
        echo -e "${GREEN}Création de session interactive fonctionnelle!${NC}"
    else
        echo -e "${RED}Problème avec la création de session interactive (code: $INTERACTIVE_RESULT)${NC}"
    fi
else
    echo -e "${RED}L'API backend n'est pas accessible (code: $API_STATUS).${NC}"
    echo -e "${YELLOW}Logs du conteneur backend:${NC}"
    docker logs docker-backend-1 --tail 20
fi

# Nettoyage
rm -f /tmp/upload_fix.py /tmp/interactive_fix.py /tmp/fix_python.py

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Réparation terminée." 