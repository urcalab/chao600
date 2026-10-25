# Chao 600

App local-first con una sola función: bloquear las llamadas entrantes de números **600** y **809** en Chile. Para iPhone y Android.

**Sitio:** https://chao600.com · **App Store:** https://apps.apple.com/cl/app/chao-600/id6820609522 · **Google Play:** https://play.google.com/store/apps/details?id=cl.urcalab.chao600

## Estructura

```
android/     App Android (Kotlin + Compose) y ficha de Google Play
ios/         App iOS (SwiftUI + Call Directory Extension) y sus verificaciones
site/        chao600.com: public/ (HTML estático) y wrangler.jsonc (Cloudflare)
contenido/   Marca, comentarios de redes sociales y videos
```

## Android

En `android/` está la versión Android (Kotlin + Compose, mín. Android 10). Usa un `CallScreeningService`, que sí permite bloquear por patrón: no hay listas de millones de números. Bloquea `600 XXX XXXX` y `809 XXX XXX` en formato `+56`, `56` o nacional, no pide ningún permiso y guarda el registro de bloqueadas solo en el teléfono. Una sola pantalla: estado, prefijos, números siempre permitidos y registro.

```sh
cd android && ./gradlew testDebugUnitTest installDebug
```

Para publicar en Play Store, ver [android/store/LISTING.md](android/store/LISTING.md).

## iOS

```
ios/Chao600/          App (SwiftUI): estado, interfaz, recargas de la extensión
ios/CallDirectory/    Call Directory Extension: agrega una tanda por recarga
ios/Shared/           Código de ambos targets: plan de números, estado compartido, manifiesto de privacidad
ios/Config/           Info.plist y entitlements
ios/scripts/          Verificaciones
```

### Cómo funciona

iOS no deja bloquear por patrón. Una Call Directory Extension (CallKit) necesita la lista completa de números, así que Chao 600 los lista todos:

| Prefijo | Formato | Números | Rango en CallKit |
|---|---|---|---|
| 809 (telemarketing no solicitado) | 809 XXX XXX | 1.000.000 | 56809000000 – 56809999999 |
| 600 (comerciales) | 600 XXX XXXX | 10.000.000 | 566000000000 – 566009999999 |

- **Carga por tandas.** Una extensión no alcanza a cargar millones de números en una sola pasada (se reportan fallas cerca de 2M), así que la app recarga la extensión en modo incremental, 1M números por recarga, hasta completar los 11M. Si una recarga falla, la tanda se reduce a la mitad (mínimo 125k).
- **Estado compartido.** El avance (`loaded.json`) y la configuración (`settings.json`) viven en el contenedor del App Group, escritos de forma atómica para que app y extensión siempre lean lo último.
- **Recuperación.** Si iOS reconstruye la lista por su cuenta (por ejemplo, al reactivar la extensión en Ajustes), queda solo la primera tanda; la app la completa al abrirse o en una actualización en segundo plano.
- **Siempre permitir.** Hasta 100 números 600/809 que el usuario quiere recibir. No entran en el `id` del plan: la extensión los quita de la lista ya cargada (`removeBlockingEntry`) o los saltea al cargar la tanda que los contiene, sin recargar los 11M. Quitar uno de la lista lo vuelve a bloquear.
- **Privacidad.** Sin red, sin analítica, sin acceso a contactos ni al historial de llamadas. Ver [PRIVACY.md](PRIVACY.md).

### Correr en el iPhone

1. `open ios/Chao600.xcodeproj`
2. El equipo ya está configurado (Wolf Technology Spa, `37AKWW8NZ2`). Con firma automática, Xcode registra los bundle IDs `cl.urcalab.chao600` y `cl.urcalab.chao600.CallDirectory` y el App Group `group.cl.urcalab.chao600`.
3. Elige tu iPhone como destino y dale Run.
4. En la app: **Abrir Ajustes** → activa **Chao 600** en *Bloqueo e identificación de llamadas* → vuelve a la app y espera que termine la carga.

El simulador no tiene bloqueo de llamadas: ahí la app muestra "iOS no respondió (código 0)". Hay que probar en un iPhone.

#### Con tu propia cuenta de Apple

Cambia el equipo y los identificadores por los tuyos:

- `DEVELOPMENT_TEAM` y `PRODUCT_BUNDLE_IDENTIFIER` en el proyecto (la extensión debe ser `<bundle de la app>.CallDirectory`).
- El App Group en `ios/Config/*.entitlements` y en `SharedState.appGroup`.

### Verificación

```sh
ios/scripts/check-plan.sh
```

Comprueba los rangos y simula el protocolo app ↔ extensión ↔ CallKit con recargas fallidas, recargas completas iniciadas por iOS y cambios de configuración: CallKit siempre termina con exactamente los números del plan, sin duplicados.

## Sitio

El sitio no tiene build: Cloudflare sirve la carpeta `site/public/` tal cual en https://chao600.com (configuración en `site/wrangler.jsonc`).

```sh
cd site && npx wrangler deploy
```

## Contenido

`contenido/marca/make-logo.py` genera el logo, el ícono de la app iOS, los favicons del sitio y la imagen para redes desde un solo diseño, con la tipografía Nunito Black (SIL OFL) convertida a trazos. Necesita `pip install fonttools` y `brew install librsvg imagemagick`.

Los comentarios de redes sociales y los videos están descritos en [contenido/README.md](contenido/README.md).

## Licencia

MIT. Ver [LICENSE](LICENSE).
