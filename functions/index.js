const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

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
