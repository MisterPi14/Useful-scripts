#!/bin/bash

# 1. Detectar el usuario de Windows y definir el escritorio
USER_WIN=$(/mnt/c/Windows/System32/whoami.exe | cut -d'\' -f2 | tr -d '\r')
ESCRITORIO="/mnt/c/Users/$USER_WIN/Desktop"

# 2. Definir la carpeta de destino (donde vive el script)
DESTINO=$(cd "$(dirname "$0")" && pwd)

echo "Analizando archivos en: $ESCRITORIO"
echo "Destino: $DESTINO"

# 3. Mover archivos con exclusiones específicas
# -type f: Solo archivos (excluye directorios automáticamente)
# ! -iname: Excluye extensiones de imagen comunes
# ! -name: Excluye extensiones de accesos directos (.lnk) e hipervínculos (.url)
find "$ESCRITORIO" -maxdepth 1 -type f \
    ! -iname "*.jpg" ! -iname "*.jpeg" ! -iname "*.png" ! -iname "*.gif" ! -iname "*.webp" \
    ! -name "*.lnk" ! -name "*.url" \
    -exec mv -t "$DESTINO" {} +

echo "Proceso finalizado. Los archivos (JSON, VTT, Video, etc.) han sido movidos."
