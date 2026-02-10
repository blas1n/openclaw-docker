#!/usr/bin/env node
// cron-rpc.mjs — Lightweight gateway RPC client for cron management from sandbox
// Usage:
//   node scripts/cron-rpc.mjs list
//   node scripts/cron-rpc.mjs add '{"name":"test","message":"hello","every":"1h"}'
//   node scripts/cron-rpc.mjs rm <id>
//   node scripts/cron-rpc.mjs enable <id>
//   node scripts/cron-rpc.mjs disable <id>

import { randomUUID } from "node:crypto";

// Node 22+ has built-in WebSocket (browser-like API); fall back to ws package
const WS = globalThis.WebSocket ?? (await import("ws").then(m => m.default || m.WebSocket).catch(() => null));

const GATEWAY_URL = "ws://100.112.147.39:18789";
const GATEWAY_TOKEN = process.env.OPENCLAW_TOKEN || "21accf5097348b2cd3303b5fd9b04a15e3b3652520a8938de3623b53f5847b86";
const TELEGRAM_CHAT_ID = "8242700007";
const TIMEOUT_MS = 15000;

// --- Minimal WS RPC client (works with both browser-like and ws-package APIs) ---

function connectAndCall(method, params) {
  return new Promise((resolve, reject) => {
    if (!WS) { reject(new Error("WebSocket not available")); return; }

    const ws = new WS(GATEWAY_URL);
    const timer = setTimeout(() => { ws.close(); reject(new Error("timeout")); }, TIMEOUT_MS);

    let connected = false;
    const reqId = randomUUID();

    function onOpen() {
      const connectId = randomUUID();
      ws.send(JSON.stringify({
        type: "req",
        id: connectId,
        method: "connect",
        params: {
          minProtocol: 3,
          maxProtocol: 3,
          client: { id: "cli", version: "1.0.0", platform: "linux", mode: "cli" },
          caps: [],
          auth: { token: GATEWAY_TOKEN },
          role: "operator",
          scopes: ["operator.admin"]
        }
      }));
    }

    function onMessage(evt) {
      const raw = typeof evt === "string" ? evt : (evt.data ?? evt);
      const msg = JSON.parse(typeof raw === "string" ? raw : raw.toString());

      if (msg.type === "res" && !connected) {
        connected = true;
        ws.send(JSON.stringify({ type: "req", id: reqId, method, params: params || {} }));
        return;
      }

      if (msg.type === "res" && msg.id === reqId) {
        clearTimeout(timer);
        ws.close();
        if (!msg.ok || msg.error) reject(new Error(msg.error?.message || JSON.stringify(msg.error || msg)));
        else resolve(msg.payload);
      }
    }

    function onError(err) {
      clearTimeout(timer);
      reject(err instanceof Error ? err : new Error(String(err)));
    }

    // Support both Node EventEmitter (.on) and browser-like (.onopen) APIs
    if (typeof ws.on === "function") {
      ws.on("open", onOpen);
      ws.on("message", onMessage);
      ws.on("error", onError);
    } else {
      ws.onopen = onOpen;
      ws.onmessage = onMessage;
      ws.onerror = onError;
    }
  });
}

// --- CLI ---

const [,, action, ...args] = process.argv;

function parseSchedule(opts) {
  if (opts.every) {
    const dur = opts.every;
    let ms = 0;
    const h = dur.match(/(\d+)h/);
    const m = dur.match(/(\d+)m/);
    const s = dur.match(/(\d+)s/);
    if (h) ms += parseInt(h[1]) * 3600000;
    if (m) ms += parseInt(m[1]) * 60000;
    if (s) ms += parseInt(s[1]) * 1000;
    return { kind: "every", everyMs: ms, anchorMs: Date.now() };
  }
  if (opts.cron) return { kind: "cron", expr: opts.cron, tz: opts.tz || "" };
  if (opts.at) return { kind: "at", at: opts.at };
  throw new Error("Schedule required: every, cron, or at");
}

try {
  let result;

  switch (action) {
    case "list": {
      result = await connectAndCall("cron.list", { includeDisabled: true });
      break;
    }
    case "add": {
      const opts = JSON.parse(args[0]);
      const schedule = parseSchedule(opts);
      const job = {
        name: opts.name || "unnamed-job",
        description: opts.description,
        enabled: opts.enabled !== false,
        schedule,
        sessionTarget: opts.session || "isolated",
        wakeMode: opts.wakeMode || "now",
        payload: { kind: "agentTurn", message: opts.message },
        delivery: { mode: "announce", channel: "last", to: opts.to || TELEGRAM_CHAT_ID }
      };
      if (opts.deleteAfterRun) job.deleteAfterRun = true;
      if (opts.model) job.payload.model = opts.model;
      result = await connectAndCall("cron.add", job);
      break;
    }
    case "rm":
    case "remove": {
      result = await connectAndCall("cron.remove", { id: args[0] });
      break;
    }
    case "enable": {
      result = await connectAndCall("cron.update", { id: args[0], enabled: true });
      break;
    }
    case "disable": {
      result = await connectAndCall("cron.update", { id: args[0], enabled: false });
      break;
    }
    case "run": {
      result = await connectAndCall("cron.run", { id: args[0], mode: "force" });
      break;
    }
    default:
      console.error("Usage: node scripts/cron-rpc.mjs <list|add|rm|enable|disable|run> [args]");
      process.exit(1);
  }

  console.log(JSON.stringify(result, null, 2));
} catch (err) {
  console.error("Error:", err.message);
  process.exit(1);
}
