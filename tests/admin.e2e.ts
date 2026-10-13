import { test } from '@e2e-dev/web';
import { expect } from 'e2e';

test(
  'owner dashboard exposes the full management menu',
  { session: 'owner' },
  async ({ app, screen, browser }) => {
    await app.open('/');
    await expect(browser).toHaveURL('/');
    await expect(screen.getByRole('heading', { name: 'OWNER' })).toBeVisible();
    await expect(screen.getByRole('link', 'Hierarchy & Branches')).toBeVisible();
    await expect(screen.getByRole('link', 'Resellers')).toBeVisible();
    await expect(screen.getByRole('link', 'Withdrawals')).toBeVisible();
    await expect(screen.getByRole('link', 'Host Metrics')).toBeVisible();
  },
);

test(
  'hierarchy screen loads the scoped roster through the getScopedUsers callable',
  { session: 'owner' },
  async ({ app, screen }) => {
    await app.open('/hierarchy');
    await expect(
      screen.getByRole('heading', 'Hierarchy & Branch Permissions'),
    ).toBeVisible();
    // The callable runs in the functions emulator against the real
    // functions/index.js and returns the seeded users for the owner scope.
    await expect(
      screen.getByRole('row').filter({ hasText: 'ownerT1' }),
    ).toContainText('Test Owner', { timeout: 20_000 });
    await expect(
      screen.getByRole('row').filter({ hasText: 'saT1' }),
    ).toContainText('Test SuperAdmin');
    await expect(
      screen.getByRole('row').filter({ hasText: 'hstT1' }),
    ).toContainText('Test Host');
    await expect(
      screen.getByRole('row').filter({ hasText: 'agyT1' }),
    ).toContainText('Test Agency');
  },
);

test(
  'reseller screen renders the seeded merchant roster',
  { session: 'owner' },
  async ({ app, screen }) => {
    await app.open('/resellers');
    await expect(screen.getByRole('heading', 'Merchant & Reseller Control')).toBeVisible();
    await expect(screen.getByText('Reseller 1')).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByText('ID: HLresT1')).toBeVisible();
    await expect(screen.getByText('Reseller 4')).toBeVisible();
  },
);

test(
  'withdrawal hub lists seeded requests behind owner-only rules',
  { session: 'owner' },
  async ({ app, screen }) => {
    await app.open('/withdrawals');
    await expect(screen.getByRole('heading', 'Disbursement Hub')).toBeVisible();
    // Seeded amounts (125, 100, 75, 50, 25 cents) render as Est: $x.xx USD.
    await expect(screen.getByText('Est: $1.25 USD')).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByText('Est: $0.25 USD')).toBeVisible();
  },
);
