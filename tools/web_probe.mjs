// 웹 빌드를 진짜 브라우저에서 띄워 **녹화**를 확인합니다.
//
//     python tools/serve.py            (다른 창에서)
//     node tools/web_probe.mjs http://127.0.0.1:8807/ out/web
//
// # 왜 필요한가
//
// 녹화는 브라우저 안에서만 도는 기능이라 엔진 쪽 테스트로는 한 줄도
// 확인되지 않습니다. 그리고 이 기능의 실패는 대개 **조용합니다** -
//
//   - 화면이 검게만 녹화된다 (파일 크기는 멀쩡합니다)
//   - 소리가 안 들어간다 (재생해 보기 전에는 모릅니다)
//   - 두 번째 녹화부터 무음이 된다 (오디오 갈래를 한 번 끊으면 그렇습니다)
//
// 그래서 결과 영상을 한 프레임 그려 밝기를 세고, 파일을 꺼내 컨테이너 안에
// 소리 트랙이 있는지까지 봅니다. 그리고 **두 번** 찍습니다.
//
// playwright-core 만 씁니다(브라우저는 PC 에 깔린 크롬을 그대로 씁니다).
//
//     npm install playwright-core
import { chromium } from 'playwright-core';
import fs from 'fs';

const url = process.argv[2] || 'http://127.0.0.1:8807/';
const outDir = process.argv[3] || 'out/web';
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

// 제목 화면의 "녹화하며 내려가기" 와 HUD 의 "여기까지 저장" 자리입니다.
// 1000x600 으로 띄웠을 때의 좌표라, 창 크기를 바꾸면 같이 고쳐야 합니다.
const REC_BUTTON = { x: 600, y: 353 };
const SAVE_BUTTON = { x: 605, y: 48 };

fs.mkdirSync(outDir, { recursive: true });
const log = (...a) => console.log(...a);
let failed = 0;
function check(name, ok, detail) {
  log(`  ${ok ? '[ok]' : '[!!]'} ${name}${detail ? ' - ' + detail : ''}`);
  if (!ok) { failed++; }
}

const browser = await chromium.launch({
  executablePath: CHROME,
  headless: true,
  args: [
    '--enable-unsafe-swiftshader',                 // 헤드리스에는 GPU 가 없습니다
    '--use-angle=swiftshader',
    '--autoplay-policy=no-user-gesture-required',  // 오디오를 클릭 없이 열어 둡니다
  ],
});
const page = await browser.newPage({ viewport: { width: 1000, height: 600 } });
page.on('pageerror', (e) => log('  [pageerror]', String(e).slice(0, 300)));

log('여는 중:', url);
await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
// 게임이 뜨면 Recorder 가 __r1rec 을 심습니다. 그게 곧 기동 완료 신호입니다.
await page.waitForFunction('!!window.__r1rec', null, { timeout: 180000 });
log('기동 완료');
await page.mouse.click(500, 560);      // 오디오 잠금 해제용 클릭
await page.waitForTimeout(500);

const outs = await page.evaluate('(window.__r1out||[]).length');
check('오디오 출력 노드를 잡았다', outs > 0, `${outs}개`);
check('이 브라우저에서 녹화 가능', (await page.evaluate('window.__r1rec.ready()')) === 1);
await page.screenshot({ path: `${outDir}/title.png` });

async function play(seconds) {
  const until = Date.now() + seconds * 1000;
  while (Date.now() < until) {
    await page.keyboard.down('w');
    await page.waitForTimeout(350);
    await page.keyboard.up('w');
    await page.mouse.click(500, 300);   // 고함 - 소리가 나야 오디오가 담깁니다
    await page.keyboard.down('d');
    await page.waitForTimeout(350);
    await page.keyboard.up('d');
  }
}

async function grabClip(tag) {
  // 미리보기 <video> 를 한 프레임 그려 봅니다. 검게 녹화되는 실패는 파일
  // 크기만 봐서는 절대 안 보입니다.
  const shot = await page.evaluate(async () => {
    const v = document.querySelector('#r1panel video');
    if (!v) { return { err: '미리보기 없음' }; }
    await new Promise((r) => {
      if (v.readyState >= 2) { r(); return; }
      v.addEventListener('loadeddata', r, { once: true });
      setTimeout(r, 5000);
    });
    try { v.currentTime = Math.min(1.0, (v.duration || 1) / 2); } catch (e) {}
    await new Promise((r) => setTimeout(r, 800));
    const c = document.createElement('canvas');
    c.width = v.videoWidth;
    c.height = v.videoHeight;
    if (!c.width) { return { err: '영상 크기 0' }; }
    const g = c.getContext('2d');
    g.drawImage(v, 0, 0);
    const d = g.getImageData(0, 0, c.width, c.height).data;
    let lit = 0;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] * 0.3 + d[i + 1] * 0.6 + d[i + 2] * 0.1 > 24) { lit++; }
    }
    const buf = new Uint8Array(await (await fetch(v.src)).arrayBuffer());
    let s = '';
    for (let i = 0; i < buf.length; i += 8192) {
      s += String.fromCharCode.apply(null, buf.subarray(i, i + 8192));
    }
    return { w: c.width, h: c.height, dur: v.duration, lit: lit / (d.length / 4), b64: btoa(s) };
  });
  if (shot.err) { check(`${tag} 영상`, false, shot.err); return; }
  const bin = Buffer.from(shot.b64, 'base64');
  fs.writeFileSync(`${outDir}/clip_${tag}.bin`, bin);
  check(`${tag} 영상이 재생된다`, shot.dur > 1.0,
    `${shot.w}x${shot.h} ${shot.dur.toFixed(1)}초 ${(bin.length / 1048576).toFixed(2)}MB`);
  check(`${tag} 화면이 검지 않다`, shot.lit > 0.3, `밝은 픽셀 ${(shot.lit * 100).toFixed(0)}%`);
  // 컨테이너 안을 훑어 소리 트랙을 찾습니다. 'soun'/'mp4a' 는 mp4 쪽,
  // 'Opus'/'A_' 는 webm 쪽 표시입니다.
  const head = bin.subarray(0, Math.min(bin.length, 200000)).toString('latin1');
  check(`${tag} 소리 트랙이 들어 있다`,
    head.includes('soun') || head.includes('mp4a') || head.includes('Opus')
    || head.includes('A_OPUS') || head.includes('A_VORBIS'));
}

// ---- 1차: 제목 화면의 버튼으로 시작하고, HUD 버튼으로 저장 ----------------
log('1차: 제목 버튼으로 시작 → 게임 안 저장 버튼으로 마무리');
await page.mouse.click(REC_BUTTON.x, REC_BUTTON.y);
await page.waitForTimeout(1000);
check('버튼 하나로 판과 녹화가 같이 시작된다',
  JSON.parse(await page.evaluate('window.__r1rec.state()')).rec === 1);
await play(6);
await page.screenshot({ path: `${outDir}/rec_playing.png` });
await page.mouse.click(SAVE_BUTTON.x, SAVE_BUTTON.y);
await page.waitForTimeout(2500);
check('게임 안 버튼으로 녹화가 멈춘다',
  JSON.parse(await page.evaluate('window.__r1rec.state()')).rec === 0);
const panel = await page.$('#r1panel');
check('저장 판이 뜬다', panel !== null);
if (panel) { await panel.screenshot({ path: `${outDir}/panel.png` }); }
await grabClip('1차');

// 폰에서 '내려받기' 로 파일이 실제로 떨어지는지 봅니다. 공유창(navigator.share)
// 은 헤드리스에서 확인할 길이 없지만, 내려받기는 브라우저가 파일을 만드는
// 일이라 여기서 끝까지 볼 수 있습니다.
try {
  const [download] = await Promise.all([
    page.waitForEvent('download', { timeout: 20000 }),
    page.click('#r1panel button:has-text("내려받기")'),
  ]);
  const file = await download.path();
  const size = file ? fs.statSync(file).size : 0;
  check('내려받기로 파일이 떨어진다', size > 100000,
    `${download.suggestedFilename()} ${(size / 1048576).toFixed(2)}MB`);
  check('파일 이름이 mp4/webm 이다', /\.(mp4|webm)$/.test(download.suggestedFilename()));
} catch (e) {
  check('내려받기로 파일이 떨어진다', false, String(e).slice(0, 120));
}

// ---- 2차: 이어서 한 번 더 --------------------------------------------------
// 두 번째가 무음이 되는 실수를 잡으려고 둡니다. 정지할 때 소리 갈래까지
// 끊으면 여기서 소리 트랙이 사라집니다.
log('2차: 같은 판에서 한 번 더');
await page.evaluate('window.__r1rec.start(120, 64)');
await page.waitForTimeout(600);
await play(5);
await page.evaluate('window.__r1rec.stop()');
await page.waitForTimeout(2500);
await grabClip('2차');

await browser.close();
log(failed === 0 ? '\n전부 통과' : `\n실패 ${failed}건`);
process.exit(failed === 0 ? 0 : 1);
