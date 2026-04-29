# FILE REFERENCES: FastAPI → Django Mapping

## ESTRUCTURA ACTUAL (FastAPI)

### Backend (`ad_backend/`)

**Configuración:**
- `requirements.txt` — FastAPI, SQLAlchemy, pandas, WeasyPrint, JWT, etc.
- `pyproject.toml` (si existe)
- `.env` template — DATABASE_URL, JWT_SECRET_KEY, APP_ENV

**Main app:**
- `src/main.py` — FastAPI app setup, CORS, router mounts

**Database:**
- `src/inventory/infrastructure/db/database.py` — SQLAlchemy engine, SessionLocal, Base
- `alembic/` — migration scripts (50+ versions)

**Auth module (Crítico):**
- `src/auth/infrastructure/services/jwt_service.py` — JWT creation/decode
- `src/auth/infrastructure/db/models.py` — User, Employee, Role, Permission, UserRole, UserStore, RefreshToken, AuditLog
- `src/auth/interfaces/auth_router.py` — login, logout, refresh, select-company, me endpoints
- `src/auth/interfaces/dependencies.py` — get_current_user, get_company_id_from_token, get_jwt_payload, decorators
- `src/auth/infrastructure/services/password_hasher.py` — bcrypt

**Inventory (Módulo grande):**
- `src/inventory/infrastructure/db/models.py` — Category, Brand, Unit, Product, PriceList, ProductPrice, Store, Warehouse, StockByWarehouse, Movement, MovementDetail, DocumentType, Carrier (líneas 20-520)
- `src/inventory/infrastructure/db/repositories/*.py` — 13 repos (product, category, etc)
- `src/inventory/infrastructure/api/*_router.py` — 10 routers
- `src/inventory/application/services/*.py` — 8 services (product, category, movement, etc)

**Sales (Módulo comercial):**
- `src/sales/infrastructure/db/models.py` — DocumentSeries, BusinessDocumentType, SaleOrder, SaleOrderLine, Quotation, QuotationLine, Voucher, VoucherLine (líneas 133-680)
- `src/sales/infrastructure/db/*.py` — 4 repos (quotation, sale_order, voucher, document_type)
- `src/sales/infrastructure/api/*_router.py` — 5 routers (quotation, sale_order, voucher, series, settings)
- `src/sales/application/*.py` — 5 services (quotation, sale_order, voucher, settings, pdf, document_pdf)

**Partners (Clientes + Proveedores):**
- `src/customer/infrastructure/db/repository.py` — SqlAlchemy repo para Customer
- `src/customer/infrastructure/db/customer_query_service.py` — queries lectura
- `src/customer/infrastructure/api/router.py` — CRUD customer
- `src/core/infrastructure/db/models.py` — CoreCustomerModel (línea 11)
- `src/supplier/infrastructure/db/model.py` — SupplierModel (línea 13)
- `src/supplier/infrastructure/db/repository.py` — repo supplier
- `src/supplier/infrastructure/api/router.py` — CRUD supplier

**Company (Multiempresa):**
- `src/company/infrastructure/db/models.py` — Company, CompanyBranding, CompanyDocumentSettings (línea 24+)
- `src/company/infrastructure/db/repositories.py` — repos
- `src/company/interfaces/router.py` — CRUD company

**Reports:**
- `src/inventory/infrastructure/api/report_router.py` — stock, movements, kardex (Excel + PDF)

**PDF/Rendering:**
- `src/core/infrastructure/pdf/renderer.py` — WeasyPrint wrapper
- `src/core/infrastructure/pdf/templates/` — HTML templates por tipo documento

**Billing (Separado de sales, revisar si congelar):**
- `src/billing/infrastructure/db/models.py` — BillingInvoice, BillingInvoiceLine (línea 14+)
- `src/billing/infrastructure/api/invoice_router.py` — CRUD invoice
- `src/billing/application/services/invoice_service.py` — service
- `src/billing/infrastructure/sunat/noop_gateway.py` — dummy SUNAT

**Documents (Transversal, acoplado a sales):**
- `src/documents/infrastructure/db/series_repo.py` — DocumentSeries repo
- `src/documents/application/series_service.py` — service
- `src/documents/infrastructure/api/series_router.py` — CRUD series

### Frontend (`ad_frontend/`)

**Services (Integración con API FastAPI):**
- `src/services/authService.js` — login, select-company, refresh, logout, profile, roles/permissions
- `src/services/storeAccessService.js` — get accessible stores, assign user to store
- `src/services/productsService.js` — CRUD products
- `src/services/customersService.js` — getCustomers (basic list)
- `src/services/suppliersService.js` — CRUD suppliers
- `src/services/movementsService.js` — CRUD movements
- `src/services/salesService.js` — quotations, sale orders, vouchers, series, PDF export
- `src/services/reportsService.js` — stock, movements, kardex reports (Excel + PDF)
- `src/services/api.js` — base apiFetch con JWT auth, refresh logic

**Pages (Admin routes):**
- `src/app/(admin)/admin/inventory/products` — list/create product
- `src/app/(admin)/admin/inventory/categories` — CRUD category
- `src/app/(admin)/admin/inventory/brands` — CRUD brand
- `src/app/(admin)/admin/inventory/warehouses` — CRUD warehouse
- `src/app/(admin)/admin/inventory/movements` — list + register (entrada/salida/transfer)
- `src/app/(admin)/admin/inventory/entries` → movimiento tipo ENTRY
- `src/app/(admin)/admin/inventory/exits` → movimiento tipo EXIT
- `src/app/(admin)/admin/sales/quotations` — list + create + detail + PDF export
- `src/app/(admin)/admin/sales/orders` → sale_orders
- `src/app/(admin)/admin/partners/customers` — CRUD customer
- `src/app/(admin)/admin/partners/suppliers` — CRUD supplier
- `src/app/(admin)/admin/reports/` — stock-by-warehouse, movements, kardex (Excel + PDF export)

**Public:**
- `src/app/(public)/catalog/page.js` — catálogo público (NO migrar a Django MVP)

**Components (Tabler UI + React):**
- `src/components/ui/` — Radix + Tailwind buttons, selects, dialogs, dropdowns
- `src/components/admin/movements/` — MovementsTable, forms
- `src/components/admin/partners/` — customer/supplier forms

**Auth:**
- `src/app/login/page.js` — login form + company selection
- `src/lib/AuthContext.jsx` — React context para token + user

### Infrastructure (`ad_infraestructura/`)

- `docker-compose.yml` — PostgreSQL 15, backend (FastAPI), frontend (Next.js) services
- `iniciar_apudig.bat` — script batch para Windows

---

## MAPEO: FastAPI Code → Django Equivalent

| FastAPI | File | Django Equivalent | File (to create) |
|---------|------|------------------|-----------------|
| SQLAlchemy Base | `src/inventory/db/database.py` | Django settings.py + models base | `config/settings.py` + `apps/core/models.py` |
| ProductModel | `src/inventory/db/models.py:54` | `inventory.Product` | `apps/inventory/models.py` |
| CategoryModel | `src/inventory/db/models.py:20` | `inventory.Category` | `apps/inventory/models.py` |
| SupplierModel | `src/supplier/db/model.py:13` | `partners.Supplier` | `apps/partners/models.py` |
| CoreCustomerModel | `src/core/db/models.py:11` | `partners.Customer` | `apps/partners/models.py` |
| UserModel | `src/auth/db/models.py:31` | `users.User` | `apps/users/models.py` |
| RoleModel | `src/auth/db/models.py:81` | `users.Role` | `apps/users/models.py` |
| UserRoleModel | `src/auth/db/models.py:108` | `users.UserRole` | `apps/users/models.py` |
| QuotationModel | `src/sales/db/models.py:313` | `sales.Quotation` | `apps/sales/models.py` |
| VoucherModel | `src/sales/db/models.py:432` | `sales.Voucher` | `apps/sales/models.py` |
| DocumentSeriesModel | `src/sales/db/models.py:133` | `sales.DocumentSeries` | `apps/sales/models.py` |
| MovementModel | `src/inventory/db/models.py:286` | `inventory.Movement` | `apps/inventory/models.py` |
| JWTService | `src/auth/services/jwt_service.py` | Django JWT (django-rest-framework-simplejwt o custom) | `apps/users/auth.py` |
| LoginUser UC | `src/auth/application/use_cases/login_user.py` | views.login + form | `apps/users/views.py` |
| QuotationService | `src/sales/application/quotation_service.py` | `sales.services.QuotationService` | `apps/sales/services.py` |
| ReportRepository | `src/inventory/db/repositories/report_repository.py` | Django QuerySet + view | `apps/reports/views.py` |
| product_router | `src/inventory/api/product_router.py` | views + urls | `apps/inventory/views.py` + `apps/inventory/urls.py` |
| quotation_router | `src/sales/api/quotation_router.py` | views + urls | `apps/sales/views.py` + `apps/sales/urls.py` |
| login (router) | `src/auth/interfaces/auth_router.py:79` | view + template + form | `apps/users/views.py` + `templates/login.html` |
| render_document_pdf | `src/core/infrastructure/pdf/renderer.py:44` | django template → HTML → WeasyPrint | `apps/sales/pdf.py` |
| get_stock_report | `src/inventory/api/report_router.py:100` | django view + template + export | `apps/reports/views.py` |

---

## COMANDOS / HERRAMIENTAS CLAVE

**FastAPI actual:**
```bash
pip install -r requirements.txt
source .venv/bin/activate  # o .venv\Scripts\activate en Windows
alembic upgrade head
python -m src.main  # o: uvicorn src.main:app --reload
```

**Django nueva (a crear):**
```bash
python manage.py migrate
python manage.py runserver
python manage.py createsuperuser
python manage.py collectstatic
```

**Database actual:**
```
PostgreSQL 15
Host: localhost:5432 (Docker)
DB: db_apudig
User: postgres / postgres
```

**JWT Secret (IMPORTANTE):**
```
.env:
  JWT_SECRET_KEY=xxxxx  # MISMO en FastAPI y Django
  DATABASE_URL=postgresql://...
  ALLOWED_ORIGINS=localhost:3000,localhost:8000
```

---

## QUICK CHECKLIST: ANTES DE EMPEZAR FASE 1

- [ ] PostgreSQL corriendo (docker-compose up -d)
- [ ] FastAPI actual funcional (uvicorn src.main:app --reload)
- [ ] Django project creado (django-admin startproject erp)
- [ ] Apps base creados (manage.py startapp core, companies, users, partners, inventory, sales, reports)
- [ ] settings.py: DATABASES, INSTALLED_APPS, SECRET_KEY, ALLOWED_HOSTS
- [ ] base template Tabler (templates/base.html)
- [ ] test login redirige a /admin/dashboard (o similar)
- [ ] JWT token validation funciona (mismo secreto)

---

## DOCUMENTACIÓN INTERNA DEL PROYECTO

**Guía de auth:**
- `ad_backend/AUTH_MODULE_GUIDE.md` — endpoints, JWT payload, decoradores, uso

**Readme:**
- `ad_backend/README.md` — stack, setup, migraciones, comandos
- `ad_frontend/README.md` — setup Next.js, dev environment

**Schema de ejemplo:**
- `schema_erp_example.rb` — posible script de seed/referencia

