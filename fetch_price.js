// Fetches a URL with headless Chromium and prints the rendered page's visible text to stdout.
// Usage: node fetch_price.js <url>
const { chromium } = require('playwright');

const url = process.argv[2];
if (!url) {
  console.error('Usage: node fetch_price.js <url>');
  process.exit(1);
}

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.PLAYWRIGHT_BROWSERS_PATH
      ? `${process.env.PLAYWRIGHT_BROWSERS_PATH}/chromium`
      : undefined,
    proxy: process.env.HTTPS_PROXY
      ? { server: process.env.HTTPS_PROXY }
      : undefined,
    args: [
      '--disable-quic',
      '--disable-http2',
      '--ignore-certificate-errors',
      `--proxy-server=${process.env.HTTPS_PROXY || ''}`,
    ],
  });
  try {
    const page = await browser.newPage({
      userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
      locale: 'sv-SE',
    });
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    try {
      await page.waitForLoadState('networkidle', { timeout: 8000 });
    } catch (e) {
      // ignore, some pages never go idle
    }
    await page.waitForTimeout(1500);
    const text = await page.evaluate(() => document.body ? document.body.innerText : '');
    console.log(text);
  } finally {
    await browser.close();
  }
})().catch((err) => {
  console.error('FETCH_ERROR: ' + err.message);
  process.exit(1);
});
