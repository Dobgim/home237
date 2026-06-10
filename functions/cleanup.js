resetLandlordTenantAccounts.run({ data: {} }).then(res => {
  console.log('CLEANUP_SUCCESS:', res);
  process.exit(0);
}).catch(err => {
  console.error('CLEANUP_FAILED:', err);
  process.exit(1);
});
// Event loop hold
setTimeout(() => {
  console.log('CLEANUP_TIMEOUT');
  process.exit(1);
}, 60000);
