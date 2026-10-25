# AGENTS.md

## Commits

- Todos los cambios del repo (sitio, app iOS y app Android) se commitean y se pushean directo a `main`, sin rama ni PR.

## Sitio (chao600.com)

- Deploy: `npx wrangler deploy` desde la raíz del repo, con el token del item **Cloudflare** del vault **DevOps Routines** de 1Password:

  ```bash
  CLOUDFLARE_API_TOKEN="op://DevOps Routines/Cloudflare/CLOUDFLARE_API_TOKEN" \
  CLOUDFLARE_ACCOUNT_ID="op://DevOps Routines/Cloudflare/CLOUDFLARE_ACCOUNT_ID" \
  op run -- npx wrangler deploy
  ```

- Si un deploy sale mal, se arregla con otro commit o con `npx wrangler rollback`.
