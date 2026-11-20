import fs from 'node:fs';
import path from 'node:path';

const OUT_DIR = path.resolve(process.cwd(), 'docs/frames');
const BASE_URL = process.env.FRAMES_URL || 'http://127.0.0.1:3000';

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const { chromium } = await import('playwright');
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });

    await page.screenshot({ path: path.join(OUT_DIR, '00_authentication.png'), fullPage: false });

    // 0. Sign in on AuthView as Claire Bennett
    await page.getByRole('button', { name: /Claire Bennett/i }).click();

    // 1. POC List (navigate from Onboarding landing page)
    await page.getByRole('button', { name: 'POCs', exact: true }).click();
    await page.getByText('Active Proof-of-Concept Reviews').waitFor();
    await page.screenshot({ path: path.join(OUT_DIR, '01_poc_list.png'), fullPage: false });

    // 2. Architecture Map
    await page.getByRole('button', { name: 'Architecture', exact: true }).click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(OUT_DIR, '02_architecture_map.png'), fullPage: false });

    // 3. Scorecard (Desktop + Mobile 375px)
    await page.getByRole('button', { name: 'Scorecard' }).click();
    await page.getByText('Requirements Scorecard').waitFor();
    await page.screenshot({ path: path.join(OUT_DIR, '03_scorecard_desktop.png'), fullPage: false });

    await page.setViewportSize({ width: 375, height: 812 });
    await page.waitForTimeout(250);
    await page.screenshot({ path: path.join(OUT_DIR, '03_scorecard_mobile.png'), fullPage: false });

    // 4. What-If (Desktop)
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.getByRole('button', { name: 'What-If' }).click();
    await page.locator('#users-multiplier-slider').fill('10');
    await page.locator('#users-multiplier-slider').dispatchEvent('change');
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(OUT_DIR, '04_what_if.png'), fullPage: false });

    // 5. Sign-Off
    await page.getByRole('button', { name: 'Sign-Off' }).click();
    await page.getByText('Stakeholder Sign-Off & Review Notes').waitFor();
    await page.screenshot({ path: path.join(OUT_DIR, '05_signoff.png'), fullPage: false });

    console.log(`Captured 6 frames in ${OUT_DIR}`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('Frame capture failed:', err.message);
  process.exit(1);
});
