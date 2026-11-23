import { expect, test } from '@playwright/test';

const BASE_URL = process.env.DRISHYA_BASE_URL || 'http://localhost:3000';

test('Drishya mock E2E: upload fixture paper, generate EN & HI 2-min videos, play, ask Q&A, click citation, delete', async ({
  page,
}) => {
  await page.goto(BASE_URL);
  await expect(page.getByRole('heading', { name: 'Research Library' })).toBeVisible();

  // Navigate to New Video and create English Student 2-min video
  await page.getByRole('button', { name: 'New Video' }).first().click();
  await page.getByRole('button', { name: 'Generate Grounded Video' }).click();

  await page.getByRole('button', { name: 'Video Podcast' }).click();
  await expect(page.getByRole('button', { name: 'Play' })).toBeVisible({ timeout: 20000 });
  await page.getByRole('button', { name: 'Play' }).click();

  // Generate Hindi 2-min Student video
  await page.getByRole('button', { name: 'New Video' }).first().click();
  await page.locator('#lang-select').selectOption('hi');
  await page.getByRole('button', { name: 'Generate Grounded Video' }).click();
  await expect(page.getByText('Language: HI')).toBeVisible({ timeout: 20000 });
  await page.getByRole('button', { name: 'Video Podcast' }).click();

  // Ask 2 Q&A questions (1 grounded, 1 unanswerable)
  await page.getByRole('tab', { name: 'Grounded Q&A' }).click();
  await page.locator('#qa-input').fill('What is MonsoonFormer 5-day RMSE?');
  await page.getByRole('button', { name: 'Ask' }).click();
  await expect(page.getByText('Show me').first()).toBeVisible();

  await page.locator('#qa-input').fill('What was the GDP growth rate of Brazil in 1994?');
  await page.getByRole('button', { name: 'Ask' }).click();
  await expect(page.getByText("The document and trusted sources don't answer this.")).toBeVisible();

  // Click a citation in Transcript
  await page.getByRole('tab', { name: 'Transcript' }).click();
  await page.getByRole('button', { name: /\[doc:/ }).first().click();
  await expect(page.getByText(/Citation Inspector/)).toBeVisible();

  // Delete Now
  await page.getByRole('button', { name: 'Delete Now' }).click();
  await expect(page.getByRole('heading', { name: 'Research Library' })).toBeVisible();
});
