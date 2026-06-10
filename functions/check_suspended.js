const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "home237-92c18"
});

const db = admin.firestore();

async function checkSuspended() {
  const usersSnap = await db.collection("users").where("suspended", "==", true).get();
  console.log(`Found ${usersSnap.size} suspended users.`);
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    console.log(`Suspended user: ${doc.id} - ${data.email} (Role: ${data.role})`);
  }
}

checkSuspended()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
