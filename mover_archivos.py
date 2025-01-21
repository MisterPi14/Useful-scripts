import os
import shutil

def mover_archivos(destino):
    # Obtiene la ruta del escritorio
    escritorio = os.path.join(os.path.expanduser("~"), "Desktop")
    
    # Crea la carpeta de destino si no existe
    if not os.path.exists(destino):
        os.makedirs(destino)
    
    # Itera sobre todos los elementos en el escritorio
    for item in os.listdir(escritorio):
        item_path = os.path.join(escritorio, item)
        
        # Verifica si el elemento es el directorio de destino para evitar moverlo dentro de sí mismo
        if item_path == destino:
            continue
        
        # Verifica si el elemento es un archivo o una carpeta (excluyendo accesos directos)
        if os.path.isfile(item_path) and not item_path.endswith('.lnk'):
            shutil.move(item_path, os.path.join(destino, item))
        elif os.path.isdir(item_path):
            shutil.move(item_path, os.path.join(destino, item))

# Define la ruta de destino
destino = os.path.join(os.path.expanduser("~"), "Desktop", "Archivos_Movidos", "1")

# Llama a la función para mover los archivos y carpetas
mover_archivos(destino)
