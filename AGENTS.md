# AGENTS.md

## Estructura

- `android/` app Android, `ios/` app iOS, `site/` chao600.com, `contenido/` marca, redes sociales y videos. Ver el README.

## Commits

- Todos los cambios del repo (sitio, app iOS, app Android y contenido) se commitean y se pushean directo a `main`, sin rama ni PR.

## Sitio (chao600.com)

- Deploy: `npx wrangler deploy` desde `site/`, con el token del item **Cloudflare** del vault **DevOps Routines** de 1Password:

  ```bash
  cd site && \
  CLOUDFLARE_API_TOKEN="op://DevOps Routines/Cloudflare/CLOUDFLARE_API_TOKEN" \
  CLOUDFLARE_ACCOUNT_ID="op://DevOps Routines/Cloudflare/CLOUDFLARE_ACCOUNT_ID" \
  op run -- npx wrangler deploy
  ```

- Si un deploy sale mal, se arregla con otro commit o con `npx wrangler rollback`.
