// Minimal k6 load test for the auth server /health endpoint.
// Run with: docker compose --profile test up --build

import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 5,
  duration: '30s',
};

// A standard default function running one request per iteration.
export default function () {
  const res = http.get('http://auth-server:3000/health');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'body is ok': (r) => r.body === JSON.stringify({ status: 'ok' }),
  });
}
