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