# Chao 600

App iOS local-first con una sola función: bloquear las llamadas entrantes de números **600** y **809** en Chile.

**Pruébala en TestFlight:** https://testflight.apple.com/join/FcNEGbNb

## Cómo funciona

iOS no deja bloquear por patrón. Una Call Directory Extension (CallKit) necesita la lista completa de números, así que Chao 600 los lista todos:

| Prefijo | Formato | Números | Rango en CallKit |
|---|---|---|---|
| 809 (telemarketing no solicitado) | 809 XXX XXX | 1.000.000 | 56809000000 – 56809999999 |
| 600 (comerciales) | 600 XXX XXXX | 10.000.000 | 566000000000 – 566009999999 |

- **Carga por tandas.** Una extensión no alcanza a cargar millones de números en una sola pasada (se reportan fallas cerca de 2M), así que la app recarga la extensión en modo incremental, 1M números por recarga, hasta completar los 11M. Si una recarga falla, la tanda se reduce a la mitad (mínimo 125k).
- **Estado compartido.** El avance (`loaded.json`) y la configuración (`settings.json`) viven en el contenedor del App Group, escritos de forma atómica para que app y extensión siempre lean lo último.
- **Recuperación.** Si iOS reconstruye la lista por su cuenta (por ejemplo, al reactivar la extensión en Ajustes), queda solo la primera tanda; la app la completa al abrirse o en una actualización en segundo plano.
- **Formato sin +56 (opcional).** Por si el operador entrega el número en formato nacional. Duplica la carga a 22M.
- **Privacidad.** Sin red, sin analítica, sin acceso a contactos ni al historial de llamadas. Ver [PRIVACY.md](PRIVACY.md).

## Correr en el iPhone

1. `open Chao600.xcodeproj`
2. El equipo ya está configurado (Wolf Technology Spa, `37AKWW8NZ2`). Con firma automática, Xcode registra los bundle IDs `cl.urcalab.chao600` y `cl.urcalab.chao600.CallDirectory` y el App Group `group.cl.urcalab.chao600`.
3. Elige tu iPhone como destino y dale Run.
4. En la app: **Abrir Ajustes** → activa **Chao 600** en *Bloqueo e identificación de llamadas* → vuelve a la app y espera que termine la carga.

El simulador no tiene bloqueo de llamadas: ahí la app muestra "iOS no respondió (código 0)". Hay que probar en un iPhone.

### Con tu propia cuenta de Apple

Cambia el equipo y los identificadores por los tuyos:

- `DEVELOPMENT_TEAM` y `PRODUCT_BUNDLE_IDENTIFIER` en el proyecto (la extensión debe ser `<bundle de la app>.CallDirectory`).
- El App Group en `Config/*.entitlements` y en `SharedState.appGroup`.

## Estructura

```
Chao600/          App (SwiftUI): estado, interfaz, recargas de la extensión
CallDirectory/    Call Directory Extension: agrega una tanda por recarga
Shared/           Código de ambos targets: plan de números, estado compartido, manifiesto de privacidad
Config/           Info.plist y entitlements
branding/         Logo (SVG/PNG) y su generador
site/             Landing de chao600.com (HTML estático, Cloudflare Pages)
scripts/          Verificaciones
```

## Logo y sitio

`branding/make-logo.py` genera el logo, el ícono de la app, los favicons y la imagen para redes desde un solo diseño, con la tipografía Nunito Black (SIL OFL) convertida a trazos. Necesita `pip install fonttools` y `brew install librsvg imagemagick`.

El sitio no tiene build: se publica la carpeta `site/` tal cual.

```sh
npx wrangler pages deploy site --project-name chao600 --branch main
```

## Verificación

```sh
scripts/check-plan.sh
```

Comprueba los rangos y simula el protocolo app ↔ extensión ↔ CallKit con recargas fallidas, recargas completas iniciadas por iOS y cambios de configuración: CallKit siempre termina con exactamente los números del plan, sin duplicados.

## Licencia

MIT. Ver [LICENSE](LICENSE).
