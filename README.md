# Blockchain-Based Identity Management

A minimal reference architecture for a Decentralized Identity (DID) system built on a local
EVM testnet. It deploys an `IdentityRegistry` smart contract to a local Anvil node and exposes
it through a Node.js authentication server, with an interactive client wallet and optional
k6 load testing.

Everything runs in Docker. The entire stack is one command away.

## Quick start

From the project root:

```bash
# 1. Provide the deployer private key. Anvil default account #0 ships funded, so it works out of the box:
cp .env.example .env

# 2. Build and launch every service (blockchain, deployer, redis, auth server, client wallet):
docker compose up --build -d
```

Check that everything is healthy:

```bash
docker compose ps
```

Health of the auth server (returns `{"status":"ok"}` once the contract has been deployed):

```bash
curl -s http://localhost:3000/health
```

Stop everything (and remove the persistent volumes):

```bash
docker compose down -v
```

### Running the client wallet interactively

The wallet connects to the auth server and reads the deployment metadata written by the deployer.
With the stack running, open a shell into the wallet container:

```bash
docker compose exec did-client-wallet sh
```

## Containers

| Container | Service | Image | Purpose |
|---|---|---|---|
| `did-blockchain` | blockchain | `ghcr.io/foundry-rs/foundry:latest` | Local EVM testnet running **Anvil** on port 8545. |
| `did-contract-deployer` | contract-deployer | `ghcr.io/foundry-rs/foundry:latest` | One-shot deployer. Compiles and deploys `IdentityRegistry.sol` to Anvil, writing contract metadata to `deployment.json`. Exits on success. |
| `did-redis` | redis | `redis:7-alpine` | Nonce store used for replay prevention. |
| `did-auth-server` | auth-server | built from `./server` | Node.js/Express service exposing `/health` (and later the DID auth API). Connects to Redis and reads the deployment metadata. |
| `did-client-wallet` | client-wallet | built from `./client` | Interactive client wallet. Logs a startup message and accepts CLI input. |
| `...benchmarks-1` (test profile) | benchmarks | `grafana/k6:latest` | Optional load test against the auth server. Only runs with the `test` profile. |

## Project layout

```
.
├── contracts/          # Solidity + Foundry smart contracts
│   ├── foundry.toml
│   └── src/IdentityRegistry.sol
├── server/             # Auth / target resource server (Express)
│   ├── Dockerfile
│   ├── package.json
│   └── src/index.js
├── client/             # Interactive client wallet
│   ├── Dockerfile
│   ├── package.json
│   └── src/index.js
├── tests/k6/           # Load testing scripts
│   └── auth_load_test.js
├── docker-compose.yaml
└── .env.example
```

## Load testing (optional)

The k6 benchmark runs behind a Compose **profile** so it doesn't start with the default stack.
Start the base stack first, then run the test:

```bash
docker compose up --build -d                          # start base stack
docker compose --profile test up                      # run the k6 load test
docker compose --profile test down                    # stop the k6 container
```

The test targets the auth server's `/health` endpoint, spins up 5 virtual users for 30 seconds,
and exits when it finishes.

## Configuration

- The contract deployer reads `PRIVATE_KEY` from your `.env` file (see `.env.example`).
  This is the well-known Anvil default account #0, which is funded by Anvil itself and is safe
  to use on a local testnet. **Replace it with a key you generate before any non-local use.**
- The private key is passed to the deployer as an **environment variable**, never in the process
  command line. `.env` is git-ignored — never commit it.
- Environment variables available to the auth server: `PORT`, `RPC_URL`, `REDIS_URL`, `DEPLOYMENT_FILE`.

## Notes

- The `contract-deployer` is a one-shot service: it deploys the contract, writes `deployment.json`,
  and exits successfully. To redeploy, bring the stack down and up again.
- Docker Compose v2 intentionally ignores the obsolete `version` field, so it has been removed.

