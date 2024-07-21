import os
import shutil

def mover_archivos(origen, destino):
    # Crea la carpeta de destino si no existe
    if not os.path.exists(destino):
        os.makedirs(destino)
    
    # Itera sobre todos los elementos en el origen
    for item in os.listdir(origen):
        item_path = os.path.join(origen, item)
        
        # Verifica si el elemento es el directorio de destino para evitar moverlo dentro de sí mismo
        if item_path == destino:
            continue
        
        # Verifica si el elemento es un archivo o una carpeta (excluyendo accesos directos)
        if os.path.isfile(item_path) and not item_path.endswith('.lnk'):
            shutil.move(item_path, os.path.join(destino, item))
        elif os.path.isdir(item_path):
            shutil.move(item_path, os.path.join(destino, item))

# Define la ruta de origen y destino
origen = 'K:\\Escritorio 1'  # Puedes cambiar esta ruta a la carpeta de origen que desees
destino = 'E:\\Users\\Diego\\Desktop\\2'  # Puedes cambiar esta ruta a la carpeta de destino que desees

# Llama a la función para mover los archivos y carpetas
mover_archivos(origen, destino)
