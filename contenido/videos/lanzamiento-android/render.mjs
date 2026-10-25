// Renderiza index.html cuadro a cuadro con Chrome y lo codifica con ffmpeg.
//   node render.mjs ig            → out/chao600-android-ig.mp4
//   node render.mjs tiktok        → out/chao600-android-tiktok.mp4
//   node render.mjs ig stills 1.5 9.5 …  → out/stills/ig-<t>.png
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import puppeteer from 'puppeteer-core';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const FPS = 30;
const here = dirname(fileURLToPath(import.meta.url));
const [version = 'ig', mode = 'video', ...times] = process.argv.slice(2);

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--hide-scrollbars', '--force-color-profile=srgb', '--font-render-hinting=none'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });
await page.goto(`${pathToFileURL(join(here, 'index.html'))}?v=${version}`, { waitUntil: 'networkidle0' });
const fonts = await page.evaluate(async () => {
  await document.fonts.ready;
  await Promise.all([...document.images].map(img => img.decode().catch(() => {})));
  return ['900 100px Nunito', '400 16px Roboto', '900 32px Roboto', '500 16px "Roboto Mono"'].map(f => `${f}: ${document.fonts.check(f)}`);
});
console.log(fonts.join(' · '));
const duration = await page.evaluate(() => window.DURATION);

if (mode === 'stills') {
  mkdirSync(join(here, 'out/stills'), { recursive: true });
  for (const t of times) {
    await page.evaluate(t => window.seek(t), +t);
    await page.screenshot({ path: join(here, `out/stills/${version}-${t}.png`) });
  }
} else {
  mkdirSync(join(here, 'out'), { recursive: true });
  const out = join(here, `out/chao600-android-${version}.mp4`);
  const ffmpeg = spawn('ffmpeg', [
    '-y', '-loglevel', 'error',
    '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
    '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo',
    '-map', '0:v', '-map', '1:a', '-shortest',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', String(FPS),
    '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', out,
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const frames = Math.round(duration * FPS);
  for (let i = 0; i < frames; i++) {
    await page.evaluate(t => window.seek(t), i / FPS);
    const buf = await page.screenshot({ type: 'jpeg', quality: 95, optimizeForSpeed: true });
    if (!ffmpeg.stdin.write(buf)) await new Promise(r => ffmpeg.stdin.once('drain', r));
    if (i % (FPS * 5) === 0) console.log(`${version}: ${(i / FPS).toFixed(0)}s / ${duration}s`);
  }
  ffmpeg.stdin.end();
  await new Promise((resolve, reject) => ffmpeg.on('close', code => (code ? reject(new Error(`ffmpeg ${code}`)) : resolve())));
  console.log(`listo: ${out}`);
}
await browser.close();
