console.log('Client Wallet initialized');

// Keep the container alive and accept optional interactive CLI input.
process.stdin.resume();
process.stdin.on('data', (chunk) => {
  const input = chunk.toString().trim();
  if (input.toLowerCase() === 'exit') {
    console.log('Client Wallet shutting down.');
    process.exit(0);
  }
  console.log(`[wallet] received: ${input}`);
});
