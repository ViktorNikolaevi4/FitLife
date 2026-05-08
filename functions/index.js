const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
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

exports.sendPushForNotificationEvent = onDocumentCreated(
  {
    document: "notification_events/{eventId}",
    region: "europe-west1"
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("Notification event snapshot is missing");
      return;
    }

    const eventId = snapshot.id;
    const data = snapshot.data();

    if (!data) {
      logger.warn("Notification event data is empty", { eventId });
      return;
    }

    const recipientId = data.recipientId;
    if (!recipientId) {
      logger.warn("recipientId is missing", { eventId });
      await markPushFailed(eventId, "missing_recipient");
      return;
    }

    const userSnapshot = await db.collection("users").doc(recipientId).get();
    const userData = userSnapshot.data() || {};
    const fcmTokens = sanitizeTokens(userData.fcmTokens);

    if (fcmTokens.length === 0) {
      logger.info("No FCM tokens for recipient", { eventId, recipientId });
      await markPushFailed(eventId, "no_tokens");
      return;
    }

    const preferredLanguage = normalizeLanguage(userData.preferredLanguage);
    const pushContent = buildPushContent(data, preferredLanguage);
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
        payload: {
          aps: {
            sound: "default",
            badge: 1
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

    await markPushFailed(eventId, "send_failed");
  }
);

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

async function markPushFailed(eventId, reason) {
  await db.collection("notification_events").doc(eventId).set(
    {
      pushStatus: "failed",
      pushFailureReason: reason
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
