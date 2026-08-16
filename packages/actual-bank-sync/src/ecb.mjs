export const ECB_HISTORICAL_RATES_URL =
  'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.xml';

export function parseEcbRates(xml) {
  const rates = {};
  const dayPattern =
    /<Cube\s+time=["'](\d{4}-\d{2}-\d{2})["']\s*>([\s\S]*?)<\/Cube>/g;
  for (const dayMatch of xml.matchAll(dayPattern)) {
    const [, date, body] = dayMatch;
    const quoted = {};
    const ratePattern =
      /<Cube\s+currency=["']([A-Z]{3})["']\s+rate=["']([0-9.]+)["']\s*\/>/g;
    for (const rateMatch of body.matchAll(ratePattern)) {
      quoted[rateMatch[1]] = rateMatch[2];
    }
    const ron = Number(quoted.RON);
    const gbp = Number(quoted.GBP);
    if (!Number.isFinite(ron) || ron <= 0 || !Number.isFinite(gbp) || gbp <= 0) {
      continue;
    }
    rates[date] = {
      EUR: quoted.RON,
      GBP: (ron / gbp).toFixed(6),
    };
  }
  if (Object.keys(rates).length === 0) {
    throw new Error('ECB feed contains no dated rates');
  }
  return rates;
}

export function assertRateFeedFresh(rates, today, maxAgeDays = 7) {
  const latest = Object.keys(rates).sort().at(-1);
  const latestTime = Date.parse(`${latest}T00:00:00Z`);
  const todayTime = Date.parse(`${today}T00:00:00Z`);
  const ageDays = (todayTime - latestTime) / 86_400_000;
  if (!Number.isInteger(ageDays) || ageDays < 0 || ageDays > maxAgeDays) {
    throw new Error(`ECB feed latest date ${latest} is not fresh for ${today}`);
  }
}

export async function fetchEcbRates(fetchImpl = fetch) {
  const response = await fetchImpl(ECB_HISTORICAL_RATES_URL, {
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) {
    throw new Error(`ECB feed request failed with HTTP ${response.status}`);
  }
  return parseEcbRates(await response.text());
}
