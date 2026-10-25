# AGENTS.md

## Sitio (chao600.com)

- Los cambios al sitio (`site/`, `wrangler.jsonc`) se commitean y se pushean directo a `main`, sin rama ni PR. Es un sitio estático: el riesgo es nulo y cualquier error se arregla con otro commit o con `npx wrangler rollback`.
- Deploy: `npx wrangler deploy` desde la raíz del repo, con el token del item **Cloudflare** del vault **DevOps Routines** de 1Password:

  ```bash
  CLOUDFLARE_API_TOKEN="op://DevOps Routines/Cloudflare/CLOUDFLARE_API_TOKEN" \
  CLOUDFLARE_ACCOUNT_ID="op://DevOps Routines/Cloudflare/CLOUDFLARE_ACCOUNT_ID" \
  op run -- npx wrangler deploy
  ```
