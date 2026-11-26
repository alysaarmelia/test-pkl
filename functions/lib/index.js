"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.broadcastAttendanceClosingSoon = exports.broadcastAttendanceOpeningSoon = exports.broadcastAttendanceOpen = exports.scheduleDailyAttendanceWindow = exports.onAdminAttendanceOpened = exports.onDocumentCreatedNotification = exports.helloWorld = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
async function collectAllUserTokens() {
    var _a;
    const tokenSet = new Set();
    const usersSnapshot = await admin.firestore().collection("users").get();
    for (const doc of usersSnapshot.docs) {
        const data = doc.data();
        extractTokens((_a = data === null || data === void 0 ? void 0 : data.fcmTokens) !== null && _a !== void 0 ? _a : data === null || data === void 0 ? void 0 : data.fcmToken).forEach((t) => tokenSet.add(t));
    }
    return tokenSet;
}
/**
 * Normalize different token shapes into a flat list of strings.
 * Accepts single strings, arrays, or maps keyed by token (value true/metadata).
 */
function extractTokens(raw) {
    if (!raw)
        return [];
    if (Array.isArray(raw)) {
        return raw
            .filter((token) => typeof token === "string")
            .map((token) => token.trim())
            .filter(Boolean);
    }
    if (typeof raw === "string") {
        return raw.trim() ? [raw.trim()] : [];
    }
    if (typeof raw === "object") {
        const tokens = [];
        for (const [key, value] of Object.entries(raw)) {
            if (typeof value === "string" && value.trim()) {
                tokens.push(value.trim());
            }
            else if (value === true && typeof key === "string" && key.trim()) {
                // Some legacy shapes store tokens as keys with boolean flags.
                tokens.push(key.trim());
            }
        }
        return tokens;
    }
    return [];
}
const DIVISION_LABELS = {
    all: "Semua Divisi",
    administrations: "Administrations",
    finance: "Finance",
    project_officer: "Project Officer",
    head_officer: "Head Officer",
    purchasing_logistik: "Purchasing & Logistik",
};
function normalizeDivision(raw) {
    if (raw === null || raw === undefined)
        return "";
    if (Array.isArray(raw)) {
        for (const item of raw) {
            const normalized = normalizeDivision(item);
            if (normalized)
                return normalized;
        }
        return "";
    }
    const value = raw.toString().trim().toLowerCase();
    if (!value)
        return "";
    if (value === "all" || value.includes("semua") || value.includes("all")) {
        return "all";
    }
    if (value.includes("purchasing") ||
        value.includes("logistik") ||
        value.includes("logistic")) {
        return "purchasing_logistik";
    }
    if (value.includes("admin"))
        return "administrations";
    if (value.includes("finance") || value.includes("finans"))
        return "finance";
    if (value.includes("project"))
        return "project_officer";
    if (value.includes("head"))
        return "head_officer";
    return "";
}
function sanitizeDivisionList(raw) {
    const ids = [];
    const add = (value) => {
        if (value && !ids.includes(value))
            ids.push(value);
    };
    if (Array.isArray(raw)) {
        for (const item of raw) {
            const normalized = normalizeDivision(item);
            if (normalized)
                add(normalized);
        }
    }
    else {
        const normalized = normalizeDivision(raw);
        if (normalized)
            add(normalized);
    }
    if (ids.length === 0)
        return ["all"];
    return ids;
}
function divisionsFromUserData(data) {
    const ids = new Set();
    if (!data)
        return ids;
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
        const normalized = normalizeDivision(data[key]);
        if (normalized)
            ids.add(normalized);
    }
    return ids;
}
function hasDivisionOverlap(userDivisions, targets) {
    if (targets.size === 0 || userDivisions.size === 0)
        return false;
    for (const id of targets) {
        if (userDivisions.has(id))
            return true;
    }
    return false;
}
function chunk(arr, size) {
    const result = [];
    for (let i = 0; i < arr.length; i += size) {
        result.push(arr.slice(i, i + size));
    }
    return result;
}
exports.helloWorld = (0, https_1.onRequest)((request, response) => {
    response.send("Hello from Firebase!");
});
// Cloud Function to send push notification when a document is uploaded
exports.onDocumentCreatedNotification = (0, firestore_1.onDocumentCreated)("employee_documents/{documentId}", async (event) => {
    var _a, _b, _c, _d;
    const snapshot = event.data;
    if (!snapshot) {
        console.log("No data associated with the event");
        return;
    }
    const documentData = snapshot.data();
    const documentId = event.params.documentId;
    const documentDivisions = sanitizeDivisionList(documentData.divisions);
    const targetDivisionSet = new Set(documentDivisions.filter((id) => id && id !== "all"));
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
    const tokenSet = new Set(extractTokens((_a = userData === null || userData === void 0 ? void 0 : userData.fcmTokens) !== null && _a !== void 0 ? _a : userData === null || userData === void 0 ? void 0 : userData.fcmToken));
    const fallbackUid = typeof (userData === null || userData === void 0 ? void 0 : userData.uid) === "string" && userData.uid !== uid
        ? userData.uid
        : undefined;
    const email = typeof (userData === null || userData === void 0 ? void 0 : userData.email) === "string"
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
        extractTokens((_b = altData === null || altData === void 0 ? void 0 : altData.fcmTokens) !== null && _b !== void 0 ? _b : altData === null || altData === void 0 ? void 0 : altData.fcmToken).forEach((t) => tokenSet.add(t));
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
            extractTokens((_c = altData === null || altData === void 0 ? void 0 : altData.fcmTokens) !== null && _c !== void 0 ? _c : altData === null || altData === void 0 ? void 0 : altData.fcmToken).forEach((t) => tokenSet.add(t));
        }
    }
    // Add tokens for every user whose division matches the selected divisions.
    if (hasDivisionTargets) {
        const usersSnapshot = await admin.firestore().collection("users").get();
        for (const user of usersSnapshot.docs) {
            const data = user.data();
            const divisions = divisionsFromUserData(data);
            if (!hasDivisionOverlap(divisions, targetDivisionSet))
                continue;
            extractTokens((_d = data === null || data === void 0 ? void 0 : data.fcmTokens) !== null && _d !== void 0 ? _d : data === null || data === void 0 ? void 0 : data.fcmToken).forEach((t) => tokenSet.add(t));
        }
    }
    const tokens = Array.from(tokenSet);
    if (tokens.length === 0) {
        console.log("No FCM token found for user:", uid, "fallbackUid=", fallbackUid, "email=", email);
        return;
    }
    // Prepare notification payload
    const title = documentData.title || "Dokumen baru";
    const fileName = documentData.originalFileName;
    const divisionLabelText = Array.from(targetDivisionSet)
        .map((id) => { var _a; return (_a = DIVISION_LABELS[id]) !== null && _a !== void 0 ? _a : id; })
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
            priority: "high",
            notification: {
                channelId: "general_notifications",
                priority: "high",
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
            console.log(`Sent document notification batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`);
        }
    }
    catch (error) {
        console.error("Error sending notification:", error);
    }
});
exports.onAdminAttendanceOpened = (0, firestore_1.onDocumentCreated)("admin_signals/{signalId}", async (event) => {
    var _a, _b, _c;
    const snapshot = event.data;
    if (!snapshot) {
        console.log("No data for signal event");
        return;
    }
    const data = (_a = snapshot.data()) !== null && _a !== void 0 ? _a : {};
    const type = ((_b = data.type) !== null && _b !== void 0 ? _b : "").toString().toLowerCase();
    const isOpen = type === "attendance_open";
    const isClose = type === "attendance_close";
    if (!isOpen && !isClose)
        return;
    const adminEmail = typeof data.adminEmail === "string" ? data.adminEmail : undefined;
    const adminUid = typeof data.adminUid === "string" ? data.adminUid : null;
    const tokens = new Set();
    const usersSnapshot = await admin.firestore().collection("users").get();
    for (const doc of usersSnapshot.docs) {
        const userData = doc.data();
        extractTokens((_c = userData === null || userData === void 0 ? void 0 : userData.fcmTokens) !== null && _c !== void 0 ? _c : userData === null || userData === void 0 ? void 0 : userData.fcmToken).forEach((t) => tokens.add(t));
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
            adminUid: adminUid !== null && adminUid !== void 0 ? adminUid : "",
            adminEmail: adminEmail !== null && adminEmail !== void 0 ? adminEmail : "",
        },
        android: {
            priority: "high",
            notification: {
                channelId: "attendance_notifications_v2",
                priority: "high",
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
            console.log(`Sent attendance signal batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`);
        }
    }
    catch (error) {
        console.error("Error sending attendance signal:", error);
    }
});
exports.scheduleDailyAttendanceWindow = (0, scheduler_1.onSchedule)({
    schedule: "0 6 * * *",
    timeZone: "Asia/Makassar",
}, async () => {
    var _a, _b;
    const nowMakassar = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Makassar" }));
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
    const isHoliday = holidayDoc.exists &&
        (((_a = holidayDoc.data()) === null || _a === void 0 ? void 0 : _a.isHoliday) !== false || ((_b = holidayDoc.data()) === null || _b === void 0 ? void 0 : _b.name));
    if (isHoliday) {
        console.log(`Skipping attendance window for holiday ${docId}`);
        return;
    }
    const openAt = new Date(`${docId}T08:30:00+08:00`);
    const closeAt = new Date(`${docId}T09:30:00+08:00`);
    await admin.firestore().collection("attendance_windows").doc(docId).set({
        openAt: admin.firestore.Timestamp.fromDate(openAt),
        closeAt: admin.firestore.Timestamp.fromDate(closeAt),
        lateGraceMinutes: 30,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`Attendance window set for ${docId} from 08:30 to 09:30 Asia/Makassar (WITA)`);
});
exports.broadcastAttendanceOpen = (0, scheduler_1.onSchedule)({
    schedule: "30 8 * * *",
    timeZone: "Asia/Makassar",
}, async () => {
    var _a, _b;
    const nowMakassar = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Makassar" }));
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
    const isHoliday = holidayDoc.exists &&
        (((_a = holidayDoc.data()) === null || _a === void 0 ? void 0 : _a.isHoliday) !== false || ((_b = holidayDoc.data()) === null || _b === void 0 ? void 0 : _b.name));
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
        notification: { title, body },
        data: {
            type: "attendance",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            notification: {
                priority: "high",
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
            console.log(`Sent attendance open batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`);
        }
    }
    catch (error) {
        console.error("Error sending attendance open notification:", error);
    }
});
exports.broadcastAttendanceOpeningSoon = (0, scheduler_1.onSchedule)({
    schedule: "0 8 * * *",
    timeZone: "Asia/Makassar",
}, async () => {
    var _a, _b;
    const nowMakassar = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Makassar" }));
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
    const isHoliday = holidayDoc.exists &&
        (((_a = holidayDoc.data()) === null || _a === void 0 ? void 0 : _a.isHoliday) !== false || ((_b = holidayDoc.data()) === null || _b === void 0 ? void 0 : _b.name));
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
        notification: { title, body },
        data: {
            type: "attendance",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            notification: {
                priority: "high",
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
            console.log(`Sent opening-soon attendance batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`);
        }
    }
    catch (error) {
        console.error("Error sending opening-soon attendance notification:", error);
    }
});
exports.broadcastAttendanceClosingSoon = (0, scheduler_1.onSchedule)({
    schedule: "20 9 * * *",
    timeZone: "Asia/Makassar",
}, async () => {
    var _a, _b;
    const nowMakassar = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Makassar" }));
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
    const isHoliday = holidayDoc.exists &&
        (((_a = holidayDoc.data()) === null || _a === void 0 ? void 0 : _a.isHoliday) !== false || ((_b = holidayDoc.data()) === null || _b === void 0 ? void 0 : _b.name));
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
        notification: { title, body },
        data: {
            type: "attendance",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            notification: {
                priority: "high",
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
            console.log(`Sent closing-soon attendance batch size=${batch.length} success=${response.successCount} failure=${response.failureCount}`);
        }
    }
    catch (error) {
        console.error("Error sending closing-soon attendance notification:", error);
    }
});
//# sourceMappingURL=index.js.map