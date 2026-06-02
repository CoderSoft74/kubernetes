#!/bin/bash
# setup_repo_simple.sh - Sin preguntas interactivas (OFFLINE)

set -e

REPO_DIR="/opt/ansible-local-repo"
BACKUP_DIR="/etc/apt/sources.list.d/backup_$(date +%Y%m%d_%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAR_FILE="$SCRIPT_DIR/repositorio/ubuntu.tar.gz"

echo "Configurando repositorio local APT (OFFLINE)..."

# ============================================
# 1. VERIFICAR ARCHIVO
# ============================================
if [ ! -f "$TAR_FILE" ]; then
    echo "❌ Error: No se encuentra $TAR_FILE"
    exit 1
fi

# ============================================
# 2. DESHABILITAR SOURCES DE INTERNET
# ============================================
echo "Deshabilitando sources de internet..."

# Crear directorio de backup
sudo mkdir -p "$BACKUP_DIR"

# Mover todos los sources.list.d existentes a backup
if [ -d "/etc/apt/sources.list.d" ]; then
    for file in /etc/apt/sources.list.d/*.list; do
        if [ -f "$file" ]; then
            sudo mv "$file" "$BACKUP_DIR/" 2>/dev/null
            echo "  Movido: $(basename $file)"
        fi
    done
fi

# Mover el sources.list principal si existe
if [ -f "/etc/apt/sources.list" ]; then
    sudo mv /etc/apt/sources.list "$BACKUP_DIR/sources.list.bak"
    echo "  Movido: sources.list"
fi

# Crear sources.list vacío
echo "# Repositorio local offline" | sudo tee /etc/apt/sources.list > /dev/null

echo "✅ Sources de internet deshabilitados"

# ============================================
# 3. EXTRAER REPOSITORIO LOCAL
# ============================================
echo "Extrayendo repositorio local..."
sudo rm -rf "$REPO_DIR"
sudo mkdir -p "$REPO_DIR"
sudo tar -xvf "$TAR_FILE" -C "$REPO_DIR" --strip-components=1 > /dev/null

# ============================================
# 4. GENERAR Packages.gz
# ============================================
if [ ! -f "$REPO_DIR/Packages.gz" ]; then
    echo "Generando Packages.gz..."
    cd "$REPO_DIR"
    sudo dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    cd - > /dev/null
fi

# ============================================
# 5. CONFIGURAR FUENTE LOCAL APT
# ============================================
echo "Configurando fuente local APT..."
echo "deb [trusted=yes] file:$REPO_DIR ./" | sudo tee /etc/apt/sources.list.d/ansible-local-repo.list > /dev/null

# ============================================
# 6. ACTUALIZAR E INSTALAR (OFFLINE)
# ============================================
echo "Actualizando APT (offline)..."
sudo apt-get update --allow-insecure-repositories -o Acquire::Check-Valid-Until=false

echo "Instalando Ansible..."
sudo apt-get install -y ansible sshpass chrony --allow-unauthenticated --no-install-recommends

# ============================================
# 7. VERIFICAR REPOSITORIO
# ============================================
echo "✅ Instalación completada"
ansible --version

# ============================================
# 8. PREPARACION KUBESPRAY BOOTSTRAP
# ============================================

#$SCRIPT_DIR/setup-all.sh

# ============================================
# 9. MOSTRAR INFO DE RESTAURACIÖN
# ============================================
echo ""
echo "=========================================="
echo "Backup de sources originales guardado en:"
echo "  $BACKUP_DIR"
echo ""
echo "Para restaurar los sources de internet:"
echo "  sudo cp -r $BACKUP_DIR/* /etc/apt/sources.list.d/ 2>/dev/null"
echo "  sudo cp $BACKUP_DIR/sources.list.bak /etc/apt/sources.list 2>/dev/null"
echo "  sudo apt-get update"
echo "=========================================="

# ============================================
#  CONFIGURAR SERVIDOR DE TIEMPO
# ============================================

scp $SCRIPT_DIR/server_time/chrony.conf /etc/chrony/
systemctl enable chrony
systemctl start chrony

ip=`hostname -i`
echo "Servidor de tiempo configurado con ip: $ip"

# ============================================
#  COPIANDO ENTORNO PYTHON3
# ============================================

tar -xvf python_env/kubespray-env.tar.gz -C ~/ 

# ============================================
#  ESTABLECIENDO ZONA HORARIA AMERICA/HAVANA
# ============================================

ansible-playbook -i $SCRIPT_DIR/kubespray/inventory/local/hosts.ini $SCRIPT_DIR/kubespray/playbooks/time_sync.yml -e "node_ip=$ip"

# ============================================
#  CONFIGURANDO /ETC/HOSTS
# ============================================

ansible-playbook -i $SCRIPT_DIR/kubespray/inventory/local/hosts.ini $SCRIPT_DIR/kubespray/playbooks/configure_etc_hosts.yml 
