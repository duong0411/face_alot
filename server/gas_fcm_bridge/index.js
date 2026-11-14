/**
 * Gas FCM Bridge
 * - App POST /api/push/register { token, chipId, platform }
 * - Subscribe MQTT tele/+/status → lọc *_vitals → khi gasAlert=1 → FCM
 *
 * Env:
 *   PORT=8787
 *   MQTT_URL=wss://mqtt.duynguyen.io.vn/mqtt
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccount.json
 *   COOLDOWN_SEC=45
 */
const fs = require('fs');
const path = require('path');
const express = require('express');
const mqtt = require('mqtt');
const admin = require('firebase-admin');

const PORT = Number(process.env.PORT || 8787);
const MQTT_URL = process.env.MQTT_URL || 'wss://mqtt.duynguyen.io.vn/mqtt';
const COOLDOWN_MS = Number(process.env.COOLDOWN_SEC || 45) * 1000;
const STORE = path.join(__dirname, 'data', 'devices.json');

function loadStore() {
  try {
    return JSON.parse(fs.readFileSync(STORE, 'utf8'));
  } catch {
    return { devices: [] };
  }
}

function saveStore(data) {
  fs.mkdirSync(path.dirname(STORE), { recursive: true });
  fs.writeFileSync(STORE, JSON.stringify(data, null, 2));
}

function initFirebase() {
  const credPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.join(__dirname, 'serviceAccount.json');
  if (!fs.existsSync(credPath)) {
    console.error(
      `[FCM] Thiếu service account: ${credPath}\n` +
        'Tải JSON từ Firebase Console → Project settings → Service accounts.',
    );
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.cert(require(credPath)),
  });
  console.log('[FCM] firebase-admin ready');
}

const lastSent = new Map(); // chipId → timestamp

async function sendGasPush({ chipId, gas, gasAlert }) {
  if (!gasAlert) return;
  const now = Date.now();
  const prev = lastSent.get(chipId) || 0;
  if (now - prev < COOLDOWN_MS) return;
  lastSent.set(chipId, now);

  const store = loadStore();
  const targets = store.devices.filter((d) => d.chipId === String(chipId));
  if (!targets.length) {
    console.log(`[push] chip=${chipId} gas=${gas} — không có device token`);
    return;
  }

  const title = `⚠ Cảnh báo gas — nhà ${chipId}`;
  const body = `Phát hiện khí gas vượt ngưỡng (mức ${gas}/1023). Kiểm tra ngay!`;
  // firebase_messaging 17: app gửi FID; Admin SDK vẫn nhận qua field `token` (transition).
  const tokens = targets.map((d) => d.token);
  let successCount = 0;
  let failureCount = 0;
  const dead = [];

  for (const token of tokens) {
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: {
          type: 'gas_alert',
          gasAlert: '1',
          gas: String(gas),
          chipId: String(chipId),
          title,
          body,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'gas_alert',
            priority: 'max',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
          payload: {
            aps: {
              alert: { title, body },
              sound: 'default',
              'interruption-level': 'time-sensitive',
            },
          },
        },
      });
      successCount += 1;
    } catch (e) {
      failureCount += 1;
      const code = e?.code || e?.errorInfo?.code || '';
      if (
        String(code).includes('registration-token-not-registered') ||
        String(code).includes('invalid-registration-token') ||
        String(code).includes('invalid-argument')
      ) {
        dead.push(token);
      }
      console.error(`[push] fail token=${token.slice(0, 12)}…`, code || e.message);
    }
  }

  console.log(
    `[push] chip=${chipId} gas=${gas} ok=${successCount} fail=${failureCount}`,
  );

  if (dead.length) {
    store.devices = store.devices.filter((d) => !dead.includes(d.token));
    saveStore(store);
  }
}

function startMqtt() {
  const client = mqtt.connect(MQTT_URL, {
    protocolVersion: 4,
    reconnectPeriod: 3000,
    connectTimeout: 15000,
  });

  client.on('connect', () => {
    console.log(`[MQTT] connected ${MQTT_URL}`);
    // tele/{chipId}_vitals/status → levels: tele / {chip}_vitals / status
    client.subscribe('tele/+/status', { qos: 0 });
  });

  client.on('message', (topic, buf) => {
    try {
      if (!topic.includes('_vitals')) return;
      const parts = topic.split('/');
      // tele / 123_vitals / status
      const mid = parts[1] || '';
      const chipId = mid.replace(/_vitals$/, '');
      if (!chipId || mid === chipId) return;

      const j = JSON.parse(buf.toString('utf8'));
      const gasAlert = j.gasAlert === 1 || j.gasAlert === true || j.gasAlert === '1';
      const gas = Number(j.gas ?? 0);
      if (gasAlert) {
        sendGasPush({ chipId, gas, gasAlert: true }).catch((e) =>
          console.error('[push]', e.message || e),
        );
      }
    } catch (e) {
      console.error('[MQTT] parse', topic, e.message || e);
    }
  });

  client.on('error', (e) => console.error('[MQTT]', e.message || e));
}

function startHttp() {
  const app = express();
  app.use(express.json({ limit: '32kb' }));

  app.get('/health', (_req, res) => res.json({ ok: true }));

  app.post('/api/push/register', (req, res) => {
    const token = String(req.body?.token || '').trim();
    const chipId = String(req.body?.chipId || '').trim();
    const platform = String(req.body?.platform || 'unknown').trim();
    if (!token || !chipId) {
      return res.status(400).json({ success: false, message: 'token + chipId required' });
    }
    const store = loadStore();
    store.devices = store.devices.filter((d) => d.token !== token);
    store.devices.push({
      token,
      chipId,
      platform,
      updatedAt: new Date().toISOString(),
    });
    saveStore(store);
    console.log(`[register] chip=${chipId} platform=${platform}`);
    return res.json({ success: true });
  });

  app.post('/api/push/unregister', (req, res) => {
    const token = String(req.body?.token || '').trim();
    if (!token) {
      return res.status(400).json({ success: false, message: 'token required' });
    }
    const store = loadStore();
    store.devices = store.devices.filter((d) => d.token !== token);
    saveStore(store);
    return res.json({ success: true });
  });

  app.listen(PORT, () => {
    console.log(`[HTTP] gas-fcm-bridge :${PORT}`);
  });
}

initFirebase();
startHttp();
startMqtt();
