const fs = require('fs');
const path = require('path');
const { UserRefreshClient } = require('google-auth-library');
const { Firestore } = require('@google-cloud/firestore');

const tokenPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');

if (!fs.existsSync(tokenPath)) {
  console.error("Firebase CLI token file not found at " + tokenPath);
  process.exit(1);
}

try {
  const firebaseTools = JSON.parse(fs.readFileSync(tokenPath, 'utf8'));
  const tokenData = firebaseTools.tokens;
  
  if (!tokenData || !tokenData.refresh_token) {
    console.error("No refresh token found in firebase-tools.json");
    process.exit(1);
  }

  // Create a UserRefreshClient with the token
  const client = new UserRefreshClient(
    '563584335869-5jles7q2m25vup588563qas1a67t595f.apps.googleusercontent.com',
    'j9i1rJg2EC3VOIlV249mj7KK',
    tokenData.refresh_token
  );

  const db = new Firestore({
    projectId: "home237-92c18",
    authClient: client
  });

  async function test() {
    console.log("Connecting to Firestore via @google-cloud/firestore...");
    const usersSnap = await db.collection("users").limit(5).get();
    console.log(`Successfully connected! Found ${usersSnap.size} users (limit 5).`);
    for (const doc of usersSnap.docs) {
      console.log(`- ${doc.id}: ${doc.data().email} (Role: ${doc.data().role})`);
    }
  }

  test()
    .then(() => process.exit(0))
    .catch(err => {
      console.error("Query failed:", err);
      process.exit(1);
    });

} catch (e) {
  console.error("Error reading token or initializing:", e);
  process.exit(1);
}
