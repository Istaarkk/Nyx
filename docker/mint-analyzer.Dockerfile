FROM linuxmintd/mint20-amd64

# Mise à jour du système et installation des dépendances
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    python3-dev \
    python3-setuptools \
    binutils binwalk file \
    radare2 \
    xxd util-linux \
    unzip p7zip-full \
    curl wget \
    git build-essential \
    # Dépendances pour yara et autres compilations
    libyara-dev \
    libssl-dev \
    flex bison \
    # Nouveaux packages pour VNC/NoVNC
    xfce4 xfce4-goodies \
    tightvncserver novnc websockify \
    firefox \
    # Package pour le terminal web
    shellinabox \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installation des outils Python
RUN pip3 install --no-cache-dir \
    fastapi \
    uvicorn \
    colorama \
    pyyaml \
    pyelftools \
    pefile \
    r2pipe

# Installation de yara-python et lief séparément
RUN pip3 install --no-cache-dir yara-python
RUN pip3 install --no-cache-dir lief

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

# Message d'accueil pour le terminal
RUN echo '#!/bin/bash\necho "=== Bienvenue dans le terminal d analyse de la plateforme Nyx ===\"\necho "Exécutez la commande ls pour voir les fichiers disponibles.\"\necho "Vous pouvez utiliser des commandes comme file, xxd, objdump, etc.\"\necho\n' > /etc/profile.d/welcome.sh && \
    chmod +x /etc/profile.d/welcome.sh

# Port exposés pour VNC, NoVNC et shellinabox
EXPOSE 5901
EXPOSE 6080
EXPOSE 8000
EXPOSE 4200

# Point d'entrée modifié pour démarrer VNC et les outils d'analyse
ENTRYPOINT ["/opt/startup.sh"]
