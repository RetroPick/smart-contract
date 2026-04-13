import { test } from 'node:test';
import { deepEqual } from 'node:assert/strict';

import { AppService } from './app.service';

test('AppService returns an ok status payload', () => {
  const service = new AppService();

  deepEqual(service.getHello(), { status: 'ok' });
});
