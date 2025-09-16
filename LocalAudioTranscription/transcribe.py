# Adaptación de código para entorno local Windows 11
# =====================================================
# Este script está simplificado para solo transcribir
# archivos de audio existentes (.wav, .m4a, .mp3, etc.)
# usando Whisper en entorno local.
# =====================================================

# 1. Instalación de dependencias (ejecutar en terminal, no en el script):
#    pip install git+https://github.com/openai/whisper.git jiwer ffmpeg-python
#
# Además, asegúrate de tener instalado ffmpeg y que esté en el PATH:
# https://ffmpeg.org/download.html

import whisper
import os

# =====================================================
# Función de transcripción de audio existente
# =====================================================
def transcribe_audio(filepath, model_name="medium", output_dir="audio_transcription"):
    print(f"Cargando modelo Whisper: {model_name}...")
    model = whisper.load_model(model_name)

    print(f"Transcribiendo {filepath}...")
    result = model.transcribe(filepath, verbose=False, task="transcribe")

    # Crear carpeta de salida si no existe
    os.makedirs(output_dir, exist_ok=True)

    # Guardar transcripción en archivo de texto
    base = os.path.splitext(os.path.basename(filepath))[0]
    out_file = os.path.join(output_dir, base + ".txt")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(result["text"])

    print(f"Transcripción guardada en {out_file}")
    return result["text"]


# =====================================================
# Ejemplo de uso
# =====================================================
if __name__ == "__main__":
    # Sustituye esta ruta por la de tu archivo local
    ejemplo_path = "2024-07-13 17-05-36.mp3"
    texto = transcribe_audio(ejemplo_path, model_name="medium")
    print("\nTexto transcrito:\n", texto)
