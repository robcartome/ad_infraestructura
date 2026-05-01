# APUDIG — Plan de migración por partes (estado actualizado)

**Fecha:** 2026-04-30  
**Referencia:** `estado-avance-django_1.md` (partes 0–9 completadas)  
**Objetivo:** Mapa exacto de lo que falta, por qué orden y con qué criterios de clean code.

---

## 1. Radiografía del estado actual

### Completado (producción-ready)

| Área | Qué existe | Tests |
|------|-----------|-------|
| Auth / sesión | Login, logout, dashboard, select_company, middleware | ✓ |
| Maestros inventario | Category, Brand, Unit, Warehouse, Product — CRUD completo + templates | 12 ✓ |
| Socios | Customer (+perfil+contactos), Supplier, Carrier — CRUD completo + templates | 16 ✓ |
| Inventario operativo | Entry, Exit, Transfer — servicios, vistas, formsets, templates | 8 ✓ |
| Stock | Reporte stock por almacén | ✓ |
| Sales catálogos (Parte 5) | BusinessDocumentType, DocumentSeries — CRUD + series toggle | ✓ |
| Cotizaciones (Parte 6) | SalesQuotation + líneas — CRUD, estados, PDF | ✓ |
| Órdenes de venta (Parte 7) | SaleOrder + líneas — CRUD, estados, orden-desde-cotización | 47 ✓ |
| Comprobantes (Parte 8) | Voucher — draft/issue/void/cancel/credit note, PDF A4 | 67 ✓ |
| Listas de precio (Parte 9) | PriceList + ProductPrice — CRUD, bulk prices, toggle | 102 ✓ |

### Modelos existentes sin capa funcional

| App | Modelo | Capa faltante |
|-----|--------|---------------|
| `users` | `Role`, `Permission`, `UserRole`, `UserStore`, `Employee` | forms, views, urls, templates |
| `companies` | `CompanyDocumentSettings`, `CompanyBranding` | forms, views, urls, templates |
| `billing` | `BillingInvoice`, `BillingInvoiceLine` | **congelado deliberadamente** |

> `sales` (todas las entidades) y `inventory.PriceList/ProductPrice` completados en Partes 5–9.

### Servicios parciales ya escritos (ampliar)

| Archivo | Estado |
|---------|--------|
| `apps/sales/services.py` | ✅ **Completo** — series, quotations, orders, vouchers, credit notes |
| `apps/sales/selectors.py` | ✅ **Completo** — búsqueda, filtros, vouchers por estado |
| `apps/sales/forms.py` | ✅ **Completo** — todos los forms con widgets Tabler |
| `apps/inventory/services.py` | ✅ **Completo** — PriceList, ProductPrice (set/delete/toggle) |
| `apps/inventory/selectors.py` | ✅ **Completo** — get_price_lists, search, detail, get_product_price |
| `apps/users/services.py` | ⬜ Vacío — pendiente Parte 10 |
| `apps/users/selectors.py` | ⬜ Vacío — pendiente Parte 10 |
| `apps/companies/views.py` | Solo `select_company` — pendiente Parte 11 |

### Sidebar `base.html` — secciones con `href="#"` pendientes

- ~~Ventas (cotizaciones, órdenes, comprobantes, series)~~ ✅ Completado
- ~~Listas de precio~~ ✅ Completado (Parte 9)
- Administración (usuarios, roles, empresa, sucursales) — pendiente Partes 10–11
- Reportes (kardex, movimientos por fecha, exportación Excel) — pendiente Parte 12

---

## 2. Criterios transversales (clean code / clean architecture)

### Reglas que se aplican en TODAS las partes siguientes

1. **Una responsabilidad por capa:**
   - `models.py` → solo persistencia e invariantes simples.
   - `selectors.py` → solo lectura, sin efectos. Usar `select_related`/`prefetch_related` siempre.
   - `services.py` → toda la lógica de negocio. `@transaction.atomic` en todo lo que escribe.
   - `forms.py` → validación de entrada HTTP. Sin lógica de negocio.
   - `views/` → delgadas: auth check → deserializar form → llamar service/selector → render.

2. **No duplicar lógica:**
   - Los cálculos de IGV, totales y descuentos van en `services.py`, no en views ni templates.
   - Los snapshots de cliente (nombre, RUC) se copian en el servicio al crear el documento.

3. **Numeración sin gaps:**
   - `select_for_update()` + `update_fields=["current_number"]` en `_next_series_number()` (ya implementado en `services.py`).
   - Nunca usar `F()` expressions fuera de `select_for_update` para series.

4. **Scoping multiempresa:**
   - Todo selector que accede a documentos filtra por `store_id` (leído de `request.active_store_id` o `request.session`).
   - Las series se filtran por `(company_id, store_id, voucher_type)`.

5. **Tests antes de templates:**
   - Cada parte tiene tests de services antes de construir las vistas.
   - Tests de views verifican: anon → redirect login, GET → 200, POST válido → redirect, POST inválido → 200 + errores.

6. **Widgets Tabler consistentes:**
   ```python
   _text    = {"class": "form-control"}
   _select  = {"class": "form-select"}
   _check   = {"class": "form-check-input"}
   _date    = {"class": "form-control", "type": "date"}
   _textarea = {"class": "form-control", "rows": 3}
   ```

---

## 3. ~~Parte 5 — Sales: catálogos documentales~~ ✅ COMPLETADO

**Prioridad:** ALTA — desbloquea cotizaciones, órdenes y comprobantes.

**Alcance:**
- `BusinessDocumentType` — CRUD (solo admin/superusuario).
- `DocumentSeries` — CRUD por empresa+sucursal.

### 5.1 Completar `services.py`

```python
# Agregar en apps/sales/services.py

@transaction.atomic
def create_document_series(company_id, store_id, voucher_type, series_code) -> DocumentSeries:
    """Crea serie si no existe. Lanza IntegrityError si ya existe."""
    ...

def reset_series(series: DocumentSeries, new_start: int = 0) -> None:
    """Reinicia contador de serie con select_for_update."""
    ...
```

### 5.2 Completar `forms.py` — widgets Tabler

```python
class DocumentSeriesForm(forms.ModelForm):
    # store filtrado por company activa en __init__(store_id=)
    # voucher_type con choices del modelo

class BusinessDocumentTypeForm(forms.ModelForm):
    # todos los campos con widgets Tabler
```

### 5.3 Vistas (`views/catalogs.py`)

```
series_list       GET  /ventas/series/
series_create     GET+POST  /ventas/series/nueva/
series_update     GET+POST  /ventas/series/<uuid:pk>/editar/
series_toggle     POST  /ventas/series/<uuid:pk>/toggle/   ← activa/desactiva
doctype_list      GET  /ventas/tipos-documento/
doctype_create    GET+POST  /ventas/tipos-documento/nuevo/
doctype_update    GET+POST  /ventas/tipos-documento/<uuid:pk>/editar/
```

### 5.4 Templates

```
templates/sales/series_list.html
templates/sales/series_form.html
templates/sales/doctype_list.html
templates/sales/doctype_form.html
```

### 5.5 Tests

```python
# apps/sales/tests/test_catalogs.py
- test_series_list_ok
- test_series_create_ok
- test_series_duplicate_raises
- test_series_toggle
- test_doctype_list_ok
```

**Criterio de salida:** Se pueden mantener series y tipos documentarios desde el sistema.

---

## 4. ~~Parte 6 — Sales: Cotizaciones~~ ✅ COMPLETADO

**Prioridad:** ALTA — es el primer documento comercial operativo.

### 4.1 Completar `services.py`

Agregar en `apps/sales/services.py`:

```python
@transaction.atomic
def create_quotation(store_id, customer, series, lines, created_by=None, **kwargs) -> SalesQuotation:
    # Ya existe, pero necesita:
    # - calcular subtotal/igv/total por línea y totales cabecera
    # - snapshot cliente completo

@transaction.atomic
def update_quotation(quotation_id, lines, created_by=None, **kwargs) -> SalesQuotation:
    # Solo si status == DRAFT
    # Borra líneas antiguas, recrea, recalcula totales

def approve_quotation(quotation_id) -> SalesQuotation:
    # DRAFT → APPROVED

def reject_quotation(quotation_id, reason: str = "") -> SalesQuotation:
    # DRAFT|SENT → REJECTED

def cancel_quotation(quotation_id) -> SalesQuotation:
    # DRAFT|SENT → CANCELLED
```

**Cálculo de línea (sin lógica en template):**

```python
def _calculate_line(quantity, unit_price, discount_amount, igv_rate, tax_type):
    net = unit_price * quantity - discount_amount
    igv = net * igv_rate / 100 if tax_type == "10" else Decimal(0)
    return {
        "subtotal": net,
        "igv_amount": igv,
        "total": net + igv,
    }
```

### 4.2 Completar `selectors.py`

```python
def search_quotations(store_id, query=None, status=None) -> QuerySet
def get_quotation_detail(pk) -> SalesQuotation  # prefetch lines__product__unit
```

### 4.3 Completar `forms.py`

```python
class QuotationHeaderForm(forms.ModelForm):
    # customer: ModelChoiceField filtrado a activos
    # series: filtrado por store_id + voucher_type=COT
    # issue_date, valid_until: _date widget
    # currency, notes

class QuotationLineForm(forms.Form):
    product: ModelChoiceField (activos)
    description: CharField
    quantity: DecimalField
    unit_price: DecimalField
    discount_amount: DecimalField (default 0)
    tax_type: ChoiceField (TAX_TYPE_CHOICES)
    memo: CharField (opcional)

QuotationLineFormSet = forms.formset_factory(
    QuotationLineForm, extra=1, min_num=1, validate_min=True, prefix="lines"
)
```

### 4.4 Vistas (`views/quotations.py`)

```
quotation_list       GET  /ventas/cotizaciones/
quotation_create     GET+POST  /ventas/cotizaciones/nueva/
quotation_detail     GET  /ventas/cotizaciones/<uuid:pk>/
quotation_update     GET+POST  /ventas/cotizaciones/<uuid:pk>/editar/  (solo DRAFT)
quotation_approve    POST  /ventas/cotizaciones/<uuid:pk>/aprobar/
quotation_reject     POST  /ventas/cotizaciones/<uuid:pk>/rechazar/
quotation_cancel     POST  /ventas/cotizaciones/<uuid:pk>/cancelar/
quotation_pdf        GET  /ventas/cotizaciones/<uuid:pk>/pdf/
```

### 4.5 PDF

```python
# apps/sales/pdf.py
from weasyprint import HTML

def render_quotation_pdf(quotation: SalesQuotation, company) -> bytes:
    html = render_to_string("sales/pdf/quotation_pdf.html", {
        "q": quotation,
        "company": company,
    })
    return HTML(string=html, base_url=settings.BASE_DIR).write_pdf()
```

### 4.6 Templates

```
templates/sales/quotation_list.html   ← tabla paginada + filtros estado + búsqueda
templates/sales/quotation_form.html   ← header + formset líneas (patrón movement_form)
templates/sales/quotation_detail.html ← cabecera + tabla líneas + botones de estado
templates/sales/pdf/quotation_pdf.html ← layout impresión A4
```

### 4.7 Tests

```python
# apps/sales/tests/test_quotations.py
- test_quotation_list_ok
- test_quotation_create_calculates_totals
- test_quotation_approve_transition
- test_quotation_update_only_if_draft
- test_quotation_cancel
- test_quotation_pdf_returns_200
```

**Criterio de salida:** Se puede emitir una cotización con PDF desde Django.

---

## 5. ~~Parte 7 — Sales: Órdenes de venta~~ ✅ COMPLETADO (47 tests)

**Prioridad:** MEDIA-ALTA.

### 5.1 Completar `services.py`

```python
@transaction.atomic
def create_sale_order(store_id, customer, document_type, series, lines, created_by=None, **kwargs) -> SaleOrder

@transaction.atomic
def create_order_from_quotation(quotation_id, document_type_id, series_id, created_by=None, **kwargs) -> SaleOrder
    # - Valida que cotización esté APPROVED
    # - Copia líneas y snapshot cliente
    # - Vincula quotation FK
    # - Marca cotización status = INVOICED si es relevante

def confirm_order(order_id) -> SaleOrder    # DRAFT → CONFIRMED
def cancel_order(order_id) -> SaleOrder     # DRAFT|CONFIRMED → CANCELLED
```

### 5.2 Vistas (`views/orders.py`)

```
order_list        GET  /ventas/ordenes/
order_create      GET+POST  /ventas/ordenes/nueva/
order_from_quot   POST  /ventas/cotizaciones/<uuid:pk>/crear-orden/
order_detail      GET  /ventas/ordenes/<uuid:pk>/
order_confirm     POST  /ventas/ordenes/<uuid:pk>/confirmar/
order_cancel      POST  /ventas/ordenes/<uuid:pk>/cancelar/
order_pdf         GET  /ventas/ordenes/<uuid:pk>/pdf/
```

### 5.3 Templates

```
templates/sales/order_list.html
templates/sales/order_form.html
templates/sales/order_detail.html
templates/sales/pdf/order_pdf.html
```

### 5.4 Tests

```python
# apps/sales/tests/test_orders.py
- test_order_create_ok
- test_order_from_quotation
- test_order_confirm
- test_order_cancel_confirmed_raises
```

**Criterio de salida:** Una cotización aprobada puede convertirse en orden de venta.

---

## 6. ~~Parte 8 — Sales: Comprobantes (Vouchers)~~ ✅ COMPLETADO (67 tests)

**Prioridad:** ALTA — comprobante es el documento fiscal obligatorio.

### 6.1 Completar `services.py`

```python
@transaction.atomic
def create_voucher_draft(store_id, customer, voucher_type, series, lines, sale_order=None, created_by=None, **kwargs) -> Voucher

@transaction.atomic
def issue_voucher(voucher_id, company_id) -> Voucher:
    # 1. Valida status == DRAFT
    # 2. select_for_update() sobre la serie → asigna número
    # 3. Verifica unicidad (series+number)
    # 4. Cambia status → ISSUED
    # 5. Si sale_order vinculada → marcarla INVOICED

def void_voucher(voucher_id, reason) -> Voucher   # ISSUED → VOIDED
def cancel_voucher(voucher_id) -> Voucher          # DRAFT → CANCELLED

@transaction.atomic
def create_credit_note(voucher_id, reason_code, lines) -> Voucher
    # Tipo 07, referencia al original
```

### 6.2 Vistas (`views/vouchers.py`)

```
voucher_list      GET  /ventas/comprobantes/
voucher_create    GET+POST  /ventas/comprobantes/nuevo/
voucher_from_ord  POST  /ventas/ordenes/<uuid:pk>/emitir/
voucher_detail    GET  /ventas/comprobantes/<uuid:pk>/
voucher_issue     POST  /ventas/comprobantes/<uuid:pk>/emitir/
voucher_void      POST  /ventas/comprobantes/<uuid:pk>/anular/
voucher_pdf       GET  /ventas/comprobantes/<uuid:pk>/pdf/
```

### 6.3 Templates

```
templates/sales/voucher_list.html
templates/sales/voucher_form.html
templates/sales/voucher_detail.html
templates/sales/pdf/voucher_pdf.html    ← reutiliza layout A4
templates/sales/pdf/voucher_ticket.html ← formato 80mm
```

### 6.4 Tests

```python
# apps/sales/tests/test_vouchers.py
- test_voucher_create_draft
- test_voucher_issue_assigns_number_atomically  ← test con threading
- test_voucher_issue_prevents_duplicate_number
- test_voucher_void
- test_credit_note_links_original
- test_pdf_response_ok
```

**Criterio de salida:** Se puede emitir un comprobante numerado y generar su PDF.

---

## 7. ~~Parte 9 — Inventario: Listas de precio~~ ✅ COMPLETADO (102 tests total)

**Implementado:**
- `apps/inventory/services.py` — `create_price_list`, `toggle_price_list`, `set_product_price`, `delete_product_price`
- `apps/inventory/selectors.py` — `get_price_lists`, `search_price_lists`, `get_pricelist_detail`, `get_product_price`
- `apps/inventory/forms.py` — `PriceListForm`, `ProductPriceForm`, `ProductPriceFormSet`
- `apps/inventory/views/pricelists.py` — 7 vistas: list, create, detail (con bulk formset), update, toggle, del_price
- `apps/inventory/urls.py` — rutas bajo `/inventario/listas-precio/`
- Templates: `pricelist_list.html`, `pricelist_form.html`, `pricelist_detail.html`
- Sidebar `base.html` — link "Listas de precio" en sección Inventario
- `apps/inventory/tests/test_pricelists.py` — 5 service tests + 10 view tests

---

## 8. Parte 10 — Administración: Usuarios y roles

**Prioridad:** MEDIA — necesario para multi-usuario real.

**Alcance:** `User`, `Role`, `Permission`, `UserRole`, `UserStore`, `Employee`.

### Vistas (`apps/users/views/admin.py`)

```
user_list        GET  /admin/usuarios/
user_create      GET+POST  /admin/usuarios/nuevo/
user_detail      GET  /admin/usuarios/<uuid:pk>/
user_update      GET+POST  /admin/usuarios/<uuid:pk>/editar/
user_deactivate  POST  /admin/usuarios/<uuid:pk>/desactivar/
role_list        GET  /admin/roles/
role_create      GET+POST  /admin/roles/nuevo/
role_update      GET+POST  /admin/roles/<uuid:pk>/editar/
```

### Servicios (`apps/users/services.py`)

```python
@transaction.atomic
def create_user(email, name, password, company_id, store_id=None, role_name="SELLER") -> User:
    user = User.objects.create_user(email=email, name=name, password=password)
    UserRole.objects.create(user=user, company_id=company_id, role=Role.objects.get(name=role_name))
    if store_id:
        UserStore.objects.create(user=user, store_id=store_id)
    UserCompanyAccess.objects.create(user=user, company_id=company_id, store_id=store_id, is_default=True)
    return user

def assign_role(user_id, role_id, company_id) -> UserRole: ...
def assign_store(user_id, store_id) -> UserStore: ...
def deactivate_user(user_id) -> User: ...
def change_password(user_id, new_password) -> None: ...
```

### Selectors con permiso de acceso

```python
# apps/users/selectors.py
def get_users_for_company(company_id) -> QuerySet
def can_user_access_store(user_id, store_id) -> bool
```

### Decorador de permiso

```python
# apps/users/decorators.py
def role_required(*roles):
    """Redirige a 403 si el usuario no tiene ninguno de los roles indicados."""
    def decorator(view_func):
        @wraps(view_func)
        def wrapper(request, *args, **kwargs):
            # leer UserRole desde sesión/DB y comparar
            ...
        return wrapper
    return decorator
```

**Criterio de salida:** Un superusuario puede crear usuarios, asignar roles y sucursales.

---

## 9. Parte 11 — Administración: Empresa y sucursales

**Prioridad:** MEDIA.

**Alcance:** `Company` CRUD, `Store` CRUD, `CompanyBranding`, `CompanyDocumentSettings`.

### Vistas (`apps/companies/views_admin.py`)

```
company_list         GET  /admin/empresas/
company_detail       GET  /admin/empresas/<uuid:pk>/
company_update       GET+POST  /admin/empresas/<uuid:pk>/editar/
company_branding     GET+POST  /admin/empresas/<uuid:pk>/branding/
company_doc_settings GET+POST  /admin/empresas/<uuid:pk>/documentos/
store_list           GET  /admin/empresas/<uuid:company_pk>/sucursales/
store_create         GET+POST  /admin/empresas/<uuid:company_pk>/sucursales/nueva/
store_update         GET+POST  /admin/sucursales/<uuid:pk>/editar/
```

**Criterio de salida:** Administrador puede configurar logo, colores y plantillas PDF por empresa.

---

## 10. Parte 12 — Reportes

**Prioridad:** MEDIA — ya existe `stock_report`.

**Alcance:**

| Reporte | Vista | Template |
|---------|-------|----------|
| Stock por almacén | ya existe | ya existe |
| Kardex por producto | `kardex_report` | `reports/kardex.html` |
| Movimientos por fecha | `movement_report` | `reports/movement_report.html` |
| Ventas por período | `sales_report` | `reports/sales_report.html` |
| Exportación Excel | `export_stock_excel`, `export_movements_excel` | — |

### Selector de kardex

```python
# apps/inventory/selectors.py (agregar)
def get_kardex(product_id, warehouse_id=None, date_from=None, date_to=None):
    """
    Retorna lista de MovementDetail ordenados por fecha con saldo acumulado.
    Calcula saldo_anterior + entradas - salidas cronológicamente.
    """
```

### Exportación Excel

```python
# apps/inventory/reports.py (nuevo)
import openpyxl

def export_stock_to_excel(store_id) -> bytes:
    wb = openpyxl.Workbook()
    ...
    return save_virtual_workbook(wb)
```

**Criterio de salida:** Se puede descargar stock y kardex en Excel.

---

## 11. Parte 13 — Ajustes y mejoras de seguridad

**Prioridad:** ALTA antes de producción.

### Checklist

- [ ] `DEBUG = False` en producción, `ALLOWED_HOSTS` correctos.
- [ ] `SECRET_KEY` desde variable de entorno, nunca en código.
- [ ] CSRF activado en todos los forms (ya lo está por defecto Django).
- [ ] Sanitizar inputs con `bleach` o similar en campos `notes`/`description` largo.
- [ ] `select_related` y `prefetch_related` en todos los listados (N+1 queries).
- [ ] Índices en PostgreSQL: `(store_id, status)` en quotations, orders, vouchers.
- [ ] `select_for_update()` en `_next_series_number` (ya implementado).
- [ ] Rate limiting en login (Django Axes o similar).
- [ ] `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE` en producción.
- [ ] Contraseñas: `AUTH_PASSWORD_VALIDATORS` configurados.
- [ ] Validar que el `store_id` en POST pertenezca al `company_id` del usuario logueado.

---

## 12. Orden recomendado de ejecución

```
✅ Parte 5  → Catálogos documentales (series + tipos)      COMPLETADO
✅ Parte 6  → Cotizaciones con PDF                          COMPLETADO
✅ Parte 7  → Órdenes de venta                              COMPLETADO (47 tests)
✅ Parte 8  → Comprobantes con PDF + numeración atómica     COMPLETADO (67 tests)
✅ Parte 9  → Listas de precio                              COMPLETADO (102 tests)
⬜ Parte 10 → Usuarios y roles                              [~2 días]
⬜ Parte 11 → Empresa y sucursales CRUD                     [~1 día]
⬜ Parte 12 → Reportes y exportación Excel                  [~2 días]
⬜ Parte 13 → Seguridad y hardening                         [~1 día]
```

**Total estimado restante:** ~6 días de desarrollo.

---

## 13. Sidebar `base.html` — plan de links pendientes

```html
<!-- VENTAS ✅ ya en sidebar -->
<a href="{% url 'sales:quotation_list' %}">Cotizaciones</a>
<a href="{% url 'sales:order_list' %}">Órdenes de venta</a>
<a href="{% url 'sales:voucher_list' %}">Comprobantes</a>
<a href="{% url 'sales:series_list' %}">Series documentales</a>

<!-- INVENTARIO ✅ ya en sidebar -->
<a href="{% url 'inventory:pricelist_list' %}">Listas de precio</a>

<!-- REPORTES ⬜ agregar en Parte 12 -->
<a href="{% url 'inventory:kardex_report' %}">Kardex</a>
<a href="{% url 'reports:sales_report' %}">Ventas</a>
<a href="{% url 'inventory:export_stock_excel' %}">Exportar Excel</a>

<!-- ADMINISTRACIÓN ⬜ agregar en Partes 10-11 -->
<a href="{% url 'users:user_list' %}">Usuarios</a>
<a href="{% url 'users:role_list' %}">Roles</a>
<a href="{% url 'companies:company_detail' %}">Empresa</a>
```

---

## 14. Archivos de referencia por parte

| Parte | Archivos origen ad_backend |
|-------|---------------------------|
| 5–8 (Sales) | `src/sales/application/quotation_service.py`, `sale_order_service.py`, `voucher_service.py`, `document_pdf_service.py` |
| 5 (Series) | `src/documents/application/series_service.py` |
| 8 (PDF) | `src/core/infrastructure/pdf/renderer.py`, templates en `src/core/infrastructure/pdf/templates/sales/` |
| 10 (Usuarios) | `src/auth/application/`, `src/auth/infrastructure/db/models.py` |
| 11 (Empresa) | `src/company/infrastructure/db/models.py` |
| 12 (Reportes) | `src/inventory/infrastructure/api/report_router.py` |

---

## 15. Decisiones pendientes (requieren confirmación)

| Decisión | Opciones | Impacto |
|----------|----------|---------|
| PDF engine | `weasyprint` vs `xhtml2pdf` | Verificar en `requirements.txt` del venv actual |
| SUNAT integration MVP | NoOp (campos guardados, sin envío) vs integración real | Recomendado: NoOp para MVP, preparar campos |
| Billing app | Mantener congelada vs eliminar | Recomendado: dejar modelos, no agregar UI |
| Catálogo público Next.js | Mantener vs migrar a Django | Fuera del MVP actual |
| `UserCompanyAccess` vs `UserStore` | Tabla auxiliar actual vs tabla real `user_stores` | Migrar en Parte 10 cuando se implemente gestión real de usuarios |
