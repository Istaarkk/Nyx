#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Diagnostic et réparation du backend..."

# Vérification directe du fichier main.py
echo -e "${YELLOW}Examen du fichier backend/main.py à la ligne 410...${NC}"
sed -n "405,415p" backend/main.py

# Correction de l'indentation
echo -e "${YELLOW}Correction de l'indentation dans la fonction upload_file...${NC}"

# Sauvegarde du fichier original
cp backend/main.py backend/main.py.bak
echo -e "${GREEN}Sauvegarde créée: backend/main.py.bak${NC}"

# Correction du fichier main.py avec sed
sed -i '410s/^    /        /' backend/main.py
echo -e "${GREEN}Indentation corrigée à la ligne 410${NC}"

# Vérification des modifications
echo -e "${YELLOW}Vérification des modifications:${NC}"
sed -n "405,415p" backend/main.py

# Vérification des dépendances
echo -e "${YELLOW}Installation et mise à jour des dépendances Python...${NC}"
docker exec -it docker-backend-1 pip install fastapi==0.95.0 uvicorn==0.21.0 sqlalchemy==2.0.9

# Redémarrage du backend
echo -e "${YELLOW}Redémarrage du conteneur backend...${NC}"
docker restart docker-backend-1

# Attente du redémarrage
echo -e "${YELLOW}Attente du redémarrage (10 secondes)...${NC}"
sleep 10

# Vérification finale
echo -e "${YELLOW}Vérification de l'API...${NC}"
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "0")

if [ "$API_STATUS" == "200" ]; then
    echo -e "${GREEN}API backend opérationnelle!${NC}"
else
    echo -e "${RED}L'API backend n'est toujours pas accessible (code: $API_STATUS).${NC}"
    echo -e "${YELLOW}Logs du conteneur backend:${NC}"
    docker logs docker-backend-1 --tail 20
    
    # Tentative de réparation complète
    echo -e "${YELLOW}Tentative de réparation complète...${NC}"
    
    # Remplacer la fonction upload_file complète
    cat > backend/upload_fix.py << 'EOL'
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
    
    # Trouver la ligne de début de la fonction upload_file
    UPLOAD_LINE=$(grep -n "@app.post(\"/upload\"" backend/main.py | cut -d: -f1)
    
    if [ ! -z "$UPLOAD_LINE" ]; then
        echo -e "${GREEN}Fonction upload_file trouvée à la ligne $UPLOAD_LINE${NC}"
        
        # Utiliser awk pour remplacer la fonction
        awk -v line="$UPLOAD_LINE" -v fix="$(cat backend/upload_fix.py)" '
        NR == line {print fix; in_function=1; next}
        /^@app\./ && in_function {in_function=0; print; next}
        in_function {next}
        {print}
        ' backend/main.py > backend/main.py.new
        
        # Remplacer le fichier original
        mv backend/main.py.new backend/main.py
        
        # Nettoyage
        rm backend/upload_fix.py
        
        echo -e "${GREEN}Fonction upload_file remplacée${NC}"
        
        # Redémarrage du backend
        docker restart docker-backend-1
        sleep 10
        
        # Vérification finale après réparation complète
        API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "0")
        if [ "$API_STATUS" == "200" ]; then
            echo -e "${GREEN}API backend opérationnelle après réparation complète!${NC}"
        else
            echo -e "${RED}L'API backend est toujours inaccessible. Une intervention manuelle est nécessaire.${NC}"
        fi
    else
        echo -e "${RED}Impossible de localiser la fonction upload_file. Une intervention manuelle est nécessaire.${NC}"
    fi
fi

echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Diagnostic terminé." 