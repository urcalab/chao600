# Ficha de Google Play (es-CL)

**Nombre:** Chao 600
**Descripción corta (80):** Bloquea llamadas 600 y 809 y revisa cuáles frenaste. Todo en tu teléfono.

**Descripción completa:**
Chao 600 bloquea las llamadas de números 600 (bancos, isapres, retail, cobranzas) y 809 (telemarketing) antes de que suene el teléfono.

• Una sola pantalla: estado, qué prefijos bloquear y el registro de llamadas bloqueadas.
• 100% local: sin internet, sin cuenta, sin permisos de contactos ni de historial de llamadas.
• El registro vive solo en tu teléfono y puedes borrarlo cuando quieras.
• Código abierto (MIT).

Para funcionar, Android te pide elegir Chao 600 como app de identificación de llamadas y spam. Eso es todo.

**Categoría:** Herramientas · **Contacto:** https://chao600.com/soporte · **Política de privacidad:** https://chao600.com/privacidad

## Play Console
- **Seguridad de los datos:** no recopila ni comparte datos. Marcar "no se recopilan datos" y "sin transmisión".
- **Permisos:** ninguno declarado. Rol `CALL_SCREENING` (se pide en pantalla). No usa permisos de registro de llamadas ni SMS.
- **Clasificación de contenido:** sin contenido sensible. **Anuncios:** no. **Público:** 18+ no necesario; apto para todos.
- **Gráficos:** `icon-512.png`, capturas en esta carpeta. Falta el gráfico de función 1024×500 (se puede derivar de `branding/og.svg`).

## Publicar
1. `keytool -genkeypair -v -keystore android/chao600-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
2. `cp android/keystore.properties.example android/keystore.properties` y completar.
3. `cd android && ./gradlew bundleRelease` → `app/build/outputs/bundle/release/app-release.aab`
4. Subirlo en Play Console (con Play App Signing). Las cuentas personales nuevas necesitan una prueba cerrada con 12 testers durante 14 días antes de producción.
