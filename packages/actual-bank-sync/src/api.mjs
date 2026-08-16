import { createRequire } from 'node:module';

export const actualApi = createRequire(import.meta.url)('@actual-app/api');
