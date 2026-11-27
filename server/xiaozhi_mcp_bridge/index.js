/**
 * Xiaozhi MCP ↔ MQTT SmartHome ESP32
 *
 * Kết nối wss://api.xiaozhi.me/mcp/?token=... rồi ánh xạ tools → MQTT
 * cmnd/esp32_* (firmware SmartHome_ESP32.ino).
 *
 * Env: XIAOZHI_URL, MQTT_URL, CHIP_ID=esp32, PORT=8790
 */
'use strict';

const http = require('http');
const mqtt = require('mqtt');
const WebSocket = require('ws');

const XIAOZHI_URL = process.env.XIAOZHI_URL || '';
const MQTT_URL = process.env.MQTT_URL || 'wss://mqtt.duynguyen.io.vn/mqtt';
const CHIP_ID = process.env.CHIP_ID || 'esp32';
const PORT = Number(process.env.PORT || 8790);

const DEV = {
  light: `${CHIP_ID}_led1`,
  pump: `${CHIP_ID}_pump`,
  pumpLegacy: `${CHIP_ID}_fan_livingroom`,
  fan: `${CHIP_ID}_fan`,
  door: `${CHIP_ID}_door_livingroom1`,
  face: `${CHIP_ID}_face_livingroom`,
  mode: `${CHIP_ID}_mode`,
  rules: `${CHIP_ID}_rules`,
  vitals: `${CHIP_ID}_vitals`,
  temp: `${CHIP_ID}_temp_livingroom`,
  humi: `${CHIP_ID}_humi_living_room`,
  gas: `${CHIP_ID}_gas_livingroom`,
  water: `${CHIP_ID}_water`,
  soil: `${CHIP_ID}_soil`,
  rain: `${CHIP_ID}_rain`,
};

const cache = {
  mode: 'MANUAL',
  temp: null,
  humi: null,
  gasAlert: false,
  dark: false,
  light: 'OFF',
  fan: 'OFF',
  pump: 'OFF',
  door: 0,
  soil: null,
  soilDry: false,
  rain: false,
  waterCm: null,
  waterEmpty: false,
  rules: {},
  updatedAt: 0,
};

let mqttClient = null;
let ws = null;
let reconnectTimer = null;
let pingTimer = null;
let startedAt = Date.now();

function pub(device, payload) {
  if (!mqttClient || !mqttClient.connected) {
    console.warn('[MQTT] chưa sẵn sàng:', device, payload);
    return false;
  }
  const topic = `cmnd/${device}/POWER`;
  const msg = typeof payload === 'string' ? payload : JSON.stringify(payload);
  mqttClient.publish(topic, msg);
  console.log(`[MCP→MQTT] ${topic} = ${msg}`);
  return true;
}

function pubRules(body) {
  if (!mqttClient || !mqttClient.connected) {
    console.warn('[MQTT] chưa sẵn sàng rules');
    return false;
  }
  const topic = `cmnd/${DEV.rules}/SET`;
  const msg = JSON.stringify(body);
  mqttClient.publish(topic, msg);
  console.log(`[MCP→MQTT] ${topic} = ${msg}`);
  return true;
}

function connectMqtt() {
  console.log('[MQTT] connecting', MQTT_URL);
  mqttClient = mqtt.connect(MQTT_URL, {
    protocolVersion: 4,
    reconnectPeriod: 3000,
    connectTimeout: 15000,
  });

  mqttClient.on('connect', () => {
    console.log('[MQTT] connected');
    const subs = [
      `tele/${DEV.vitals}/status`,
      `tele/${DEV.mode}/status`,
      `tele/${DEV.rules}/status`,
      `tele/${DEV.light}/status`,
      `tele/${DEV.pump}/status`,
      `tele/${DEV.pumpLegacy}/status`,
      `tele/${DEV.fan}/status`,
      `tele/${DEV.door}/status`,
      `tele/${DEV.temp}/status`,
      `tele/${DEV.humi}/status`,
      `tele/${DEV.gas}/status`,
      `tele/${DEV.water}/status`,
      `tele/${DEV.soil}/status`,
      `tele/${DEV.rain}/status`,
      `tele/${CHIP_ID}/status`,
    ];
    mqttClient.subscribe(subs, (err) => {
      if (err) console.error('[MQTT] subscribe error', err.message);
      else console.log('[MQTT] subscribed', subs.length, 'topics');
    });
  });

  mqttClient.on('message', (topic, buf) => {
    const raw = buf.toString();
    cache.updatedAt = Date.now();
    let json = null;
    try {
      if (raw.startsWith('{')) json = JSON.parse(raw);
    } catch (_) {
      /* plain */
    }

    if (topic.includes('_vitals/')) {
      if (!json) return;
      if (json.temp != null) cache.temp = Number(json.temp);
      if (json.humi != null) cache.humi = Number(json.humi);
      cache.gasAlert = json.gasAlert == 1 || json.gasAlert === true;
      cache.dark = json.dark == 1 || json.dark === true;
      if (json.light) cache.light = String(json.light).toUpperCase();
      if (json.fan) cache.fan = String(json.fan).toUpperCase();
      if (json.pump) cache.pump = String(json.pump).toUpperCase();
      if (json.door != null) cache.door = Number(json.door);
      if (json.soil != null) cache.soil = Number(json.soil);
      if (json.soilPct != null) cache.soil = Number(json.soilPct);
      cache.soilDry = json.soilDry == 1 || json.soilDry === true;
      cache.rain = json.rain == 1 || json.rain === true;
      if (json.waterCm != null) cache.waterCm = Number(json.waterCm);
      cache.waterEmpty = json.waterEmpty == 1 || json.waterEmpty === true;
      if (json.mode) cache.mode = String(json.mode).toUpperCase();
      return;
    }

    if (topic.includes('_mode/')) {
      const m = json?.value || json?.mode || raw;
      cache.mode = String(m).replace(/"/g, '').toUpperCase();
      return;
    }

    if (topic.includes('_rules/')) {
      if (json) {
        cache.rules = { ...cache.rules, ...json };
        if (json.mode) cache.mode = String(json.mode).toUpperCase();
      }
      return;
    }

    if (topic.includes('_led1/')) {
      cache.light = String(json?.value || raw).replace(/"/g, '').toUpperCase();
      return;
    }
    if (topic.includes('_pump/') || topic.includes('_fan_livingroom/')) {
      cache.pump = String(json?.value || raw).replace(/"/g, '').toUpperCase();
      return;
    }
    if (topic.endsWith(`${DEV.fan}/status`) || topic.includes(`/${DEV.fan}/`)) {
      cache.fan = String(json?.value || raw).replace(/"/g, '').toUpperCase();
      return;
    }
    if (topic.includes('_door_')) {
      const v = json?.value ?? json?.door ?? raw;
      const n = Number(v);
      cache.door = Number.isFinite(n) ? n : cache.door;
      return;
    }
    if (topic.includes('_temp_')) {
      cache.temp = Number(json?.value ?? raw);
      return;
    }
    if (topic.includes('_humi_')) {
      cache.humi = Number(json?.value ?? raw);
      return;
    }
    if (topic.includes('_water')) {
      if (json?.waterCm != null) cache.waterCm = Number(json.waterCm);
      else if (json?.value != null) cache.waterCm = Number(json.value);
      if (json?.waterEmpty != null) cache.waterEmpty = json.waterEmpty == 1;
      return;
    }
    if (topic.includes('_soil')) {
      if (json?.soilPct != null) cache.soil = Number(json.soilPct);
      else if (json?.value != null) cache.soil = Number(json.value);
      return;
    }
    if (topic.includes('_rain')) {
      cache.rain = json?.value == 1 || raw === '1' || /rain|ON/i.test(raw);
    }
  });

  mqttClient.on('error', (err) => console.error('[MQTT]', err.message));
  mqttClient.on('close', () => console.warn('[MQTT] disconnected'));
}

function tools() {
  return [
    {
      name: 'set_control_mode',
      description:
        'Chuyển chế độ nhà thông minh: MANUAL (thủ công bằng lệnh giọng nói) hoặc AUTO (tự động theo rule cảm biến: đất khô/hết nước → bơm, tối → đèn, nhiệt/gas → quạt).',
      inputSchema: {
        type: 'object',
        properties: {
          mode: { type: 'string', enum: ['MANUAL', 'AUTO'], description: 'MANUAL hoặc AUTO' },
        },
        required: ['mode'],
      },
    },
    {
      name: 'control_light',
      description: 'Bật hoặc tắt đèn nhà. Khi đang AUTO, lệnh tay sẽ ép MANUAL.',
      inputSchema: {
        type: 'object',
        properties: {
          state: { type: 'string', enum: ['ON', 'OFF'] },
        },
        required: ['state'],
      },
    },
    {
      name: 'control_pump',
      description:
        'Bật hoặc tắt bơm nước (tưới / bơm bể). Dùng khi người dùng nói bật bơm, tắt bơm, tưới cây, bơm nước.',
      inputSchema: {
        type: 'object',
        properties: {
          state: { type: 'string', enum: ['ON', 'OFF'] },
        },
        required: ['state'],
      },
    },
    {
      name: 'control_fan',
      description: 'Bật hoặc tắt quạt.',
      inputSchema: {
        type: 'object',
        properties: {
          state: { type: 'string', enum: ['ON', 'OFF'] },
        },
        required: ['state'],
      },
    },
    {
      name: 'control_door',
      description: 'Mở hoặc đóng cửa (servo). Mở cửa cũng dùng được khi nhận diện khuôn mặt Face AIoT.',
      inputSchema: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['open', 'close'] },
        },
        required: ['action'],
      },
    },
    {
      name: 'control_all_devices',
      description: 'Bật hoặc tắt cùng lúc đèn + bơm + quạt.',
      inputSchema: {
        type: 'object',
        properties: {
          state: { type: 'string', enum: ['ON', 'OFF'] },
        },
        required: ['state'],
      },
    },
    {
      name: 'set_auto_rules',
      description:
        'Cấu hình rule AUTO bằng lời nói: ngưỡng độ ẩm đất bật/tắt bơm, khoảng cách mực nước (cm) hết/đủ nước, mưa dừng bơm, nhiệt bật quạt, gas mở cửa/còi, giữ cửa.',
      inputSchema: {
        type: 'object',
        properties: {
          soilDryOn: { type: 'number', description: 'Độ ẩm đất % <= giá trị này → coi khô → bơm (AUTO)' },
          soilWetOff: { type: 'number', description: 'Độ ẩm đất % >= giá trị này → đủ ẩm → tắt bơm' },
          waterEmptyCm: { type: 'number', description: 'HC-SR04: khoảng cách >= cm → hết/thấp nước' },
          waterOkCm: { type: 'number', description: 'HC-SR04: khoảng cách <= cm → đủ nước (hysteresis)' },
          autoPumpSoil: { type: 'boolean', description: 'AUTO: đất khô → bơm' },
          autoPumpEmpty: { type: 'boolean', description: 'AUTO: hết nước → bơm' },
          stopPumpRain: { type: 'boolean', description: 'Đang mưa → không bơm' },
          darkLightOn: { type: 'boolean', description: 'Tối → bật đèn' },
          tempFanOn: { type: 'number', description: 'Nhiệt độ >= °C → bật quạt' },
          tempFanOff: { type: 'number', description: 'Nhiệt độ <= °C → tắt quạt' },
          gasOpenDoor: { type: 'boolean', description: 'Gas → mở cửa' },
          gasFanOn: { type: 'boolean', description: 'Gas → bật quạt' },
          gasPumpOn: { type: 'boolean', description: 'Gas → bật bơm (tuỳ chọn)' },
          buzzerOnGas: { type: 'boolean', description: 'Gas → còi' },
          buzzerOnEmpty: { type: 'boolean', description: 'Hết nước → còi' },
          doorHoldSec: { type: 'integer', description: 'Giữ cửa mở (giây) 1-60' },
        },
      },
    },
    {
      name: 'read_home_status',
      description:
        'Đọc toàn bộ trạng thái nhà thông minh: chế độ, nhiệt độ, độ ẩm không khí, độ ẩm đất, mực nước (cm), mưa, gas, đèn, bơm, quạt, cửa, rule. Dùng khi hỏi nhà thế nào, kiểm tra cảm biến.',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'read_temperature',
      description:
        'Đọc nhiệt độ phòng (°C) từ DHT11. Dùng khi hỏi nóng không, bao nhiêu độ, đọc nhiệt độ. Có thể gọi cùng control_door khi người dùng nói mở cửa và đọc nhiệt độ.',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'read_humidity',
      description:
        'Đọc độ ẩm không khí (DHT11) và độ ẩm đất (%). Dùng khi hỏi độ ẩm, đất khô không, có cần tưới không.',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'read_water_level',
      description:
        'Đọc mực nước / khoảng cách HC-SR04 (cm) và cờ hết nước. Khoảng cách lớn = mực nước thấp (cảm biến treo trên mặt nước).',
      inputSchema: { type: 'object', properties: {} },
    },
  ];
}

function bool01(v, fallback) {
  if (v === undefined || v === null) return fallback;
  return v ? 1 : 0;
}

function handleTool(name, args) {
  if (name === 'set_control_mode') {
    const mode = String(args.mode || '').toUpperCase() === 'AUTO' ? 'AUTO' : 'MANUAL';
    pub(DEV.mode, mode);
    cache.mode = mode;
    return `Đã chuyển nhà sang chế độ ${mode === 'AUTO' ? 'TỰ ĐỘNG (theo cảm biến)' : 'THỦ CÔNG'}.`;
  }

  if (name === 'control_light') {
    const state = args.state === 'ON' ? 'ON' : 'OFF';
    pub(DEV.light, state);
    cache.light = state;
    return `Đã ${state === 'ON' ? 'bật' : 'tắt'} đèn.`;
  }

  if (name === 'control_pump') {
    const state = args.state === 'ON' ? 'ON' : 'OFF';
    pub(DEV.pump, state);
    pub(DEV.pumpLegacy, state);
    cache.pump = state;
    return `Đã ${state === 'ON' ? 'bật' : 'tắt'} bơm nước.`;
  }

  if (name === 'control_fan') {
    const state = args.state === 'ON' ? 'ON' : 'OFF';
    pub(DEV.fan, state);
    cache.fan = state;
    return `Đã ${state === 'ON' ? 'bật' : 'tắt'} quạt.`;
  }

  if (name === 'control_door') {
    const open = args.action !== 'close';
    const ok = pub(DEV.door, open ? 'ON' : 'OFF');
    if (open) pub(DEV.face, JSON.stringify({ name: 'Xiaozhi', action: 'OPEN' }));
    if (!ok) {
      return 'Chưa gửi được lệnh cửa — MQTT bridge chưa kết nối broker. Thử lại sau vài giây.';
    }
    return open
      ? 'Đã gửi lệnh mở cửa (servo) qua MQTT cmnd/esp32_door_livingroom1/POWER=ON.'
      : 'Đã gửi lệnh đóng cửa qua MQTT.';
  }

  if (name === 'control_all_devices') {
    const state = args.state === 'ON' ? 'ON' : 'OFF';
    pub(DEV.light, state);
    pub(DEV.pump, state);
    pub(DEV.pumpLegacy, state);
    pub(DEV.fan, state);
    cache.light = cache.pump = cache.fan = state;
    return `Đã gửi ${state} cho đèn, bơm và quạt.`;
  }

  if (name === 'set_auto_rules') {
    const cur = cache.rules || {};
    const body = {
      mode: cache.mode || 'AUTO',
      soilDryOn: args.soilDryOn ?? cur.soilDryOn ?? 30,
      soilWetOff: args.soilWetOff ?? cur.soilWetOff ?? 50,
      waterEmptyCm: args.waterEmptyCm ?? cur.waterEmptyCm ?? 25,
      waterOkCm: args.waterOkCm ?? cur.waterOkCm ?? 15,
      autoPumpSoil: bool01(args.autoPumpSoil, cur.autoPumpSoil ?? 1),
      autoPumpEmpty: bool01(args.autoPumpEmpty, cur.autoPumpEmpty ?? 0),
      stopPumpRain: bool01(args.stopPumpRain, cur.stopPumpRain ?? 1),
      darkLightOn: bool01(args.darkLightOn, cur.darkLightOn ?? 1),
      tempFanOn: args.tempFanOn ?? cur.tempFanOn ?? 30,
      tempFanOff: args.tempFanOff ?? cur.tempFanOff ?? 28,
      gasOpenDoor: bool01(args.gasOpenDoor, cur.gasOpenDoor ?? 1),
      gasFanOn: bool01(args.gasFanOn, cur.gasFanOn ?? 1),
      gasPumpOn: bool01(args.gasPumpOn, cur.gasPumpOn ?? 0),
      buzzerOnGas: bool01(args.buzzerOnGas, cur.buzzerOnGas ?? 1),
      buzzerOnEmpty: bool01(args.buzzerOnEmpty, cur.buzzerOnEmpty ?? 1),
      doorHoldSec: args.doorHoldSec ?? cur.doorHoldSec ?? 5,
    };
    pubRules(body);
    cache.rules = body;
    return (
      `Đã lưu rule AUTO: đất khô ≤${body.soilDryOn}% / đủ ẩm ≥${body.soilWetOff}%, ` +
      `nước hết ≥${body.waterEmptyCm}cm / đủ ≤${body.waterOkCm}cm, ` +
      `quạt ≥${body.tempFanOn}°C, mưa dừng bơm=${body.stopPumpRain ? 'có' : 'không'}.`
    );
  }

  if (name === 'read_temperature') {
    const age = cache.updatedAt ? Math.round((Date.now() - cache.updatedAt) / 1000) : null;
    if (cache.temp == null || Number.isNaN(cache.temp)) {
      return JSON.stringify({
        loi: 'Chưa có dữ liệu nhiệt độ từ ESP32 (MQTT tele). Kiểm tra WiFi/MQTT board và DHT11.',
        du_lieu_cu_giay: age,
      });
    }
    return JSON.stringify(
      {
        nhiet_do_C: cache.temp,
        do_am_khong_khi_pct: cache.humi,
        du_lieu_cu_giay: age,
        nguon: 'DHT11 qua tele/esp32_vitals hoặc tele/esp32_temp_livingroom',
      },
      null,
      2,
    );
  }

  if (name === 'read_home_status') {
    const age = cache.updatedAt ? Math.round((Date.now() - cache.updatedAt) / 1000) : null;
    return JSON.stringify(
      {
        che_do: cache.mode,
        nhiet_do_C: cache.temp,
        do_am_khong_khi_pct: cache.humi,
        do_am_dat_pct: cache.soil,
        dat_kho: cache.soilDry ? 'Có' : 'Không',
        muc_nuoc_cm: cache.waterCm,
        het_nuoc: cache.waterEmpty ? 'Có (khoảng cách lớn)' : 'Không',
        mua: cache.rain ? 'Đang mưa' : 'Không',
        gas_canh_bao: cache.gasAlert ? 'CÓ' : 'Không',
        anh_sang: cache.dark ? 'Tối' : 'Sáng',
        den: cache.light,
        bom: cache.pump,
        quat: cache.fan,
        cua_goc: cache.door,
        rule: cache.rules,
        du_lieu_cu_giay: age,
      },
      null,
      2,
    );
  }

  if (name === 'read_humidity') {
    return JSON.stringify(
      {
        do_am_khong_khi_pct: cache.humi,
        nhiet_do_C: cache.temp,
        do_am_dat_pct: cache.soil,
        dat_kho: cache.soilDry ? 'Có — có thể cần tưới/bơm' : 'Không',
        goi_y:
          cache.soilDry || (cache.soil != null && cache.soil <= 30)
            ? 'Đất đang khô. Có thể bật bơm (control_pump ON) hoặc chuyển AUTO.'
            : 'Độ ẩm đất ổn định.',
      },
      null,
      2,
    );
  }

  if (name === 'read_water_level') {
    return JSON.stringify(
      {
        khoang_cach_cm: cache.waterCm,
        ghi_chu:
          'Cảm biến HC-SR04 treo trên mặt nước: số cm càng lớn → mực nước càng thấp / gần hết.',
        het_nuoc: cache.waterEmpty ? 'Có' : 'Không',
        bom: cache.pump,
        goi_y: cache.waterEmpty
          ? 'Mực nước thấp. Có thể bật bơm hoặc kiểm tra bể chứa nước.'
          : 'Mực nước trong ngưỡng an toàn (theo rule hiện tại).',
      },
      null,
      2,
    );
  }

  return 'Tool không tồn tại.';
}

function send(msgObj) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msgObj));
  }
}

function handleJsonRpc(messageStr) {
  let doc;
  try {
    doc = JSON.parse(messageStr);
  } catch (_) {
    return;
  }

  if (doc.method === 'ping') {
    send({ jsonrpc: '2.0', id: doc.id, result: {} });
    return;
  }

  if (doc.method === 'initialize') {
    send({
      jsonrpc: '2.0',
      id: doc.id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: {
          experimental: {},
          prompts: { listChanged: false },
          resources: { subscribe: false, listChanged: false },
          tools: { listChanged: false },
        },
        serverInfo: { name: 'FaceAIoT-SmartHome-ESP32', version: '1.0.0' },
      },
    });
    send({ jsonrpc: '2.0', method: 'notifications/initialized' });
    console.log('[XiaoZhi] initialize OK — SmartHome ESP32 tools ready');
    return;
  }

  if (doc.method === 'tools/list') {
    send({ jsonrpc: '2.0', id: doc.id, result: { tools: tools() } });
    console.log('[XiaoZhi] tools/list →', tools().length, 'tools');
    return;
  }

  if (doc.method === 'tools/call') {
    const toolName = doc.params?.name;
    const args = doc.params?.arguments || {};
    console.log('[XiaoZhi] tools/call', toolName, args);
    let text = 'Lỗi xử lý tool';
    let isError = false;
    try {
      text = handleTool(toolName, args);
    } catch (e) {
      text = `Lỗi: ${e.message}`;
      isError = true;
    }
    send({
      jsonrpc: '2.0',
      id: doc.id,
      result: {
        content: [{ type: 'text', text }],
        isError,
      },
    });
  }
}

function connectXiaozhi() {
  if (!XIAOZHI_URL || !XIAOZHI_URL.includes('token=')) {
    console.error('❌ Thiếu XIAOZHI_URL (wss://api.xiaozhi.me/mcp/?token=...)');
    return;
  }
  console.log('[XiaoZhi] connecting MCP...');
  ws = new WebSocket(XIAOZHI_URL);

  ws.on('open', () => {
    console.log('[XiaoZhi] MCP connected');
    if (pingTimer) clearInterval(pingTimer);
    pingTimer = setInterval(() => {
      if (ws && ws.readyState === WebSocket.OPEN) ws.ping();
    }, 25000);
  });

  ws.on('message', (data) => handleJsonRpc(data.toString()));

  ws.on('close', () => {
    if (pingTimer) clearInterval(pingTimer);
    console.warn('[XiaoZhi] disconnected — retry 5s');
    if (reconnectTimer) clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connectXiaozhi, 5000);
  });

  ws.on('error', (err) => console.error('[XiaoZhi]', err.message));
}

function startHealthServer() {
  const server = http.createServer((req, res) => {
    if (req.url === '/health' || req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(
        JSON.stringify({
          ok: true,
          service: 'xiaozhi-mcp-smarthome',
          chipId: CHIP_ID,
          mqtt: !!(mqttClient && mqttClient.connected),
          xiaozhi: !!(ws && ws.readyState === WebSocket.OPEN),
          uptimeSec: Math.round((Date.now() - startedAt) / 1000),
          cacheAgeSec: cache.updatedAt ? Math.round((Date.now() - cache.updatedAt) / 1000) : null,
          cache: {
            mode: cache.mode,
            temp: cache.temp,
            humi: cache.humi,
            soil: cache.soil,
            waterCm: cache.waterCm,
            pump: cache.pump,
            light: cache.light,
            fan: cache.fan,
          },
        }),
      );
      return;
    }
    res.writeHead(404);
    res.end('not found');
  });
  server.listen(PORT, () => console.log(`[HTTP] health http://0.0.0.0:${PORT}/health`));
}

connectMqtt();
connectXiaozhi();
startHealthServer();
