# APUDIG MVP: Gap Analysis y plan de migracion por partes

Fecha: 2026-04-30

## 1. Resumen ejecutivo

La migracion a Django ya tiene una base inicial en `apudig_mvp`, pero hoy el proyecto esta en una fase de esqueleto funcional, no de paridad operativa.

Lo que si existe:
- Proyecto Django levantable con login, logout, seleccion de empresa y dashboard basico.
- Modelos Django para la mayor parte del dominio: users, companies, partners, inventory, sales y billing.
- Middleware basico para empresa y sucursal activa en sesion.
- Migraciones Django creadas para varias apps.

Lo que aun no existe o esta incompleto:
- Casi toda la capa de casos de uso, vistas, formularios, URLs y templates de negocio.
- Compatibilidad con el frontend actual en JWT y endpoints API.
- Scoping multiempresa real alineado al sistema original.
- Reportes, PDFs, exportaciones y flujos comerciales operativos.
- Pruebas, capa de servicios, validaciones y criterios claros de arquitectura limpia.

Conclusion practica:
- `apudig_mvp` no esta listo para reemplazar `ad_backend` + `ad_frontend`.
- La base de datos y buena parte del dominio ya estan modelados, asi que conviene continuar desde este MVP.
- Antes de migrar funcionalidades, hay que corregir algunas divergencias estructurales del MVP para no arrastrar deuda tecnica.

## 2. Evidencia revisada

Origen FastAPI y Next.js:
- `ad_backend/src/main.py`
- `ad_backend/src/auth/infrastructure/db/models.py`
- `ad_backend/src/company/infrastructure/db/models.py`
- `ad_backend/src/inventory/infrastructure/db/models.py`
- `ad_backend/src/sales/infrastructure/db/models.py`
- `ad_frontend/src/services/authService.js`
- `ad_frontend/src/app/(admin)/admin/**/page.js`

Estado actual del MVP Django:
- `apudig_mvp/config/settings.py`
- `apudig_mvp/config/urls.py`
- `apudig_mvp/apps/web/views.py`
- `apudig_mvp/apps/companies/views.py`
- `apudig_mvp/apps/companies/middleware.py`
- `apudig_mvp/apps/users/models.py`
- `apudig_mvp/apps/companies/models.py`
- `apudig_mvp/apps/partners/models.py`
- `apudig_mvp/apps/inventory/models.py`
- `apudig_mvp/apps/sales/models.py`
- `apudig_mvp/apps/billing/models.py`

## 3. Hallazgos clave

### 3.1 Cobertura funcional del MVP

Implementado realmente:
- Login Django por sesion.
- Logout Django por sesion.
- Seleccion de empresa/sucursal.
- Dashboard basico con empresa y sucursal activa.

Solo modelado, pero aun no implementado funcionalmente:
- Clientes, proveedores, transportistas y tipos de documento.
- Productos, listas de precio, almacenes, stock y movimientos.
- Series documentarias, cotizaciones, ordenes de venta, comprobantes.
- Facturacion paralela en `billing`.

No implementado:
- CRUDs, filtros, busquedas, formularios y validaciones de negocio.
- Reportes de stock, kardex, movimientos y exportaciones.
- PDF comercial y documentos imprimibles.
- API de compatibilidad para el frontend actual.
- Tests automatizados.

### 3.2 Diferencias estructurales importantes

1. Auth y sesion no equivalen al sistema original.

En el sistema actual:
- El frontend usa JWT, refresh token y seleccion de empresa por token.
- El backend expone `/auth/login`, `/auth/select-company`, `/auth/me`, `/auth/refresh`, `/auth/my-companies`.

En el MVP:
- Se usa `LoginView` de Django por sesion en `config/urls.py`.
- La empresa activa vive en `request.session` via `ActiveCompanyMiddleware`.

Impacto:
- El MVP no puede reemplazar hoy al frontend de Next.js sin una capa API compatible.
- Si la meta final es monolito Django con templates, esta decision puede mantenerse. Si la migracion sera progresiva, falta una capa puente JWT.

2. El modelo `users.User` no esta alineado 1:1 con la tabla original.

En FastAPI:
- La tabla `users` tiene `password_hash`, `is_superuser`, `last_login`.

En Django actual:
- `apps.users.models.User` hereda de `AbstractBaseUser` y Django espera su propio campo `password`.
- El modelo define `is_staff`, pero no `password_hash` ni `last_login` como en el origen.

Impacto:
- Hay riesgo alto de incompatibilidad de esquema y autenticacion si se apunta a la misma tabla PostgreSQL original sin una estrategia explicita.

3. `Company` en el MVP mezcla branding dentro de `companies`.

En FastAPI:
- `companies` y `company_branding` son tablas separadas.

En Django actual:
- `apps.companies.models.Company` incluye `app_logo_url`, `pdf_logo_url`, `primary_color`, `secondary_color` directamente.

Impacto:
- El modelo actual no refleja fielmente el esquema del sistema original.
- Si se quiere reutilizar PostgreSQL sin friccion, conviene volver a separar branding.

4. El MVP agrega `user_companies`, que no existe en el sistema original.

En Django actual:
- `UserCompanyAccess` usa tabla `user_companies` como auxiliar para seleccion de empresa/sucursal.

En FastAPI:
- El acceso real se deriva de `user_roles`, `user_stores`, `employees` y companias asignadas.

Impacto:
- El MVP hoy resuelve la seleccion de empresa con una tabla nueva, no con el modelo de autorizacion real.
- Esto simplifica el arranque, pero se desvia del dominio autentico.

5. `DocumentSeries` no conserva toda la restriccion original.

En FastAPI:
- Unicidad por `(company_id, store_id, voucher_type, series)`.

En Django actual:
- `apps.sales.models.DocumentSeries` usa `unique_together = (company, voucher_type, series)`.

Impacto:
- Puede romper la convivencia de series iguales por sucursal.
- Esta diferencia debe corregirse antes de migrar ventas.

6. La UI del MVP esta muy por detras del frontend actual.

Frontend actual disponible:
- Productos, categorias, marcas, almacenes.
- Movimientos, entradas, salidas, transferencias, ajustes.
- Clientes y proveedores.
- Cotizaciones, series, reportes, administracion de usuarios.

MVP actual:
- Solo login, seleccion de empresa y dashboard.

Impacto:
- La brecha principal ya no es de modelos sino de casos de uso y experiencia operativa.

7. Falta la capa limpia de aplicacion.

En el MVP actual no aparecen:
- `forms.py`
- `services.py`
- tests
- vistas por dominio fuera de `web` y `companies`

Impacto:
- Si se migra funcionalidad directamente sobre views y models, el proyecto se volvera dificil de mantener.

## 4. Estado por dominio

### 4.1 Auth / Users

Origen:
- Login JWT, refresh token, seleccion de empresa por token, roles, permisos, user_roles, user_stores, employees, audit logs.

Estado en MVP:
- Modelo `User`, `Role`, `Permission`, `UserRole`, `UserStore`, `Employee` existe.
- Login real implementado solo con Django session auth.
- No hay endpoints JWT ni refresh token.
- No hay vistas de usuarios, roles o permisos.

Faltantes criticos:
- Decidir estrategia final de autenticacion: session-only o session + JWT bridge.
- Alinear modelo `users` con la tabla real.
- Implementar autorizacion real por empresa y sucursal usando tablas autenticas.
- Implementar auditoria y administracion de usuarios.

### 4.2 Companies / multiempresa

Origen:
- Company, CompanyBranding, CompanyDocumentSettings, stores, acceso por usuario y store.

Estado en MVP:
- Company, Store y CompanyDocumentSettings existen.
- Seleccion de empresa existe, pero usa tabla auxiliar `user_companies`.
- Branding esta mezclado dentro de `Company`.

Faltantes criticos:
- Separar `CompanyBranding`.
- Reemplazar `UserCompanyAccess` por acceso real derivado de roles y stores.
- Introducir managers/querysets para filtrar por empresa y store.

### 4.3 Partners

Origen:
- `core_customers`, `sales_customer_profiles`, `sales_customer_contacts`, `suppliers`, `carriers`.

Estado en MVP:
- Modelos existentes y relativamente completos.
- No hay CRUD, vistas, forms ni busquedas.

Faltantes criticos:
- Listado, alta, edicion, detalle y busqueda por documento.
- Reglas de unicidad y saneamiento de datos.
- Integracion con ventas y movimientos.

### 4.4 Inventory

Origen:
- Maestros, stock por almacen, movimientos, detalles, reportes, catalogo.

Estado en MVP:
- Modelos de categorias, marcas, unidades, productos, listas, almacenes, stock y movimientos existen.
- No hay vistas, servicios, forms ni reportes.

Faltantes criticos:
- CRUDs de maestros.
- Servicios de stock transaccionales para entradas, salidas, transferencias y ajustes.
- Validaciones de negocio por tipo de movimiento.
- Reportes: stock, movimientos, kardex.

### 4.5 Sales

Origen:
- Series, tipos documentarios, cotizaciones, ordenes de venta, comprobantes, settings, PDF.

Estado en MVP:
- Modelos base existen y cubren una parte importante del esquema.
- No hay views, forms, servicios, templates ni generacion PDF.

Faltantes criticos:
- Correccion de restricciones y campos para alinearse al origen.
- Flujos de cotizacion -> orden -> comprobante.
- Numeracion por series y sucursal.
- Impresion/PDF y configuracion documental por empresa.

### 4.6 Billing

Origen:
- Modulo paralelo de facturacion, posiblemente redundante con vouchers.

Estado en MVP:
- Modelos existentes.
- Sin funcionalidad.

Recomendacion:
- Congelar `billing` hasta cerrar ventas y comprobantes.
- No migrar UI ni casos de uso de billing en primera ola.

### 4.7 Reports

Origen:
- Reportes de stock por almacen, movimientos y kardex con exportacion Excel/PDF.

Estado en MVP:
- No existe app dedicada ni vistas/reportes funcionales.

Faltantes criticos:
- Queries optimizadas.
- Exportadores y templates.
- Permisos y filtros multiempresa/sucursal.

## 5. Riesgos arquitectonicos actuales del MVP

1. Migrar funcionalidad encima de modelos que no coinciden exactamente con PostgreSQL original.

2. Mantener una autenticacion por sesion mientras el frontend legado depende de JWT, sin definir estrategia de coexistencia.

3. Dejar la logica de negocio dispersa en futuras views por ausencia de services y forms.

4. Seguir creando pantallas sin pruebas, lo que hara inseguro el reemplazo del sistema actual.

5. Duplicar modulos de ventas y billing antes de definir el canonico para MVP.

## 6. Lineamientos de arquitectura limpia para continuar

La recomendacion no es volver al exceso de CQRS y capas del backend FastAPI. La meta es una arquitectura limpia, pero pragmatica.

### 6.1 Estructura recomendada por app Django

Para cada app de negocio:

```
apps/<dominio>/
  models.py
  selectors.py
  services.py
  forms.py
  urls.py
  views/
  admin.py
  tests/
    test_models.py
    test_services.py
    test_views.py
```

### 6.2 Responsabilidades

- `models.py`
  - Persistencia y reglas invariantes simples.
- `selectors.py`
  - Consultas de lectura reutilizables y optimizadas.
- `services.py`
  - Casos de uso y logica transaccional.
- `forms.py`
  - Validacion de entrada HTML y admin interno.
- `views/`
  - Coordinacion HTTP, muy delgadas.
- `tests/`
  - Cobertura por caso de uso, no solo por ruta.

### 6.3 Reglas practicas

- No reintroducir repositorios si Django ORM ya resuelve la persistencia.
- No poner calculos de negocio complejos dentro de templates o views.
- Usar `transaction.atomic()` en servicios de inventario y ventas.
- Centralizar scoping por empresa y sucursal en middleware, mixins y querysets.
- Preferir una sola fuente de verdad por dominio.
- Evitar implementar `billing` y `vouchers` a la vez en la misma fase.

## 7. Plan de migracion por partes

## Parte 0. Enderezar la base del MVP

Objetivo:
- Corregir divergencias estructurales antes de migrar funcionalidad.

Entregables:
- Definicion oficial de estrategia auth: `session-only` o `session + JWT bridge`.
- Refactor de `users.User` para compatibilidad con la tabla real o definicion de tabla nueva con migracion de datos.
- Separacion de `CompanyBranding` fuera de `Company`.
- Revision de `UserCompanyAccess` y reemplazo o encapsulamiento transitorio.
- Correccion de `DocumentSeries` para incluir `store` en unicidad.
- Convencion de carpetas por app: `views`, `services`, `selectors`, `forms`, `tests`.

Criterio de salida:
- El modelo de datos del MVP ya no entra en conflicto con el sistema origen.

## Parte 1. Auth, multiempresa y shell de navegacion

Objetivo:
- Dejar lista la columna vertebral del sistema.

Entregables:
- Login robusto.
- Seleccion empresa/sucursal basada en acceso real.
- Middleware y mixins de scoping.
- Decoradores o mixins de permisos.
- Layout base, menu lateral y dashboard.
- Si hay coexistencia con Next.js: endpoints JWT minimos compatibles.

Criterio de salida:
- Un usuario real puede entrar, seleccionar empresa/sucursal y navegar una shell segura.

## Parte 2. Maestros compartidos

Objetivo:
- Migrar los catalogos que desbloquean el resto del negocio.

Alcance:
- Companies settings.
- Categories, brands, units.
- Stores, warehouses.
- Document types, carriers.
- Price lists.
- Customers y suppliers basicos.

Entregables:
- Listados, formularios, filtros y validaciones.
- Admin interno para soporte.
- Tests de creacion, unicidad y filtros.

Criterio de salida:
- Se pueden mantener todos los maestros desde Django.

## Parte 3. Partners completo

Objetivo:
- Cerrar el dominio de clientes y proveedores.

Alcance:
- `core_customers`
- `sales_customer_profiles`
- `sales_customer_contacts`
- `suppliers`

Entregables:
- Alta, edicion y detalle.
- Busqueda por documento y razon social.
- Vinculo con listas de precio y condiciones comerciales.

Criterio de salida:
- Ventas e inventario ya pueden usar clientes y proveedores reales.

## Parte 4. Inventory operativo

Objetivo:
- Migrar operacion interna y stock.

Alcance:
- Productos.
- Stock por almacen.
- Entradas, salidas, transferencias y ajustes.

Entregables:
- Servicios transaccionales de movimientos.
- Pantallas de registro y consulta.
- Validaciones por tipo de movimiento.
- Tests de stock y consistencia.

Criterio de salida:
- El stock puede administrarse desde Django con trazabilidad minima.

## Parte 5. Sales operativo

Objetivo:
- Migrar el flujo comercial principal.

Alcance:
- Business document types.
- Document series.
- Cotizaciones.
- Ordenes de venta.
- Comprobantes.
- Settings documentarios y PDF.

Entregables:
- Flujo `cotizacion -> orden -> comprobante`.
- Numeracion consistente por empresa y sucursal.
- Plantillas imprimibles.
- Tests de totales e integridad documental.

Criterio de salida:
- El ciclo comercial principal ya puede operarse desde Django.

## Parte 6. Reportes y exportaciones

Objetivo:
- Cerrar la brecha de consulta y control.

Alcance:
- Stock por almacen.
- Kardex.
- Reporte de movimientos.
- Exportacion Excel/PDF.

Entregables:
- Selectors optimizados.
- Exportadores desacoplados.
- Filtros por empresa/sucursal/rango de fechas.

Criterio de salida:
- La operacion puede consultar y exportar informacion desde el MVP.

## Parte 7. Cutover y retiro del legado

Objetivo:
- Pasar a produccion sin convivencias indefinidas.

Entregables:
- Checklist de paridad funcional.
- Pruebas de humo por modulo.
- Plan de migracion de usuarios activos.
- Plan de retiro de Next.js y FastAPI o mantenimiento parcial si aun se requiere API externa.

Criterio de salida:
- Django queda como canonico.

## 8. Orden recomendado de ejecucion inmediata

Secuencia recomendada desde hoy:

1. Corregir Parte 0.
2. Cerrar Parte 1.
3. Migrar Parte 2 y Parte 3 juntas o en dos sprints cortos.
4. Migrar Parte 4.
5. Migrar Parte 5.
6. Dejar Parte 6 para cuando inventory y sales ya usen datos reales.
7. Congelar `billing` hasta validar que realmente sigue siendo necesario.

## 9. Backlog priorizado de cambios faltantes

Prioridad alta:
- Alinear auth y tabla `users`.
- Alinear `companies` + `company_branding`.
- Corregir unicidad de `document_series`.
- Crear estructura `services/selectors/forms/tests` en apps.
- Implementar permisos y scoping real por empresa/sucursal.

Prioridad media:
- CRUD de maestros.
- Partners.
- Inventory transaccional.

Prioridad media-alta:
- Ventas, series y PDF.

Prioridad baja para MVP:
- Billing paralelo.
- Catalogo publico.

## 10. Recomendacion final

Si el objetivo es migrar bien y por partes, no conviene empezar por pantallas nuevas.

Conviene empezar por estas tres decisiones tecnicas:
- Definir si el frontend legado seguira vivo durante la transicion.
- Corregir el desacople entre el esquema real y los modelos Django actuales.
- Crear una base de arquitectura limpia y testeable antes de abrir CRUDs masivos.

La mejor siguiente iteracion es:
- Ejecutar Parte 0 completa.
- Luego implementar Parte 1 con calidad de produccion.
- A partir de ahi migrar dominio por dominio, empezando por maestros y partners.