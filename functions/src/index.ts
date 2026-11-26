import {onRequest, Request} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  FirestoreEvent,
  QueryDocumentSnapshot,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {Response} from "express";

admin.initializeApp();

async function collectAllUserTokens(): Promise<Set<string>> {
  const tokenSet = new Set<string>();
  const usersSnapshot = await admin.firestore().collection("users").get();
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    extractTokens(data?.fcmTokens ?? data?.fcmToken).forEach((t) =>
      tokenSet.add(t),
    );
  }
  return tokenSet;
}

/**
 * Normalize different token shapes into a flat list of strings.
 * Accepts single strings, arrays, or maps keyed by token (value true/metadata).
 */
function extractTokens(raw: unknown): string[] {
  if (!raw) return [];

  if (Array.isArray(raw)) {
    return raw
      .filter((token): token is string => typeof token === "string")
      .map((token) => token.trim())
      .filter(Boolean);
  }

  if (typeof raw === "string") {
    return raw.trim() ? [raw.trim()] : [];
  }

  if (typeof raw === "object") {
    const tokens: string[] = [];
    for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
      if (typeof value === "string" && value.trim()) {
        tokens.push(value.trim());
      } else if (value === true && typeof key === "string" && key.trim()) {
        // Some legacy shapes store tokens as keys with boolean flags.
        tokens.push(key.trim());
      }
    }
    return tokens;
  }

  return [];
}

const DIVISION_LABELS: Record<string, string> = {
  all: "Semua Divisi",
  administrations: "Administrations",
  finance: "Finance",
  project_officer: "Project Officer",
  head_officer: "Head Officer",
  purchasing_logistik: "Purchasing & Logistik",
};

function normalizeDivision(raw: unknown): string {
  if (raw === null || raw === undefined) return "";
  if (Array.isArray(raw)) {
    for (const item of raw) {
      const normalized = normalizeDivision(item);
      if (normalized) return normalized;
    }
    return "";
  }
  const value = raw.toString().trim().toLowerCase();
  if (!value) return "";
  if (value === "all" || value.includes("semua") || value.includes("all")) {
    return "all";
  }
  if (
    value.includes("purchasing") ||
    value.includes("logistik") ||
    value.includes("logistic")
  ) {
    return "purchasing_logistik";
  }
  if (value.includes("admin")) return "administrations";
  if (value.includes("finance") || value.includes("finans")) return "finance";
  if (value.includes("project")) return "project_officer";
  if (value.includes("head")) return "head_officer";
  return "";
}

function sanitizeDivisionList(raw: unknown): string[] {
  const ids: string[] = [];
  const add = (value: string) => {
    if (value && !ids.includes(value)) ids.push(value);
  };

  if (Array.isArray(raw)) {
    for (const item of raw) {
      const normalized = normalizeDivision(item);
      if (normalized) add(normalized);
    }
  } else {
    const normalized = normalizeDivision(raw);
    if (normalized) add(normalized);
  }

  if (ids.length === 0) return ["all"];
  return ids;
}

function divisionsFromUserData(
  data: admin.firestore.DocumentData | undefined,
): Set<string> {
  const ids = new Set<string>();
  if (!data) return ids;

  for (const key of [
    "division",
    "divisi",
    "divisions",
    "department",
    "team",
    "role",
    "section",
    "unit",
    "position",
    "jabatan",
  ]) {
    const normalized = normalizeDivision((data as Record<string, unknown>)[key]);
    if (normalized) ids.add(normalized);
  }
  return ids;
}

function hasDivisionOverlap(
  userDivisions: Set<string>,
  targets: Set<string>,
): boolean {
  if (targets.size === 0 || userDivisions.size === 0) return false;
  for (const id of targets) {
    if (userDivisions.has(id)) return true;
  }
  return false;
}

function chunk<T>(arr: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    result.push(arr.slice(i, i + size));
  }
  return result;
}

function normalizeString(value: unknown): string {
  if (value === null || value === undefined) return "";
  return value.toString().trim();
}

async function tokensForUserIds(uids: string[]): Promise<Set<string>> {
  const tokens = new Set<string>();
  const usersRef = admin.firestore().collection("users");
  const snapshots = await Promise.all(
    uids.filter(Boolean).map((uid) => usersRef.doc(uid).get()),
  );
  snapshots.forEach((snap) => {
    const data = snap.data();
    extractTokens(data?.fcmTokens ?? data?.fcmToken).forEach((t) =>
      tokens.add(t),
    );
  });
  return tokens;
}

export const helloWorld = onRequest((request: Request, response: Response) => {
  response.send("Hello from Firebase!");
});

// Cloud Function to send push notification when a document is uploaded
export const onDocumentCreatedNotification = onDocumentCreated(
  "employee_documents/{documentId}",
  async (
    event: FirestoreEvent<
      QueryDocumentSnapshot | undefined,
      {documentId: string}
    >,
  ): Promise<void> => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const documentData = snapshot.data();
    const documentId = event.params.documentId;

    const documentDivisions = sanitizeDivisionList(documentData.divisions);
    const targetDivisionSet = new Set(
      documentDivisions.filter((id) => id && id !== "all"),
    );
    const hasDivisionTargets = targetDivisionSet.size > 0;

    // Skip if the document was created by the same user (they already know about it)
    const createdBy = documentData.createdBy;
    const uid = documentData.uid;

    if (createdBy === uid) {
      console.log("Document created by the owner, skipping notification");
      return;
    }

    // Get the user's FCM token(s)
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const userData = userDoc.data();

    const tokenSet = new Set<string>(
      extractTokens(userData?.fcmTokens ?? userData?.fcmToken),
    );

    const fallbackUid =
      typeof userData?.uid === "string" && userData.uid !== uid
        ? userData.uid
        : undefined;
    const email =
      typeof userData?.email === "string"
        ? userData.email.trim().toLowerCase()
        : undefined;

    // If tokens are missing on the main user doc, try alternative locations.
    if (tokenSet.size === 0 && fallbackUid) {
      const altDoc = await admin
        .firestore()
        .collection("users")
        .doc(fallbackUid)
        .get();
      const altData = altDoc.data();
      extractTokens(altData?.fcmTokens ?? altData?.fcmToken).forEach((t) =>
        tokenSet.add(t),
      );
    }

    if (tokenSet.size === 0 && email) {
      const altSnapshot = await admin
        .firestore()
        .collection("users")
        .where("email", "==", email)
        .limit(3)
        .get();
      for (const doc of altSnapshot.docs) {
        const altData = doc.data();
        extractTokens(altData?.fcmTokens ?? altData?.fcmToken).forEach((t) =>
          tokenSet.add(t),
        );
      }
    }

    // Add tokens for every user whose division matches the selected divisions.
    if (hasDivisionTargets) {
      const usersSnapshot = await admin.firestore().collection("users").get();
      for (const user of usersSnapshot.docs) {
        const data = user.data();
        const divisions = divisionsFromUserData(data);
        if (!hasDivisionOverlap(divisions, targetDivisionSet)) continue;
        extractTokens(data?.fcmTokens ?? data?.fcmToken).forEach((t) =>
          tokenSet.add(t),
        );
      }
    }

    const tokens = Array.from(tokenSet);

    if (tokens.length === 0) {
      console.log(
        "No FCM token found for user:",
        uid,
        "fallbackUid=",
        fallbackUid,
        "email=",
        email,
      );
      return;
    }

    // Prepare notification payload
    const title = documentData.title || "Dokumen baru";
    const fileName = documentData.originalFileName;
    const divisionLabelText = Array.from(targetDivisionSet)
      .map((id) => DIVISION_LABELS[id] ?? id)
      .join(", ");
    const body = hasDivisionTargets
      ? `Admin menambahkan dokumen "${title}"${divisionLabelText ? ` untuk divisi ${divisionLabelText}` : ""}.`
      : fileName
          ? `Admin menambahkan dokumen "${title}" (${fileName}) ke akun Anda.`
          : `Admin menambahkan dokumen "${title}" ke akun Anda.`;

    const messageBase = {
      notification: {
        title: "Dokumen baru ditambahkan",
        body: body,
      },
      data: {
        type: "document",
        documentId: documentId,
        title: title,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        divisions: JSON.stringify(documentDivisions),
      },
      android: {
        priority: "high" as const,
        notification: {
          channelId: "general_notifications",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      for (const batch of chunk(tokens, 450)) {
        const response = await admin.messaging().sendEachForMulticast({
          ...messageBase,
          tokens: batch,
        });
        console.log(
          `Sent document notification batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`,
        );
      }
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
);

export const onChatMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (
    event: FirestoreEvent<
      QueryDocumentSnapshot | undefined,
      {chatId: string; messageId: string}
    >,
  ): Promise<void> => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No message data for chat message event");
      return;
    }

    const message = snapshot.data() ?? {};
    const senderId = normalizeString(message.senderId);
    const chatId = event.params.chatId;

    if (!senderId) {
      console.log("Skip chat notification: missing senderId");
      return;
    }
    if (message.silent === true) {
      console.log("Skip chat notification: marked silent");
      return;
    }

    const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      console.log(`Chat ${chatId} not found; skip notification`);
      return;
    }

    const chatData = chatDoc.data() ?? {};
    const membersRaw = Array.isArray(chatData.members)
      ? (chatData.members as unknown[])
      : [];
    const members = membersRaw
      .map((val) => normalizeString(val))
      .filter((uid) => uid && uid !== senderId);

    if (members.length === 0) {
      console.log(`No recipients for chat ${chatId}`);
      return;
    }

    const tokenSet = await tokensForUserIds(members);
    if (tokenSet.size === 0) {
      console.log(`No tokens for chat ${chatId}`);
      return;
    }

    const isGroup =
      chatData.type === "group" ||
      chatData.isGroup === true ||
      membersRaw.length > 2;
    const groupName = normalizeString(
      chatData.groupName ?? chatData.name ?? chatData.title,
    );
    const memberInfo = (chatData.memberInfo ??
      {}) as Record<string, Record<string, unknown>>;
    const senderInfo = memberInfo[senderId] ?? memberInfo[senderId.toString()];
    const senderName = normalizeString(
      (senderInfo?.name as string | undefined) ??
        (senderInfo?.displayName as string | undefined) ??
        chatData.senderName ??
        chatData.displayName,
    );
    const title = isGroup
      ? groupName || "Pesan grup baru"
      : senderName || "Pesan baru";

    const type = normalizeString(message.type || "text").toLowerCase();
    let body = normalizeString(message.text ?? message.body);
    if (!body) {
      if (type === "image") {
        body = "Mengirim foto";
      } else if (type === "file") {
        const fileName = normalizeString(message.fileName);
        body = fileName ? `Mengirim file ${fileName}` : "Mengirim file";
      } else {
        body = "Pesan baru";
      }
    }

    const tokens = Array.from(tokenSet);
    const messageBase = {
      notification: {title, body},
      data: {
        type: "chat",
        chatId,
        title,
        body,
        senderId,
        senderName: senderName || undefined,
        isGroup: isGroup ? "true" : "false",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high" as const,
        notification: {
          channelId: isGroup ? "group_messages" : "direct_messages",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      for (const batch of chunk(tokens, 450)) {
        const response = await admin.messaging().sendEachForMulticast({
          ...messageBase,
          tokens: batch,
        });
        console.log(
          `Sent chat notification chatId=${chatId} batch=${batch.length} success=${response.successCount} failure=${response.failureCount}`,
        );
      }
    } catch (error) {
      console.error("Error sending chat notification:", error);
    }
  },
);

export const onAdminAttendanceOpened = onDocumentCreated(
  "admin_signals/{signalId}",
  async (
    event: FirestoreEvent<
      QueryDocumentSnapshot | undefined,
      {signalId: string}
    >,
  ): Promise<void> => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data for signal event");
      return;
    }
    const data = snapshot.data() ?? {};
    const type = (data.type ?? "").toString().toLowerCase();
    const isOpen = type === "attendance_open";
    const isClose = type === "attendance_close";
    if (!isOpen && !isClose) return;

    const adminEmail =
      typeof data.adminEmail === "string" ? data.adminEmail : undefined;
    const adminUid = typeof data.adminUid === "string" ? data.adminUid : null;

    const tokens = new Set<string>();
    const usersSnapshot = await admin.firestore().collection("users").get();
    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      extractTokens(userData?.fcmTokens ?? userData?.fcmToken).forEach((t) =>
        tokens.add(t),
      );
    }

    if (tokens.size === 0) {
      console.log("No tokens found for attendance signal");
      return;
    }

    const title = isOpen ? "Admin membuka absensi" : "Admin menutup absensi";
    const body = isOpen
      ? "Segera lakukan absen agar kehadiran Anda tercatat hari ini."
      : "Absen hari ini ditutup admin. Hubungi admin jika membutuhkan bantuan.";
    const messageBase = {
      notification: {
        title,
        body,
      },
      data: {
        type: "attendance",
        event: isOpen ? "open" : "close",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        adminUid: adminUid ?? "",
        adminEmail: adminEmail ?? "",
      },
      android: {
        priority: "high" as const,
        notification: {
          channelId: "attendance_notifications_v2",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      for (const batch of chunk(Array.from(tokens), 450)) {
        const response = await admin.messaging().sendEachForMulticast({
          ...messageBase,
          tokens: batch,
        });
        console.log(
          `Sent attendance signal batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`,
        );
      }
    } catch (error) {
      console.error("Error sending attendance signal:", error);
    }
  },
);

export const scheduleDailyAttendanceWindow = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "Asia/Makassar",
  },
  async () => {
    const nowMakassar = new Date(
      new Date().toLocaleString("en-US", {timeZone: "Asia/Makassar"}),
    );
    const year = nowMakassar.getFullYear();
    const month = nowMakassar.getMonth() + 1; // 1-indexed
    const day = nowMakassar.getDate();
    const weekday = nowMakassar.getDay(); // 0 = Sunday

    if (weekday === 0) {
      console.log("Skipping attendance window for Sunday");
      return;
    }

    const docId = `${year.toString().padStart(4, "0")}-${month
      .toString()
      .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;

    const holidayDoc = await admin
      .firestore()
      .collection("holidays")
      .doc(docId)
      .get();
    const isHoliday =
      holidayDoc.exists &&
      (holidayDoc.data()?.isHoliday !== false || holidayDoc.data()?.name);
    if (isHoliday) {
      console.log(`Skipping attendance window for holiday ${docId}`);
      return;
    }

    const openAt = new Date(`${docId}T08:30:00+08:00`);
    const closeAt = new Date(`${docId}T09:30:00+08:00`);

    await admin.firestore().collection("attendance_windows").doc(docId).set(
      {
        openAt: admin.firestore.Timestamp.fromDate(openAt),
        closeAt: admin.firestore.Timestamp.fromDate(closeAt),
        lateGraceMinutes: 30,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    console.log(
      `Attendance window set for ${docId} from 08:30 to 09:30 Asia/Makassar (WITA)`,
    );
  },
);

export const broadcastAttendanceOpen = onSchedule(
  {
    schedule: "30 8 * * *",
    timeZone: "Asia/Makassar",
  },
  async () => {
    const nowMakassar = new Date(
      new Date().toLocaleString("en-US", {timeZone: "Asia/Makassar"}),
    );
    const year = nowMakassar.getFullYear();
    const month = nowMakassar.getMonth() + 1;
    const day = nowMakassar.getDate();
    const weekday = nowMakassar.getDay(); // 0 = Sunday

    if (weekday === 0) {
      console.log("Skip open notification on Sunday");
      return;
    }

    const docId = `${year.toString().padStart(4, "0")}-${month
      .toString()
      .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
    const holidayDoc = await admin
      .firestore()
      .collection("holidays")
      .doc(docId)
      .get();
    const isHoliday =
      holidayDoc.exists &&
      (holidayDoc.data()?.isHoliday !== false || holidayDoc.data()?.name);
    if (isHoliday) {
      console.log(`Skip open notification for holiday ${docId}`);
      return;
    }

    const tokenSet = await collectAllUserTokens();

    if (tokenSet.size === 0) {
      console.log("No tokens to notify for attendance open");
      return;
    }

    const title = "Absensi sudah dibuka";
    const body = "Silakan lakukan absen sekarang. Tutup pukul 09:30 WITA.";
    const messageBase = {
      notification: {title, body},
      data: {
        type: "attendance",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high" as const,
        notification: {
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      for (const batch of chunk(Array.from(tokenSet), 450)) {
        const response = await admin.messaging().sendEachForMulticast({
          ...messageBase,
          tokens: batch,
        });
        console.log(
          `Sent attendance open batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`,
        );
      }
    } catch (error) {
      console.error("Error sending attendance open notification:", error);
    }
  },
);

export const broadcastAttendanceOpeningSoon = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Asia/Makassar",
  },
  async () => {
    const nowMakassar = new Date(
      new Date().toLocaleString("en-US", {timeZone: "Asia/Makassar"}),
    );
    const year = nowMakassar.getFullYear();
    const month = nowMakassar.getMonth() + 1;
    const day = nowMakassar.getDate();
    const weekday = nowMakassar.getDay(); // 0 = Sunday

    if (weekday === 0) {
      console.log("Skip opening-soon notification on Sunday");
      return;
    }

    const docId = `${year.toString().padStart(4, "0")}-${month
      .toString()
      .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
    const holidayDoc = await admin
      .firestore()
      .collection("holidays")
      .doc(docId)
      .get();
    const isHoliday =
      holidayDoc.exists &&
      (holidayDoc.data()?.isHoliday !== false || holidayDoc.data()?.name);
    if (isHoliday) {
      console.log(`Skip opening-soon notification for holiday ${docId}`);
      return;
    }

    const tokenSet = await collectAllUserTokens();
    if (tokenSet.size === 0) {
      console.log("No tokens to notify for opening-soon attendance");
      return;
    }

    const title = "Absensi dibuka 30 menit lagi";
    const body = "Absensi mulai pukul 08:30 WITA. Siapkan absen Anda.";
    const messageBase = {
      notification: {title, body},
      data: {
        type: "attendance",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high" as const,
        notification: {
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      for (const batch of chunk(Array.from(tokenSet), 450)) {
        const response = await admin.messaging().sendEachForMulticast({
          ...messageBase,
          tokens: batch,
        });
        console.log(
          `Sent opening-soon attendance batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`,
        );
      }
    } catch (error) {
      console.error("Error sending opening-soon attendance notification:", error);
    }
  },
);

export const broadcastAttendanceClosingSoon = onSchedule(
  {
    schedule: "20 9 * * *",
    timeZone: "Asia/Makassar",
  },
  async () => {
    const nowMakassar = new Date(
      new Date().toLocaleString("en-US", {timeZone: "Asia/Makassar"}),
    );
    const year = nowMakassar.getFullYear();
    const month = nowMakassar.getMonth() + 1;
    const day = nowMakassar.getDate();
    const weekday = nowMakassar.getDay(); // 0 = Sunday

    if (weekday === 0) {
      console.log("Skip closing-soon notification on Sunday");
      return;
    }

    const docId = `${year.toString().padStart(4, "0")}-${month
      .toString()
      .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
    const holidayDoc = await admin
      .firestore()
      .collection("holidays")
      .doc(docId)
      .get();
    const isHoliday =
      holidayDoc.exists &&
      (holidayDoc.data()?.isHoliday !== false || holidayDoc.data()?.name);
    if (isHoliday) {
      console.log(`Skip closing-soon notification for holiday ${docId}`);
      return;
    }

    const tokenSet = await collectAllUserTokens();
    if (tokenSet.size === 0) {
      console.log("No tokens to notify for closing-soon attendance");
      return;
    }

    const title = "Absensi ditutup 10 menit lagi";
    const body = "Absensi tutup pukul 09:30 WITA. Segera lakukan absen.";
    const messageBase = {
      notification: {title, body},
      data: {
        type: "attendance",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high" as const,
        notification: {
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      for (const batch of chunk(Array.from(tokenSet), 450)) {
        const response = await admin.messaging().sendEachForMulticast({
          ...messageBase,
          tokens: batch,
        });
        console.log(
          `Sent closing-soon attendance batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`,
        );
      }
    } catch (error) {
      console.error("Error sending closing-soon attendance notification:", error);
    }
  },
);
