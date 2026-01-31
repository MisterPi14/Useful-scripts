import os
import pickle
import time
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Nombre del archivo donde están las rutas
RUTAS_FILE = 'rutas.txt'
# Archivo de secretos descargado de Google Cloud Console
CLIENT_SECRETS_FILE = 'client_secret.json'
# Alcance de permisos necesarios para subir videos y verificar estado
SCOPES = [
    'https://www.googleapis.com/auth/youtube.upload',
    'https://www.googleapis.com/auth/youtube.readonly'
]
API_SERVICE_NAME = 'youtube'
API_VERSION = 'v3'

def get_authenticated_service():
    """Autentica al usuario y crea el servicio de la API de YouTube."""
    creds = None
    # El archivo token.pickle almacena los tokens de acceso y actualización del usuario
    # y se crea automáticamente cuando el flujo de autorización se completa por primera vez.
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)
    
    # Si no hay credenciales válidas disponibles, deja que el usuario inicie sesión.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CLIENT_SECRETS_FILE):
                print(f"ERROR: No se encontró el archivo '{CLIENT_SECRETS_FILE}'.")
                print("Por favor descarga el archivo JSON de credenciales OAuth 2.0 desde Google Cloud Console.")
                return None

            flow = InstalledAppFlow.from_client_secrets_file(
                CLIENT_SECRETS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Guarda las credenciales para la próxima ejecución
        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)

    return build(API_SERVICE_NAME, API_VERSION, credentials=creds)

def verify_upload(youtube, video_id):
    """Verifica el estado del video en YouTube antes de eliminar el local."""
    print(f"Verificando estado del video ID: {video_id}...")
    attempt = 1
    
    while True:
        try:
            request = youtube.videos().list(
                part="status,processingDetails",
                id=video_id
            )
            response = request.execute()
            
            if not response.get('items'):
                print(f"Intento {attempt}: Video no encontrado en API aun. Esperando...")
                time.sleep(5)
                attempt += 1
                continue
                
            status = response['items'][0]['status']
            upload_status = status.get('uploadStatus')
            
            print(f"Intento {attempt} | Estado en YouTube: {upload_status}")
            
            # 'uploaded': Subida completada exitosamente (YouTube ya tiene el archivo raw)
            # 'processed': Ya procesado
            if upload_status in ['uploaded', 'processed']:
                print("Verificación exitosa: YouTube ha recibido el archivo correctamente.")
                return True
            
            if upload_status in ['rejected', 'failed']:
                print("ERROR FATAL: El video fue rechazado o falló la subida.")
                return False
                
        except Exception as e:
            # Si es un error de permisos (403), no tiene sentido reintentar infinitamente sin cambios
            if "insufficient authentication scopes" in str(e):
                print("\nERROR CRÍTICO DE PERMISOS:")
                print("El token actual no tiene permisos para 'leer' el estado del video.")
                print("SOLUCIÓN: Borra el archivo 'token.pickle' y ejecuta el script de nuevo para re-autorizar.")
                return False
                
            print(f"Error verificando (Intento {attempt}): {e}")
            
        time.sleep(5)
        attempt += 1

def format_file_size(size_bytes):
    """Formatea el tamaño del archivo con prefijos apropiados (KB, MB, GB, TB)."""
    for unit in ['Bytes', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"

def deleteUploadedFiles(file_path):
    """Elimina el archivo local tras verificar subida."""
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"ELIMINADO LOCALMENTE: {file_path}")
    except OSError as e:
        # Si está bloqueado (WinError 32), esperar un poco y reintentar
        if e.errno == 32: # ERROR_SHARING_VIOLATION
            print("Archivo retenido por el sistema, reintentando borrar en 5 segundos...")
            time.sleep(5)
            try:
                os.remove(file_path)
                print(f"ELIMINADO LOCALMENTE (Reintento): {file_path}")
            except Exception as e2:
                 print(f"ERROR FINAL al eliminar {file_path}: {e2}")
        else:
            print(f"ERROR al eliminar {file_path}: {e}")

def upload_video(youtube, file_path, delete_after_upload=False):
    """Sube un video a YouTube."""
    try:
        # Limpiar comillas si existen en la ruta
        clean_path = file_path.strip().strip('"').strip("'")
        
        if not os.path.exists(clean_path):
            print(f"SALTADO: El archivo no existe: {clean_path}")
            return

        filename = os.path.basename(clean_path)
        file_size = os.path.getsize(clean_path)
        formatted_size = format_file_size(file_size)
        print(f"Subiendo: {filename} ({formatted_size}) ...")

        body = {
            'snippet': {
                'title': filename,  # Usamos el nombre del archivo como título
                'description': f'Subido automáticamente vía script Python \n\nRuta original: {clean_path}\nTamaño: {formatted_size}',
                'tags': ['auto-upload'],
                'categoryId': '22' # Categoría 'People & Blogs', puedes cambiarla
            },
            'status': {
                'privacyStatus': 'private', # Privado
                'selfDeclaredMadeForKids': False, # No es contenido para niños
            }
        }

        # MediaFileUpload maneja la subida del archivo. 
        # chunksize=-1 permite que la librería determine el tamaño del fragmento.
        # resumable=True permite reanudar si se corta la conexión.
        media = MediaFileUpload(clean_path, chunksize=-1, resumable=True)

        request = youtube.videos().insert(
            part=','.join(body.keys()),
            body=body,
            media_body=media
        )

        response = None
        while response is None:
            status, response = request.next_chunk()
            if status:
                print(f"Progreso subida: {int(status.progress() * 100)}%")

        video_id = response.get('id')
        print(f"COMPLETADO: El video {filename} se subió con ID: {video_id}\n")

        # IMPORTANTE: Liberar referencias al archivo para evitar WinError 32
        media = None
        request = None

        # Verificar éxito con la API y eliminar si se solicitó
        if delete_after_upload and video_id:
            if verify_upload(youtube, video_id):
                deleteUploadedFiles(clean_path)
            else:
                print("AVISO: No se borró el archivo porque no se pudo verificar la subida exitosa.")

    except Exception as e:
        print(f"ERROR al subir {file_path}: {str(e)}")

def main():
    if not os.path.exists(RUTAS_FILE):
        print(f"No se encontró el archivo {RUTAS_FILE}")
        return

    print("--- OPCIONES DE SUBIDA ---")
    print("1. Subir videos y MANTENER archivos originales")
    print("2. Subir videos y ELIMINAR archivos originales (Borrado definitivo)")
    opcion = input("Seleccione una opción (1/2): ").strip()
    
    delete_files = False
    if opcion == '2':
        confirm = input("¿Está seguro que desea ELIMINAR los archivos tras la subida? (s/n): ").lower()
        if confirm == 's':
            delete_files = True
        else:
            print("Operación cancelada. Se mantendrán los archivos.")
    elif opcion != '1':
        print("Opción no válida. Saliendo...")
        return

    youtube = get_authenticated_service()
    if not youtube:
        return

    print("=== Iniciando proceso de carga masiva ===\n")
    
    with open(RUTAS_FILE, 'r', encoding='utf-8') as f:
        rutas = f.readlines()

    for ruta in rutas:
        ruta = ruta.strip()
        if ruta:
            upload_video(youtube, ruta, delete_after_upload=delete_files)
            
    print("=== Proceso finalizado ===")

if __name__ == '__main__':
    main()
