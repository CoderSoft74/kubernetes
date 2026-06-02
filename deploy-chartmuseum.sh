#!/usr/bin/env bash
set -euo pipefail

# Variables
CHARTMUSEUM_PORT=8081
CHARTS_DIR="./charts"
CHARTMUSEUM_CONTAINER="chartmuseum"
CHARTMUSEUM_IMAGE="ghcr.io/helm/chartmuseum:v0.15.0"

# Detectar IP del bastion
BASTION_IP=$(hostname -I | awk '{print $1}')

echo "[INFO] Usando bastion IP: $BASTION_IP"
echo "[INFO] Verificando si existe carpeta $CHARTS_DIR"

if [ ! -d "$CHARTS_DIR" ]; then
  echo "[ERROR] No existe la carpeta $CHARTS_DIR con los charts"
  exit 1
fi

# Levantar ChartMuseum en Docker
echo "[INFO] Levantando ChartMuseum en puerto $CHARTMUSEUM_PORT..."
docker rm -f $CHARTMUSEUM_CONTAINER >/dev/null 2>&1 || true
docker run -d --name $CHARTMUSEUM_CONTAINER \
  -p ${CHARTMUSEUM_PORT}:8080 \
  -v "$(pwd)/charts":/charts \
  -e STORAGE="local" \
  -e STORAGE_LOCAL_ROOTDIR="/charts" \
  $CHARTMUSEUM_IMAGE

sleep 5

# Verificar que el contenedor levantó
if ! docker ps | grep -q "$CHARTMUSEUM_CONTAINER"; then
  echo "[ERROR] ChartMuseum no pudo iniciar"
  exit 1
fi

echo "[INFO] Charts disponibles en ChartMuseum:"
helm search repo local

echo "[SUCCESS] ChartMuseum corriendo en http://${BASTION_IP}:${CHARTMUSEUM_PORT}"
