#!/usr/bin/env bash
# Deploys IdentityRegistry to local Anvil and writes deployment.json into the
# shared contract-artifacts volume (mounted at /app/out) so auth-server and
# client-wallet can read the address. forge ships with no node/jq, so we parse
# its JSON with grep and build the file with printf.

set -uo pipefail

RPC_URL="http://blockchain:8545"
CONTRACT="src/IdentityRegistry.sol:IdentityRegistry"
RAW="/tmp/forge_raw.json"
FINAL="/app/out/deployment.json"

mkdir -p /tmp/forge-out /app/out

# Pull the deployer address out of forge's receipt and lowercase it.
json_field() {
  grep -o "\"$1\": *\"0x[0-9a-fA-F]*\"" "$2" | head -1 | cut -d'"' -f4 | tr 'A-Z' 'a-z'
}

# The receipt no longer reports the nonce, so read the sender's account nonce
# up front (derived from the same PRIVATE_KEY we deploy with).
DEPLOYER=$(cast wallet address "${PRIVATE_KEY}" 2>/dev/null)
NONCE_HEX=$(cast rpc eth_getTransactionCount "$DEPLOYER" --rpc-url "$RPC_URL" 2>/dev/null | tr -d '"')
NONCE=$(( 16#${NONCE_HEX#0x} ))

set +e
# --broadcast is mandatory: without it forge just simulates and nothing lands.
forge create "$CONTRACT" --out /tmp/forge-out --rpc-url "$RPC_URL" --private-key "${PRIVATE_KEY}" --broadcast --json > "$RAW" 2>/tmp/forge_err.txt
EXIT=$?
set -e

if [ "$EXIT" -ne 0 ]; then
  echo "forge create failed (exit $EXIT)" >&2
  sed -n '1,200p' /tmp/forge_err.txt >&2
  exit 1
fi

ADDR=$(json_field "deployedTo" "$RAW")
[ -z "$ADDR" ] && ADDR=$(json_field "deployer" "$RAW")
FROM=$(json_field "deployer" "$RAW")

if [ -z "$ADDR" ]; then
  echo "no contract address in forge output:" >&2
  head -c 500 "$RAW" >&2
  exit 1
fi

# --broadcast returns before the tx is mined, so poll for code to appear.
for _ in $(seq 1 30); do
  LEN=$(cast code "$ADDR" --rpc-url "$RPC_URL" 2>/dev/null | tr -d '\n' | wc -c)
  [ "$LEN" -gt 2 ] && break
  sleep 1
done

if [ "${LEN:-0}" -le 2 ]; then
  echo "contract code never appeared at $ADDR - deploy didn't land" >&2
  exit 1
fi

{
  printf '{\n'
  printf '  "contract": "IdentityRegistry",\n'
  printf '  "contractAddress": "%s",\n' "$ADDR"
  printf '  "from": "%s",\n' "$FROM"
  printf '  "nonce": "%d",\n' "$NONCE"
  printf '  "abi": []\n'
  printf '}\n'
} > "$FINAL"

echo "Deployed $CONTRACT at $ADDR (nonce $NONCE)"
