import assert from 'node:assert/strict';
import test from 'node:test';

let actualApi;
try {
  ({ actualApi } = await import('../src/api.mjs'));
} catch (error) {
  if (
    error.code !== 'MODULE_NOT_FOUND' ||
    !error.message.includes('@actual-app/api')
  ) {
    throw error;
  }
}

test(
  'production API adapter loads the Actual CommonJS API',
  {
    skip: actualApi
      ? false
      : 'npm dependencies are available in the Nix package check',
  },
  () => {
    assert.equal(typeof actualApi.init, 'function');
  },
);
