import assert from 'node:assert/strict';
import test from 'node:test';

import { assertRateFeedFresh, parseEcbRates } from '../src/ecb.mjs';

const feed = `<?xml version="1.0" encoding="UTF-8"?>
<gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
  <Cube>
    <Cube time="2026-08-13">
      <Cube currency="RON" rate="4.9000"/>
      <Cube currency="GBP" rate="0.7000"/>
    </Cube>
    <Cube time="2026-08-14">
      <Cube currency="RON" rate="5.0000"/>
      <Cube currency="GBP" rate="0.8000"/>
    </Cube>
  </Cube>
</gesmes:Envelope>`;

test('parses ECB EUR and GBP cross-rates into RON-per-currency rates', () => {
  assert.deepEqual(parseEcbRates(feed), {
    '2026-08-13': { EUR: '4.9000', GBP: '7.000000' },
    '2026-08-14': { EUR: '5.0000', GBP: '6.250000' },
  });
});

test('accepts a feed published on the prior business day', () => {
  const rates = parseEcbRates(feed);
  assert.doesNotThrow(() => assertRateFeedFresh(rates, '2026-08-16'));
});

test('ignores historical days before every required currency was quoted', () => {
  const incompleteDay = `
    <Cube time="2004-12-31">
      <Cube currency="GBP" rate="0.70505"/>
    </Cube>`;
  const historicalFeed = feed.replace('<Cube time="2026-08-13">', `${incompleteDay}
    <Cube time="2026-08-13">`);

  assert.deepEqual(parseEcbRates(historicalFeed), {
    '2026-08-13': { EUR: '4.9000', GBP: '7.000000' },
    '2026-08-14': { EUR: '5.0000', GBP: '6.250000' },
  });
});
