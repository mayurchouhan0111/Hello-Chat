import { test } from '@e2e-dev/web';
import { expect } from 'e2e';

const CODES_API =
  'http://127.0.0.1:9099/emulator/v1/projects/hellochat-e8965/verificationCodes';
const OWNER_PHONE = '+919000000001';

test.setup(
  'owner signs in through the real phone OTP flow',
  { sessions: ['owner'] },
  async ({ app, screen, browser, session }) => {
    // Unauthenticated visits are bounced to the login screen.
    await app.open('/');
    await expect(browser).toHaveURL('/login');
    await expect(screen.getByRole('heading', { name: 'Hello Chat', level: 1 })).toBeVisible();

    // Phone step: LoginScreen prefixes +91, so the digits select the seeded owner.
    await screen.getByLabel('Phone Identifier').fill('9000000001');
    await screen.getByRole('button', 'Enter Platform').tap();
    await expect(screen.getByLabel('Entry Key')).toBeVisible({ timeout: 20_000 });

    // The auth emulator sends no SMS: read the code it generated from its admin API.
    const res = await fetch(CODES_API);
    const body = (await res.json()) as {
      verificationCodes?: { phoneNumber: string; code: string }[];
    };
    const codes = (body.verificationCodes ?? []).filter((v) => v.phoneNumber === OWNER_PHONE);
    expect(codes.length).toBeGreaterThan(0);
    const code = codes[codes.length - 1].code;

    await screen.getByLabel('Entry Key').fill(code);
    await screen.getByRole('button', 'Establish Link').tap();

    // LoginScreen loads users/{uid}, derives the tier (owner), and lands on the dashboard.
    await expect(browser).toHaveURL('/', { timeout: 20_000 });
    await expect(screen.getByRole('heading', { name: 'OWNER' })).toBeVisible();
    await session.save('owner');
  },
);
