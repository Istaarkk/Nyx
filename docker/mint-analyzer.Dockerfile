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

# Définition des variables d'environnement
ENV USER=root
ENV HOME=/root

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
