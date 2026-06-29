const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const nodemailer = require("nodemailer");

admin.initializeApp();

// ── Email transporter (configure via Firebase environment config) ─────────
// To set credentials run:
//   firebase functions:secrets:set GMAIL_USER
//   firebase functions:secrets:set GMAIL_PASS
// Use a Gmail account with "App Passwords" enabled (not your main password)
function createTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: {
      user: process.env.GMAIL_USER || "",
      pass: process.env.GMAIL_PASS || "",
    },
  });
}

// ── Send 2FA Code ─────────────────────────────────────────────────────────
exports.send2FACode = onCall(async (request) => {
  const { email, code } = request.data;

  if (!email || !code) {
    throw new Error("Missing email or code");
  }

  const transporter = createTransporter();

  const mailOptions = {
    from: `"Home237 Security" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: "Your Home237 Verification Code",
    // Plain text version (required for Primary inbox placement)
    text: `Your Home237 verification code is: ${code}\n\nThis code expires in 10 minutes.\nIf you did not request this, please ignore this email.\n\n— The Home237 Team`,
    // HTML version
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <div style="background: #3B82F6; padding: 24px; text-align: center; border-radius: 12px 12px 0 0;">
          <h1 style="color: white; font-size: 24px; margin: 0;">🏠 Home237</h1>
        </div>
        <div style="background: #f9fafb; padding: 32px; border-radius: 0 0 12px 12px; border: 1px solid #e5e7eb;">
          <h2 style="color: #1e293b; margin-bottom: 8px;">Your Verification Code</h2>
          <p style="color: #64748b;">Use the code below to complete your two-factor authentication setup:</p>
          <div style="background: white; border: 2px solid #3B82F6; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
            <span style="font-size: 36px; font-weight: bold; letter-spacing: 12px; color: #1e293b;">${code}</span>
          </div>
          <p style="color: #64748b; font-size: 14px;">This code expires in <strong>10 minutes</strong>.</p>
          <p style="color: #9ca3af; font-size: 12px;">If you did not request this code, please ignore this email or contact support if you have concerns.</p>
        </div>
        <p style="text-align: center; color: #9ca3af; font-size: 12px; margin-top: 16px;">© 2023 Home237. All rights reserved.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    logger.info(`2FA code sent to ${email}`);
    return { success: true };
  } catch (error) {
    logger.error("Error sending 2FA email:", error);
    throw new Error("Failed to send verification email. Please try again.");
  }
});

exports.onNewMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data.data();
    if (!messageData) {
      logger.error("No message data received");
      return;
    }

    const { senderId, text } = messageData;
    const conversationId = event.params.conversationId;

    try {
      // 1. Fetch the conversation metadata to find the recipient
      const conversationRef = admin
        .firestore()
        .collection("conversations")
        .doc(conversationId);
      const conversationSnap = await conversationRef.get();

      if (!conversationSnap.exists) {
        logger.error(`Conversation ${conversationId} not found`);
        return;
      }

      const conversationData = conversationSnap.data();
      const participants = conversationData.participants || [];

      // The recipient is the participant who is NOT the sender
      const recipientId = participants.find((id) => id !== senderId);

      if (!recipientId) {
        logger.error("Recipient ID not found in conversation participants");
        return;
      }

      // 2. Fetch the recipient's FCM token from their user document
      const recipientSnap = await admin
        .firestore()
        .collection("users")
        .doc(recipientId)
        .get();

      if (!recipientSnap.exists) {
        logger.error(`Recipient user ${recipientId} not found`);
        return;
      }

      const recipientData = recipientSnap.data();
      const fcmToken = recipientData.fcmToken;

      if (!fcmToken) {
        logger.log(`Recipient ${recipientId} does not have an FCM token. Skipping push notification.`);
        return;
      }

      // 3. Get the sender's name to display in the notification
      const senderSnap = await admin
        .firestore()
        .collection("users")
        .doc(senderId)
        .get();

      let senderName = "Someone";
      if (senderSnap.exists && senderSnap.data().name) {
        senderName = senderSnap.data().name;
      }

      // 4. Construct and send the FCM Payload
      const payload = {
        token: fcmToken,
        notification: {
          title: `New message from ${senderName}`,
          body: text,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          conversationId: conversationId,
          type: "chat_message",
        },
        // Setup iOS APNs payload options
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        // Setup Android priority options
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
          },
        },
      };

      const response = await admin.messaging().send(payload);
      logger.info(`Successfully sent message to ${recipientId}:`, response);
    } catch (error) {
      logger.error("Error sending push notification:", error);
    }
  }
);

exports.deleteUserAccount = onCall(async (request) => {
  // Ensure the caller is an admin
  const callerUid = request.auth && request.auth.uid;
  if (!callerUid) {
    throw new Error("Unauthorized: Must be logged in");
  }

  const adminDoc = await admin.firestore().collection("users").doc(callerUid).get();
  if (!adminDoc.exists || adminDoc.data().role !== "admin") {
    throw new Error("Unauthorized: Admin access required");
  }

  const { uid } = request.data;
  if (!uid) {
    throw new Error("Missing target user uid");
  }

  try {
    await admin.auth().deleteUser(uid);
    logger.info(`Successfully deleted user ${uid} from Firebase Auth`);
    return { success: true };
  } catch (error) {
    logger.error(`Error deleting user ${uid} from Firebase Auth:`, error);
    throw new Error("Failed to delete user from Auth");
  }
});

exports.syncUsersWithAuth = onCall(async (request) => {
  // Ensure the caller is an admin
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new Error("Unauthorized: Must be logged in");
  }

  const adminDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!adminDoc.exists || adminDoc.data().role !== "admin") {
    throw new Error("Unauthorized: Admin access required");
  }

  logger.info("🚀 Starting user sync with Firebase Auth...");
  let usersCreated = 0;
  let nextPageToken;

  try {
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      const batch = admin.firestore().batch();
      let batchCount = 0;

      for (const userRecord of listUsersResult.users) {
        const userRef = admin.firestore().collection("users").doc(userRecord.uid);
        const userDoc = await userRef.get();

        if (!userDoc.exists) {
          batch.set(userRef, {
            name: userRecord.displayName || (userRecord.email ? userRecord.email.split("@")[0] : "User"),
            email: userRecord.email || "",
            role: "none",
            createdAt: admin.firestore.Timestamp.fromDate(new Date(userRecord.metadata.creationTime)),
            emailVerified: userRecord.emailVerified || false,
            hasSeenWelcome: true,
            subscriptionStatus: "free",
          });
          batchCount++;
          usersCreated++;
        }

        // Firestore batches can only have 500 operations
        if (batchCount >= 400) {
          await batch.commit();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);

    logger.info(`✅ User sync complete. Created ${usersCreated} missing user documents.`);
    return { success: true, usersCreated };
  } catch (error) {
    logger.error("❌ Error during user sync:", error);
    throw new Error("Failed to sync users with Firebase Auth");
  }
});

exports.resetLandlordTenantAccounts = onCall(async (request) => {
  const db = admin.firestore();
  
  // 1. Get all users
  const usersSnap = await db.collection("users").get();
  const deletedUserIds = [];
  
  logger.info(`Found ${usersSnap.size} total users in Firestore.`);
  
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
      logger.info(`Marking user ${userId} (${data.email}, role: ${role}) for deletion.`);
      
      // Delete from Auth
      try {
        await admin.auth().deleteUser(userId);
        logger.info(`Deleted auth user: ${userId}`);
      } catch (authError) {
        logger.warn(`Could not delete auth user ${userId}: ${authError.message}`);
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
    logger.info("No landlord or tenant users found to delete.");
    return { success: true, deletedCount: 0 };
  }
  
  logger.info(`Starting cascade cleanup for ${deletedUserIds.length} users...`);
  
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
  
  logger.info(`Successfully completed cleanup for ${deletedUserIds.length} users.`);
  return { success: true, deletedCount: deletedUserIds.length };
});

exports.onNewProperty = onDocumentCreated("properties/{propertyId}", async (event) => {
  const propertyData = event.data.data();
  if (!propertyData) {
    logger.error("No property data received");
    return;
  }

  const propertyId = event.params.propertyId;
  const title = propertyData.title || "A new property";
  const area = propertyData.area || "";
  const town = propertyData.town || "";
  const location = propertyData.location || (area ? `${area}, ${town}` : town);

  const messageText = `🏠 A new home "${title}" was just posted in ${location}! Tap to view and schedule a tour.`;

  try {
    const db = admin.firestore();
    
    // Fetch all users to notify tenants and free users
    const tenantsSnap = await db.collection("users").get();
    
    const notificationPromises = [];

    for (const doc of tenantsSnap.docs) {
      const userData = doc.data();
      const userId = doc.id;
      const role = userData.role || "";
      const fcmToken = userData.fcmToken;

      // Notify users who are tenants or haven't set a role yet (none)
      if (role === "tenant" || role === "none") {
        // 1. Create In-App Notification document
        const inAppPromise = db.collection("notifications").doc(userId).collection("items").add({
          title: "New House Posted! 🏠",
          message: messageText,
          type: "property",
          propertyId: propertyId,
          read: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        notificationPromises.push(inAppPromise);

        // 2. If user has an FCM token, send a push notification
        if (fcmToken) {
          const payload = {
            token: fcmToken,
            notification: {
              title: "New House Posted! 🏠",
              body: messageText,
            },
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              propertyId: propertyId,
              type: "property",
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
            android: {
              priority: "high",
              notification: {
                channelId: "high_importance_channel",
                sound: "default",
              },
            },
          };

          const fcmPromise = admin.messaging().send(payload)
            .then((response) => {
              logger.info(`Successfully sent property push notification to user ${userId}:`, response);
            })
            .catch((error) => {
              logger.error(`Error sending push notification to user ${userId}:`, error);
            });
          notificationPromises.push(fcmPromise);
        }
      }
    }

    await Promise.all(notificationPromises);
    logger.info(`Successfully sent new property notifications to all tenants.`);
  } catch (error) {
    logger.error("Error broadcasting new property notifications:", error);
  }
});

exports.broadcastNotification = onCall(async (request) => {
  // Ensure the caller is logged in and is an admin
  const callerUid = request.auth && request.auth.uid;
  if (!callerUid) {
    throw new Error("Unauthorized: Must be logged in");
  }

  const adminDoc = await admin.firestore().collection("users").doc(callerUid).get();
  if (!adminDoc.exists || adminDoc.data().role !== "admin") {
    throw new Error("Unauthorized: Admin access required");
  }

  const { title, message } = request.data;
  if (!title || !message) {
    throw new Error("Missing title or message");
  }

  try {
    const db = admin.firestore();
    const usersSnap = await db.collection("users").get();
    const notificationPromises = [];
    const transporter = createTransporter();

    for (const doc of usersSnap.docs) {
      const userData = doc.data();
      const userId = doc.id;
      const fcmToken = userData.fcmToken;

      // 1. Create In-App Notification document
      const inAppPromise = db.collection("notifications").doc(userId).collection("items").add({
        title: title,
        message: message,
        type: "announcement",
        read: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      notificationPromises.push(inAppPromise);

      // 2. Send email notification via GMAIL SMTP if user has an email
      const email = userData.email;
      if (email) {
        const mailOptions = {
          from: `"Home237 Announcement" <${process.env.GMAIL_USER}>`,
          to: email,
          subject: title,
          text: `Hello ${userData.name || "User"},\n\nWe have an important announcement for you:\n\n${message}\n\n— The Home237 Team`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;">
              <div style="background: #3B82F6; padding: 24px; text-align: center;">
                <h1 style="color: white; font-size: 24px; margin: 0;">🏠 Home237</h1>
              </div>
              <div style="background: #f9fafb; padding: 32px;">
                <h2 style="color: #1e293b; margin-top: 0; margin-bottom: 16px; font-size: 20px;">${title}</h2>
                <p style="color: #475569; font-size: 15px; line-height: 1.6;">Hello ${userData.name || "User"},</p>
                <div style="background: white; border-radius: 8px; padding: 20px; border: 1px solid #e2e8f0; margin: 20px 0; color: #334155; line-height: 1.6; font-size: 14px; white-space: pre-wrap;">${message}</div>
                <p style="color: #64748b; font-size: 13px; margin-bottom: 0;">If you have any questions, feel free to reply to this email or contact support inside the app.</p>
              </div>
              <div style="background: #f3f4f6; padding: 16px; text-align: center; border-top: 1px solid #e5e7eb;">
                <p style="color: #9ca3af; font-size: 12px; margin: 0;">© 2026 Home237. All rights reserved.</p>
              </div>
            </div>
          `,
        };
        const emailPromise = transporter.sendMail(mailOptions)
          .then(() => {
            logger.info(`Successfully sent broadcast email to ${email}`);
          })
          .catch((error) => {
            logger.error(`Error sending broadcast email to ${email}:`, error);
          });
        notificationPromises.push(emailPromise);
      }

      // 2. If user has an FCM token, send a push notification
      if (fcmToken) {
        const payload = {
          token: fcmToken,
          notification: {
            title: title,
            body: message,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "announcement",
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              sound: "default",
            },
          },
        };

        const fcmPromise = admin.messaging().send(payload)
          .then((response) => {
            logger.info(`Successfully sent broadcast push to user ${userId}:`, response);
          })
          .catch((error) => {
            logger.error(`Error sending broadcast push to user ${userId}:`, error);
          });
        notificationPromises.push(fcmPromise);
      }
    }

    await Promise.all(notificationPromises);
    logger.info(`Successfully broadcast announcement to ${usersSnap.size} users.`);
    return { success: true, count: usersSnap.size };
  } catch (error) {
    logger.error("Error broadcasting announcement:", error);
    throw new Error("Failed to broadcast announcement");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// FAPSHI SECURE PAYMENT FUNCTIONS
//
// How credentials are kept secure:
//   • Credentials (apiUser, apiKey) are stored in Firestore: admin_settings/fapshi
//   • The Flutter app CANNOT read admin_settings (Firestore rules: admin only)
//   • These Cloud Functions read credentials using the Firebase Admin SDK,
//     which bypasses Firestore rules entirely — only the server has access.
//   • The app only calls these Cloud Functions and receives a transId back.
//   • Your Fapshi API keys are NEVER sent to the client.
//
// To update credentials:
//   Go to Firestore → admin_settings → fapshi → set { apiUser, apiKey, mode }
//   mode: "live" (default) or "sandbox"
// ─────────────────────────────────────────────────────────────────────────────

const FAPSHI_LIVE_URL    = "https://live.fapshi.com";
const FAPSHI_SANDBOX_URL = "https://sandbox.fapshi.com";

// Module-level credential cache to avoid hitting Firestore on every call
let _fapshiCache = null;
let _fapshiCacheTime = 0;
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/** Loads Fapshi credentials from Firestore admin_settings/fapshi (Admin SDK). */
async function loadFapshiCredentials() {
  const now = Date.now();
  if (_fapshiCache && (now - _fapshiCacheTime) < CACHE_TTL_MS) {
    return _fapshiCache;
  }

  const doc = await admin.firestore()
    .collection("admin_settings")
    .doc("fapshi")
    .get();

  if (!doc.exists) {
    throw new Error(
      "Fapshi credentials not found. Please set apiUser and apiKey in " +
      "Firestore → admin_settings → fapshi."
    );
  }

  const data = doc.data();
  const tryField = (keys) => {
    for (const k of keys) {
      if (data[k] && String(data[k]).trim()) return String(data[k]).trim();
    }
    return "";
  };

  const apiUser = tryField(["apiUser", "api_user", "apiuser", "ApiUser"]);
  const apiKey  = tryField(["apiKey",  "api_key",  "apikey",  "ApiKey"]);
  const mode    = tryField(["mode", "Mode"]) || "live";

  if (!apiUser || !apiKey) {
    throw new Error(
      "Fapshi apiUser or apiKey is empty in admin_settings/fapshi. " +
      "Please update the document with your Live credentials from the Fapshi dashboard."
    );
  }

  const baseUrl = mode === "sandbox" ? FAPSHI_SANDBOX_URL : FAPSHI_LIVE_URL;
  _fapshiCache = { apiUser, apiKey, baseUrl, mode };
  _fapshiCacheTime = now;

  logger.info(`FapshiCredentials: loaded mode=${mode} baseUrl=${baseUrl} apiUser=${apiUser.slice(0, 8)}...`);
  return _fapshiCache;
}

/** Normalise a Cameroonian phone number to the 9-digit local format Fapshi expects. */
function normalizeCmrPhone(raw) {
  let phone = raw.replace(/[\s\-\+]/g, "");
  if (phone.startsWith("237") && phone.length > 9) phone = phone.slice(3);
  if (phone.startsWith("0")   && phone.length > 9) phone = phone.slice(1);
  return phone;
}

/**
 * Initiates a Fapshi Direct-Pay (MoMo push prompt) from the server.
 * Called by the Flutter app instead of hitting Fapshi directly.
 *
 * Request data:
 *   amount     {number}  — XAF amount (min 100)
 *   phone      {string}  — payer's phone (e.g. "237671234567")
 *   medium     {string}  — "mobile money" | "orange money"
 *   message    {string?} — description shown to payer
 *   userId     {string?} — internal user UID for reconciliation
 *   externalId {string?} — your order/transaction ID
 *
 * Returns: { transId: string }
 */
exports.initiateFapshiPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated: You must be signed in to make a payment.");
  }

  const { amount, phone, medium, message, userId, externalId } = request.data;

  if (!amount || !phone || !medium) {
    throw new Error("Missing required fields: amount, phone, medium.");
  }
  if (amount < 100) {
    throw new Error("Minimum payment amount is 100 XAF.");
  }

  const { apiUser, apiKey, baseUrl } = await loadFapshiCredentials();
  const cleanPhone = normalizeCmrPhone(String(phone));

  const body = { amount, phone: cleanPhone, medium };
  if (message)    body.message    = message;
  if (userId)     body.userId     = userId;
  if (externalId) body.externalId = externalId;

  logger.info(`initiateFapshiPayment: uid=${request.auth.uid} amount=${amount} phone=${cleanPhone} medium=${medium} url=${baseUrl}`);

  let res;
  try {
    res = await fetch(`${baseUrl}/direct-pay`, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "apiuser": apiUser,
        "apikey":  apiKey,
      },
      body: JSON.stringify(body),
    });
  } catch (netErr) {
    logger.error("initiateFapshiPayment: network error", netErr);
    throw new Error("Cannot reach Fapshi servers. Please check your internet connection.");
  }

  const data = await res.json().catch(() => ({}));

  if (res.status === 200 || res.status === 201) {
    logger.info(`initiateFapshiPayment: success transId=${data.transId}`);
    return { transId: data.transId };
  }

  let msg = data.message || "Unknown Fapshi error";
  if (res.status === 401 || res.status === 403) {
    msg += " — Your apiUser or apiKey in Firestore (admin_settings/fapshi) " +
           "does not match the Live credentials on your Fapshi dashboard. " +
           "Also disable IP whitelisting on the Fapshi dashboard.";
    // Bust the cache so next call re-loads fresh credentials
    _fapshiCache = null;
  }
  logger.error(`initiateFapshiPayment: Fapshi error ${res.status}: ${msg}`);
  throw new Error(msg);
});

/**
 * Checks the status of a Fapshi transaction.
 *
 * Request data:
 *   transId {string} — the transaction ID returned by initiateFapshiPayment
 *
 * Returns: { status: "created" | "pending" | "successful" | "failed" | "expired" }
 */
exports.checkFapshiPaymentStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated.");
  }

  const { transId } = request.data;
  if (!transId) throw new Error("Missing transId.");

  const { apiUser, apiKey, baseUrl } = await loadFapshiCredentials();

  let res;
  try {
    res = await fetch(`${baseUrl}/payment-status/${transId}`, {
      method:  "GET",
      headers: {
        "Content-Type": "application/json",
        "apiuser": apiUser,
        "apikey":  apiKey,
      },
    });
  } catch (netErr) {
    logger.error("checkFapshiPaymentStatus: network error", netErr);
    throw new Error("Cannot reach Fapshi servers.");
  }

  const raw = await res.json().catch(() => ({}));

  if (res.status !== 200) {
    logger.warn(`checkFapshiPaymentStatus: error ${res.status}`, raw);
    return { status: "failed" };
  }

  const item = Array.isArray(raw) ? raw[0] : raw;
  const statusRaw = (item.status || "").toUpperCase();

  const STATUS_MAP = {
    SUCCESSFUL: "successful",
    FAILED:     "failed",
    EXPIRED:    "expired",
    PENDING:    "pending",
    CREATED:    "created",
  };
  const status = STATUS_MAP[statusRaw] || "created";
  logger.info(`checkFapshiPaymentStatus: transId=${transId} status=${status}`);
  return { status };
});

/**
 * Sends a Fapshi Payout (disbursement) to a mobile money number.
 * Only callable by authenticated users.
 *
 * Request data:
 *   amount {number} — XAF amount
 *   phone  {string} — recipient phone number
 *   medium {string} — "mobile money" | "orange money"
 *
 * Returns: { success: true }
 */
exports.sendFapshiPayout = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated.");
  }

  const { amount, phone, medium } = request.data;
  if (!amount || !phone || !medium) {
    throw new Error("Missing required fields: amount, phone, medium.");
  }

  const { apiUser, apiKey, baseUrl } = await loadFapshiCredentials();
  const cleanPhone = normalizeCmrPhone(String(phone));
  const body = { amount, phone: cleanPhone, medium };

  logger.info(`sendFapshiPayout: uid=${request.auth.uid} amount=${amount} phone=${cleanPhone} medium=${medium}`);

  let res;
  try {
    res = await fetch(`${baseUrl}/payout`, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "apiuser": apiUser,
        "apikey":  apiKey,
      },
      body: JSON.stringify(body),
    });
  } catch (netErr) {
    logger.error("sendFapshiPayout: network error", netErr);
    throw new Error("Cannot reach Fapshi servers.");
  }

  const data = await res.json().catch(() => ({}));

  if (res.status === 200 || res.status === 201) {
    logger.info("sendFapshiPayout: payout success");
    return { success: true };
  }

  let msg = data.message || "Payout failed.";
  if (res.status === 401 || res.status === 403) {
    msg += " — Check apiUser/apiKey in admin_settings/fapshi and disable IP whitelisting on Fapshi dashboard.";
    _fapshiCache = null;
  }
  logger.error(`sendFapshiPayout: Fapshi error ${res.status}: ${msg}`);
  throw new Error(msg);
});
