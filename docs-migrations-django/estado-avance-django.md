# APUDIG — Estado de avance: migración Django

**Última actualización:** 2026-04-30
**Proyecto Django:** `apudig_mvp/`
**Stack:** Django 5.2.13 · SQLite (dev) · PostgreSQL (prod) · Tabler Bootstrap v1.0.0-beta20 · Tabler Icons 3.19.0

---

## 1. Resumen ejecutivo

El proyecto Django `apudig_mvp` ya supera la fase de esqueleto. Las partes 0–4 del plan de migración están completas. Existen 8 apps funcionales con modelos, servicios, selectores, formularios, vistas function-based, URLs, templates Tabler y tests. El sistema puede gestionar maestros, socios y operaciones de inventario completas.

**Partes completadas:** 0 · 1 · 2 · 3 · 4
**Próxima parte:** 5 — Sales operativo

---

## 2. Apps Django existentes

| App | Estado |
|-----|--------|
| `users` | Modelo completo. Auth por sesión. |
| `companies` | Company, Store, CompanyBranding separado, DocumentSettings, UserCompanyAccess, Middleware, context processor. |
| `core` | Modelo base heredado del backend FastAPI. |
| `partners` | CRUD completo: Clientes, Proveedores, Transportistas. |
| `inventory` | Maestros + Operaciones (stock, movimientos). |
| `sales` | Modelos existentes. Sin vistas aún. |
| `billing` | Modelos existentes. Congelado hasta cerrar ventas. |
| `web` | Login, logout, dashboard, select_company. |

---

## 3. Arquitectura por app (patrón implementado)

```
apps/<dominio>/
  models.py
  selectors.py     ← consultas reutilizables / filtros
  services.py      ← lógica de negocio, @transaction.atomic
  forms.py         ← validación de entrada HTML
  urls.py
  views/
    __init__.py    ← re-exports
    masters.py / partners.py / operations.py
  tests/
    test_masters.py / test_partners.py / test_operations.py
```

### Convenciones importantes

- Vistas: todas function-based (no CBV).
- `_require_auth(request)` → devuelve `redirect("login")` o `None`.
- `_get_store_id(request)` → lee `request.active_store_id` o `request.session["active_store_id"]`.
- `_paginate(request, qs, per_page=25)` → wrapper sobre `Paginator`.
- Widgets: `_text = {"class": "form-control"}`, `_select = {"class": "form-select"}`, `_check = {"class": "form-check-input"}`.
- `AUTH_USER_MODEL = "users.User"`.

---

## 4. Parte 0 — Base del MVP (✅ Completo)

**Qué se hizo:**
- `CompanyBranding` separado de `Company` (campos `app_logo_url`, `pdf_logo_url`, `primary_color`, `secondary_color` movidos).
- `DocumentSeries` corregida: `unique_together` incluye `store_id`.
- Scaffold de carpetas `views/`, `services.py`, `selectors.py`, `forms.py`, `tests/` por app.
- Migraciones iniciales creadas.
- 9 tests de sanidad pasando.

---

## 5. Parte 1 — Auth, multiempresa y shell (✅ Completo)

**Archivos clave:**
- `apudig_mvp/apps/web/views.py` — login, logout, dashboard, select_company.
- `apudig_mvp/apps/companies/middleware.py` — `ActiveCompanyMiddleware` inyecta `request.active_company`, `request.active_store_id`.
- `apudig_mvp/apps/companies/context_processors.py` — `active_company` en templates.
- `apudig_mvp/templates/base.html` — sidebar Tabler con submenús colapsables, dark vertical.
- `apudig_mvp/templates/base_auth.html` — layout para login.
- `apudig_mvp/config/settings.py` — `MIDDLEWARE` incluye `ActiveCompanyMiddleware`.

**Decisión de auth:** `session-only` (no JWT bridge). El frontend Next.js se abandona gradualmente.

---

## 6. Parte 2 — Maestros compartidos (✅ Completo)

**Apps:** `inventory` (maestros), `companies` (settings).

### Modelos cubiertos
- `Category`, `Brand`, `Unit` (en `inventory`)
- `Warehouse` (en `inventory`)
- `Product` (con `sku`, `barcode`, `price_purchase`, `price_sale`, `unit`, `category`, `brand`)
- `StockByWarehouse` (stock por almacén-producto)

### Archivos clave
| Archivo | Descripción |
|---------|-------------|
| `apps/inventory/forms.py` | `CategoryForm`, `BrandForm`, `UnitForm`, `WarehouseForm`, `ProductForm` |
| `apps/inventory/selectors.py` | `get_categories`, `search_categories`, `get_products`, `search_products`, etc. |
| `apps/inventory/views/masters.py` | CRUDs: category, brand, unit, warehouse, product |
| `apps/inventory/urls.py` | 20 rutas bajo `app_name = "inventory"` |
| `templates/inventory/` | `category_list/form`, `brand_list/form`, `unit_list/form`, `warehouse_list/form/detail`, `product_list/form/detail` |
| `templates/partials/` | `search_bar.html`, `pagination.html`, `delete_confirm.html` |

**Tests:** `apps/inventory/tests/test_masters.py` — 12 tests ✓

---

## 7. Parte 3 — Partners completo (✅ Completo)

**App:** `partners`

### Modelos cubiertos
- `CoreCustomer` + `SalesCustomerProfile` + `CustomerContact` (clientes con perfil comercial y contactos)
- `Supplier` (proveedores)
- `Carrier` (transportistas)
- `DocumentType` (tipos de documento: DNI, RUC, CE, Pasaporte, Otro)

### Archivos clave
| Archivo | Descripción |
|---------|-------------|
| `apps/partners/forms.py` | `CustomerForm`, `CustomerProfileForm`, `CustomerContactForm`, `SupplierForm`, `CarrierForm` |
| `apps/partners/selectors.py` | `get_customers`, `search_customers`, `get_suppliers`, `search_suppliers`, `get_carriers`, `search_carriers` |
| `apps/partners/views/partners.py` | customer_list/create/detail/update/delete, contact_create/delete, supplier_list/create/update/delete, carrier_list/create/update/delete |
| `apps/partners/urls.py` | 16 rutas bajo `app_name = "partners"` |
| `templates/partners/` | customer_list, customer_form, customer_detail, supplier_list, supplier_form, carrier_list, carrier_form |

**Notas:**
- `customer_create` crea `CoreCustomer` + `SalesCustomerProfile` en `@transaction.atomic`.
- `customer_update` usa `get_or_create` para el perfil.
- `supplier_create/update` captura `IntegrityError` en `document_number` y vuelve el error al form.

**Tests:** `apps/partners/tests/test_partners.py` — 16 tests ✓

---

## 8. Parte 4 — Inventory operativo (✅ Completo)

**App:** `inventory` (operaciones)

### Modelos cubiertos
- `Movement` (con tipos ENTRY / EXIT / TRANSFER / ADJUSTMENT)
- `MovementDetail`
- `StockByWarehouse` (actualizado por servicios transaccionales)

### Archivos clave
| Archivo | Descripción |
|---------|-------------|
| `apps/inventory/services.py` | `register_entry`, `register_exit`, `register_transfer`, `_create_details_and_update_stock`, `_update_stock_bulk` (todos `@transaction.atomic`) |
| `apps/inventory/selectors.py` (añadido) | `get_movements_for_store`, `search_movements`, `get_movement_detail`, `get_stock_for_product` |
| `apps/inventory/forms.py` (añadido) | `MovementHeaderForm`, `MovementTransferForm`, `MovementDetailForm`, `MovementDetailFormSet` |
| `apps/inventory/views/operations.py` | `stock_report`, `movement_list`, `movement_detail`, `entry_create`, `exit_create`, `transfer_create` |
| `apps/inventory/urls.py` (añadido) | 6 rutas: stock/, movimientos/, movimientos/<pk>/, movimientos/entrada/, movimientos/salida/, movimientos/transferencia/ |
| `templates/inventory/stock_report.html` | Filtro por almacén, tabla de stock. Fila roja si cantidad <= 0. |
| `templates/inventory/movement_list.html` | Badges por tipo, filtro tipo+búsqueda, paginación. |
| `templates/inventory/movement_form.html` | Template compartida entry/exit/transfer. Formset inline con JS add/remove filas. |
| `templates/inventory/movement_detail.html` | Cabecera + tabla de ítems. |

**`MovementHeaderForm.__init__`:** acepta `store_id=` y `movement_type=`. Filtra almacenes por `store_id`. Oculta campos irrelevantes por tipo (ENTRY oculta customer, EXIT oculta supplier, TRANSFER/ADJUSTMENT oculta supplier+customer+carrier).

**`MovementDetailFormSet`:** prefix `"lines"`. JS en `movement_form.html` maneja `lines-TOTAL_FORMS` al agregar/quitar filas.

**Bug corregido:** `min_value` en `MovementDetailForm` estaba como `str`. Corregido a `Decimal("0.001")` / `Decimal("0")`.

**Tests:** `apps/inventory/tests/test_operations.py` — 8 tests ✓

**Total tests inventory:** 20 (12 masters + 8 operations)

---

## 9. Sidebar `base.html` — estado actual

```html
<!-- Inventario -->
<a href="{% url 'inventory:product_list' %}">Productos</a>
<a href="{% url 'inventory:warehouse_list' %}">Almacenes</a>
<a href="{% url 'inventory:movement_list' %}">Movimientos</a>
<a href="{% url 'inventory:stock_report' %}">Stock</a>
<!-- Maestros -->
<a href="{% url 'inventory:category_list' %}">Categorías</a>
<a href="{% url 'inventory:brand_list' %}">Marcas</a>
<a href="{% url 'inventory:unit_list' %}">Unidades</a>
<!-- Socios -->
<a href="{% url 'partners:customer_list' %}">Clientes</a>
<a href="{% url 'partners:supplier_list' %}">Proveedores</a>
<a href="{% url 'partners:carrier_list' %}">Transportistas</a>
```

---

## 10. Tests totales por app

| App | Archivo | Tests |
|-----|---------|-------|
| `inventory` | `test_masters.py` | 12 ✓ |
| `inventory` | `test_operations.py` | 8 ✓ |
| `partners` | `test_partners.py` | 16 ✓ |
| `companies` | *(varios)* | 9 ✓ |
| **Total** | | **~45 ✓** |

---

## 11. Parte 5 — Sales operativo (⏳ PENDIENTE)

**Objetivo:** Migrar el flujo comercial principal.

**Alcance:**
- `BusinessDocumentType` (tipos documentarios por empresa/sucursal)
- `DocumentSeries` (series por sucursal, tipo y serie)
- `Quotation` + `QuotationLine` (cotizaciones)
- `SaleOrder` + `SaleOrderLine` (órdenes de venta)
- `Voucher` + `VoucherLine` (comprobantes)
- PDF de comprobante/cotización
- Settings documentarios por empresa

**Archivos de referencia para implementar:**
- `apudig_mvp/apps/sales/models.py` — modelos ya existentes
- `ad_backend/src/sales/` — lógica original FastAPI
- `ad_frontend/src/app/(admin)/admin/sales/` — UI original Next.js

**Notas para arrancar:**
- `DocumentSeries` ya tiene `unique_together = (company, store, voucher_type, series)` (corregido en Parte 0).
- El flujo es: Cotización → aprobar → Orden de venta → emitir → Comprobante.
- Los comprobantes se numeran correlativelamente por serie y sucursal.
- PDF: usar `weasyprint` o `xhtml2pdf` (ya en `requirements.txt` del backend FastAPI: buscar cual está disponible).

---

## 12. Partes 6 y 7 — Futuro

### Parte 6 — Reportes y exportaciones
- Reporte de stock por almacén (ya existe vista básica `stock_report`).
- Kardex por producto.
- Movimientos filtrados por fecha/tipo/almacén.
- Exportación Excel (`openpyxl`) y PDF.

### Parte 7 — Cutover
- Migración de datos desde PostgreSQL del sistema FastAPI.
- Desactivación del frontend Next.js + backend FastAPI.
- Configuración de entorno producción.

---

## 13. Comandos útiles

```bash
# Activar entorno virtual
cd C:\Proyectos\Apudig\Proyecto\apudig_mvp
.\.venv\Scripts\Activate.ps1

# Verificar sistema
python manage.py check

# Tests
python manage.py test apps.inventory apps.partners apps.companies --verbosity=1

# Migraciones
python manage.py makemigrations
python manage.py migrate

# Servidor de desarrollo
python manage.py runserver
```

---

## 14. Archivos de referencia importantes

| Archivo | Propósito |
|---------|-----------|
| `ad_infraestructura/docs-migrations-django/mvp-gap-analysis-and-phased-plan.md` | Plan completo de migración por partes |
| `ad_infraestructura/docs-migrations-django/django-migration-plan-complete.md` | Plan detallado técnico |
| `ad_infraestructura/docs-migrations-django/file-references.md` | Mapa de archivos origen → destino |
| `ad_infraestructura/docs-migrations-django/quick-reference.md` | Referencia rápida de convenciones |
| `apudig_mvp/apps/inventory/models.py` | Movement.MOVEMENT_TYPES, StockByWarehouse |
| `apudig_mvp/apps/inventory/services.py` | register_entry / exit / transfer |
| `apudig_mvp/apps/sales/models.py` | Modelos de ventas (punto de partida Parte 5) |
| `apudig_mvp/templates/base.html` | Layout base con sidebar Tabler |
