// Firebase Functions setup
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const fetch = require("node-fetch");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// Express app for payment session
const app = express();
app.use(cors({ origin: true }));

// Capture the raw request body BEFORE it's parsed by Express
// This is necessary for webhook signature verification.
app.use(
  express.json({
    verify: (req, res, buf) => {
      req.rawBody = buf; // Save the raw body buffer to the request object
    },
  })
);

// Endpoint to create a payment session
app.post("/create-payment-session", async (req, res) => {
  try {
    const {
      amount,
      currency,
      email,
      firstName,
      lastName,
      description,
      userId,
      phone,
    } = req.body;

    if (!amount || !currency || !email || !firstName || !lastName || !userId) {
      return res.status(400).send({ error: "Missing required fields." });
    }

    const txRef = `yetuga_${userId}_${Date.now()}`;

    const paymentData = {
      amount: String(amount),
      currency,
      email,
      first_name: firstName,
      last_name: lastName,
      tx_ref: txRef,
      callback_url: `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/chapaWebhook?userId=${userId}&txRef=${txRef}`,
      customization: {
        title: "Verification",
        description: description || "Payment for account services",
      },
    };

    if (phone) {
      paymentData.phone_number = phone;
    }

    const chapaSecretKey = functions.config().chapa.secret_key;
    const response = await fetch(
      "https://api.chapa.co/v1/transaction/initialize",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${chapaSecretKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(paymentData),
      }
    );

    const responseData = await response.json();

    if (responseData.status !== "success") {
      console.error("Chapa API returned an error:", responseData);
      return res
        .status(500)
        .send({
          error: "Failed to initialize payment with Chapa.",
          details: responseData,
        });
    }

    // --- FIX: Added displayName to the document ---
    await db
      .collection("verification_payments")
      .doc(txRef)
      .set({
        userId,
        displayName: `${firstName} ${lastName}`, // Save the full name
        amount: String(amount),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending",
      });

    res
      .status(200)
      .send({ checkoutUrl: responseData.data.checkout_url, txRef });
  } catch (error) {
    console.error("Error creating payment session:", error);
    res
      .status(500)
      .send({
        error: "Failed to create payment session due to an internal error.",
      });
  }
});

exports.createPaymentSession = functions.https.onRequest(app);

// Webhook endpoint for Chapa payment verification
exports.chapaWebhook = functions.https.onRequest(async (req, res) => {
  // 1. Verify the request is from Chapa using the signature
  const chapaSignature = req.headers["x-chapa-signature"];
  const secretHash = functions.config().chapa.secret_hash;

  if (!chapaSignature) {
    console.error("Webhook error: No Chapa signature found in headers.");
    return res.status(401).send("Unauthorized: Missing signature.");
  }

  const calculatedSignature = crypto
    .createHmac("sha256", secretHash)
    .update(req.rawBody)
    .digest("hex");

  if (chapaSignature !== calculatedSignature) {
    console.error(`Webhook error: Invalid signature.`);
    return res.status(401).send("Unauthorized: Invalid signature.");
  }
  console.log("Webhook signature verified successfully.");

  try {
    // 2. Get the transaction reference from the webhook BODY
    const tx_ref = req.body.tx_ref;
    if (!tx_ref) {
      console.error("Webhook call missing tx_ref in body.");
      return res.status(400).send("Missing tx_ref");
    } // 3. Verify the transaction with Chapa's API as the source of truth

    const chapaSecretKey = functions.config().chapa.secret_key;
    const verificationResponse = await fetch(
      `https://api.chapa.co/v1/transaction/verify/${tx_ref}`,
      {
        method: "GET",
        headers: { Authorization: `Bearer ${chapaSecretKey}` },
      }
    );
    const verificationData = await verificationResponse.json();
    console.log(
      "Chapa verification response:",
      JSON.stringify(verificationData, null, 2)
    ); // 4. If Chapa confirms success, proceed

    if (
      verificationData.status === "success" &&
      verificationData.data?.status === "success"
    ) {
      // --- Look up our internal record to get the userId ---
      const paymentDocRef = db.collection("verification_payments").doc(tx_ref);
      const paymentDoc = await paymentDocRef.get();

      if (!paymentDoc.exists) {
        console.error(`Could not find payment document for tx_ref: ${tx_ref}`);
        return res.status(404).send("Payment record not found.");
      }

      const userId = paymentDoc.data().userId; // Now that we have the correct userId, update the user and payment status
      await db.collection("users").doc(userId).update({ verified: true });
      await paymentDocRef.update({ status: "success" });
      console.log(
        `SUCCESS: User ${userId} marked as verified for tx_ref: ${tx_ref}.`
      );
      res.status(200).send("Webhook processed successfully.");
    } else {
      // If Chapa says the payment was not successful, update our record accordingly
      await db
        .collection("verification_payments")
        .doc(tx_ref)
        .update({
          status: verificationData.data?.status || "failed_verification",
        });
      console.warn(
        `Webhook received for tx_ref: ${tx_ref}, but payment not successful.`
      );
      res.status(200).send("Webhook received, but payment not successful.");
    }
  } catch (error) {
    console.error("Error in webhook processing:", error);
    res.status(500).send("Error processing webhook");
  }
});
