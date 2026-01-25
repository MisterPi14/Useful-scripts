# VideoUpLoad - YouTube Uploader

Este script automatiza la subida de videos a YouTube. Para utilizarlo, necesitas configurar dos archivos esenciales: `rutas.txt` y `client_secret.json`.

## 1. Archivo de Rutas (`rutas.txt`)

Debes crear un archivo de texto llamado `rutas.txt` en el mismo directorio que el script. Este archivo debe contener las rutas absolutas de los archivos de video que deseas subir, una ruta por línea.

**Ejemplo de contenido para `rutas.txt`:**
```text
C:\Users\Usuario\Videos\video_vacaciones.mp4
D:\Edicion\ProyectoX\final_render.mov
C:\Users\Usuario\Desktop\vlog_diario.mkv
```

## 2. Credenciales de Google (`client_secret.json`)

Para autenticarte con la API de YouTube, necesitas obtener un archivo de credenciales desde Google Cloud Platform (GCP). Sigue estos pasos detallados:

### Pasos en Google Cloud Platform:

1.  **Crear Proyecto:**
    *   Ve a [Google Cloud Console](https://console.cloud.google.com/).
    *   Crea un nuevo proyecto o selecciona uno existente.

2.  **Habilitar la API de YouTube:**
    *   En el menú de navegación, ve a **"APIs y servicios"** > **"Biblioteca"**.
    *   Busca **"YouTube Data API v3"**.
    *   Selecciónala y haz clic en **"Habilitar"**.

3.  **Configurar Pantalla de Consentimiento OAuth:**
    *   Ve a **"APIs y servicios"** > **"Pantalla de consentimiento de OAuth"**.
    *   Selecciona **"Externo"** (o **"Interno"** si tienes Workspace) y haz clic en "Crear".
    *   Rellena los campos obligatorios (Nombre de la aplicación, Correo de asistencia, Datos de contacto del desarrollador).
    *   Haz clic en "Guardar y continuar" hasta llegar a la sección de **"Usuarios de prueba"**.
    *   **IMPORTANTE:** Añade tu dirección de correo (la que usarás para subir los videos) como usuario de prueba. Si no haces esto, la autenticación fallará porque la app no está verificada por Google.

4.  **Crear Credenciales:**
    *   Ve a **"APIs y servicios"** > **"Credenciales"**.
    *   Haz clic en **"+ CREAR CREDENCIALES"** y selecciona **"ID de cliente de OAuth"**.
    *   En "Tipo de aplicación", selecciona **"Aplicación de escritorio"**.
    *   Ponle un nombre (ej. "Uploader Script") y haz clic en "Crear".

5.  **Descargar y Renombrar:**
    *   Aparecerá una ventana con tus credenciales. Haz clic en el icono de **descarga (JSON)**.
    *   Busca el archivo descargado en tu PC.
    *   **Renómbralo** exactamente a: `client_secret.json`.
    *   Mueve este archivo a la carpeta `VideoUpLoad` junto al script `subir_videos.py`.

## Ejecución

Una vez configurados los archivos anteriores e instaladas las dependencias (`pip install -r requirements.txt`), ejecuta el script:

```bash
python subir_videos.py
```
