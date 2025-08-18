#!/bin/bash

# Habilitar autocompletado de nombres de archivos
echo "Por favor, ingresa el nombre del archivo de video (con la extensión, por ejemplo, video.mp4):"
read -e input_file

# Obtener el nombre del archivo sin la extensión
video_name="${input_file%.*}"

# Definir los nombres de los directorios de salida y originales
output_dir="comprimidos"
originals_dir="eliminar"

# Crear los directorios de salida y originales si no existen
mkdir -p "$output_dir"
mkdir -p "$originals_dir"

# Definir el nombre del archivo de salida con la ruta del directorio
output_file="${output_dir}/${video_name}-compressed.mp4"

# Registrar el tiempo de inicio
start_time=$(date +%s)

# Ejecutar el comando de FFmpeg con los nombres de archivo especificados
ffmpeg -hwaccel cuda -i "$input_file" -c:v h264_nvenc -preset slow -b:v 2.5M -c:a aac -b:a 64k "$output_file"

# Registrar el tiempo de finalización
end_time=$(date +%s)

# Calcular el tiempo de ejecución
execution_time=$((end_time - start_time))

# Convertir el tiempo de ejecución a horas, minutos y segundos
hours=$((execution_time / 3600))
minutes=$(( (execution_time % 3600) / 60 ))
seconds=$((execution_time % 60))

# Mover el archivo original al directorio de originales
mv "$input_file" "$originals_dir/"

echo "Compresión completada. El archivo comprimido se ha guardado en $output_dir"
echo "El archivo original se ha movido a $originals_dir"
echo "Tiempo de ejecución: $hours horas, $minutes minutos y $seconds segundos"
