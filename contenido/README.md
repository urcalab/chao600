# Contenido

Marca y material para redes sociales de Chao 600.

```
marca/                        Logo, ícono, imagen para redes y capturas del App Store, con sus generadores
comentarios/                  Comentarios de Instagram y TikTok exportados, y una selección de los mejores
videos/lanzamiento-android/   Video del lanzamiento en Android: guion, animación y mp4
```

## Marca

```sh
python3 contenido/marca/make-logo.py         # logo, ícono iOS, favicons del sitio e imagen para redes
python3 contenido/marca/make-screenshots.py  # capturas del App Store desde marca/screenshots/raw/
```

Necesitan `pip install fonttools` y `brew install librsvg imagemagick`.

## Comentarios

Un CSV por post, con una fila por comentario o respuesta, en el orden en que aparecen: `n`, `tipo` (comentario o respuesta), `usuario`, `likes` y `comentario`. El de TikTok agrega `hace` (tiempo desde que se publicó, al 25-10-2026). `mejores-comentarios.md` agrupa los más útiles para contenido.

## Videos

Cada video es una página HTML animada (`index.html`, 1080×1920) que se renderiza cuadro a cuadro con Chrome y se codifica con ffmpeg. Necesita Google Chrome y `brew install ffmpeg`.

```sh
cd contenido/videos/lanzamiento-android
npm install
npm run render     # out/chao600-android-ig.mp4 y out/chao600-android-tiktok.mp4
```

Para ver la animación sin renderizar, abre `index.html#play` en el navegador. Los textos y tiempos se cambian en `index.html`; lo que se dice encima está en `guion.md`.
