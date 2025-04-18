import os
import uuid
import shutil
import json
import subprocess
import hashlib
from typing import List, Optional
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import logging
import sqlite3

# Configuration
UPLOAD_DIR = os.path.abspath("./uploads")
RESULTS_DIR = os.path.abspath("./results")
DB_PATH = os.path.abspath("./db/analyzer.db")

# Initialisation des répertoires
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# Modèles Pydantic
class FileAnalysis(BaseModel):
    id: str
    filename: str
    status: str
    upload_time: str
    completion_time: Optional[str] = None
    container_id: Optional[str] = None
    file_hash: Optional[str] = None
    container_info: Optional[dict] = None
    analysis_type: Optional[str] = "auto"

class AnalysisResult(BaseModel):
    analysis_id: str
    metadata: dict
    tools_results: dict

# Initialisation de l'application FastAPI
app = FastAPI(title="Malware Analysis Platform")

# Middleware CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production, spécifiez les origines exactes
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialisation de la base de données
def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS analyses (
        id TEXT PRIMARY KEY,
        filename TEXT,
        status TEXT,
        upload_time TEXT,
        completion_time TEXT,
        container_id TEXT,
        file_hash TEXT,
        container_info TEXT,
        analysis_type TEXT DEFAULT 'auto'
    )
    ''')
    conn.commit()
    conn.close()

# Fonction pour calculer les hashes d'un fichier
def calculate_hashes(file_path):
    with open(file_path, 'rb') as f:
        content = f.read()
    
    return {
        "md5": hashlib.md5(content).hexdigest(),
        "sha1": hashlib.sha1(content).hexdigest(),
        "sha256": hashlib.sha256(content).hexdigest()
    }

# Fonction pour exécuter une commande et récupérer le résultat
def run_command(command, timeout=60):
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
            "stderr": f"Command timed out after {timeout} seconds",
            "returncode": -1
        }
    except Exception as e:
        return {
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }

# Fonction pour exécuter l'analyse directement sans Docker
def run_analysis(file_id: str, file_path: str):
    try:
        # Préparation des répertoires pour ce job
        job_upload_dir = os.path.join(UPLOAD_DIR, file_id)
        job_results_dir = os.path.join(RESULTS_DIR, file_id)
        
        os.makedirs(job_upload_dir, exist_ok=True)
        os.makedirs(job_results_dir, exist_ok=True)
        
        # Copie du fichier dans le répertoire d'upload spécifique
        filename = os.path.basename(file_path)
        target_path = os.path.join(job_upload_dir, filename)
        shutil.copy2(file_path, target_path)
        
        # Mise à jour du statut
        update_status(file_id, "running")
        
        # Analyse du fichier
        try:
            results = {
                "metadata": {
                    "filename": filename,
                    "filesize": os.path.getsize(target_path),
                    "hashes": calculate_hashes(target_path),
                    "analysis_timestamp": datetime.now().isoformat()
                },
                "tools": {}
            }
            
            # Analyse avec 'file'
            results["tools"]["file"] = run_command(["file", target_path])
            
            # Extraction de strings
            results["tools"]["strings"] = run_command(["strings", target_path])
            
            # Analyse avec binwalk si disponible
            try:
                results["tools"]["binwalk"] = run_command(["binwalk", "-B", target_path])
            except:
                results["tools"]["binwalk"] = {"stdout": "", "stderr": "Binwalk n'est pas disponible", "returncode": -1}
            
            # Enregistrement des résultats
            result_filename = f"{results['metadata']['hashes']['sha256']}.json"
            result_path = os.path.join(job_results_dir, result_filename)
            
            with open(result_path, 'w') as f:
                json.dump(results, f, indent=2)
            
            # Stockage du hash
            update_file_hash(file_id, results["metadata"]["hashes"]["sha256"])
            
            # Création du fichier 'completed' pour indiquer que l'analyse est terminée
            with open(os.path.join(job_results_dir, "completed"), 'w') as f:
                f.write(result_filename)
            
            # Mise à jour du statut
            update_status(file_id, "completed")
            
            return {"success": True, "error": None}
            
        except Exception as e:
            logger.error(f"Erreur pendant l'analyse du fichier {filename}: {str(e)}")
            update_status(file_id, "failed")
            return {"success": False, "error": str(e)}
                
    except Exception as e:
        logger.error(f"Erreur lors de l'analyse {file_id}: {str(e)}")
        update_status(file_id, "failed")
        return {"success": False, "error": str(e)}

# Fonctions d'accès à la base de données
def save_analysis(file_id: str, filename: str, analysis_type="auto"):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO analyses (id, filename, status, upload_time, analysis_type) VALUES (?, ?, ?, ?, ?)",
        (file_id, filename, "pending", datetime.now().isoformat(), analysis_type)
    )
    conn.commit()
    conn.close()

def update_status(file_id: str, status: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    if status in ("completed", "failed"):
        cursor.execute(
            "UPDATE analyses SET status = ?, completion_time = ? WHERE id = ?",
            (status, datetime.now().isoformat(), file_id)
        )
    else:
        cursor.execute(
            "UPDATE analyses SET status = ? WHERE id = ?",
            (status, file_id)
        )
    
    conn.commit()
    conn.close()

def update_container_id(file_id: str, container_id: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE analyses SET container_id = ? WHERE id = ?",
        (container_id, file_id)
    )
    conn.commit()
    conn.close()

def update_file_hash(file_id: str, file_hash: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE analyses SET file_hash = ? WHERE id = ?",
        (file_hash, file_id)
    )
    conn.commit()
    conn.close()

def update_container_info(file_id: str, container_id: str, container_info: dict):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE analyses SET container_id = ?, container_info = ? WHERE id = ?",
        (container_id, json.dumps(container_info), file_id)
    )
    conn.commit()
    conn.close()

def get_analysis(file_id: str) -> Optional[FileAnalysis]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM analyses WHERE id = ?", (file_id,))
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return FileAnalysis(**dict(row))
    return None

def get_all_analyses() -> List[FileAnalysis]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM analyses ORDER BY upload_time DESC")
    rows = cursor.fetchall()
    conn.close()
    
    return [FileAnalysis(**dict(row)) for row in rows]

# Routes de l'API
@app.on_event("startup")
async def startup_event():
    logger.info("Initialisation de l'application...")
    init_db()
    logger.info("Base de données initialisée.")

@app.get("/health")
async def health_check():
    """Endpoint de vérification de l'état de santé de l'API."""
    return {"status": "ok"}

@app.post("/upload", response_model=FileAnalysis)
async def upload_file(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    """Upload et analyse d'un fichier."""
    logger.info(f"Réception d'un fichier: {file.filename}")
    
    # Génération d'un ID unique pour cette analyse
    file_id = str(uuid.uuid4())
    
    # Sauvegarde temporaire du fichier uploadé
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Enregistrement de l'analyse en base
    save_analysis(file_id, file.filename)
    
    # Lancement de l'analyse en arrière-plan
    background_tasks.add_task(run_analysis, file_id, file_path)
    
    # Retourne les informations sur l'analyse
    return FileAnalysis(
        id=file_id,
        filename=file.filename,
        status="pending",
        upload_time=datetime.now().isoformat()
    )

@app.get("/files", response_model=List[FileAnalysis])
async def get_files():
    """Récupération de toutes les analyses."""
    return get_all_analyses()

@app.get("/files/{file_id}", response_model=FileAnalysis)
async def get_file(file_id: str):
    """Récupération des détails d'une analyse spécifique."""
    analysis = get_analysis(file_id)
    if not analysis:
        raise HTTPException(status_code=404, detail="Analyse non trouvée")
    return analysis

@app.get("/files/{file_id}/results")
async def get_results(file_id: str):
    """Récupération des résultats d'une analyse."""
    analysis = get_analysis(file_id)
    if not analysis:
        raise HTTPException(status_code=404, detail="Analyse non trouvée")
    
    if analysis.status != "completed":
        return {
            "analysis_id": file_id,
            "status": analysis.status,
            "message": "L'analyse n'est pas encore terminée."
        }
    
    # Recherche du fichier de résultats
    job_results_dir = os.path.join(RESULTS_DIR, file_id)
    
    if not os.path.exists(job_results_dir):
        raise HTTPException(status_code=404, detail="Répertoire de résultats non trouvé")
    
    completed_file = os.path.join(job_results_dir, "completed")
    if not os.path.exists(completed_file):
        return {
            "analysis_id": file_id,
            "status": "error",
            "message": "Fichier de complétion non trouvé."
        }
    
    with open(completed_file, 'r') as f:
        result_filename = f.read().strip()
    
    result_path = os.path.join(job_results_dir, result_filename)
    if not os.path.exists(result_path):
        return {
            "analysis_id": file_id,
            "status": "error",
            "message": "Fichier de résultats non trouvé."
        }
    
    with open(result_path, 'r') as f:
        results = json.load(f)
    
    return {
        "analysis_id": file_id,
        "status": "completed",
        "metadata": results.get("metadata", {}),
        "tools_results": results.get("tools", {})
    }

@app.post("/files/{file_id}/restart", response_model=FileAnalysis)
async def restart_analysis(file_id: str, background_tasks: BackgroundTasks):
    """Redémarrage d'une analyse."""
    analysis = get_analysis(file_id)
    if not analysis:
        raise HTTPException(status_code=404, detail="Analyse non trouvée")
    
    # Vérification que le fichier est toujours disponible
    file_path = os.path.join(UPLOAD_DIR, analysis.filename)
    if not os.path.exists(file_path):
        job_upload_dir = os.path.join(UPLOAD_DIR, file_id)
        file_path = os.path.join(job_upload_dir, analysis.filename)
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail="Fichier à analyser non trouvé")
    
    # Mise à jour du statut
    update_status(file_id, "pending")
    
    # Lancement de l'analyse en arrière-plan
    background_tasks.add_task(run_analysis, file_id, file_path)
    
    return get_analysis(file_id)

@app.post("/interactive", response_model=FileAnalysis)
async def start_interactive_session(background_tasks: BackgroundTasks):
    """Démarrage d'une session interactive (version simplifiée)."""
    try:
        # Génération d'un ID unique pour cette session
        session_id = str(uuid.uuid4())
        
        # Enregistrement de la session en base
        save_analysis(session_id, "Session interactive (simplifiée)", analysis_type="interactive")
        
        # Informations sur le conteneur
        container_info = {
            'message': "Mode interactif non disponible dans cette version simplifiée"
        }
        
        # Enregistrement des informations
        update_container_info(session_id, "none", container_info)
        
        # Mise à jour du statut
        update_status(session_id, "completed")
        
        # Retourne les informations sur la session
        return FileAnalysis(
            id=session_id,
            filename="Session interactive (simplifiée)",
            status="completed",
            upload_time=datetime.now().isoformat(),
            completion_time=datetime.now().isoformat(),
            container_id="none",
            container_info=container_info,
            analysis_type="interactive"
        )
        
    except Exception as e:
        logger.error(f"Erreur lors du démarrage de la session interactive: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": f"Erreur lors du démarrage de la session: {str(e)}"}
        )

@app.get("/files/{file_id}/vnc")
async def get_vnc_info(file_id: str):
    """Récupération des informations VNC pour une session interactive."""
    analysis = get_analysis(file_id)
    if not analysis:
        raise HTTPException(status_code=404, detail="Session non trouvée")
    
    if analysis.analysis_type != "interactive":
        raise HTTPException(status_code=400, detail="Cette analyse n'est pas une session interactive")
    
    if not analysis.container_info:
        raise HTTPException(status_code=400, detail="Aucune information de connexion disponible")
    
    container_info = json.loads(analysis.container_info) if isinstance(analysis.container_info, str) else analysis.container_info
    
    return {
        "session_id": file_id,
        "message": "Mode interactif simplifié dans cette version"
    } 