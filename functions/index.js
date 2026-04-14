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
