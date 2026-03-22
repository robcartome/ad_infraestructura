# Despliegue de ApuDig (Backend + Frontend + DB) con Docker

Este repositorio contiene el archivo `docker-compose.yml` para levantar todo el sistema de ApuDig de forma sencilla.

## Requisitos

- Docker Desktop instalado

## Estructura esperada

Coloca las carpetas de los proyectos así:

```
infraestructura/
  docker-compose.yml
  README.md
ad_backend/
  Dockerfile
  requirements.txt
  ...
ad_frontend/
  Dockerfile
  package.json
  ...
```


## Primer uso

1. Clona los tres repositorios en la misma carpeta raíz.
2. Desde la carpeta `infraestructura`, puedes:

### Opción 1: Usar Docker Compose (recomendado)

```sh
docker-compose up --build
```

Esto levantará backend, frontend y base de datos en contenedores.

### Opción 2: Usar el script iniciar_apudig.bat (modo desarrollo)

Haz doble clic en `iniciar_apudig.bat` para lanzar backend y frontend en modo desarrollo (requiere tener Python y Node instalados localmente, y las dependencias instaladas en cada proyecto).

---

Accede a:
- Backend: http://localhost:8000/docs
- Frontend: http://localhost:3000

## Personalización

- Modifica variables de entorno en `docker-compose.yml` según tus necesidades.
- Para producción, ajusta los puertos y credenciales.
