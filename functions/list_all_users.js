const admin = require("firebase-admin");

(async () => {
  // Delete all existing apps to force a clean slate
  for (const app of admin.apps) {
    try {
      await app.delete();
    } catch (e) {}
  }

  admin.initializeApp({
    projectId: "home237-92c18"
  });

  const db = admin.firestore();
  console.log("--- LISTING ALL USERS IN FIRESTORE ---");
  const usersSnap = await db.collection("users").get();
  console.log(`Total users found: ${usersSnap.size}`);
  usersSnap.forEach(doc => {
    const data = doc.data();
    console.log(`USER_INFO: ID: ${doc.id} | Email: ${data.email} | Role: ${data.role} | Suspended: ${data.suspended || false}`);
  });
  console.log("--- END OF LIST ---");
})().catch(err => console.error("Error listing users:", err));
