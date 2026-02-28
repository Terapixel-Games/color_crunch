var DEFAULT_USERNAME_CHANGE_COST_COINS = 300;
var DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS = 300;
var DEFAULT_USERNAME_CHANGE_MAX_PER_DAY = 3;
var ACCOUNT_COLLECTION = "account";
var MAGIC_LINK_STATUS_KEY = "magic_link_status";
var MAGIC_LINK_PENDING_KEY = "magic_link_pending";
var MAGIC_LINK_EMAIL_LOOKUP_KEY_PREFIX = "magic_link_email_lookup_";
var MAGIC_LINK_PROFILE_LOOKUP_KEY_PREFIX = "magic_link_profile_lookup_";
var MAGIC_LINK_NOTIFY_REPLAY_KEY = "magic_link_notify_replay";
var USERNAME_STATE_KEY = "username_state";
var EMAIL_MAX_LENGTH = 320;
var MAGIC_LINK_TOKEN_MAX_LENGTH = 512;
var SYSTEM_USER_ID = "00000000-0000-0000-0000-000000000000";
var DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS = 600;
var MAX_MAGIC_LINK_NOTIFY_REPLAY_ENTRIES = 2048;

var MODULE_CONFIG = {
  gameId: "",
  leaderboardId: "",
  platformIdentityUrl: "",
  platformUsernameValidateUrl: "",
  platformAccountMagicLinkStartUrl: "",
  platformAccountMagicLinkCompleteUrl: "",
  platformAccountMergeCodeUrl: "",
  platformAccountMergeRedeemUrl: "",
  platformTelemetryEventsUrl: "",
  platformInternalKey: "",
  magicLinkNotifySecret: "",
  magicLinkNotifyRequireTimestamp: true,
  magicLinkNotifyMaxSkewSeconds: DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS,
  usernameChangeCostCoins: DEFAULT_USERNAME_CHANGE_COST_COINS,
  usernameChangeCooldownSeconds: DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS,
  usernameChangeMaxPerDay: DEFAULT_USERNAME_CHANGE_MAX_PER_DAY,
};

function InitModule(ctx, logger, nk, initializer) {
  MODULE_CONFIG = loadConfig(ctx);
  initializer.registerRpc("platform_auth_exchange", rpcPlatformAuthExchange);
  initializer.registerRpc("platform_username_validate", rpcPlatformUsernameValidate);
  initializer.registerRpc("tpx_account_magic_link_start", rpcAccountMagicLinkStart);
  initializer.registerRpc("tpx_account_magic_link_complete", rpcAccountMagicLinkComplete);
  initializer.registerRpc("tpx_account_magic_link_status", rpcAccountMagicLinkStatus);
  initializer.registerRpc("tpx_account_magic_link_notify", rpcAccountMagicLinkNotify);
  initializer.registerRpc("tpx_account_merge_code", rpcAccountMergeCode);
  initializer.registerRpc("tpx_account_merge_redeem", rpcAccountMergeRedeem);
  initializer.registerRpc("tpx_account_username_status", rpcAccountUsernameStatus);
  initializer.registerRpc("tpx_account_update_username", rpcAccountUpdateUsername);
  initializer.registerRpc("tpx_client_event_track", rpcClientEventTrack);
  logger.info("ArcadeCore Nakama template module loaded for game=%s", MODULE_CONFIG.gameId);
}

function loadConfig(ctx) {
  var env = (ctx && ctx.env) || {};
  var gameId = String(env.GAME_ID || "").trim().toLowerCase();
  return {
    gameId: gameId,
    leaderboardId: String(env.LEADERBOARD_ID || (gameId + "_high_scores")).trim().toLowerCase(),
    platformIdentityUrl: String(env.PLATFORM_IDENTITY_URL || "").trim(),
    platformUsernameValidateUrl: String(env.PLATFORM_USERNAME_VALIDATE_URL || "").trim(),
    platformAccountMagicLinkStartUrl: String(
      env.PLATFORM_ACCOUNT_MAGIC_LINK_START_URL || env.TPX_PLATFORM_MAGIC_LINK_START_URL || ""
    ).trim(),
    platformAccountMagicLinkCompleteUrl: String(
      env.PLATFORM_ACCOUNT_MAGIC_LINK_COMPLETE_URL || env.TPX_PLATFORM_MAGIC_LINK_COMPLETE_URL || ""
    ).trim(),
    platformAccountMergeCodeUrl: String(
      env.PLATFORM_ACCOUNT_MERGE_CODE_URL || env.TPX_PLATFORM_ACCOUNT_MERGE_CODE_URL || ""
    ).trim(),
    platformAccountMergeRedeemUrl: String(
      env.PLATFORM_ACCOUNT_MERGE_REDEEM_URL || env.TPX_PLATFORM_ACCOUNT_MERGE_REDEEM_URL || ""
    ).trim(),
    platformTelemetryEventsUrl: String(
      env.PLATFORM_TELEMETRY_EVENTS_URL || env.PLATFORM_TELEMETRY_URL || ""
    ).trim(),
    platformInternalKey: String(env.PLATFORM_INTERNAL_KEY || "").trim(),
    magicLinkNotifySecret: String(env.TPX_MAGIC_LINK_NOTIFY_SECRET || env.MAGIC_LINK_NOTIFY_SECRET || "").trim(),
    magicLinkNotifyRequireTimestamp: toBool(env.TPX_MAGIC_LINK_NOTIFY_REQUIRE_TIMESTAMP, true),
    magicLinkNotifyMaxSkewSeconds: Math.max(
      30,
      toInt(env.TPX_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS, DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS)
    ),
    usernameChangeCostCoins: toInt(env.USERNAME_CHANGE_COST_COINS, DEFAULT_USERNAME_CHANGE_COST_COINS),
    usernameChangeCooldownSeconds: toInt(env.USERNAME_CHANGE_COOLDOWN_SECONDS, DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS),
    usernameChangeMaxPerDay: toInt(env.USERNAME_CHANGE_MAX_PER_DAY, DEFAULT_USERNAME_CHANGE_MAX_PER_DAY),
  };
}

function rpcPlatformAuthExchange(ctx, logger, nk, payload) {
  var data = parsePayload(payload);
  var nakamaUserId = String(data.nakama_user_id || ctx.userId || "").trim();
  if (!nakamaUserId) {
    throw new Error("nakama_user_id is required");
  }
  if (!MODULE_CONFIG.platformIdentityUrl) {
    throw new Error("PLATFORM_IDENTITY_URL is required");
  }
  var response = nk.httpRequest(
    MODULE_CONFIG.platformIdentityUrl + "/v1/auth/nakama",
    "post",
    {
      "Content-Type": "application/json",
    },
    JSON.stringify({
      game_id: MODULE_CONFIG.gameId,
      nakama_user_id: nakamaUserId,
      display_name: String(data.display_name || ctx.username || "").trim(),
    }),
    5000,
    false
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("platform auth exchange failed");
  }
  return response.body || "{}";
}

function rpcPlatformUsernameValidate(ctx, logger, nk, payload) {
  var data = parsePayload(payload);
  var username = String(data.username || "").trim();
  if (!username) {
    throw new Error("username is required");
  }
  if (!MODULE_CONFIG.platformUsernameValidateUrl || !MODULE_CONFIG.platformInternalKey) {
    throw new Error("username validation endpoint is not configured");
  }
  var response = nk.httpRequest(
    MODULE_CONFIG.platformUsernameValidateUrl,
    "post",
    {
      "Content-Type": "application/json",
      "x-admin-key": MODULE_CONFIG.platformInternalKey,
    },
    JSON.stringify({
      game_id: MODULE_CONFIG.gameId,
      username: username,
    }),
    5000,
    false
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("platform username moderation failed");
  }
  return response.body || "{}";
}

function rpcAccountMagicLinkStart(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var email = sanitizeEmailAddress(data.email || "");
  if (!email) {
    throw new Error("valid email is required");
  }
  if (!MODULE_CONFIG.platformAccountMagicLinkStartUrl) {
    throw new Error("PLATFORM_ACCOUNT_MAGIC_LINK_START_URL is required");
  }
  clearMagicLinkStatus(nk, ctx.userId);
  writeMagicLinkPending(nk, ctx.userId, {
    email: email,
    startedAt: Math.floor(Date.now() / 1000),
  });
  writeMagicLinkLookupByEmail(nk, email, ctx.userId);
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = httpPost(
    nk,
    MODULE_CONFIG.platformAccountMagicLinkStartUrl,
    {
      email: email,
      game_id: MODULE_CONFIG.gameId,
      nakama_user_id: ctx.userId,
    },
    {},
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to start magic link: " + extractHttpErrorDetail(response));
  }
  return JSON.stringify(parseHttpBodyJson(response.body) || { ok: true });
}

function rpcAccountMagicLinkComplete(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var token = sanitizeMagicLinkToken(data.ml_token || data.magic_link_token || "");
  if (!token) {
    throw new Error("ml_token is required");
  }
  if (!MODULE_CONFIG.platformAccountMagicLinkCompleteUrl) {
    throw new Error("PLATFORM_ACCOUNT_MAGIC_LINK_COMPLETE_URL is required");
  }
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = httpPost(
    nk,
    MODULE_CONFIG.platformAccountMagicLinkCompleteUrl,
    {
      ml_token: token,
    },
    {},
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to complete magic link: " + extractHttpErrorDetail(response));
  }
  return JSON.stringify(parseHttpBodyJson(response.body) || {});
}

function rpcAccountMagicLinkStatus(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var clearAfterRead = data.clear_after_read === undefined ? true : !!data.clear_after_read;
  var status = readMagicLinkStatus(nk, ctx.userId);
  if (!status) {
    return JSON.stringify({
      pending: true,
      completed: false,
    });
  }
  if (clearAfterRead) {
    clearMagicLinkStatus(nk, ctx.userId);
    clearMagicLinkPending(nk, ctx.userId);
    if (status.email) {
      var statusEmail = sanitizeEmailAddress(status.email || "");
      if (statusEmail) {
        clearMagicLinkLookupByEmail(nk, statusEmail);
      }
    }
  }
  return JSON.stringify({
    pending: false,
    completed: true,
    status: status.status || "",
    email: status.email || "",
    primaryProfileId: status.primaryProfileId || "",
    secondaryProfileId: status.secondaryProfileId || "",
    completedAt: toInt(status.completedAt, 0),
    source: "platform_callback",
  });
}

function rpcAccountMagicLinkNotify(ctx, logger, nk, payload) {
  var data = {};
  try {
    data = parsePayload(payload);
  } catch (err) {
    logger.warn("magic_link_notify rejected: invalid payload err=%s", String(err || ""));
    throw err;
  }
  var expectedSecret =
    String(MODULE_CONFIG.magicLinkNotifySecret || "").trim() ||
    String((ctx && ctx.env && ctx.env.TPX_MAGIC_LINK_NOTIFY_SECRET) || "").trim();
  if (!expectedSecret) {
    logger.error("magic_link_notify rejected: notify secret is not configured (env=TPX_MAGIC_LINK_NOTIFY_SECRET)");
    throw new Error("magic link notify secret is not configured (set TPX_MAGIC_LINK_NOTIFY_SECRET)");
  }
  var providedSecret = String(data.secret || "").trim();
  if (!providedSecret || !secureEquals(providedSecret, expectedSecret)) {
    throw new Error("invalid notify secret");
  }
  var replayValidation = validateMagicLinkNotifyReplay(nk, data);
  if (!replayValidation.ok) {
    throw new Error(replayValidation.error || "invalid notify request");
  }
  var incomingEmail = "";
  var rawNotifyEmail = String(data.email || "").trim();
  if (rawNotifyEmail) {
    incomingEmail = sanitizeEmailAddress(rawNotifyEmail);
    if (!incomingEmail) {
      throw new Error("valid email is required");
    }
  }
  var resolved = resolveMagicLinkNotifyTarget(nk, data, incomingEmail);
  var userId = resolved.userId;
  if (!userId) {
    throw new Error("nakama_user_id is required");
  }
  var incomingGameId = String(data.game_id || data.gameId || "").trim().toLowerCase();
  if (incomingGameId && incomingGameId !== String(MODULE_CONFIG.gameId || "").trim().toLowerCase()) {
    throw new Error("game_id mismatch");
  }
  var status = String(data.status || data.link_status || "").trim().toLowerCase();
  if (!status) {
    throw new Error("status is required");
  }
  var row = {
    status: status,
    email: incomingEmail,
    primaryProfileId: String(data.primary_profile_id || data.primaryProfileId || "").trim(),
    secondaryProfileId: String(data.secondary_profile_id || data.secondaryProfileId || "").trim(),
    completedAt: toInt(data.completed_at || data.completedAt, Math.floor(Date.now() / 1000)),
    receivedAt: Math.floor(Date.now() / 1000),
  };
  writeMagicLinkStatus(nk, userId, row);
  clearMagicLinkPending(nk, userId);
  if (row.email) {
    clearMagicLinkLookupByEmail(nk, row.email);
  }
  return JSON.stringify({
    ok: true,
    userId: userId,
    status: row.status,
  });
}

function rpcAccountMergeCode(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  if (!MODULE_CONFIG.platformAccountMergeCodeUrl) {
    throw new Error("PLATFORM_ACCOUNT_MERGE_CODE_URL is required");
  }
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = httpPost(
    nk,
    MODULE_CONFIG.platformAccountMergeCodeUrl,
    {},
    {},
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to create merge code: " + extractHttpErrorDetail(response));
  }
  var parsed = parseHttpBodyJson(response.body);
  return JSON.stringify({
    merge_code: parsed.merge_code || "",
    expires_at: parsed.expires_at || 0,
  });
}

function rpcAccountMergeRedeem(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  if (!MODULE_CONFIG.platformAccountMergeRedeemUrl) {
    throw new Error("PLATFORM_ACCOUNT_MERGE_REDEEM_URL is required");
  }
  var data = parsePayload(payload);
  var code = String(data.merge_code || data.code || "").trim().toUpperCase();
  if (!code) {
    throw new Error("merge_code is required");
  }
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = httpPost(
    nk,
    MODULE_CONFIG.platformAccountMergeRedeemUrl,
    {
      merge_code: code,
    },
    {},
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to redeem merge code: " + extractHttpErrorDetail(response));
  }
  var parsed = parseHttpBodyJson(response.body);
  return JSON.stringify({
    ok: parsed.ok === true,
    status: String(parsed.status || "").trim(),
    primaryProfileId: String(parsed.primary_profile_id || parsed.primaryProfileId || "").trim(),
    secondaryProfileId: String(parsed.secondary_profile_id || parsed.secondaryProfileId || "").trim(),
    mergedAt: toInt(parsed.merged_at || parsed.mergedAt, 0),
  });
}

function rpcAccountUsernameStatus(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var state = readUsernameState(nk, ctx.userId, ctx.username || "");
  return JSON.stringify(buildUsernameStatusResponse(state));
}

function rpcAccountUpdateUsername(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var requested = String(data.username || "").trim();
  var normalized = sanitizeRequestedUsername(requested);
  if (!normalized) {
    throw new Error("username must be 3-20 characters and use letters, numbers, _ or -");
  }
  var moderation = validateUsernameModeration(nk, normalized);
  if (!moderation.allowed) {
    throw new Error("username is not allowed");
  }
  var state = readUsernameState(nk, ctx.userId, ctx.username || "");
  var now = Math.floor(Date.now() / 1000);
  var cooldownSeconds = Math.max(0, toInt(MODULE_CONFIG.usernameChangeCooldownSeconds, DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS));
  if (cooldownSeconds > 0 && toInt(state.lastChangedAt, 0) > 0) {
    var nextAllowedAt = toInt(state.lastChangedAt, 0) + cooldownSeconds;
    if (nextAllowedAt > now) {
      throw new Error("username change cooldown active");
    }
  }
  var maxPerDay = Math.max(1, toInt(MODULE_CONFIG.usernameChangeMaxPerDay, DEFAULT_USERNAME_CHANGE_MAX_PER_DAY));
  var windowStartAt = toInt(state.changeWindowStartAt, 0);
  var windowCount = Math.max(0, toInt(state.changeWindowCount, 0));
  if (windowStartAt <= 0 || (now - windowStartAt) >= 86400) {
    windowStartAt = now;
    windowCount = 0;
  }
  if (windowCount >= maxPerDay) {
    throw new Error("username change daily limit reached");
  }
  var currentNormalized = sanitizeRequestedUsername(state.currentUsername || "");
  if (normalized === currentNormalized) {
    return JSON.stringify({
      ok: true,
      changed: false,
      username: state.currentUsername || normalized,
      coinCost: 0,
      reason: "same_username",
      usernamePolicy: buildUsernameStatusResponse(state),
    });
  }
  try {
    nk.accountUpdateId(ctx.userId, normalized, null, null, null, null, null, null);
  } catch (err) {
    var message = String(err || "");
    if (message.toLowerCase().indexOf("already") >= 0 || message.toLowerCase().indexOf("exists") >= 0) {
      throw new Error("username is already taken");
    }
    throw new Error("failed to update username");
  }
  state.currentUsername = normalized;
  state.hasUsedFreeChange = true;
  state.changeCount = Math.max(0, toInt(state.changeCount, 0)) + 1;
  state.lastChangedAt = now;
  state.changeWindowStartAt = windowStartAt;
  state.changeWindowCount = windowCount + 1;
  writeUsernameState(nk, ctx.userId, state);
  return JSON.stringify({
    ok: true,
    changed: true,
    username: normalized,
    coinCost: 0,
    usernamePolicy: buildUsernameStatusResponse(state),
  });
}

function rpcClientEventTrack(ctx, logger, nk, payload) {
  if (!ctx || !ctx.userId) {
    throw new Error("user session is required");
  }
  if (!MODULE_CONFIG.platformTelemetryEventsUrl) {
    return JSON.stringify({
      accepted: false,
      reason: "PLATFORM_TELEMETRY_EVENTS_URL is not configured"
    });
  }
  var data = parsePayload(payload);
  var eventName = normalizeEventName(data.event_name || data.eventName || "");
  if (!eventName) {
    throw new Error("event_name is required");
  }
  var eventTime = toInt(
    data.event_time || data.eventTime,
    Math.floor(Date.now() / 1000)
  );
  var properties = ensurePlainObject(data.properties, {});
  properties.nakama_user_id = String(ctx.userId || "").trim();
  properties.nakama_username = String(ctx.username || "").trim();
  properties.game_id = MODULE_CONFIG.gameId;
  var seq = toInt(data.seq, -1);
  var eventRow = {
    event_name: eventName,
    event_time: eventTime,
    properties
  };
  if (seq >= 0) {
    eventRow.seq = seq;
  }

  var platformSession = exchangePlatformSession(ctx, nk);
  var response = nk.httpRequest(
    MODULE_CONFIG.platformTelemetryEventsUrl,
    "post",
    {
      "Content-Type": "application/json",
      Authorization: "Bearer " + platformSession
    },
    JSON.stringify({
      game_id: MODULE_CONFIG.gameId,
      profile_id: String(ctx.userId || "").trim(),
      session_id: String(data.session_id || data.sessionId || "").trim(),
      events: [eventRow]
    }),
    5000,
    false
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("platform telemetry ingest failed");
  }
  return JSON.stringify({
    accepted: true,
    event_name: eventName
  });
}

function exchangePlatformSession(ctx, nk) {
  if (!MODULE_CONFIG.platformIdentityUrl) {
    throw new Error("PLATFORM_IDENTITY_URL is required");
  }
  var response = nk.httpRequest(
    MODULE_CONFIG.platformIdentityUrl + "/v1/auth/nakama",
    "post",
    {
      "Content-Type": "application/json"
    },
    JSON.stringify({
      game_id: MODULE_CONFIG.gameId,
      nakama_user_id: String((ctx && ctx.userId) || "").trim(),
      display_name: String((ctx && ctx.username) || "").trim()
    }),
    5000,
    false
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("platform auth exchange failed");
  }
  var parsed = parsePayload(response.body || "{}");
  var sessionToken = String(parsed.session_token || "").trim();
  if (!sessionToken) {
    throw new Error("platform auth exchange missing session_token");
  }
  var platformProfileId = String(parsed.player_id || parsed.playerId || "").trim();
  if (platformProfileId && ctx && ctx.userId) {
    writeMagicLinkLookupByProfile(nk, platformProfileId, ctx.userId);
  }
  return sessionToken;
}

function parsePayload(payload) {
  if (!payload) {
    return {};
  }
  if (typeof payload === "object" && !Array.isArray(payload)) {
    return payload;
  }
  if (typeof payload !== "string") {
    throw new Error("invalid JSON payload");
  }
  try {
    var parsed = JSON.parse(payload);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("payload must be a JSON object");
    }
    return parsed;
  } catch (_err) {
    throw new Error("invalid JSON payload");
  }
}

function toInt(value, fallback) {
  var parsed = Number(value);
  if (!isFinite(parsed)) {
    return fallback;
  }
  return Math.floor(parsed);
}

function toBool(value, fallback) {
  if (value === null || value === undefined || value === "") {
    return !!fallback;
  }
  var normalized = String(value).trim().toLowerCase();
  if (!normalized) {
    return !!fallback;
  }
  if (normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on") {
    return true;
  }
  if (normalized === "0" || normalized === "false" || normalized === "no" || normalized === "off") {
    return false;
  }
  return !!fallback;
}

function normalizeEventName(value) {
  var out = String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]/g, "_");
  if (!out) {
    return "";
  }
  if (out.length > 120) {
    out = out.substring(0, 120);
  }
  return out;
}

function ensurePlainObject(value, fallback) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  return fallback;
}

function assertAuthenticated(ctx) {
  if (!ctx || !ctx.userId) {
    throw new Error("User session is required.");
  }
}

function httpPost(nk, url, body, extraHeaders, bearerToken) {
  var headers = {
    "Content-Type": "application/json",
  };
  if (extraHeaders && typeof extraHeaders === "object") {
    for (var key in extraHeaders) {
      if (Object.prototype.hasOwnProperty.call(extraHeaders, key)) {
        headers[key] = extraHeaders[key];
      }
    }
  }
  if (bearerToken) {
    headers.Authorization = "Bearer " + bearerToken;
  }
  return nk.httpRequest(
    url,
    "post",
    headers,
    JSON.stringify(body || {}),
    5000,
    false
  );
}

function parseHttpBodyJson(body) {
  if (!body) {
    return {};
  }
  var parsed = JSON.parse(body);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {};
  }
  return parsed;
}

function extractHttpErrorDetail(response) {
  var code = toInt(response && response.code, 0);
  var parsed = {};
  try {
    parsed = parseHttpBodyJson(response && response.body);
  } catch (_err) {
    parsed = {};
  }
  var message = "";
  if (parsed && parsed.error && parsed.error.message) {
    message = String(parsed.error.message);
  } else if (parsed && parsed.message) {
    message = String(parsed.message);
  } else if (response && response.body) {
    message = String(response.body);
  }
  message = message.trim();
  if (message.length > 220) {
    message = message.substring(0, 220) + "...";
  }
  if (message) {
    return "[" + code + "] " + message;
  }
  return "status " + code;
}

function magicLinkLookupKeyByEmail(email) {
  var normalized = sanitizeEmailAddress(email || "");
  if (!normalized) {
    return "";
  }
  var digest = stableHashHex(normalized);
  if (!digest) {
    return "";
  }
  return MAGIC_LINK_EMAIL_LOOKUP_KEY_PREFIX + digest;
}

function magicLinkLookupKeyByProfile(profileId) {
  var normalized = String(profileId || "").trim().toLowerCase();
  if (!normalized) {
    return "";
  }
  var safe = normalized.replace(/[^a-z0-9_-]/g, "_");
  if (!safe) {
    return "";
  }
  if (safe.length > 96) {
    safe = safe.substring(0, 96);
  }
  return MAGIC_LINK_PROFILE_LOOKUP_KEY_PREFIX + safe;
}

function writeMagicLinkLookupByEmail(nk, email, userId) {
  var normalizedEmail = sanitizeEmailAddress(email || "");
  if (!normalizedEmail) {
    return;
  }
  clearMagicLinkLookupByEmail(nk, normalizedEmail);
  var key = magicLinkLookupKeyByEmail(normalizedEmail);
  if (!key) {
    return;
  }
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: key,
      userId: SYSTEM_USER_ID,
      value: {
        email: normalizedEmail,
        userId: String(userId || "").trim(),
        updatedAt: Math.floor(Date.now() / 1000),
      },
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function writeMagicLinkLookupByProfile(nk, profileId, userId) {
  var key = magicLinkLookupKeyByProfile(profileId);
  if (!key) {
    return;
  }
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: key,
      userId: SYSTEM_USER_ID,
      value: {
        profileId: String(profileId || "").trim().toLowerCase(),
        userId: String(userId || "").trim(),
        updatedAt: Math.floor(Date.now() / 1000),
      },
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function readMagicLinkLookupByEmail(nk, email) {
  var normalized = sanitizeEmailAddress(email || "");
  if (!normalized) {
    return "";
  }
  var key = magicLinkLookupKeyByEmail(normalized);
  var byNewKey = readMagicLinkLookupUserIdByKey(nk, key);
  if (byNewKey) {
    return byNewKey;
  }
  var legacyKey = legacyMagicLinkLookupKeyByEmail(normalized);
  if (legacyKey && legacyKey !== key) {
    return readMagicLinkLookupUserIdByKey(nk, legacyKey);
  }
  return "";
}

function readMagicLinkLookupByProfile(nk, profileId) {
  var key = magicLinkLookupKeyByProfile(profileId);
  if (!key) {
    return "";
  }
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: key,
      userId: SYSTEM_USER_ID,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value) {
    return String(storage[0].value.userId || "").trim();
  }
  return "";
}

function clearMagicLinkLookupByEmail(nk, email) {
  var normalized = sanitizeEmailAddress(email || "");
  if (!normalized) {
    return;
  }
  var key = magicLinkLookupKeyByEmail(normalized);
  deleteMagicLinkLookupByKey(nk, key);
  var legacyKey = legacyMagicLinkLookupKeyByEmail(normalized);
  if (legacyKey && legacyKey !== key) {
    deleteMagicLinkLookupByKey(nk, legacyKey);
  }
}

function readMagicLinkStatus(nk, userId) {
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_STATUS_KEY,
      userId: userId,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value) {
    return storage[0].value;
  }
  return null;
}

function writeMagicLinkStatus(nk, userId, value) {
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_STATUS_KEY,
      userId: userId,
      value: value || {},
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function clearMagicLinkStatus(nk, userId) {
  nk.storageDelete([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_STATUS_KEY,
      userId: userId,
    },
  ]);
}

function writeMagicLinkPending(nk, userId, value) {
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_PENDING_KEY,
      userId: userId,
      value: value || {},
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function clearMagicLinkPending(nk, userId) {
  nk.storageDelete([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_PENDING_KEY,
      userId: userId,
    },
  ]);
}

function resolveMagicLinkNotifyTarget(nk, data, incomingEmail) {
  var explicit = String(data.nakama_user_id || data.nakamaUserId || "").trim();
  if (explicit && isExistingNakamaUserId(nk, explicit)) {
    return { userId: explicit, source: "explicit_nakama_user_id" };
  }
  var profileCandidates = resolveMagicLinkNotifyProfileCandidates(data);
  for (var i = 0; i < profileCandidates.length; i++) {
    var byProfile = readMagicLinkLookupByProfile(nk, profileCandidates[i]);
    var resolvedByProfile = resolveStoredNakamaUserId(nk, byProfile);
    if (resolvedByProfile) {
      return { userId: resolvedByProfile, source: "profile_lookup" };
    }
  }
  for (var j = 0; j < profileCandidates.length; j++) {
    if (isExistingNakamaUserId(nk, profileCandidates[j])) {
      return { userId: profileCandidates[j], source: "profile_field" };
    }
  }
  if (incomingEmail) {
    var byEmail = readMagicLinkLookupByEmail(nk, incomingEmail);
    var resolvedByEmail = resolveStoredNakamaUserId(nk, byEmail);
    if (resolvedByEmail) {
      return { userId: resolvedByEmail, source: "email_lookup" };
    }
  }
  return { userId: "", source: "unresolved" };
}

function resolveMagicLinkNotifyProfileCandidates(data) {
  var candidates = [
    data.profile_id,
    data.profileId,
    data.secondary_profile_id,
    data.secondaryProfileId,
    data.primary_profile_id,
    data.primaryProfileId,
  ];
  var out = [];
  var seen = {};
  for (var i = 0; i < candidates.length; i++) {
    var candidate = String(candidates[i] || "").trim();
    if (!candidate) {
      continue;
    }
    var key = candidate.toLowerCase();
    if (seen[key]) {
      continue;
    }
    seen[key] = true;
    out.push(candidate);
  }
  return out;
}

function resolveStoredNakamaUserId(nk, userId) {
  var candidate = String(userId || "").trim();
  if (!candidate) {
    return "";
  }
  if (isExistingNakamaUserId(nk, candidate)) {
    return candidate;
  }
  if (isLikelyNakamaUserId(candidate)) {
    return candidate;
  }
  return "";
}

function isLikelyNakamaUserId(value) {
  var text = String(value || "").trim();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(text);
}

function isExistingNakamaUserId(nk, userId) {
  var candidate = String(userId || "").trim();
  if (!isLikelyNakamaUserId(candidate)) {
    return false;
  }
  try {
    var users = nk.usersGetId([candidate]);
    return !!(users && users.length > 0 && users[0] && users[0].id);
  } catch (_err) {
    return false;
  }
}

function readUsernameState(nk, userId, fallbackUsername) {
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: USERNAME_STATE_KEY,
      userId: userId,
    },
  ]);
  var value = null;
  if (storage && storage.length > 0 && storage[0].value) {
    value = storage[0].value;
  }
  var currentUsername = String((value && value.currentUsername) || fallbackUsername || "").trim().toLowerCase();
  return {
    currentUsername: currentUsername,
    hasUsedFreeChange: value ? !!value.hasUsedFreeChange : false,
    changeCount: value ? Math.max(0, toInt(value.changeCount, 0)) : 0,
    lastChangedAt: value ? Math.max(0, toInt(value.lastChangedAt, 0)) : 0,
    changeWindowStartAt: value ? Math.max(0, toInt(value.changeWindowStartAt, 0)) : 0,
    changeWindowCount: value ? Math.max(0, toInt(value.changeWindowCount, 0)) : 0,
  };
}

function writeUsernameState(nk, userId, state) {
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: USERNAME_STATE_KEY,
      userId: userId,
      value: {
        currentUsername: String(state.currentUsername || "").trim().toLowerCase(),
        hasUsedFreeChange: !!state.hasUsedFreeChange,
        changeCount: Math.max(0, toInt(state.changeCount, 0)),
        lastChangedAt: Math.max(0, toInt(state.lastChangedAt, 0)),
        changeWindowStartAt: Math.max(0, toInt(state.changeWindowStartAt, 0)),
        changeWindowCount: Math.max(0, toInt(state.changeWindowCount, 0)),
      },
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function buildUsernameStatusResponse(state) {
  var freeChangeAvailable = !state.hasUsedFreeChange;
  return {
    username: String(state.currentUsername || "").trim().toLowerCase(),
    freeChangeAvailable: freeChangeAvailable,
    nextChangeCostCoins: freeChangeAvailable ? 0 : Math.max(0, toInt(MODULE_CONFIG.usernameChangeCostCoins, 0)),
    changeCount: Math.max(0, toInt(state.changeCount, 0)),
    lastChangedAt: Math.max(0, toInt(state.lastChangedAt, 0)),
    cooldownSeconds: Math.max(0, toInt(MODULE_CONFIG.usernameChangeCooldownSeconds, DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS)),
    maxChangesPerDay: Math.max(1, toInt(MODULE_CONFIG.usernameChangeMaxPerDay, DEFAULT_USERNAME_CHANGE_MAX_PER_DAY)),
  };
}

function sanitizeEmailAddress(input) {
  var value = String(input || "").trim().toLowerCase();
  if (!value || value.length > EMAIL_MAX_LENGTH) {
    return "";
  }
  if (/\s/.test(value)) {
    return "";
  }
  var atIndex = value.indexOf("@");
  if (atIndex <= 0 || atIndex !== value.lastIndexOf("@") || atIndex >= value.length - 1) {
    return "";
  }
  var localPart = value.substring(0, atIndex);
  var domainPart = value.substring(atIndex + 1);
  if (!isValidEmailLocalPart(localPart)) {
    return "";
  }
  if (!isValidEmailDomainPart(domainPart)) {
    return "";
  }
  return value;
}

function isValidEmailLocalPart(localPart) {
  if (!localPart || localPart.length > 64) {
    return false;
  }
  if (localPart[0] === "." || localPart[localPart.length - 1] === "." || localPart.indexOf("..") >= 0) {
    return false;
  }
  return /^[a-z0-9!#$%&'*+/=?^_`{|}~.-]+$/.test(localPart);
}

function isValidEmailDomainPart(domainPart) {
  if (!domainPart || domainPart.length > 255) {
    return false;
  }
  if (domainPart[0] === "." || domainPart[domainPart.length - 1] === ".") {
    return false;
  }
  var labels = domainPart.split(".");
  if (labels.length < 2) {
    return false;
  }
  for (var i = 0; i < labels.length; i++) {
    var label = labels[i];
    if (!label || label.length > 63) {
      return false;
    }
    if (label[0] === "-" || label[label.length - 1] === "-") {
      return false;
    }
    if (!/^[a-z0-9-]+$/.test(label)) {
      return false;
    }
  }
  return true;
}

function sanitizeMagicLinkToken(value) {
  var token = String(value || "").trim();
  if (!token || token.length > MAGIC_LINK_TOKEN_MAX_LENGTH) {
    return "";
  }
  if (!/^[A-Za-z0-9._~+/=-]+$/.test(token)) {
    return "";
  }
  return token;
}

function sanitizeRequestedUsername(input) {
  var raw = String(input || "").trim().toLowerCase();
  if (!raw) {
    return "";
  }
  var out = "";
  for (var i = 0; i < raw.length; i++) {
    var c = raw[i];
    var isLetter = c >= "a" && c <= "z";
    var isDigit = c >= "0" && c <= "9";
    if (isLetter || isDigit || c === "_" || c === "-") {
      out += c;
    } else {
      return "";
    }
  }
  if (out.length < 3 || out.length > 20) {
    return "";
  }
  if (out[0] === "-" || out[0] === "_" || out[out.length - 1] === "-" || out[out.length - 1] === "_") {
    return "";
  }
  return out;
}

function validateUsernameModeration(nk, username) {
  if (!MODULE_CONFIG.platformUsernameValidateUrl || !MODULE_CONFIG.platformInternalKey) {
    return {
      allowed: true,
      source: "disabled",
    };
  }
  var response = nk.httpRequest(
    MODULE_CONFIG.platformUsernameValidateUrl,
    "post",
    {
      "Content-Type": "application/json",
      "x-admin-key": MODULE_CONFIG.platformInternalKey,
    },
    JSON.stringify({
      game_id: MODULE_CONFIG.gameId,
      username: username,
    }),
    5000,
    false
  );
  if (response.code < 200 || response.code >= 300) {
    return {
      allowed: false,
      source: "platform_error",
    };
  }
  var parsed = parseHttpBodyJson(response.body);
  return {
    allowed: parsed.allowed === true,
    source: "platform",
  };
}

function stableHashHex(input) {
  var text = String(input || "");
  if (!text) {
    return "";
  }
  var h1 = fnv1a32(text, 2166136261);
  var h2 = fnv1a32(text, 2166136261 ^ 0x9e3779b9);
  return toHex32(h1) + toHex32(h2);
}

function fnv1a32(text, seed) {
  var hash = seed >>> 0;
  for (var i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash >>> 0;
}

function toHex32(value) {
  var out = (value >>> 0).toString(16);
  while (out.length < 8) {
    out = "0" + out;
  }
  return out;
}

function legacyMagicLinkLookupKeyByEmail(email) {
  var normalized = sanitizeEmailAddress(email || "");
  if (!normalized) {
    return "";
  }
  var safe = normalized.replace(/[^a-z0-9_-]/g, "_");
  if (!safe) {
    return "";
  }
  if (safe.length > 96) {
    safe = safe.substring(0, 96);
  }
  return MAGIC_LINK_EMAIL_LOOKUP_KEY_PREFIX + safe;
}

function readMagicLinkLookupUserIdByKey(nk, key) {
  if (!key) {
    return "";
  }
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: key,
      userId: SYSTEM_USER_ID,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value) {
    return String(storage[0].value.userId || "").trim();
  }
  return "";
}

function deleteMagicLinkLookupByKey(nk, key) {
  if (!key) {
    return;
  }
  nk.storageDelete([
    {
      collection: ACCOUNT_COLLECTION,
      key: key,
      userId: SYSTEM_USER_ID,
    },
  ]);
}

function secureEquals(left, right) {
  var a = String(left || "");
  var b = String(right || "");
  var mismatch = a.length === b.length ? 0 : 1;
  var len = Math.max(a.length, b.length);
  for (var i = 0; i < len; i++) {
    var charA = i < a.length ? a.charCodeAt(i) : 0;
    var charB = i < b.length ? b.charCodeAt(i) : 0;
    mismatch |= charA ^ charB;
  }
  return mismatch === 0;
}

function validateMagicLinkNotifyReplay(nk, data) {
  if (!MODULE_CONFIG.magicLinkNotifyRequireTimestamp) {
    return { ok: true };
  }
  var requestId = normalizeReplayRequestId(
    data.request_id || data.requestId || data.event_id || data.eventId || data.nonce || ""
  );
  if (!requestId) {
    return { ok: false, error: "request_id is required" };
  }
  var sentAt = toInt(data.sent_at || data.sentAt || data.timestamp || data.ts, 0);
  if (sentAt <= 0) {
    return { ok: false, error: "sent_at is required" };
  }
  var now = Math.floor(Date.now() / 1000);
  var maxSkew = Math.max(
    30,
    toInt(MODULE_CONFIG.magicLinkNotifyMaxSkewSeconds, DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS)
  );
  if (Math.abs(now - sentAt) > maxSkew) {
    return { ok: false, error: "stale notify request" };
  }
  var state = readMagicLinkNotifyReplayState(nk);
  var entries = state.entries || {};
  var minAllowed = now - maxSkew;
  var keys = Object.keys(entries);
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    if (toInt(entries[key], 0) < minAllowed) {
      delete entries[key];
    }
  }
  if (entries[requestId]) {
    return { ok: false, error: "duplicate notify request" };
  }
  entries[requestId] = sentAt;
  state.entries = trimReplayEntries(entries, MAX_MAGIC_LINK_NOTIFY_REPLAY_ENTRIES);
  writeMagicLinkNotifyReplayState(nk, state);
  return { ok: true };
}

function normalizeReplayRequestId(value) {
  var out = String(value || "").trim().toLowerCase();
  if (!out) {
    return "";
  }
  if (!/^[a-z0-9._:-]+$/.test(out)) {
    return "";
  }
  if (out.length > 96) {
    out = out.substring(0, 96);
  }
  return out;
}

function readMagicLinkNotifyReplayState(nk) {
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_NOTIFY_REPLAY_KEY,
      userId: SYSTEM_USER_ID,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value && storage[0].value.entries) {
    return {
      entries: storage[0].value.entries,
    };
  }
  return { entries: {} };
}

function writeMagicLinkNotifyReplayState(nk, state) {
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: MAGIC_LINK_NOTIFY_REPLAY_KEY,
      userId: SYSTEM_USER_ID,
      value: {
        entries: state && state.entries ? state.entries : {},
        updatedAt: Math.floor(Date.now() / 1000),
      },
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function trimReplayEntries(entries, maxEntries) {
  var rows = [];
  var keys = Object.keys(entries || {});
  for (var i = 0; i < keys.length; i++) {
    rows.push({
      key: keys[i],
      at: toInt(entries[keys[i]], 0),
    });
  }
  rows.sort(function (a, b) {
    return b.at - a.at;
  });
  var limit = Math.max(1, toInt(maxEntries, MAX_MAGIC_LINK_NOTIFY_REPLAY_ENTRIES));
  var out = {};
  for (var j = 0; j < rows.length && j < limit; j++) {
    out[rows[j].key] = rows[j].at;
  }
  return out;
}
