@echo off
REM Script para iniciar backend y frontend desde la carpeta infraestructura

REM Calcula la ruta absoluta a la carpeta infraestructura
set "BASE_DIR=%~dp0..\"

REM Inicia el backend
start cmd /k "cd /d %BASE_DIR%ad_backend && call .venv\Scripts\activate && uvicorn src.main:app --reload"

REM Inicia el frontend
start cmd /k "cd /d %BASE_DIR%ad_frontend && npm run dev"

REM Mensaje final
echo Backend y Frontend iniciados en ventanas separadas.
pause