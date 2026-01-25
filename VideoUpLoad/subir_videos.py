import os
import pickle
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Nombre del archivo donde están las rutas
RUTAS_FILE = 'rutas.txt'
# Archivo de secretos descargado de Google Cloud Console
CLIENT_SECRETS_FILE = 'client_secret.json'
# Alcance de permisos necesarios para subir videos
SCOPES = ['https://www.googleapis.com/auth/youtube.upload']
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

def upload_video(youtube, file_path):
    """Sube un video a YouTube."""
    try:
        # Limpiar comillas si existen en la ruta
        clean_path = file_path.strip().strip('"').strip("'")
        
        if not os.path.exists(clean_path):
            print(f"SALTADO: El archivo no existe: {clean_path}")
            return

        filename = os.path.basename(clean_path)
        print(f"Subiendo: {filename} ...")

        body = {
            'snippet': {
                'title': filename,  # Usamos el nombre del archivo como título
                'description': 'Subido automáticamente vía script Python',
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

        print(f"COMPLETADO: El video {filename} se subió con ID: {response['id']}\n")

    except Exception as e:
        print(f"ERROR al subir {file_path}: {str(e)}")

def main():
    if not os.path.exists(RUTAS_FILE):
        print(f"No se encontró el archivo {RUTAS_FILE}")
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
            upload_video(youtube, ruta)
            
    print("=== Proceso finalizado ===")

if __name__ == '__main__':
    main()
