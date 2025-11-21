import sys
import os
import subprocess
from pathlib import Path
import time

def setup_environment():
    """Configura y activa el entorno virtual automáticamente."""
    home = Path.home()
    venv_path = home / ".python-envs" / "textDevider"
    
    # Determinar ruta del ejecutable python en el venv
    if sys.platform == "win32":
        venv_python = venv_path / "Scripts" / "python.exe"
    else:
        venv_python = venv_path / "bin" / "python"

    # Verificar si estamos corriendo dentro del venv
    try:
        # Resolvemos rutas para comparar correctamente
        # Si el venv no existe, venv_python.resolve() podría fallar o comportarse distinto, 
        # pero la comparación con sys.executable es lo importante.
        if venv_python.exists():
            is_in_venv = Path(sys.executable).resolve() == venv_python.resolve()
        else:
            is_in_venv = False
    except Exception:
        is_in_venv = False

    if not is_in_venv:
        print(f"--- Configurando entorno virtual en {venv_path} ---")
        
        # Crear venv si no existe
        if not venv_python.exists():
            print("Creando entorno virtual...")
            subprocess.check_call([sys.executable, "-m", "venv", str(venv_path)])
            
            # Instalar dependencias
            print("Instalando dependencias...")
            req_file = Path(__file__).parent / "requirements.txt"
            if req_file.exists():
                subprocess.check_call([str(venv_python), "-m", "pip", "install", "-r", str(req_file)])
            else:
                print("requirements.txt no encontrado, instalando pyperclip directamente...")
                subprocess.check_call([str(venv_python), "-m", "pip", "install", "pyperclip"])
        else:
            print("Entorno virtual encontrado.")

        print("Reiniciando script dentro del entorno virtual...\n")
        # Re-ejecutar el script usando el python del venv
        try:
            subprocess.call([str(venv_python)] + sys.argv)
        except KeyboardInterrupt:
            pass
        sys.exit()

# Ejecutar configuración antes de importar librerías externas
setup_environment()

import pyperclip

def split_by_chars(text, n):
    """Divide el texto en bloques de n caracteres."""
    return [text[i:i+n] for i in range(0, len(text), n)]

def split_by_words(text, n):
    """Divide el texto en bloques de n palabras."""
    words = text.split()
    chunks = []
    for i in range(0, len(words), n):
        chunk = " ".join(words[i:i+n])
        chunks.append(chunk)
    return chunks

def main():
    print("--- Script Divisor de Texto y Copiado al Portapapeles ---")
    
    # 1. Leer la cadena de texto desde cadena.txt
    text_file = Path(__file__).parent / "cadena.txt"
    try:
        if not text_file.exists():
            print(f"No se encontró '{text_file.name}'. Creando archivo vacío...")
            text_file.write_text("", encoding='utf-8')
            print(f"Por favor abre '{text_file.name}', pega tu texto y guarda los cambios.")
            input(">>> Presiona ENTER una vez hayas guardado el texto en el archivo...")
        
        text = text_file.read_text(encoding='utf-8').strip()
        if not text:
            print(f"El archivo '{text_file.name}' está vacío. Saliendo...")
            return
        print(f"Texto leído exitosamente de '{text_file.name}' ({len(text)} caracteres).")
            
    except Exception as e:
        print(f"Error al leer el archivo: {e}")
        return

    # 2. Preguntar el tipo de elemento (letra, palabra o longitud)
    mode = ""
    while mode not in ['letra', 'palabra', 'longitud', 'l', 'p', 'c']:
        mode = input("\n¿Quieres dividir por 'letra' (l), 'palabra' (p) o ver la 'longitud' (c)? ").lower().strip()
    
    # Normalizar modo
    if mode == 'l': mode = 'letra'
    if mode == 'p': mode = 'palabra'
    if mode == 'c': mode = 'longitud'

    if mode == 'longitud':
        print(f"\n--- Información del Texto ---")
        print(f"Longitud total (caracteres): {len(text)}")
        print(f"Cantidad de palabras: {len(text.split())}")
        return

    # 3. Preguntar el valor de n
    n = 0
    while n <= 0:
        try:
            n_input = input(f"Ingresa el número de {mode}s por bloque: ")
            n = int(n_input)
            if n <= 0:
                print("Por favor ingresa un número mayor a 0.")
        except ValueError:
            print("Entrada no válida. Por favor ingresa un número entero.")

    # Procesar el texto
    if mode == 'letra':
        blocks = split_by_chars(text, n)
    else:
        blocks = split_by_words(text, n)

    total_blocks = len(blocks)
    print(f"\n--- Se han generado {total_blocks} bloques ---")

    # 4. Copiar al portapapeles bloque por bloque
    for i, block in enumerate(blocks):
        pyperclip.copy(block)
        print(f"\n[Bloque {i+1} de {total_blocks} COPIADO al portapapeles]")
        print(f"Contenido: \"{block}\"")
        
        if i < total_blocks - 1:
            input(">>> Presiona ENTER para copiar el siguiente bloque al portapapeles...")
        else:
            print("\n>>> ¡Listo! Todos los bloques han sido copiados.")

if __name__ == "__main__":
    main()
