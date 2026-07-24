import { readFileSync } from "node:fs";

export class JsonRpcError extends Error {
  constructor(code, message, data = undefined) {
    super(message);
    this.name = "JsonRpcError";
    this.code = code;
    this.data = data;
  }
}

export class HanabiPlugin {
  #handlers = new Map();

  register(name, handler) {
    const normalized = String(name ?? "").trim();
    if (!normalized) throw new TypeError("method name cannot be empty");
    if (typeof handler !== "function") throw new TypeError("handler must be a function");
    if (this.#handlers.has(normalized)) {
      throw new TypeError(`method already registered: ${normalized}`);
    }
    this.#handlers.set(normalized, handler);
    return this;
  }

  async run() {
    let requestId = null;
    try {
      const request = this.#readRequest();
      requestId = request.id ?? null;
      const method = String(request.method ?? "").trim();
      if (!method) throw new JsonRpcError(-32600, "Request method is required");
      const handler = this.#handlers.get(method);
      if (!handler) throw new JsonRpcError(-32601, `Method not found: ${method}`);
      if (request.params != null && !isObject(request.params)) {
        throw new JsonRpcError(-32602, "params must be an object");
      }

      const context = Object.freeze({
        requestId,
        method,
        meta: isObject(request.meta) ? request.meta : {},
        pluginId: process.env.HANABI_PLUGIN_ID ?? "",
        pluginDir: process.env.HANABI_PLUGIN_DIR ?? "",
        dataDir: process.env.HANABI_PLUGIN_DATA_DIR ?? "",
        logDir: process.env.HANABI_PLUGIN_LOG_DIR ?? "",
      });
      const result = await handler(request.params ?? {}, context);
      this.#write({ jsonrpc: "2.0", id: requestId, result });
      return 0;
    } catch (error) {
      if (!(error instanceof JsonRpcError)) console.error(error);
      const rpcError = error instanceof JsonRpcError
        ? error
        : new JsonRpcError(-32603, error?.message || error?.name || "Internal error");
      this.#write({
        jsonrpc: "2.0",
        id: requestId,
        error: {
          code: rpcError.code,
          message: rpcError.message,
          ...(rpcError.data === undefined ? {} : { data: rpcError.data }),
        },
      });
      return 0;
    }
  }

  #readRequest() {
    const raw = readFileSync(0, "utf8").replace(/^\uFEFF/, "");
    if (!raw.trim()) throw new JsonRpcError(-32600, "Request body is empty");
    let request;
    try {
      request = JSON.parse(raw);
    } catch (error) {
      throw new JsonRpcError(-32700, `Invalid JSON: ${error.message}`);
    }
    if (!isObject(request)) throw new JsonRpcError(-32600, "Request must be an object");
    if (request.jsonrpc != null && request.jsonrpc !== "2.0") {
      throw new JsonRpcError(-32600, "Only JSON-RPC 2.0 is supported");
    }
    return request;
  }

  #write(response) {
    process.stdout.write(`${JSON.stringify(response)}\n`);
  }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
