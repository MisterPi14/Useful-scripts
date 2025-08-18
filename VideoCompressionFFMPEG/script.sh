#!/bin/bash

# Definir los directorios de salida y originales
output_dir="comprimidos"
originals_dir="eliminar"

# Crear los directorios de salida y originales si no existen
mkdir -p "$output_dir"
mkdir -p "$originals_dir"

# Extensiones de vídeo a procesar (puedes añadir o quitar según tus necesidades)
extensions=("mp4" "mkv" "avi" "mov" "flv")

# Función para comprimir un archivo
compress_video() {
  local input_file="$1"
  # Obtener el nombre del archivo sin la extensión
  local video_name="${input_file%.*}"
  # Definir el archivo de salida
  local output_file="${output_dir}/${video_name}-compressed.mp4"

  echo "-----------------------------------------"
  echo "Procesando: $input_file"
  echo "Salida:    $output_file"
  
  # Tiempo de inicio
  start_time=$(date +%s)
  
  # Compresión con FFmpeg usando aceleración CUDA
  ffmpeg -hwaccel cuda -i "$input_file" \
    -c:v h264_nvenc -preset slow -b:v 1.75M \
    -c:a aac -b:a 64k \
    "$output_file"
  
  # Tiempo de fin
  end_time=$(date +%s)
  
  # Calcular duración
  execution_time=$((end_time - start_time))
  hours=$((execution_time / 3600))
  minutes=$(((execution_time % 3600) / 60))
  seconds=$((execution_time % 60))
  
  echo "Compresión completada en: ${hours}h ${minutes}m ${seconds}s"
  
  # Mover el original
  mv "$input_file" "$originals_dir/"
  echo "Movido original a: $originals_dir/"
  echo "-----------------------------------------"
  echo
}

# Recorrer todas las extensiones
for ext in "${extensions[@]}"; do
  for file in *."$ext"; do
    # Si no hay archivos con esa extensión, skip
    [[ -e "$file" ]] || continue
    compress_video "$file"
  done
done

echo "Todos los vídeos han sido procesados."
