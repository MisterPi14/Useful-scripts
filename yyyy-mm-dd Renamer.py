import os
from mutagen.easymp4 import EasyMP4
from datetime import datetime

def rename_files_in_current_folder():
    folder_path = os.path.dirname(os.path.abspath(__file__))
    date_count = {}

    for filename in os.listdir(folder_path):
        if filename.endswith('.m4a'):
            file_path = os.path.join(folder_path, filename)
            audio = EasyMP4(file_path)

            # Intentar obtener la fecha de los metadatos
            creation_date = None
            if audio.tags:
                creation_date = audio.tags.get('©day', None)
            
            if creation_date:
                try:
                    # Convertir la fecha a formato yyyy-mm-dd
                    date_obj = datetime.strptime(creation_date[0], '%Y-%m-%dT%H:%M:%SZ')
                    base_filename = date_obj.strftime('%Y-%m-%d')
                except Exception as e:
                    print(f"Error procesando {filename} usando metadatos: {e}")
                    continue
            else:
                # Si no hay metadatos, usar la fecha de modificación del archivo
                modification_time = os.path.getmtime(file_path)
                date_obj = datetime.fromtimestamp(modification_time)
                base_filename = date_obj.strftime('%Y-%m-%d')
            
            # Contar cuántos archivos ya tienen este nombre base
            if base_filename in date_count:
                date_count[base_filename] += 1
            else:
                date_count[base_filename] = 1

            # Agregar el número incremental si es necesario
            new_filename = f"{base_filename}_{date_count[base_filename]:02}.m4a"
            new_file_path = os.path.join(folder_path, new_filename)
            
            try:
                os.rename(file_path, new_file_path)
                print(f"Renombrado: {filename} -> {new_filename}")
            except Exception as e:
                print(f"Error al renombrar {filename}: {e}")

# Ejecutar la función
rename_files_in_current_folder()
