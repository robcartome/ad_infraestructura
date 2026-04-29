# Migración APUDIG: FastAPI → Django Monolítico (MVP)

**Estado:** Análisis completado, listo para implementación.  
**Última actualización:** 29 abril 2026  
**Responsable:** Análisis inicial completo

---

## RESUMEN EJECUTIVO

**Proyecto actual:**
- Backend FastAPI + SQLAlchemy async, arquitectura hexagonal/CQRS
- 9 bounded contexts: inventory, sales, customer, supplier, auth, company, documents, billing, core
- Frontend Next.js App Router (admin + catálogo público separado)
- PostgreSQL multiempresa por company_id y store_id
- 50 migraciones acumuladas, 42 tablas activas

**Objetivo MVP:**
- Reconstruir como Django monolito (admin web con Tabler)
- Mantener mismo PostgreSQL, reusar modelo de datos
- Eliminar CQRS/hexagonal innecesarios
- Salida a producción 6-8 semanas
- Posponer Next.js admin para después (solo catálogo web si aplica)

**Ganancia clave:** Reducción del 60-70% en capas de código, liberación de ciclo de desarrollo, mantenimiento 3x más simple para equipo pequeño.

---

## 1. ANÁLISIS DEL PROYECTO ACTUAL

### Bounded Contexts (FastAPI)
| BC | Carpeta | Propósito | Tablas clave | Complejidad |
|----|---------|-----------|--------------|-------------|
| inventory | src/inventory | Maestros + operación | products, categories, brands, units, warehouses, stock_by_warehouse, movements, movement_details, document_types, carriers | ALTA (CQRS + repos) |
| sales | src/sales | Comercial | document_series, business_document_types, sale_orders, sale_order_lines, sales_quotations, sales_quotation_lines, vouchers, voucher_lines | ALTA (CQRS + services) |
| customer | src/customer | Source of truth clientes | core_customers, sales_customer_profiles, sales_customer_contacts | MEDIA (commands/queries) |
| supplier | src/supplier | Source of truth proveedores | suppliers | BAJA (commands/queries) |
| auth | src/auth | Auth multiempresa | users, employees, roles, permissions, user_roles, user_stores, refresh_tokens, audit_logs | ALTA (JWT + RBAC) |
| company | src/company | Config empresa | companies, company_branding, company_document_settings | BAJA |
| documents | src/documents | Series transversal | (acoplado a sales.document_series) | BAJA |
| billing | src/billing | Factura | billing_invoices, billing_invoice_lines | BAJA (paralelo a sales.vouchers) |
| core | src/core | Compartido | core_customers (fuente), PDF rendering | MEDIA |

**Conclusión:** 7/9 contexts tienen capas completas (domain/application/infrastructure) que en MVP no son necesarias.

### Tablas Principales (PostgreSQL, 42 activas)

**Maestros Inventario:**
- categories, brands, units, products, price_lists, product_prices

**Operación Física:**
- stores, warehouses, stock_by_warehouse, movements, movement_details

**Partners:**
- core_customers (PK: id UUID)
- suppliers (PK: id UUID)
- sales_customer_profiles (1:1 con core_customers)
- sales_customer_contacts

**Comercial (Sales):**
- document_series, business_document_types
- sales_quotations + sales_quotation_lines
- sale_orders + sale_order_lines
- vouchers + voucher_lines

**Multiempresa/Config:**
- companies (id, name, ruc UNIQUE)
- company_branding (1:1 con companies)
- company_document_settings (1:n con companies)
- stores (company_id FK, name)
- user_stores (user_id FK, store_id FK)

**Auth/Seguridad:**
- users (id, email UNIQUE, password_hash)
- employees (id, company_id FK, user_id FK 1:1)
- roles (id, name UNIQUE)
- permissions (id, code UNIQUE)
- user_roles (user_id FK, role_id FK, company_id FK) — PK compuesto
- refresh_tokens
- audit_logs

**Billing (Paralelo, analizar si congelar):**
- billing_invoices, billing_invoice_lines

**Referencias de archivos:**
- Inventory models: ad_backend/src/inventory/infrastructure/db/models.py (line 20+)
- Sales models: ad_backend/src/sales/infrastructure/db/models.py (line 133+)
- Auth models: ad_backend/src/auth/infrastructure/db/models.py (line 31+)
- Company models: ad_backend/src/company/infrastructure/db/models.py (line 24+)
- Core models: ad_backend/src/core/infrastructure/db/models.py (line 11+)
- Billing models: ad_backend/src/billing/infrastructure/db/models.py (line 14+)

### Complejidad No-MVP Identificada

| Aspecto | Estado Actual | Recomendación |
|--------|---------------|---------------|
| CQRS (commands/queries/handlers) | En todos los BC mayores | Eliminar; usar services simples Django |
| Hexagonal (domain/application/infrastructure) | Implementado | Reducir a models/services/views/forms |
| Mapeos domain ↔ ORM | Repetitivos (from_domain/to_domain) | Dejar ORM como truth, no duplicar |
| Separación de documentos BC | BC separado pero acoplado a sales | Absorber en sales.models |
| Facturación paralela | Billing separado + vouchers en sales | Congelar billing para después del MVP |
| Permisos granulares | 100+ códigos per permission | Simplificar a ~15 roles base (admin, seller, warehouse, etc) |
| PDF WeasyPrint | Actual, con lógica template | Mantener igual, wrapper en Django |
| Reportes pandas/openpyxl/reportlab | Actual | Mantener, posible wrapper en Django |

**Riesgos aceptados en MVP:**
- Documentación de eventos/auditoría básica (no full event sourcing)
- Sin Event Bus; cambios se propagan vía transacciones
- Cache simple en memoria o Redis básico, no invalidación sofisticada
- Permisos por rolle + grupo, no ACL granular por recurso

---

## 2. MAPEO A DJANGO (Apps Propuestas)

### Estructura de apps Django recomendada

```
erp_django/
  manage.py
  config/
    settings.py (BASE_DIR, INSTALLED_APPS, DB config, EMAIL, FILES)
    urls.py (root router)
    wsgi.py
    asgi.py
  apps/
    core/
      models.py (TimeStampedModel, SoftDeleteModel, CompanyScopedModel, StoreScopedModel mixins)
      managers.py (seguridad por company/store)
      auditing.py (decorators/middleware auditoría)
      permissions.py (permisos base)
    companies/
      models.py (Company, CompanyBranding, CompanyDocumentSettings)
      views.py (CRUD)
      forms.py
      admin.py
    users/
      models.py (User, Employee, Role, Permission, UserRole, UserStore, RefreshToken)
      views.py (login, logout, select company/store, profile)
      forms.py (login, register)
      services.py (JWT, password hashing)
      auth.py (middleware, decorators)
      admin.py
    partners/
      models.py (Customer, Supplier, CustomerContact, SalesCustomerProfile)
      views.py (CRUD por tipo)
      forms.py
      services.py (búsqueda, snapshot management)
      admin.py
    inventory/
      models.py (Category, Brand, Unit, Product, PriceList, ProductPrice, Store, Warehouse, StockByWarehouse, Movement, MovementDetail, DocumentType, Carrier)
      views.py (CRUD maestros, registro movimientos, consulta stock)
      forms.py (entrada/salida/transfer/ajuste)
      services.py (reglas stock, validaciones, movimiento)
      reports.py (kardex, stock por almacén)
      admin.py
    sales/
      models.py (DocumentSeries, BusinessDocumentType, SaleOrder, SaleOrderLine, Quotation, QuotationLine, Voucher, VoucherLine)
      views.py (CRUD cotización/pedido/comprobante)
      forms.py
      services.py (workflow cotización→pedido→comprobante, cálculo IGV)
      pdf.py (render PDF comercial)
      admin.py
    reports/
      views.py (stock, movimientos, kardex, análisis)
      exports.py (Excel, PDF)
  templates/
    base.html (Tabler layout, sidebar por permisos)
    navbar.html
    sidebar.html
    pagination.html
    form.html
    tables/
      (macros por tabla tipo)
  static/
    css/ (Tabler custom)
    js/ (HTMX, búsquedas dinámicas)
```

### Mapeo Directo: FastAPI BC → Django App

| FastAPI BC | Django App | Modelos | Simplificación |
|-----------|-----------|---------|---|
| inventory | inventory | Category, Brand, Unit, Product, PriceList, ProductPrice, Store, Warehouse, StockByWarehouse, Movement, MovementDetail, DocumentType, Carrier, ReportView | Quitar commands/queries/services pesados; usar ORM directo en views |
| sales | sales | DocumentSeries, BusinessDocumentType, SaleOrder, SaleOrderLine, Quotation, QuotationLine, Voucher, VoucherLine | Absorber series del BC documents; quitar CQRS |
| customer | partners | Customer (absorber core_customers), SalesCustomerProfile, CustomerContact | 1 modelo Customer con campos comerciales opcionales |
| supplier | partners | Supplier | mismo modelo de suppliers actual |
| auth | users | User, Employee, Role, Permission, UserRole, UserStore, RefreshToken, AuditLog | Mantener JWT, simplificar RBAC si es necesario |
| company | companies | Company, CompanyBranding, CompanyDocumentSettings | sin cambios lógicos |
| documents | (absorber en sales) | DocumentSeries (integrado en sales) | - |
| billing | (congelar para MVP) | - | Dejar para fase 2 si es necesario |
| core | core (app base) | Mixins, shared enums, PDF rendering | - |

---

## 3. DECISIONES ARQUITECTÓNICAS CLAVE

### Multiempresa (CRÍTICO)

**Principio:** company_id y store_id inyectado SIEMPRE desde sesión usuario, nunca de request.

**Implementación:**
```python
# apps/core/middleware.py
class CompanyStoreMiddleware:
  def __call__(self, request):
    if request.user.is_authenticated:
      company_id = request.session.get('company_id')
      store_ids = request.session.get('accessible_store_ids', [])
      request.company_id = UUID(company_id) if company_id else None
      request.store_ids = store_ids
    return response

# apps/core/managers.py
class CompanyScopedQuerySet(QuerySet):
  def for_company(self, company_id):
    return self.filter(company_id=company_id)

class CompanyScopedManager(Manager):
  def get_queryset(self):
    # Siempre filtrado; no devuelve nada sin company_id
    return CompanyScopedQuerySet(self.model, using=self._db)

# apps/inventory/models.py
class Store(models.Model):
  company_id = models.ForeignKey(Company, on_delete=models.CASCADE)
  name = models.CharField(...)
  objects = CompanyScopedManager()
```

**Validación en formularios/vistas:**
- Siempre verificar `request.company_id` vs datos POST.
- 403 Forbidden si tentativa de acceso cross-company.
- Índices PostgreSQL compuestos (company_id, store_id, tipo_documento, fecha).

**Referencias:**
- Auth actual: ad_backend/src/auth/interfaces/dependencies.py (get_company_id_from_token, get_accessible_store_ids)
- Uso en sales: ad_backend/src/sales/infrastructure/api/quotation_router.py (line 149, payload de JWT)

### Modelos Base (Mixins)

```python
# apps/core/models.py
class TimeStampedModel(models.Model):
  created_at = models.DateTimeField(auto_now_add=True)
  updated_at = models.DateTimeField(auto_now=True)
  class Meta:
    abstract = True

class CompanyScopedModel(TimeStampedModel):
  company_id = models.ForeignKey(Company, on_delete=models.CASCADE, db_index=True)
  objects = CompanyScopedManager()
  class Meta:
    abstract = True

class StoreScopedModel(TimeStampedModel):
  store_id = models.ForeignKey(Store, on_delete=models.CASCADE, db_index=True)
  company_id = models.ForeignKey(Company, on_delete=models.CASCADE, db_index=True)  # redundante pero rápido
  objects = StoreScopedManager()
  class Meta:
    abstract = True

class SoftDeleteModel(models.Model):
  deleted_at = models.DateTimeField(null=True, blank=True)
  class Meta:
    abstract = True
```

### Autenticación y Sesión

**Mantener JWT pero simplificar flujo:**
- Login: email + password → access_token + refresh_token (sin company_id).
- Paso 2: select-company → acceso_token NEW (con company_id + roles + permisos scope).
- Middleware: extraer company_id, store_ids del JWT y guardar en sesión.
- Permiso: decorador @permission_required('inventory.view') que verifica JWT payload.

**No romper con FastAPI:**
- API Django debe validar igual JWT (secreto compartido).
- Clientes Next.js/web actuales usan mismo token.

**Referencia:**
- Auth actual: ad_backend/src/auth/infrastructure/services/jwt_service.py
- Login flow: ad_backend/src/auth/interfaces/auth_router.py (line 79+)

### ORM vs Capas (Decisión pragmática)

**No hacer:** domain entities + repositorios + DTOs para CRUD simple.  
**Hacer:** Django models directo, QuerySet manager, form validation, view en template.

**Excepción:** casos con lógica empresarial compleja (generar número serie correlativo, calcular IGV, impacto stock), usar `services.py` con métodos estáticos o instancias.

```python
# apps/sales/services.py
class QuotationService:
  @staticmethod
  def create_from_template(quotation_data: dict, company_id: UUID) -> Quotation:
    # validaciones negocio, cálculos, snapshots
    q = Quotation.objects.create(...)
    for line_data in quotation_data['lines']:
      QuotationLine.objects.create(...)
    return q

# apps/sales/views.py
def quotation_create(request):
  if request.method == 'POST':
    form = QuotationForm(request.POST)
    if form.is_valid():
      try:
        quotation = QuotationService.create_from_template(
          form.cleaned_data,
          company_id=request.company_id
        )
        return redirect('quotation_detail', pk=quotation.id)
      except ValueError as e:
        form.add_error(None, str(e))
  else:
    form = QuotationForm()
  return render(request, 'quotation_form.html', {'form': form})
```

**Beneficio:** lógica testeable, reutilizable, sin overhead de puertos/adaptadores.

---

## 4. PLAN DE MIGRACIÓN (6-8 semanas)

### Fase 0: Descubrimiento (3-5 días)

**Objetivo:** Congelar requisitos, alinear equipo.

**Deliverables:**
- [ ] MVP backlog cerrado (sí/no a billing, websockets, SSO, etc)
- [ ] Matriz mapping FastAPI endpoint → Django URL/view
- [ ] Validar que PostgreSQL actual es fuente única
- [ ] Ambiente de desarrollo Django base setup

**Tareas:**
- Entrevista stakeholder (qué funcionalidad no se toca en MVP, qué se simplifica)
- Ejecutar script análisis FastAPI endpoints (count, tipos, dependencias)
- Crear Django project scaffold con apps base

### Fase 1: Django Base + Auth (1-2 semanas)

**Objetivo:** Login, selección empresa/sucursal, middleware, dashboard mínimo.

**Deliverables:**
- [ ] Django project conectado a PostgreSQL existente
- [ ] Login (email + password) → token + company selection
- [ ] Middleware filtrado por company_id, store_id en sesión
- [ ] Plantilla base Tabler con navbar + sidebar dinámico por permisos
- [ ] Views: login, select-company, dashboard, profile
- [ ] Admin Django funcional para maestros

**Modelos a crear:**
- User, Employee, Role, Permission, UserRole, UserStore (migrate existentes o recrear)
- Company (puede ser lectura de tabla existente)

**Dependencias críticas:**
- Secreto JWT debe ser MISMO que FastAPI (env var compartida)
- URLs Django no chocar con FastAPI (pueden correr en paralelo durante transición)

**Ref. actual:**
- Login FastAPI: ad_backend/src/auth/interfaces/auth_router.py (line 79+)
- JWT service: ad_backend/src/auth/infrastructure/services/jwt_service.py

### Fase 2: Maestros Inventario (1-2 semanas)

**Objetivo:** CRUD completo para categorías, marcas, unidades, productos, almacenes, sucursales.

**Deliverables:**
- [ ] Modelos: Category, Brand, Unit, Product, Store, Warehouse, DocumentType, Carrier
- [ ] Views CRUD (list, detail, create, update, delete)
- [ ] Forms validación + dups check (category name, brand, etc)
- [ ] Filtrado por company + store donde aplique
- [ ] Vistas admin Django para ingesta rápida
- [ ] Búsqueda productos (por nombre, SKU, barcode)

**Datos iniciales:**
- Migrar categories, brands, units, products desde PostgreSQL con Django data migration
- Verificar integridad FK

**Ref. actual:**
- Product model: ad_backend/src/inventory/infrastructure/db/models.py (line 54)
- Producto router FastAPI: ad_backend/src/inventory/infrastructure/api/product_router.py

### Fase 3: Partners (Clientes + Proveedores) (1 semana)

**Objetivo:** Gestión unificada de socios de negocio.

**Deliverables:**
- [ ] Modelos: Customer (absorber core_customers), Supplier, CustomerContact, SalesCustomerProfile
- [ ] Views CRUD por tipo (customers, suppliers)
- [ ] Búsqueda por documento, nombre
- [ ] Integración snapshots (para docs comerciales) vs datos vivos
- [ ] Perfiles comerciales (términos pago, restricciones)

**Simplificación:**
- Usar 1 modelo Customer con campos opcionales en lugar de core_customers + sales_profile separados
- Mantener auditoría básica (quién creó, cuándo)

**Ref. actual:**
- Customer actual: ad_backend/src/customer/infrastructure/db/repository.py
- Supplier actual: ad_backend/src/supplier/infrastructure/db/model.py

### Fase 4: Inventario Operativo (Stock + Movimientos) (2 semanas)

**Objetivo:** Entrada, salida, transferencia, ajuste; consulta stock en tiempo real.

**Deliverables:**
- [ ] Modelos: StockByWarehouse, Movement, MovementDetail
- [ ] Views: registrar entrada/salida/transfer/ajuste
- [ ] Validaciones: stock sufficient para salida, warehouse exists, etc
- [ ] Cálculo automático de stock (entrada suma, salida resta)
- [ ] Consulta kardex por producto x almacén x período
- [ ] Reporte stock actual por almacén
- [ ] Auditoría: quién, cuándo, usuario_id en movements

**Reglas negocio:**
- Movimiento de salida requiere cliente (core_customer_id)
- Movimiento de entrada requiere proveedor (supplier_id) u origen interno
- Transfer requiere warehouse_origin + warehouse_dest
- Ajuste requiere cantidad_física vs cantidad_sistema
- Prevenir salida si stock insuficiente

**Ref. actual:**
- Movement model: ad_backend/src/inventory/infrastructure/db/models.py (line 286)
- Movement service: ad_backend/src/inventory/application/services/movement_service.py
- Frontend movimientos: ad_frontend/src/app/(admin)/admin/inventory/movements/page.js

### Fase 5: Ventas (Cotización → Pedido → Comprobante) (2-3 semanas)

**Objetivo:** Ciclo comercial operativo con PDF.

**Deliverables:**
- [ ] Modelos: DocumentSeries, BusinessDocumentType, Quotation, QuotationLine, SaleOrder, SaleOrderLine, Voucher, VoucherLine
- [ ] Views: CRUD cotización (draft → sent → approved/rejected → cancelled)
- [ ] Views: CRUD pedido (draft → confirmed → cancelled)
- [ ] Views: CRUD comprobante (draft → issued → SUNAT estado)
- [ ] Cálculo IGV, descuentos, totales (automático en modelo o service)
- [ ] Snapshot cliente (documento, nombre, dirección) al emitir
- [ ] Series correlativas (F001-000001, B001-000001, etc) sin gaps
- [ ] PDF comercial (reutilizar plantillas actual o simplificar)
- [ ] Linking: quotation → sale_order → voucher

**Simplificaciones:**
- No CQRS, solo servicios transaccionales
- SUNAT integration: mantener campo sunat_ticket pero fake response en MVP (NoOp gateway)
- No websockets ni notificaciones en tiempo real
- No revisión de crédito cliente (para después)

**Ref. actual:**
- Quotation model: ad_backend/src/sales/infrastructure/db/models.py (line 313)
- Quotation service: ad_backend/src/sales/application/quotation_service.py
- Quotation router: ad_backend/src/sales/infrastructure/api/quotation_router.py
- PDF renderer: ad_backend/src/core/infrastructure/pdf/renderer.py
- Frontend quotaciones: ad_frontend/src/app/(admin)/admin/sales/quotations/page.js

### Fase 6: Reportes + Exportación (1 semana)

**Objetivo:** Stock, movimientos, kardex, análisis en Excel y PDF.

**Deliverables:**
- [ ] Reporte stock por almacén (tabla, filtro by tienda)
- [ ] Reporte movimientos (filtro date range, warehouse, tipo)
- [ ] Kardex por producto (movimientos + saldos acumulados)
- [ ] Exportación Excel (pandas/openpyxl reutilizado)
- [ ] Exportación PDF (ReportLab reutilizado)
- [ ] Filtros dinámicos en vistas (date picker, select warehouse, etc)

**Ref. actual:**
- Report router FastAPI: ad_backend/src/inventory/infrastructure/api/report_router.py
- Frontend reportes: ad_frontend/src/app/(admin)/admin/reports

### Fase 7: Hardening + Deploy (1 semana)

**Objetivo:** Producción estable.

**Deliverables:**
- [ ] Validación funcional end-to-end (login → create quotation → export PDF)
- [ ] Pruebas permisos (user sin rol no ve ventas, etc)
- [ ] Performance baseline (time queries reportes grandes)
- [ ] Backup/restore plan PostgreSQL
- [ ] Env production (DEBUG=False, ALLOWED_HOSTS, SECRET_KEY, DB SSL)
- [ ] Deploy gunicorn + nginx
- [ ] Documentación operativa (cómo backupear, logs, troubleshooting)
- [ ] Capacitación usuarios (1 sesión ~30 min)

---

## 5. SIMPLIFICACIONES EN MVP

### Qué Eliminar / Congelar

| Aspecto | FastAPI Actual | Django MVP | Razón |
|--------|---|---|---|
| Documentación de eventos | Event bus + handlers | Transacciones DB | Reduce complejidad async |
| CQRS por dominio | Full stack (commands/queries) | Services directos | ORM es suficiente para CRUD |
| Permisos granulares | 100+ códigos (inventory.create, inventory.read.detailed, etc) | 12-15 roles (Admin, SalesManager, Seller, Warehouse, Viewer) | 80/20 cubre casos reales |
| Auditoría detallada | Full metadata JSON | user_id, timestamp, basic action | Suficiente para MVP |
| Integraciones externas | SUNAT (aunque dummy) | NoOp gateway, campos para después | Agregar cuando real |
| Sincronización caché | Redis + invalidación | QuerySet caching simple | Sin usuarios concurrentes masivos |
| Websockets/real-time | No implementado | No incluir | Agregar después si necesario |
| Billing separado | 2 tablas + service | Congelar = no migrar | Reusar vouchers de sales por ahora |
| Catálogo Next.js | Parcialmente hecho | No incluir en fase 1 | Después de Django estable |

### Qué Mantener / Priorizar

| Aspecto | FastAPI | Django MVP | Razón |
|--------|---------|-----------|-------|
| Multiempresa core | company_id en todas partes | Misma estrategia | Non-negotiable para SaaS |
| JWT + RBAC | Custom service | Django JWT + decoradores | SSO ready, compatible |
| PDF comercial | WeasyPrint + templates HTML | Mismo | Generación reportes crítica |
| Stock tracking | Transacciones + validaciones | Misma lógica | Core business |
| Series correlativas | Service custom | Django signals + DB constraints | Sin gaps es requerimiento |
| Validaciones documentales | Pydantic | Django forms + custom validators | Protección datos |

---

## 6. REFERENCIAS CLAVE DEL PROYECTO ACTUAL

**Backend FastAPI:**
- Main: ad_backend/src/main.py (routers mapping)
- Inventory models: ad_backend/src/inventory/infrastructure/db/models.py
- Sales models: ad_backend/src/sales/infrastructure/db/models.py
- Auth models: ad_backend/src/auth/infrastructure/db/models.py
- Company models: ad_backend/src/company/infrastructure/db/models.py
- Auth service: ad_backend/src/auth/infrastructure/services/jwt_service.py
- Quotation service: ad_backend/src/sales/application/quotation_service.py
- PDF renderer: ad_backend/src/core/infrastructure/pdf/renderer.py
- Reports: ad_backend/src/inventory/infrastructure/api/report_router.py
- Database: ad_backend/src/inventory/infrastructure/db/database.py
- Migraciones Alembic: ad_backend/alembic/versions (50 scripts)

**Frontend Next.js:**
- Auth context: ad_frontend/src/services/authService.js
- Store access: ad_frontend/src/services/storeAccessService.js
- Movements page: ad_frontend/src/app/(admin)/admin/inventory/movements/page.js
- Quotations page: ad_frontend/src/app/(admin)/admin/sales/quotations/page.js
- Login page: ad_frontend/src/app/login/page.js
- Catálogo público: ad_frontend/src/app/(public)/catalog/page.js

**Infraestructura:**
- Docker compose: ad_infraestructura/docker-compose.yml
- Backend Dockerfile: ad_backend/Dockerfile
- Frontend Dockerfile: ad_frontend/Dockerfile

**Documentación existente:**
- Backend README: ad_backend/README.md
- Frontend README: ad_frontend/README.md
- Auth module guide: ad_backend/AUTH_MODULE_GUIDE.md
- Schema de ejemplo: schema_erp_example.rb

---

## 7. NEXT STEPS PARA OTRO AGENTE / SIGUIENTE SESIÓN

**Tareas inmediatas:**
1. Crear proyecto Django scaffold (django-admin startproject + apps)
2. Configurar PostgreSQL existente en settings.py
3. Crear apps base: core, companies, users, partners, inventory, sales, reports
4. Definir modelos iniciales (TimeStampedModel, CompanyScopedModel, StoreScopedModel)
5. Implementar Fase 1 (auth + dashboard)

**Orden recomendado si retomar:**
- Primero: Fase 1 (auth) → verify login actual funciona + JWT compat
- Luego: Fase 2 (maestros) → port modelos ORM (reusar DDL PostgreSQL)
- Luego: Fase 4 (movimientos) → core business logic
- Luego: Fase 5 (ventas) → comercial
- Finalmente: Fase 6 (reportes) + Fase 7 (producción)

**Riesgos principales:**
- Migración datos: scripts de migración Django vs Alembic actual (usar Django data migrations o raw SQL)
- JWT compatibility: secreto compartido, payload format
- Transición: correr FastAPI + Django en paralelo ~1-2 semanas, luego switch
- Testing: sin tests unitarios en FastAPI actual, agregar en Django desde inicio

---

## DECISIÓN FINAL: EMPEZAR FASE 1

Recomendación: **Pasar a acción directo.** Análisis suficiente, requiere construcción concreta.

Si próxima sesión, abrir con: "Estoy en Fase 1 (Django auth + dashboard)" y referencias a este documento bastará para contexto completo.
