# Verificar el códec
ffmpeg -i tu_video.mp4

# Cambiar el códec a H.264 y comprimir el video
ffmpeg -i tu_video.mp4 -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k video_final.mp4
