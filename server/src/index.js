const express = require('express');
const { createClient } = require('redis');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const DEPLOYMENT_FILE = process.env.DEPLOYMENT_FILE || '/app/contracts/deployment.json';

const app = express();

// Connect to Redis; never crash if it is temporarily unavailable.
const redisClient = createClient({ url: process.env.REDIS_URL });
redisClient.on('error', (err) => console.error('Redis connection error:', err.message));
redisClient.on('connect', () => console.log('Connected to Redis.'));
redisClient.connect().catch((err) => console.error('Redis connect() rejected:', err.message));

// Optional: read deployment metadata when available.
let deploymentInfo = null;
try {
  if (fs.existsSync(DEPLOYMENT_FILE)) {
    deploymentInfo = JSON.parse(fs.readFileSync(DEPLOYMENT_FILE, 'utf8'));
    console.log('Loaded deployment metadata from', path.resolve(DEPLOYMENT_FILE));
  }
} catch (err) {
  console.warn('Could not parse deployment file:', err.message);
}

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Auth server listening on port ${PORT}`);
  if (deploymentInfo) {
    console.log('Deployment address:', deploymentInfo.contractAddress);
  }
});
