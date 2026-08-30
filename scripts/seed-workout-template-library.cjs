#!/usr/bin/env node

const { execFileSync } = require("node:child_process");
const path = require("node:path");

const DEFAULT_PROJECT_ID = "fitnessapp-fe94a";
const APPLY_FLAG = "--apply";

const templates = [
  {
    id: "warmup-1",
    parent: {
      title: "Разминка 1",
      notes: "Приседания и отжимания — по 10 повторений.",
      category: "warmup",
      difficulty: "Начальный",
      durationMinutes: 3,
      exerciseCount: 2,
      sortOrder: 100,
      isActive: true,
    },
    blocks: [
      {
        id: "warmup",
        data: {
          title: "Разминка",
          typeRawValue: "warmup",
          modeRawValue: "rounds",
          presetRawValue: "warmup",
          orderIndex: 0,
          rounds: 1,
          durationMinutes: 3,
          workSeconds: 0,
          restSeconds: 0,
          restBetweenRoundsSeconds: 0,
          groups: [],
        },
      },
    ],
    exercises: [
      {
        id: "squats",
        data: {
          blockId: "warmup",
          name: "Приседания",
          systemImage: "Приседания",
          accentName: "orange",
          activityTypeRaw: "strength",
          metValue: 5.0,
          orderIndex: 0,
          note: "",
          sets: [
            { weight: 0, reps: 10, durationSeconds: 30, metricType: "reps" },
          ],
        },
      },
      {
        id: "push-ups",
        data: {
          blockId: "warmup",
          name: "Отжимания от пола",
          systemImage: "Отжимания от пола",
          accentName: "blue",
          activityTypeRaw: "strength",
          metValue: 3.8,
          orderIndex: 1,
          note: "",
          sets: [
            { weight: 0, reps: 10, durationSeconds: 30, metricType: "reps" },
          ],
        },
      },
    ],
  },
];

function argumentValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };

  switch (typeof value) {
    case "string":
      return { stringValue: value };
    case "boolean":
      return { booleanValue: value };
    case "number":
      return Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
    case "object":
      return {
        mapValue: {
          fields: Object.fromEntries(
            Object.entries(value).map(([key, nestedValue]) => [
              key,
              firestoreValue(nestedValue),
            ]),
          ),
        },
      };
    default:
      throw new Error(`Unsupported Firestore value: ${typeof value}`);
  }
}

function documentWrite(name, data) {
  return {
    update: {
      name,
      fields: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
      ),
    },
  };
}

function buildWrites(projectId) {
  const root = `projects/${projectId}/databases/(default)/documents`;
  const now = new Date();

  return templates.flatMap((template) => {
    const templatePath = `${root}/workout_template_library/${template.id}`;
    return [
      documentWrite(templatePath, {
        ...template.parent,
        updatedAt: now,
      }),
      ...template.blocks.map((block) =>
        documentWrite(`${templatePath}/blocks/${block.id}`, block.data),
      ),
      ...template.exercises.map((exercise) =>
        documentWrite(`${templatePath}/exercises/${exercise.id}`, exercise.data),
      ),
    ];
  });
}

async function firebaseAccessToken() {
  if (process.env.FIREBASE_ACCESS_TOKEN) return process.env.FIREBASE_ACCESS_TOKEN;

  const globalModules = execFileSync("npm", ["root", "-g"], {
    encoding: "utf8",
  }).trim();
  const auth = require(path.join(globalModules, "firebase-tools/lib/auth"));
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI login not found. Run `firebase login` first.");
  }

  const tokens = await auth.getAccessToken(account.tokens.refresh_token, [
    "https://www.googleapis.com/auth/cloud-platform",
  ]);
  return tokens.access_token;
}

async function main() {
  const projectId = argumentValue("--project") || DEFAULT_PROJECT_ID;
  const writes = buildWrites(projectId);

  if (!process.argv.includes(APPLY_FLAG)) {
    console.log(`Dry run: ${templates.length} template(s), ${writes.length} document(s).`);
    console.log(`Run with ${APPLY_FLAG} to publish them to ${projectId}.`);
    return;
  }

  const accessToken = await firebaseAccessToken();
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ writes }),
    },
  );

  if (!response.ok) {
    throw new Error(`Firestore commit failed (${response.status}): ${await response.text()}`);
  }

  console.log(`Published ${templates.length} template(s) to ${projectId}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
