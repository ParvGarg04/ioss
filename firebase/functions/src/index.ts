import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

admin.initializeApp();
const db = admin.firestore();

// ─── Gmail transporter ───────────────────────────────────────────────────────
// These come from Firebase environment config (set once, see README)
function getTransporter() {
  
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_PASS,
    },
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Fetch all member emails, optionally filtered to specific user IDs */
async function getMemberEmails(targetUserIds?: string[]): Promise<{ name: string; email: string }[]> {
  let query: admin.firestore.Query = db.collection("users").where("role", "==", "member");
  const snap = await query.get();

  const members: { name: string; email: string }[] = [];
  snap.forEach((doc) => {
    const data = doc.data();
    if (!data.email) return;
    if (targetUserIds && targetUserIds.length > 0 && !targetUserIds.includes(doc.id)) return;
    members.push({ name: data.name ?? "Member", email: data.email });
  });
  return members;
}

/** Branded HTML email wrapper */
function htmlWrap(title: string, body: string, color = "#e879a0"): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
</head>
<body style="margin:0;padding:0;background:#fdf6fb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#fdf6fb;padding:32px 0;">
    <tr><td align="center">
      <table width="520" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(232,121,160,0.12);">
        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,${color},#c084fc);padding:28px 32px;text-align:center;">
            <div style="font-size:28px;margin-bottom:6px;">✨</div>
            <div style="color:#fff;font-size:22px;font-weight:700;letter-spacing:-0.3px;">DailyFlow</div>
            <div style="color:rgba(255,255,255,0.82);font-size:13px;margin-top:4px;">Your daily wellness companion</div>
          </td>
        </tr>
        <!-- Body -->
        <tr>
          <td style="padding:32px;">
            <h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#1a1a2e;">${title}</h2>
            ${body}
          </td>
        </tr>
        <!-- Footer -->
        <tr>
          <td style="background:#fdf6fb;padding:20px 32px;text-align:center;border-top:1px solid #f0e6f0;">
            <p style="margin:0;font-size:12px;color:#9b8ea8;">
              You're receiving this because you're a DailyFlow member.<br/>
              Open the app to take action.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ─── 1. EMERGENCY ALERT ──────────────────────────────────────────────────────

export const onEmergencyAlert = functions.firestore
  .document("emergencyAlerts/{alertId}")
  .onCreate(async (snap) => {
    const alert = snap.data();
    if (!alert || !alert.isActive) return;

    const targetUserIds: string[] | undefined = alert.targetUserIds?.length
      ? alert.targetUserIds
      : undefined;

    const members = await getMemberEmails(targetUserIds);
    if (members.length === 0) return;

    const transporter = getTransporter();
    

    const body = `
      <div style="background:#fff1f2;border-left:4px solid #dc2626;border-radius:8px;padding:16px 20px;margin-bottom:20px;">
        <p style="margin:0;font-size:15px;color:#1a1a2e;line-height:1.6;">${alert.message}</p>
      </div>
      <p style="color:#6b7280;font-size:13px;margin:0;">This is an urgent message from your admin. Please open the DailyFlow app immediately.</p>`;

    const sends = members.map(({ name, email }) =>
      transporter.sendMail({
        from: `"DailyFlow 🚨" <${process.env.GMAIL_USER}>`,
        to: email,
        subject: `🚨 Emergency: ${alert.title}`,
        html: htmlWrap(`🚨 ${alert.title}`, body, "#dc2626"),
      }).catch((err: Error) => console.error(`Failed to email ${email}:`, err))
    );

    await Promise.all(sends);
    console.log(`Emergency alert emailed to ${members.length} members`);
  });

// ─── 2. TASK REMINDER ────────────────────────────────────────────────────────
// Runs every hour, finds tasks due in the next 60 min and emails the user

export const taskReminderEmail = functions.pubsub
  .schedule("every 60 minutes")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const inOneHour = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 60 * 60 * 1000
    );

    // Get all active tasks with a due time in the next hour
    const tasksSnap = await db.collection("tasks")
      .where("isActive", "==", true)
      .where("dueTime", ">=", now)
      .where("dueTime", "<=", inOneHour)
      .get();

    if (tasksSnap.empty) return;

    const transporter = getTransporter();
    

    // Group tasks by userId
    const tasksByUser: Record<string, admin.firestore.DocumentData[]> = {};
    tasksSnap.forEach((doc) => {
      const t = doc.data();
      if (!t.userId) return;
      if (!tasksByUser[t.userId]) tasksByUser[t.userId] = [];
      tasksByUser[t.userId].push(t);
    });

    const sends: Promise<unknown>[] = [];

    for (const [userId, tasks] of Object.entries(tasksByUser)) {
      // Check user hasn't already submitted today
      const userDoc = await db.collection("users").doc(userId).get();
      const userData = userDoc.data();
      if (!userData?.email) continue;

      const taskRows = tasks.map((t) => `
        <tr>
          <td style="padding:10px 0;border-bottom:1px solid #f0e6f0;">
            <div style="font-weight:600;color:#1a1a2e;font-size:14px;">${t.title}</div>
            ${t.description ? `<div style="color:#9b8ea8;font-size:12px;margin-top:2px;">${t.description}</div>` : ""}
            ${t.dueTime ? `<div style="color:#e879a0;font-size:12px;margin-top:4px;">⏰ Due: ${new Date(t.dueTime.toMillis()).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })}</div>` : ""}
          </td>
        </tr>`).join("");

      const body = `
        <p style="color:#6b7280;font-size:14px;margin:0 0 16px;">
          Hi ${userData.name ?? "Member"}, you have ${tasks.length} task${tasks.length > 1 ? "s" : ""} due soon. Don't forget to complete and submit!
        </p>
        <table width="100%" cellpadding="0" cellspacing="0">${taskRows}</table>
        <div style="margin-top:20px;padding:14px 20px;background:#fdf6fb;border-radius:10px;text-align:center;">
          <p style="margin:0;color:#9b8ea8;font-size:13px;">Open the DailyFlow app to mark tasks complete ✅</p>
        </div>`;

      sends.push(
        transporter.sendMail({
          from: `"DailyFlow ✅" <${process.env.GMAIL_USER}>`,
          to: userData.email,
          subject: `⏰ ${tasks.length} Task${tasks.length > 1 ? "s" : ""} Due Soon — DailyFlow`,
          html: htmlWrap("Task Reminder", body),
        }).catch((err: Error) => console.error(`Task email failed for ${userId}:`, err))
      );
    }

    await Promise.all(sends);
    console.log(`Task reminders sent for ${Object.keys(tasksByUser).length} users`);
  });

// ─── 3. WATER REMINDER ───────────────────────────────────────────────────────
// Runs every 2 hours between 10am–10pm IST, emails users who haven't logged water recently

export const waterReminderEmail = functions.pubsub
  .schedule("0 10,12,14,16,18,20 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = new Date();
    const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);

    // Get all members
    const usersSnap = await db.collection("users")
      .where("role", "==", "member")
      .get();

    if (usersSnap.empty) return;

    const transporter = getTransporter();
    
    const sends: Promise<unknown>[] = [];

    for (const userDoc of usersSnap.docs) {
      const userData = userDoc.data();
      if (!userData.email) continue;
      if (userData.isNotificationsOn === false) continue;

      // Check if they logged water in the last 2 hours
      const recentLog = await db.collection("waterLogs")
        .where("userId", "==", userDoc.id)
        .where("uploadedAt", ">=", admin.firestore.Timestamp.fromDate(twoHoursAgo))
        .limit(1)
        .get();

      if (!recentLog.empty) continue; // already logged, skip

      // Count today's logs
      const todayLogs = await db.collection("waterLogs")
        .where("userId", "==", userDoc.id)
        .where("uploadedAt", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
        .get();

      const count = todayLogs.size;
      const remaining = Math.max(0, 12 - count);

      const body = `
        <p style="color:#6b7280;font-size:14px;margin:0 0 16px;">
          Hi ${userData.name ?? "Member"}, time for a hydration check! 💧
        </p>
        <div style="background:#eff6ff;border-radius:12px;padding:20px;text-align:center;margin-bottom:20px;">
          <div style="font-size:36px;margin-bottom:8px;">💧</div>
          <div style="font-size:28px;font-weight:700;color:#1a1a2e;">${count} / 12</div>
          <div style="color:#9b8ea8;font-size:13px;margin-top:4px;">logs today · ${remaining} remaining</div>
        </div>
        <p style="color:#6b7280;font-size:13px;text-align:center;margin:0;">
          ${count === 0 ? "You haven't logged any water today — start now! 🚀" : `Great progress! Keep going — ${remaining} more to hit your daily goal.`}
        </p>`;

      sends.push(
        transporter.sendMail({
          from: `"DailyFlow 💧" <${process.env.GMAIL_USER}>`,
          to: userData.email,
          subject: `💧 Hydration Reminder — ${count}/12 logged today`,
          html: htmlWrap("Hydration Reminder", body, "#3b82f6"),
        }).catch((err: Error) => console.error(`Water email failed for ${userDoc.id}:`, err))
      );
    }

    await Promise.all(sends);
    console.log(`Water reminders processed for ${usersSnap.size} users`);
  });

// ─── 4. TASK VERIFICATION RESULT ─────────────────────────────────────────────
// Emails user when admin verifies or rejects their task submission

export const onTaskVerified = functions.firestore
  .document("taskSubmissions/{submissionId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only fire when verification status changes
    if (before.verificationStatus === after.verificationStatus) return;
    if (after.verificationStatus === "pending_review") return;

    const userDoc = await db.collection("users").doc(after.userId).get();
    const userData = userDoc.data();
    if (!userData?.email) return;

    const isVerified = after.verificationStatus === "verified";
    
    const transporter = getTransporter();

    const body = `
      <p style="color:#6b7280;font-size:14px;margin:0 0 16px;">
        Hi ${userData.name ?? "Member"}, your task submission has been reviewed.
      </p>
      <div style="background:${isVerified ? "#f0fdf4" : "#fff1f2"};border-left:4px solid ${isVerified ? "#22c55e" : "#dc2626"};border-radius:8px;padding:16px 20px;margin-bottom:16px;">
        <div style="font-weight:700;color:#1a1a2e;font-size:15px;margin-bottom:4px;">${after.taskTitle ?? "Task"}</div>
        <div style="font-size:13px;color:${isVerified ? "#16a34a" : "#dc2626"};font-weight:600;">
          ${isVerified ? "✅ Verified — points awarded!" : "❌ Rejected"}
        </div>
        ${after.adminComment ? `<div style="margin-top:8px;font-size:13px;color:#6b7280;">Admin note: ${after.adminComment}</div>` : ""}
      </div>
      ${isVerified ? `<p style="color:#6b7280;font-size:13px;margin:0;">Points have been added to your balance. Keep it up! 🌟</p>` : `<p style="color:#6b7280;font-size:13px;margin:0;">Please re-submit with the correct proof. You can do it! 💪</p>`}`;

    await transporter.sendMail({
      from: `"DailyFlow ✨" <${process.env.GMAIL_USER}>`,
      to: userData.email,
      subject: isVerified
        ? `✅ Task Verified — ${after.taskTitle ?? "Task"}`
        : `❌ Task Rejected — ${after.taskTitle ?? "Task"}`,
      html: htmlWrap(isVerified ? "Task Verified! 🎉" : "Task Needs Resubmission", body, isVerified ? "#22c55e" : "#dc2626"),
    });
  });

// ─── 5. WATER LOG VERIFICATION RESULT ────────────────────────────────────────

export const onWaterLogVerified = functions.firestore
  .document("waterLogs/{logId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;
    if (after.status === "pending_review") return;

    const userDoc = await db.collection("users").doc(after.userId).get();
    const userData = userDoc.data();
    if (!userData?.email) return;

    const isVerified = after.status === "verified";
    
    const transporter = getTransporter();

    const body = `
      <p style="color:#6b7280;font-size:14px;margin:0 0 16px;">
        Hi ${userData.name ?? "Member"}, your hydration log has been reviewed.
      </p>
      <div style="background:${isVerified ? "#eff6ff" : "#fff1f2"};border-left:4px solid ${isVerified ? "#3b82f6" : "#dc2626"};border-radius:8px;padding:16px 20px;margin-bottom:16px;">
        <div style="font-size:13px;color:${isVerified ? "#2563eb" : "#dc2626"};font-weight:600;">
          ${isVerified ? "💧 Hydration log verified — points awarded!" : "❌ Log rejected"}
        </div>
        ${after.adminComment ? `<div style="margin-top:8px;font-size:13px;color:#6b7280;">Admin note: ${after.adminComment}</div>` : ""}
      </div>`;

    await transporter.sendMail({
      from: `"DailyFlow 💧" <${process.env.GMAIL_USER}>`,
      to: userData.email,
      subject: isVerified ? "💧 Hydration Log Verified!" : "❌ Hydration Log Rejected",
      html: htmlWrap(isVerified ? "Log Verified! 💧" : "Log Needs Resubmission", body, "#3b82f6"),
    });
  });
