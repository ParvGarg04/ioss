# DailyFlow Email Functions — Setup Guide

## What these functions do

| Function | Trigger | Who gets emailed |
|---|---|---|
| `onEmergencyAlert` | New doc in `emergencyAlerts` | All members (or targeted ones) |
| `taskReminderEmail` | Every hour | Members with tasks due in 60 min |
| `waterReminderEmail` | Every 2 hrs (10am–10pm IST) | Members who haven't logged water recently |
| `onTaskVerified` | Task submission status changes | The member who submitted |
| `onWaterLogVerified` | Water log status changes | The member who logged |

---

## Step 1 — Upgrade to Firebase Blaze plan

Cloud Functions that send emails need the Blaze (pay-as-you-go) plan.
It's free at your scale — you get 2 million function invocations free per month.

Go to: https://console.firebase.google.com/project/dailyflow-68e98/usage/details
Click **Upgrade** → Select **Blaze**. Add a card (you won't be charged unless you exceed free tier).

---

## Step 2 — Create a Gmail App Password

Your Gmail password won't work directly. You need an **App Password**:

1. Go to your Google Account → **Security**
2. Enable **2-Step Verification** if not already on
3. Go to **App Passwords** (search it in Google Account settings)
4. Select app: **Mail**, device: **Other** → type "DailyFlow"
5. Copy the 16-character password shown (e.g. `abcd efgh ijkl mnop`)

---

## Step 3 — Set Firebase environment config

Run these commands in your terminal from the `firebase/` folder:

```bash
firebase functions:config:set gmail.user="yourgmail@gmail.com" gmail.pass="abcdefghijklmnop"
```

Replace with your actual Gmail and the App Password from Step 2.
The App Password has no spaces — remove them if copying from Google.

Verify it was saved:
```bash
firebase functions:config:get
```

You should see:
```json
{
  "gmail": {
    "user": "yourgmail@gmail.com",
    "pass": "abcdefghijklmnop"
  }
}
```

---

## Step 4 — Install dependencies and deploy

```bash
# From the firebase/functions/ folder:
npm install

# Build TypeScript:
npm run build

# Go back to firebase/ folder and deploy:
cd ..
firebase deploy --only functions
```

That's it! You should see all 5 functions listed in your Firebase Console under Functions.

---

## Step 5 — Test it

1. Go to Firebase Console → **Functions**
2. Send a test emergency alert from your admin dashboard
3. Check your email — it should arrive within seconds

---

## Troubleshooting

**Emails not sending?**
- Check Firebase Console → Functions → Logs for errors
- Make sure App Password has no spaces
- Make sure Gmail account doesn't have "Less secure apps" blocking (App Password bypasses this)

**Functions not deploying?**
- Make sure you're on Blaze plan
- Run `npm run build` inside `functions/` before deploying

**Scheduled functions not running?**
- They run on IST (Asia/Kolkata). Water reminders fire at 10am, 12pm, 2pm, 4pm, 6pm, 8pm IST.
- Task reminders run every hour.
