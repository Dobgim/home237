const admin = require("firebase-admin");

// Initialize with explicit project ID
admin.initializeApp({
  projectId: "home237-92c18",
});

const db = admin.firestore();

async function setFapshiCredentials() {
  try {
    await db.collection("admin_settings").doc("fapshi").set({
      apiUser: "ba01f9ab-b79c-4a6c-b256-787fcb716705",
      apiKey: "FAK_87900457310b82601c123b0909a182c3",
      mode: "live",
    }, { merge: true });

    console.log("✅ Fapshi credentials written to Firestore successfully!");
    console.log("   Collection: admin_settings");
    console.log("   Document:   fapshi");
    console.log("   Fields:     apiUser, apiKey, mode=live");
    
    // Verify by reading back
    const doc = await db.collection("admin_settings").doc("fapshi").get();
    console.log("\n📋 Verification - document contents:");
    console.log(JSON.stringify(doc.data(), null, 2));
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
  process.exit(0);
}

setFapshiCredentials();
