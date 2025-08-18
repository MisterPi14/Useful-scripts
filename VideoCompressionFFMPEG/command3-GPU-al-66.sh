ffmpeg -hwaccel cuda -i tu_video.mp4 -c:v h264_nvenc -preset slow -b:v 5M -c:a aac -b:a 128k video_acelerado.mp4
