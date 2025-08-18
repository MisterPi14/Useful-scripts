#!/bin/bash

# Habilitar autocompletado de nombres de archivos
echo "Por favor, ingresa el nombre del archivo de video (con la extensión, por ejemplo, video.mp4):"
read -e input_file

# Obtener el nombre del archivo sin la extensión
video_name="${input_file%.*}"

# Definir el nombre del archivo de salida
output_file="${video_name}-compressed.mp4"

# Ejecutar el comando de FFmpeg con los nombres de archivo especificados
ffmpeg -hwaccel cuda -i "$input_file" -c:v h264_nvenc -preset slow -b:v 5M -c:a aac -b:a 128k "$output_file"

echo "Compresión completada. El archivo comprimido se ha guardado como $output_file"
