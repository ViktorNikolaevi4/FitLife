const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const PUSH_LEASE_MS = 5 * 60 * 1000;
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = "gpt-4.1-mini";

exports.recognizeMeal = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: ["OPENAI_API_KEY"]
  },
  async (request, response) => {
    setJsonResponseHeaders(response);

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(405).json({ error: { code: "method_not_allowed" } });
      return;
    }

    try {
      await verifyAuthorization(request);

      const body = request.body || {};
      const mode = typeof body.mode === "string" ? body.mode : "";
      const language = normalizeRecognitionLanguage(body.language);

      let meal;
      if (mode === "image") {
        const imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : "";
        if (!imageBase64 || imageBase64.length > 8 * 1024 * 1024) {
          response.status(400).json({ error: { code: "invalid_image" } });
          return;
        }
        meal = await recognizeImageMeal(imageBase64, language);
      } else if (mode === "text") {
        const description = typeof body.description === "string" ? body.description.trim() : "";
        if (!description || description.length > 2000) {
          response.status(400).json({ error: { code: "invalid_description" } });
          return;
        }
        meal = await recognizeTextMeal(description, language);
      } else {
        response.status(400).json({ error: { code: "invalid_mode" } });
        return;
      }

      response.status(200).json(meal);
    } catch (error) {
      logger.error("Meal recognition failed", {
        code: error.code || "unknown",
        message: error.message || "unknown_error"
      });

      const status = error.status || 500;
      response.status(status).json({
        error: {
          code: error.code || "meal_recognition_failed"
        }
      });
    }
  }
);

// Creates a training draft only. The iOS app presents the result to the
// trainer and persists it after an explicit confirmation.
exports.generateWorkoutDraft = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: ["OPENAI_API_KEY"]
  },
  async (request, response) => {
    setJsonResponseHeaders(response);

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }
    if (request.method !== "POST") {
      response.status(405).json({ error: { code: "method_not_allowed" } });
      return;
    }

    try {
      const decodedToken = await verifyAuthorization(request);
      await verifyActiveTrainer(decodedToken.uid);

      const body = request.body || {};
      const command = typeof body.command === "string" ? body.command.trim() : "";
      const language = body.language === "en" ? "English" : "Russian";
      if (!command || command.length > 2_000) {
        response.status(400).json({ error: { code: "invalid_command" } });
        return;
      }

      const draft = await generateWorkoutDraft(command, language);
      response.status(200).json(draft);
    } catch (error) {
      logger.error("Workout draft generation failed", {
        code: error.code || "unknown",
        message: error.message || "unknown_error"
      });
      response.status(error.status || 500).json({
        error: { code: error.code || "workout_generation_failed" }
      });
    }
  }
);

const TYPE_CONFIG = {
  coaching_request_submitted: {
    ru: {
      title: "Новый запрос на сопровождение",
      body: (senderName) => formatSenderBody(senderName, "ru", "отправил запрос на сопровождение.", "sent a coaching request.")
    },
    en: {
      title: "New coaching request",
      body: (senderName) => formatSenderBody(senderName, "en", "отправил запрос на сопровождение.", "sent a coaching request.")
    }
  },
  coaching_request_approved: {
    ru: {
      title: "Запрос одобрен",
      body: () => "Тренер принял ваш запрос на сопровождение."
    },
    en: {
      title: "Request approved",
      body: () => "Your coach approved your coaching request."
    }
  },
  coaching_request_rejected: {
    ru: {
      title: "Запрос отклонён",
      body: () => "Тренер отклонил ваш запрос на сопровождение."
    },
    en: {
      title: "Request declined",
      body: () => "Your coach declined your coaching request."
    }
  },
  workout_report_sent: {
    ru: {
      title: "Новый отчёт по тренировке",
      body: (senderName) => formatSenderBody(senderName, "ru", "отправил тренировочный отчёт.", "sent a workout report.")
    },
    en: {
      title: "New workout report",
      body: (senderName) => formatSenderBody(senderName, "en", "отправил тренировочный отчёт.", "sent a workout report.")
    }
  },
  nutrition_report_sent: {
    ru: {
      title: "Новый отчёт по питанию",
      body: (senderName) => formatSenderBody(senderName, "ru", "отправил отчёт по питанию.", "sent a nutrition report.")
    },
    en: {
      title: "New nutrition report",
      body: (senderName) => formatSenderBody(senderName, "en", "отправил отчёт по питанию.", "sent a nutrition report.")
    }
  },
  checkin_submitted: {
    ru: {
      title: "Новый check-in",
      body: (senderName) => formatSenderBody(senderName, "ru", "отправил новый check-in.", "submitted a new check-in.")
    },
    en: {
      title: "New check-in",
      body: (senderName) => formatSenderBody(senderName, "en", "отправил новый check-in.", "submitted a new check-in.")
    }
  },
  coach_note_received: {
    ru: {
      title: "Новая заметка от тренера",
      body: (senderName) => formatSenderBody(senderName, "ru", "оставил вам сообщение.", "left you a message.")
    },
    en: {
      title: "New coach note",
      body: (senderName) => formatSenderBody(senderName, "en", "оставил вам сообщение.", "left you a message.")
    }
  },
  client_note_received: {
    ru: {
      title: "Новое сообщение от клиента",
      body: (senderName) => formatSenderBody(senderName, "ru", "отправил сообщение.", "sent a message.")
    },
    en: {
      title: "New client message",
      body: (senderName) => formatSenderBody(senderName, "en", "отправил сообщение.", "sent a message.")
    }
  },
  workout_assigned: {
    ru: {
      title: "Новая тренировка от тренера",
      body: (senderName) => formatSenderBody(senderName, "ru", "назначил вам тренировку.", "assigned you a workout.")
    },
    en: {
      title: "New workout assigned",
      body: (senderName) => formatSenderBody(senderName, "en", "назначил вам тренировку.", "assigned you a workout.")
    }
  },
  profile_update_requested: {
    ru: {
      title: "Запрос на обновление данных",
      body: (senderName) => formatSenderBody(senderName, "ru", "запросил обновить информацию профиля.", "requested a profile update.")
    },
    en: {
      title: "Profile update requested",
      body: (senderName) => formatSenderBody(senderName, "en", "запросил обновить информацию профиля.", "requested a profile update.")
    }
  }
};

// Chat delivery and notification delivery are separate concerns. Creating the
// notification on the server makes the latter reliable even if an older app
// build or a transient client-side write failure skips its notification event.
exports.createNotificationForCoachingNote = onDocumentCreated(
  {
    document: "coaching_notes/{noteId}",
    region: "europe-west1",
    retry: true
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const note = snapshot.data() || {};
    const noteId = snapshot.id;
    const authorRole = stringifyData(note.authorRole);
    const clientId = stringifyData(note.clientId);
    const trainerId = stringifyData(note.trainerId);
    const authorId = stringifyData(note.authorId);

    const isClientMessage = authorRole === "client" && authorId === clientId;
    const isTrainerMessage = authorRole === "trainer" && authorId === trainerId;
    if ((!isClientMessage && !isTrainerMessage) || !clientId || !trainerId) {
      logger.warn("Coaching note has invalid participants", { noteId });
      return;
    }

    const recipientId = isClientMessage ? trainerId : clientId;
    const type = isClientMessage ? "client_note_received" : "coach_note_received";

    // Older app versions may have already created this event themselves. Do
    // not generate a duplicate while those versions are still in the field.
    const existingEvent = await db
      .collection("notification_events")
      .where("targetId", "==", noteId)
      .limit(1)
      .get();
    if (!existingEvent.empty) {
      // Do not rely solely on the second Firestore trigger.  A direct call
      // keeps chat push delivery reliable even when Eventarc delays a chained
      // notification_events trigger. `claimPushDelivery` below prevents a
      // duplicate if that trigger is already running.
      await processPushForNotificationEvent(existingEvent.docs[0].id);
      return;
    }

    const senderSnapshot = await db.collection("users").doc(authorId).get();
    const senderData = senderSnapshot.data() || {};
    const senderName = typeof senderData.displayName === "string"
      ? senderData.displayName.trim()
      : "";

    const notificationRef = db.collection("notification_events").doc(`coaching-note-${noteId}`);
    await notificationRef.create({
      type,
      recipientId,
      senderId: authorId,
      senderName,
      targetType: "coaching_connection",
      targetId: noteId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      isArchived: false
    });

    await processPushForNotificationEvent(notificationRef.id);
  }
);

exports.sendPushForNotificationEvent = onDocumentCreated(
  {
    document: "notification_events/{eventId}",
    region: "europe-west1",
    retry: true
  },
  async (event) => {
    const eventId = event.params.eventId;
    await processPushForNotificationEvent(eventId);
  }
);

// Atomically claim an event before contacting FCM. A lease makes a failed
// invocation recoverable: Cloud Functions may retry it, while a later
// invocation can reclaim a stale `sending` state after the lease expires.
async function claimPushDelivery(eventId) {
  const eventRef = db.collection("notification_events").doc(eventId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(eventRef);
    if (!snapshot.exists) {
      logger.warn("Notification event does not exist", { eventId });
      return null;
    }

    const data = snapshot.data() || {};
    const status = stringifyData(data.pushStatus);
    if (status === "sent" || status === "permanent_failed") {
      logger.info("Push delivery already claimed", { eventId, pushStatus: data.pushStatus });
      return null;
    }

    if (status === "sending") {
      const leaseExpiresAt = data.pushLeaseExpiresAt;
      const leaseIsActive = leaseExpiresAt
        && typeof leaseExpiresAt.toMillis === "function"
        && leaseExpiresAt.toMillis() > Date.now();
      if (leaseIsActive) {
        logger.info("Push delivery is being processed", { eventId });
        return null;
      }
    }

    transaction.set(eventRef, {
      pushStatus: "sending",
      pushStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      pushLeaseExpiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + PUSH_LEASE_MS),
      pushAttemptCount: admin.firestore.FieldValue.increment(1),
      pushFailureReason: admin.firestore.FieldValue.delete()
    }, { merge: true });
    return data;
  });
}

async function processPushForNotificationEvent(eventId) {
  try {
    const data = await claimPushDelivery(eventId);
    if (!data) {
      return;
    }

    const recipientId = data.recipientId;
    if (!recipientId) {
      logger.warn("recipientId is missing", { eventId });
      await markPushPermanentlyFailed(eventId, "missing_recipient");
      return;
    }

    const userSnapshot = await db.collection("users").doc(recipientId).get();
    const userData = userSnapshot.data() || {};
    const unreadCount = await incrementUnreadNotificationCount(recipientId, userData);
    const fcmTokens = sanitizeTokens(userData.fcmTokens);

    if (fcmTokens.length === 0) {
      logger.info("No FCM tokens for recipient", { eventId, recipientId });
      await markPushPermanentlyFailed(eventId, "no_tokens");
      return;
    }

    const preferredLanguage = normalizeLanguage(userData.preferredLanguage);
    const pushContent = buildPushContent(data, preferredLanguage);
    const chatThreadId = chatNotificationThreadIdentifier(data);
    const message = {
      tokens: fcmTokens,
      notification: {
        title: pushContent.title,
        body: pushContent.body
      },
      data: {
        eventId,
        type: stringifyData(data.type),
        recipientId: stringifyData(data.recipientId),
        senderId: stringifyData(data.senderId),
        senderName: stringifyData(data.senderName),
        targetType: stringifyData(data.targetType),
        targetId: stringifyData(data.targetId)
      },
      apns: {
        // Be explicit for APNs: this is a user-visible notification, not a
        // background data update. It makes delivery semantics consistent on
        // iOS when the app is suspended or in the foreground.
        headers: {
          "apns-push-type": "alert",
          "apns-priority": "10"
        },
        payload: {
          aps: {
            // Include the alert in the APNs payload itself. The badge proves
            // APNs receives the message; this makes the banner content
            // unambiguous instead of relying on FCM's notification mapping.
            alert: {
              title: pushContent.title,
              body: pushContent.body
            },
            sound: "default",
            badge: Math.max(1, unreadCount),
            ...(chatThreadId ? { "thread-id": chatThreadId } : {})
          }
        }
      }
    };

    const response = await messaging.sendEachForMulticast(message);

    const invalidTokens = [];
    response.responses.forEach((result, index) => {
      if (result.success) {
        return;
      }

      const errorCode = result.error && result.error.code ? result.error.code : "";
      if (
        errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(fcmTokens[index]);
      }

      logger.error("Failed to send push", {
        eventId,
        recipientId,
        token: fcmTokens[index],
        errorCode,
        errorMessage: result.error ? result.error.message : "unknown_error"
      });
    });

    if (invalidTokens.length > 0) {
      await db.collection("users").doc(recipientId).set(
        {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens)
        },
        { merge: true }
      );
    }

    if (response.successCount > 0) {
      logger.info("Push sent", {
        eventId,
        recipientId,
        unreadCount,
        successCount: response.successCount,
        failureCount: response.failureCount
      });
      await db.collection("notification_events").doc(eventId).set(
        {
          pushStatus: response.failureCount === 0 ? "sent" : "partial",
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
          pushSuccessCount: response.successCount,
          pushFailureCount: response.failureCount
        },
        { merge: true }
      );
      return;
    }

    if (invalidTokens.length === fcmTokens.length) {
      await markPushPermanentlyFailed(eventId, "all_tokens_invalid");
      return;
    }

    const error = new Error("FCM did not accept any recipient token");
    error.code = "push_send_failed";
    throw error;
  } catch (error) {
    logger.error("Push delivery will be retried", {
      eventId,
      errorCode: error.code || "unknown",
      errorMessage: error.message || "unknown_error"
    });
    await markPushRetryable(eventId, error.code || "unknown_error");
    // Firestore-trigger retries are enabled above. Rethrowing is essential:
    // otherwise an invocation crash silently leaves the event undelivered.
    throw error;
  }
}

async function incrementUnreadNotificationCount(recipientId, userData) {
  const userRef = db.collection("users").doc(recipientId);

  // Existing users receive one historical calculation during migration. Each
  // subsequent notification uses an atomic increment instead of reading the
  // whole notification history.
  if (userData.unreadCounterInitialized !== true) {
    const unreadCount = await unreadNotificationCount(recipientId);
    await userRef.set(
      {
        unreadNotificationCount: unreadCount,
        unreadCounterInitialized: true,
        unreadCounterUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );
    return unreadCount;
  }

  const currentCount = Number(userData.unreadNotificationCount) || 0;
  await userRef.set(
    {
      unreadNotificationCount: admin.firestore.FieldValue.increment(1),
      unreadCounterUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );
  return Math.max(0, currentCount) + 1;
}

async function unreadNotificationCount(recipientId) {
  const snapshot = await db
    .collection("notification_events")
    .where("recipientId", "==", recipientId)
    .get();

  return snapshot.docs.filter((document) => {
    const data = document.data();
    return data.isRead !== true && data.isArchived !== true;
  }).length;
}

// `thread-id` groups chat notifications in Notification Center without
// suppressing the banner for subsequent messages. Do not set
// `apns-collapse-id` here: APNs merges notifications with a shared value.
function chatNotificationThreadIdentifier(data) {
  const senderId = stringifyData(data.senderId);
  const recipientId = stringifyData(data.recipientId);

  if (!senderId || !recipientId) {
    return null;
  }

  switch (data.type) {
    case "coach_note_received":
      return `chat-${senderId}-${recipientId}`;
    case "client_note_received":
      return `chat-${recipientId}-${senderId}`;
    default:
      return null;
  }
}

function buildPushContent(data, preferredLanguage) {
  const config = TYPE_CONFIG[data.type] || {};
  const localizedConfig = config[preferredLanguage] || config.ru || {};
  const senderName = typeof data.senderName === "string" ? data.senderName.trim() : "";

  return {
    title: localizedConfig.title || (preferredLanguage === "en" ? "New notification" : "Новое уведомление"),
    body: typeof localizedConfig.body === "function"
      ? localizedConfig.body(senderName)
      : (preferredLanguage === "en"
          ? "A new notification is available in the app."
          : "В приложении появилось новое уведомление.")
  };
}

function formatSenderBody(senderName, language, suffixRu, suffixEn) {
  const suffix = language === "en" ? suffixEn : suffixRu;
  if (senderName && senderName.length > 0) {
    return `${senderName} ${suffix}`;
  }
  return language === "en" ? `Someone ${suffixEn}` : `Пользователь ${suffixRu}`;
}

function normalizeLanguage(rawLanguage) {
  return rawLanguage === "en" ? "en" : "ru";
}

function sanitizeTokens(rawTokens) {
  if (!Array.isArray(rawTokens)) {
    return [];
  }

  return [...new Set(
    rawTokens
      .filter((token) => typeof token === "string")
      .map((token) => token.trim())
      .filter(Boolean)
  )];
}

function stringifyData(value) {
  if (value === undefined || value === null) {
    return "";
  }
  return String(value);
}

async function markPushRetryable(eventId, reason) {
  await db.collection("notification_events").doc(eventId).set(
    {
      pushStatus: "retryable_failed",
      pushFailureReason: reason
    },
    { merge: true }
  );
}

async function markPushPermanentlyFailed(eventId, reason) {
  await db.collection("notification_events").doc(eventId).set(
    {
      pushStatus: "permanent_failed",
      pushFailureReason: reason,
      pushLeaseExpiresAt: admin.firestore.FieldValue.delete()
    },
    { merge: true }
  );
}

function setJsonResponseHeaders(response) {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

async function verifyAuthorization(request) {
  const header = request.get("Authorization") || "";
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    const error = new Error("Missing Firebase ID token");
    error.status = 401;
    error.code = "unauthorized";
    throw error;
  }

  try {
    return await admin.auth().verifyIdToken(match[1]);
  } catch (verificationError) {
    const error = new Error("Invalid Firebase ID token");
    error.status = 401;
    error.code = "unauthorized";
    throw error;
  }
}

async function verifyActiveTrainer(uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  const user = snapshot.data() || {};
  if (user.role === "trainer" && user.isActive === true) {
    return;
  }

  const error = new Error("Trainer role is required");
  error.status = 403;
  error.code = "trainer_role_required";
  throw error;
}

async function generateWorkoutDraft(command, language) {
  const systemPrompt = `
You are a fitness-programming assistant for certified trainers. Convert the trainer's instruction into a conservative workout TEMPLATE DRAFT.
Return JSON only and respond in ${language}.

Return this exact object:
{
  "summary": "short description",
  "blocks": [
    {
      "title": "short block title",
      "type": "warmup|strength|main|circuit|stretching|cooldown",
      "mode": "rounds|amrap|tabata",
      "rounds": 1,
      "durationMinutes": 0,
      "workSeconds": 0,
      "restSeconds": 0,
      "restBetweenRoundsSeconds": 0,
      "exercises": [
        {
          "name": "exercise name",
          "systemImage": "valid SF Symbol name",
          "accentName": "blue|green|orange|purple|teal|red",
          "activityType": "strength|cardio|hiit|core|mobility",
          "metValue": 5,
          "note": "optional short coach note",
          "sets": [
            { "weight": 0, "reps": 10, "durationSeconds": 0, "metricType": "reps" }
          ]
        }
      ]
    }
  ]
}

Rules:
- Create only what the trainer asked for. Do not invent medical advice, contraindications, diagnoses, or client-specific limits.
- If a load is not specified, use weight 0. Never guess a client's working weight.
- "10x10" means 10 sets with 10 reps each, not a weight of 10 kg.
- Use metricType "duration" only for timed work; then durationSeconds must be 5 to 3600 and reps must be 0.
- Use metricType "reps" for normal exercises; reps must be 1 to 100 and durationSeconds must be 0.
- Keep the draft compact: at most 5 blocks, 20 exercises total, and 12 sets per exercise.
- Valid block type and activityType values must be used exactly as listed.
- For non-circuit blocks use mode "rounds", rounds 1, and all timing fields 0.
- Do not include markdown or any text outside JSON.
`;

  const rawDraft = await callOpenAIForWorkoutDraft([
    {
      role: "system",
      content: [{ type: "input_text", text: systemPrompt }]
    },
    {
      role: "user",
      content: [{ type: "input_text", text: `Trainer instruction: ${command}` }]
    }
  ]);

  return sanitizeWorkoutDraft(rawDraft);
}

async function callOpenAIForWorkoutDraft(input) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    const error = new Error("OpenAI API key is not configured");
    error.status = 500;
    error.code = "missing_openai_key";
    throw error;
  }

  const openAIResponse = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      input,
      text: { format: { type: "json_object" } }
    })
  });

  const responseText = await openAIResponse.text();
  if (!openAIResponse.ok) {
    const error = new Error("OpenAI request failed");
    error.status = openAIResponse.status >= 400 && openAIResponse.status < 500 ? 502 : 500;
    error.code = extractOpenAIErrorCode(responseText) || "openai_request_failed";
    throw error;
  }

  const outputText = extractOpenAIOutputText(responseText);
  if (!outputText) {
    const error = new Error("OpenAI response did not contain output text");
    error.status = 502;
    error.code = "invalid_openai_response";
    throw error;
  }

  try {
    return JSON.parse(outputText);
  } catch (_) {
    const error = new Error("OpenAI output was not valid JSON");
    error.status = 502;
    error.code = "invalid_workout_json";
    throw error;
  }
}

function sanitizeWorkoutDraft(rawDraft) {
  const allowedBlockTypes = new Set(["warmup", "strength", "main", "circuit", "stretching", "cooldown"]);
  const allowedModes = new Set(["rounds", "amrap", "tabata"]);
  const allowedActivityTypes = new Set(["strength", "cardio", "hiit", "core", "mobility"]);
  const allowedAccents = new Set(["blue", "green", "orange", "purple", "teal", "red"]);
  const rawBlocks = Array.isArray(rawDraft && rawDraft.blocks) ? rawDraft.blocks.slice(0, 5) : [];
  const blocks = [];
  let exerciseCount = 0;

  for (const rawBlock of rawBlocks) {
    const type = typeof rawBlock.type === "string" && allowedBlockTypes.has(rawBlock.type)
      ? rawBlock.type
      : "main";
    const isCircuit = type === "circuit";
    const rawExercises = Array.isArray(rawBlock.exercises) ? rawBlock.exercises : [];
    const exercises = [];

    for (const rawExercise of rawExercises) {
      if (exerciseCount >= 20 || !rawExercise || typeof rawExercise.name !== "string") {
        break;
      }
      const name = rawExercise.name.trim().slice(0, 120);
      if (!name) {
        continue;
      }
      const metricActivity = allowedActivityTypes.has(rawExercise.activityType)
        ? rawExercise.activityType
        : "strength";
      const rawSets = Array.isArray(rawExercise.sets) ? rawExercise.sets.slice(0, 12) : [];
      const sets = rawSets.map(sanitizeWorkoutSet).filter(Boolean);
      if (sets.length === 0) {
        sets.push({ weight: 0, reps: 10, durationSeconds: 0, metricType: "reps" });
      }
      exercises.push({
        name,
        systemImage: safeSFSymbol(rawExercise.systemImage),
        accentName: allowedAccents.has(rawExercise.accentName) ? rawExercise.accentName : "blue",
        activityType: metricActivity,
        metValue: clampNumber(rawExercise.metValue, 1, 20, 5),
        note: typeof rawExercise.note === "string" ? rawExercise.note.trim().slice(0, 500) : "",
        sets
      });
      exerciseCount += 1;
    }

    if (exercises.length === 0) {
      continue;
    }
    blocks.push({
      title: typeof rawBlock.title === "string" && rawBlock.title.trim()
        ? rawBlock.title.trim().slice(0, 120)
        : defaultBlockTitle(type),
      type,
      mode: isCircuit && allowedModes.has(rawBlock.mode) ? rawBlock.mode : "rounds",
      rounds: isCircuit ? Math.round(clampNumber(rawBlock.rounds, 1, 40, 1)) : 1,
      durationMinutes: isCircuit ? Math.round(clampNumber(rawBlock.durationMinutes, 0, 90, 0)) : 0,
      workSeconds: isCircuit ? Math.round(clampNumber(rawBlock.workSeconds, 0, 300, 0)) : 0,
      restSeconds: isCircuit ? Math.round(clampNumber(rawBlock.restSeconds, 0, 600, 0)) : 0,
      restBetweenRoundsSeconds: isCircuit ? Math.round(clampNumber(rawBlock.restBetweenRoundsSeconds, 0, 600, 0)) : 0,
      exercises
    });
  }

  if (blocks.length === 0) {
    const error = new Error("OpenAI output did not contain exercises");
    error.status = 502;
    error.code = "empty_workout_draft";
    throw error;
  }
  return {
    summary: typeof rawDraft.summary === "string" ? rawDraft.summary.trim().slice(0, 500) : "",
    blocks
  };
}

function sanitizeWorkoutSet(rawSet) {
  if (!rawSet || typeof rawSet !== "object") {
    return null;
  }
  const metricType = rawSet.metricType === "duration" ? "duration" : "reps";
  if (metricType === "duration") {
    return {
      weight: clampNumber(rawSet.weight, 0, 500, 0),
      reps: 0,
      durationSeconds: Math.round(clampNumber(rawSet.durationSeconds, 5, 3600, 30)),
      metricType
    };
  }
  return {
    weight: clampNumber(rawSet.weight, 0, 500, 0),
    reps: Math.round(clampNumber(rawSet.reps, 1, 100, 10)),
    durationSeconds: 0,
    metricType
  };
}

function clampNumber(value, minimum, maximum, fallback) {
  const number = typeof value === "number" && Number.isFinite(value) ? value : fallback;
  return Math.min(Math.max(number, minimum), maximum);
}

function safeSFSymbol(value) {
  return typeof value === "string" && /^[A-Za-z0-9.]+$/.test(value) && value.length <= 80
    ? value
    : "dumbbell.fill";
}

function defaultBlockTitle(type) {
  return {
    warmup: "Разминка",
    strength: "Силовой блок",
    main: "Основная часть",
    circuit: "Круговая часть",
    stretching: "Растяжка",
    cooldown: "Заминка"
  }[type] || "Основная часть";
}

function normalizeRecognitionLanguage(rawLanguage) {
  return rawLanguage === "en" ? "English" : "Russian";
}

async function recognizeImageMeal(imageBase64, language) {
  const systemPrompt = `
Return JSON only. Analyze a single meal photo and estimate the visible edible components.
Respond in ${language}.
Return an object with:
- dish_name: short meal name
- ingredients: array of 1 to 8 items
- notes: short uncertainty note
- is_beverage: boolean
- portion_size_guess: one of small, medium, large

Each ingredient must contain:
- name
- grams
- calories
- protein
- fat
- carbs
- confidence

Rules:
- exclude plate, tableware, background, packaging
- calories and macros must describe the estimated ingredient portion on the plate, not per 100 g
- grams must be a realistic number
- if the photo is a drink, set is_beverage to true
- choose portion_size_guess based on the visible serving size
- include sugar, syrup, sauce, oil, butter or milk when they are likely present
- if unsure, still make the best estimate and lower confidence
`;

  return callOpenAIForMeal([
    {
      role: "system",
      content: [
        {
          type: "input_text",
          text: systemPrompt
        }
      ]
    },
    {
      role: "user",
      content: [
        {
          type: "input_text",
          text: "Analyze this food photo and return JSON."
        },
        {
          type: "input_image",
          image_url: `data:image/jpeg;base64,${imageBase64}`,
          detail: "high"
        }
      ]
    }
  ]);
}

async function recognizeTextMeal(description, language) {
  const systemPrompt = `
Return JSON only. Analyze a meal description and estimate the full meal composition.
Respond in ${language}.
Return an object with:
- dish_name: short meal name
- ingredients: array of 1 to 10 items
- notes: short uncertainty note
- is_beverage: boolean
- portion_size_guess: one of small, medium, large

Each ingredient must contain:
- name
- grams
- calories
- protein
- fat
- carbs
- confidence

Rules:
- estimate the meal as eaten, not per 100 g
- if the user gives a weight, use it
- if the user gives pieces or common household portions, convert to realistic grams
- if the meal includes milk, sugar, sauce, butter or oil, include them when explicitly mentioned or strongly implied
- if unsure, still make the best estimate and lower confidence
`;

  return callOpenAIForMeal([
    {
      role: "system",
      content: [
        {
          type: "input_text",
          text: systemPrompt
        }
      ]
    },
    {
      role: "user",
      content: [
        {
          type: "input_text",
          text: `Meal description: ${description}\nReturn JSON only.`
        }
      ]
    }
  ]);
}

async function callOpenAIForMeal(input) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    const error = new Error("OpenAI API key is not configured");
    error.status = 500;
    error.code = "missing_openai_key";
    throw error;
  }

  const openAIResponse = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      input,
      text: {
        format: {
          type: "json_object"
        }
      }
    })
  });

  const responseText = await openAIResponse.text();
  if (!openAIResponse.ok) {
    const error = new Error("OpenAI request failed");
    error.status = openAIResponse.status >= 400 && openAIResponse.status < 500 ? 502 : 500;
    error.code = extractOpenAIErrorCode(responseText) || "openai_request_failed";
    throw error;
  }

  const outputText = extractOpenAIOutputText(responseText);
  if (!outputText) {
    const error = new Error("OpenAI response did not contain output text");
    error.status = 502;
    error.code = "invalid_openai_response";
    throw error;
  }

  let meal;
  try {
    meal = JSON.parse(outputText);
  } catch (parseError) {
    const error = new Error("OpenAI output was not valid JSON");
    error.status = 502;
    error.code = "invalid_meal_json";
    throw error;
  }

  if (!Array.isArray(meal.ingredients) || meal.ingredients.length === 0) {
    const error = new Error("OpenAI output did not contain ingredients");
    error.status = 502;
    error.code = "empty_ingredients";
    throw error;
  }

  return meal;
}

function extractOpenAIOutputText(responseText) {
  let jsonObject;
  try {
    jsonObject = JSON.parse(responseText);
  } catch (error) {
    return null;
  }

  if (typeof jsonObject.output_text === "string" && jsonObject.output_text.trim()) {
    return jsonObject.output_text;
  }

  if (Array.isArray(jsonObject.output)) {
    for (const output of jsonObject.output) {
      if (!Array.isArray(output.content)) {
        continue;
      }

      for (const content of output.content) {
        if (typeof content.text === "string" && content.text.trim()) {
          return content.text;
        }
      }
    }
  }

  return null;
}

function extractOpenAIErrorCode(responseText) {
  try {
    const jsonObject = JSON.parse(responseText);
    return jsonObject.error && typeof jsonObject.error.code === "string"
      ? jsonObject.error.code
      : null;
  } catch (error) {
    return null;
  }
}
