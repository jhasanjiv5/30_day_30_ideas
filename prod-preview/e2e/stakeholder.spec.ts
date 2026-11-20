import assert from 'node:assert/strict';

/**
 * Playwright End-to-End Stakeholder Journey Test
 * Run against live server (http://localhost:3000 or http://localhost:8080):
 *   npx playwright test e2e/stakeholder.spec.ts
 */
export async function runStakeholderJourney(baseUrl = 'http://localhost:3000') {
  const pwModule = 'playwright';
  const { chromium } = await import(/* @vite-ignore */ pwModule);
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto(baseUrl, { waitUntil: 'networkidle' });

    // 0. Authenticate on the Sign-In view as stakeholder Claire Bennett
    await page.getByRole('button', { name: /Claire Bennett/i }).click();

    // 1. Navigate from Onboarding to POC List and verify seeded Retail Checkout Redesign
    await page.getByRole('button', { name: 'POCs', exact: true }).click();
    await page.getByRole('heading', { name: 'Retail Checkout Redesign' }).waitFor();
    await page.locator('#active-poc-select').selectOption('poc-retail-checkout');

    // 2. Navigate to Architecture Map and click a component
    await page.getByRole('button', { name: 'Architecture', exact: true }).click();
    await page.getByRole('button', { name: /Customer Database/i }).click();
    await page.getByText(/Stores customer addresses/i).waitFor();

    // 3. Navigate to Scorecard and verify all 5 check types + Out of scope
    await page.getByRole('button', { name: 'Scorecard' }).click();
    await page.getByText('Explicitly Out of Scope for This POC').waitFor();
    await page.getByText('Measured').first().waitFor();
    await page.getByText('Projected').first().waitFor();

    // 4. Navigate to What-If, move slider to x10, and toggle region outage
    await page.getByRole('button', { name: 'What-If' }).click();
    const slider = page.locator('#users-multiplier-slider');
    await slider.fill('10');
    await slider.dispatchEvent('change');
    await page.getByTestId('users-multiplier-value').waitFor();
    await page.locator('#region-outage-toggle').check();
    await page.getByText(/no backup region/i).waitFor();

    // 5. Navigate to History and verify personal project timeline
    await page.getByRole('button', { name: 'History' }).click();
    await page.getByText('My Project History').waitFor();
    await page.getByRole('heading', { name: 'Retail Checkout Redesign' }).waitFor();

    // 6. Mobile 375px viewport check: zero horizontal scroll
    await page.setViewportSize({ width: 375, height: 812 });
    const hasOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth
    );
    assert.equal(hasOverflow, false, 'Expected zero horizontal overflow at 375px width');
  } finally {
    await browser.close();
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runStakeholderJourney(process.env.APP_URL || 'http://localhost:3000');
}
