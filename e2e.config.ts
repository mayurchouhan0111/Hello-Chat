import type { E2EConfig } from 'e2e';
import { web } from '@e2e-dev/web';

// The admin panel runs against the local Firebase emulators
// (VITE_USE_EMULATOR=1 vite), which the stack scripts start before the run:
// auth :9099, firestore :8085, functions :5001, panel :5173.
export default {
  timeout: 120_000,
  assertionTimeout: 10_000,
  targets: [
    {
      name: 'admin-chromium',
      engine: web(),
      app: {
        url: 'http://localhost:5173',
        environment: 'test',
      },
    },
  ],
} satisfies E2EConfig;
