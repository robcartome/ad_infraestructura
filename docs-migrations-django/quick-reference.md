# QUICK REFERENCE: Django Migration APUDIG

**Proyecto:** FastAPI ERP ferretero → Django monolito (MVP 6-8 semanas)

**Archivos esenciales en memoria:**
- `/memories/repo/django-migration-plan-complete.md` ← DOCUMENTO PRINCIPAL (leer primero si continuar)
- `/memories/repo/apudig-architecture-notes.md` ← Notas arquitectura original

---

## ESTADO ACTUAL (29 abril 2026)

✅ Análisis completado
✅ 9 BCs mapeados a 6 Django apps
✅ 42 tablas PostgreSQL identificadas
✅ Plan de 7 fases con tareas concretas
⏳ **PRÓXIMA ACCIÓN:** Fase 1 = Django base + auth + dashboard

---

## APPS DJANGO A CREAR

```
apps/core/ (mixins base: TimeStampedModel, CompanyScopedModel, StoreScopedModel)
apps/companies/ (Company, branding, settings)
apps/users/ (User, Employee, Role, Permission, JWT, RBAC)
apps/partners/ (Customer, Supplier, ContactS, profiles)
apps/inventory/ (maestros + stock + movimientos)
apps/sales/ (cotización + pedido + comprobante)
apps/reports/ (exportación)
```

---

## MULTIEMPRESA (REGLA DE ORO)

- **company_id + store_id SIEMPRE from request.session** (nunca POST)
- Middleware obligatorio en todas las vistas
- Índices compuestos en PostgreSQL
- 403 Forbidden si cross-company attempt
- JWT payload contiene company_id + roles + permisos

---

## TABLAS CLAVE

**Maestros:** categories, brands, units, products, price_lists
**Operación:** stores, warehouses, stock_by_warehouse, movements, movement_details
**Partners:** core_customers (rename → Customer), suppliers, sales_customer_profiles
**Comercial:** document_series, business_document_types, quotations, sale_orders, vouchers
**Auth:** users, roles, permissions, user_roles, user_stores
**Config:** companies, company_branding, company_document_settings

---

## SIMPLIFICACIONES MVP

❌ NO: CQRS, hexagonal, domain entities, repositorios, 100+ permisos
✅ SÍ: Django models directo, services simples, JWT compatible, PDF/Excel

---

## REFERENCIAS GITHUB LOCAL

FastAPI actual:
- Backend: `ad_backend/src/main.py` (routers)
- Models: `ad_backend/src/inventory/db/models.py`, `ad_backend/src/sales/db/models.py`, etc
- Auth: `ad_backend/src/auth/services/jwt_service.py`
- PDF: `ad_backend/src/core/infrastructure/pdf/renderer.py`

Frontend actual:
- Auth: `ad_frontend/src/services/authService.js`
- Pages: `ad_frontend/src/app/(admin)/admin/...`

DB:
- Docker: `ad_infraestructura/docker-compose.yml`
- Migraciones Alembic: `ad_backend/alembic/versions/` (50 scripts)

---

## PRÓXIMAS SESIONES: EMPEZAR CON

```
"Estoy continuando migración Django APUDIG (FastAPI → monolito). 
Referencia: /memories/repo/django-migration-plan-complete.md
Fase a trabajar: [1-7]
Entorno: [local dev | staging | production]
Acción: [setup Django | port models | implement views | ...]"
```

Con eso el agente sabrá exactamente dónde buscar contexto y qué hacer.

---

**Documentación:** Completa y detallada, lista para otro chat/PC
**Próximo paso:** Iniciar Fase 1 (Django setup + auth) o saltar a fase específica si ya tienes progreso
