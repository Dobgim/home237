const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "home237-92c18"
});

const db = admin.firestore();

async function runCleanup() {
  console.log("Starting cleanup...");
  
  // 1. Get all users
  const usersSnap = await db.collection("users").get();
  const deletedUserIds = [];
  
  console.log(`Found ${usersSnap.size} total users in Firestore.`);
  
  const batch = db.batch();
  let batchCount = 0;
  
  // Helper to commit and reset batch
  const commitBatchIfNeeded = async () => {
    if (batchCount >= 400) {
      await batch.commit();
      batchCount = 0;
    }
  };

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const role = data.role || "";
    const userId = doc.id;
    
    if (role === "landlord" || role === "tenant") {
      deletedUserIds.push(userId);
      console.log(`Marking user ${userId} (${data.email}, role: ${role}) for deletion.`);
      
      // Delete from Auth
      try {
        await admin.auth().deleteUser(userId);
        console.log(`Deleted auth user: ${userId}`);
      } catch (authError) {
        console.warn(`Could not delete auth user ${userId}: ${authError.message}`);
      }
      
      // Delete user document
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
      
      // Delete session
      batch.delete(db.collection("sessions").doc(userId));
      batchCount++;
      await commitBatchIfNeeded();
      
      // Delete favorites root doc
      batch.delete(db.collection("favorites").doc(userId));
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  if (batchCount > 0) {
    await batch.commit();
    batchCount = 0;
  }
  
  if (deletedUserIds.length === 0) {
    console.log("No landlord or tenant users found to delete.");
    return;
  }
  
  console.log(`Starting cascade cleanup for ${deletedUserIds.length} users...`);
  
  // 2. Clean up properties
  const propertiesSnap = await db.collection("properties").get();
  for (const doc of propertiesSnap.docs) {
    const landlordId = doc.data().landlordId;
    if (deletedUserIds.includes(landlordId)) {
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  // 3. Clean up verifications
  const verificationsSnap = await db.collection("verifications").get();
  for (const doc of verificationsSnap.docs) {
    const userId = doc.data().userId;
    if (deletedUserIds.includes(userId)) {
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  // 4. Clean up notifications subcollections and root docs
  for (const userId of deletedUserIds) {
    const itemsSnap = await db.collection("notifications").doc(userId).collection("items").get();
    for (const doc of itemsSnap.docs) {
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
    batch.delete(db.collection("notifications").doc(userId));
    batchCount++;
    await commitBatchIfNeeded();
  }
  
  // 5. Clean up favorites subcollections
  for (const userId of deletedUserIds) {
    const favPropsSnap = await db.collection("favorites").doc(userId).collection("properties").get();
    for (const doc of favPropsSnap.docs) {
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  // 6. Clean up tour requests
  const toursSnap = await db.collection("tour_requests").get();
  for (const doc of toursSnap.docs) {
    const tenantId = doc.data().tenantId || doc.data().userId;
    const landlordId = doc.data().landlordId;
    if (deletedUserIds.includes(tenantId) || deletedUserIds.includes(landlordId)) {
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  // 7. Clean up conversations
  const conversationsSnap = await db.collection("conversations").get();
  for (const doc of conversationsSnap.docs) {
    const participants = doc.data().participants || [];
    const hasDeletedUser = participants.some(p => deletedUserIds.includes(p));
    if (hasDeletedUser) {
      // Delete all messages inside this conversation
      const messagesSnap = await doc.ref.collection("messages").get();
      for (const mDoc of messagesSnap.docs) {
        batch.delete(mDoc.ref);
        batchCount++;
        await commitBatchIfNeeded();
      }
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  // 8. Clean up support chats
  const supportChatsSnap = await db.collection("support_chats").get();
  for (const doc of supportChatsSnap.docs) {
    const userId = doc.data().userId || doc.id;
    if (deletedUserIds.includes(userId)) {
      const messagesSnap = await doc.ref.collection("messages").get();
      for (const mDoc of messagesSnap.docs) {
        batch.delete(mDoc.ref);
        batchCount++;
        await commitBatchIfNeeded();
      }
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  // 9. Clean up top-level messages
  const messagesSnap = await db.collection("messages").get();
  for (const doc of messagesSnap.docs) {
    const senderId = doc.data().senderId;
    const receiverId = doc.data().receiverId;
    if (deletedUserIds.includes(senderId) || deletedUserIds.includes(receiverId)) {
      batch.delete(doc.ref);
      batchCount++;
      await commitBatchIfNeeded();
    }
  }
  
  if (batchCount > 0) {
    await batch.commit();
  }
  
  console.log(`Successfully completed cleanup for ${deletedUserIds.length} users.`);
}

runCleanup()
  .then(() => process.exit(0))
  .catch(err => {
    console.error("Cleanup failed:", err);
    process.exit(1);
  });
