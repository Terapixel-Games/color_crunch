var DEFAULT_LEADERBOARD_ID_OPEN = "colorcrunch_open_high_scores";
var DEFAULT_LEADERBOARD_ID_PURE = "colorcrunch_pure_high_scores";
var LEADERBOARD_SUBSCORE_BASE = 1000000;
var PLAYER_STATS_COLLECTION = "colorcrunch_player_stats";
var PLAYER_STATS_KEY = "high_score";
var IAP_COLLECTION = "colorcrunch_player_iap";
var IAP_KEY = "entitlements";
var SHOP_COLLECTION = "colorcrunch_player_shop";
var SHOP_KEY = "state";
var ACCOUNT_COLLECTION = "colorcrunch_player_account";
var MAGIC_LINK_STATUS_KEY = "magic_link_status";
var MAGIC_LINK_PENDING_KEY = "magic_link_pending";
var MAGIC_LINK_EMAIL_LOOKUP_KEY_PREFIX = "magic_link_email_lookup_";
var MAGIC_LINK_PROFILE_LOOKUP_KEY_PREFIX = "magic_link_profile_lookup_";
var MAGIC_LINK_NOTIFY_REPLAY_KEY = "magic_link_notify_replay";
var EMAIL_MAX_LENGTH = 320;
var MAGIC_LINK_TOKEN_MAX_LENGTH = 512;
var SYSTEM_USER_ID = "00000000-0000-0000-0000-000000000000";
var USERNAME_STATE_KEY = "username_state";
var USERNAME_AUDIT_KEY = "username_audit";
var RUN_HISTORY_KEY = "run_history";
var DEFAULT_USERNAME_CHANGE_COST_COINS = 300;
var DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS = 300;
var DEFAULT_USERNAME_CHANGE_MAX_PER_DAY = 3;
var DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS = 600;
var DEFAULT_SHOP_MAX_PURCHASE_QUANTITY = 20;
var DEFAULT_MAX_RUN_REWARDS_PER_DAY = 20;
var MAX_RUN_HISTORY_ENTRIES = 200;
var MAX_MAGIC_LINK_NOTIFY_REPLAY_ENTRIES = 2048;
var MAX_RUN_REWARD_COINS = 250;
var DEFAULT_BLOCKED_USERNAME_TOKENS = [
  "admin",
  "moderator",
  "support",
  "staff",
  "owner",
  "nigger",
  "nigga",
  "faggot",
  "retard",
  "rape",
  "rapist",
  "kike",
  "chink",
  "spic",
  "whore",
  "slut",
  "cunt",
  "fuck",
  "shit",
  "bitch",
  "dick",
  "penis",
  "vagina",
  "hitler",
  "nazi",
  "terrorist",
];
var DEFAULT_GAME_ID = "color_crunch";
var THEME_COSTS = {
  neon: 1500,
};
var POWERUP_COSTS = {
  undo: 120,
  prism: 180,
  shuffle: 140,
};
var MODULE_CONFIG = {
  leaderboardIds: {
    open: DEFAULT_LEADERBOARD_ID_OPEN,
    pure: DEFAULT_LEADERBOARD_ID_PURE,
  },
  authUrl: "",
  eventUrl: "",
  telemetryEventsUrl: "",
  identityNakamaAuthUrl: "",
  iapVerifyUrl: "",
  iapEntitlementsUrl: "",
  iapCoinsAdjustUrl: "",
  accountMergeCodeUrl: "",
  accountMergeRedeemUrl: "",
  accountMagicLinkStartUrl: "",
  accountMagicLinkCompleteUrl: "",
  usernameValidateUrl: "",
  internalServiceKey: "",
  usernameModerationFailOpen: false,
  usernameChangeCooldownSeconds: DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS,
  usernameChangeMaxPerDay: DEFAULT_USERNAME_CHANGE_MAX_PER_DAY,
  magicLinkNotifySecret: "",
  magicLinkNotifyRequireTimestamp: true,
  magicLinkNotifyMaxSkewSeconds: DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS,
  shopMaxPurchaseQuantity: DEFAULT_SHOP_MAX_PURCHASE_QUANTITY,
  maxRunRewardsPerDay: DEFAULT_MAX_RUN_REWARDS_PER_DAY,
  usernameChangeCostCoins: DEFAULT_USERNAME_CHANGE_COST_COINS,
  blockedUsernameTokens: DEFAULT_BLOCKED_USERNAME_TOKENS,
  gameId: DEFAULT_GAME_ID,
  exportTarget: "web",
  apiKey: "",
  httpTimeoutMs: 5000,
};

function InitModule(ctx, logger, nk, initializer) {
  MODULE_CONFIG = loadConfig(ctx);
  ensureLeaderboard(nk, logger, MODULE_CONFIG.leaderboardIds);

  initializer.registerRpc("tpx_submit_score", rpcSubmitScore);
  initializer.registerRpc("tpx_get_my_high_score", rpcGetMyHighScore);
  initializer.registerRpc("tpx_list_leaderboard", rpcListLeaderboard);
  initializer.registerRpc("tpx_iap_purchase_start", rpcIapPurchaseStart);
  initializer.registerRpc("tpx_iap_get_entitlements", rpcIapGetEntitlements);
  initializer.registerRpc("tpx_iap_sync_entitlements", rpcIapSyncEntitlements);
  initializer.registerRpc("tpx_wallet_get", rpcWalletGet);
  initializer.registerRpc("tpx_wallet_claim_run_reward", rpcWalletClaimRunReward);
  initializer.registerRpc("tpx_shop_purchase_theme", rpcShopPurchaseTheme);
  initializer.registerRpc("tpx_shop_equip_theme", rpcShopEquipTheme);
  initializer.registerRpc("tpx_shop_rent_theme_ad", rpcShopRentThemeAd);
  initializer.registerRpc("tpx_shop_purchase_powerup", rpcShopPurchasePowerup);
  initializer.registerRpc("tpx_shop_consume_powerup", rpcShopConsumePowerup);
  initializer.registerRpc("tpx_account_magic_link_start", rpcAccountMagicLinkStart);
  initializer.registerRpc("tpx_account_magic_link_complete", rpcAccountMagicLinkComplete);
  initializer.registerRpc("tpx_account_magic_link_status", rpcAccountMagicLinkStatus);
  initializer.registerRpc("tpx_account_magic_link_notify", rpcAccountMagicLinkNotify);
  initializer.registerRpc("tpx_account_username_status", rpcAccountUsernameStatus);
  initializer.registerRpc("tpx_account_update_username", rpcAccountUpdateUsername);
  initializer.registerRpc("tpx_account_merge_code", rpcAccountMergeCode);
  initializer.registerRpc("tpx_account_merge_redeem", rpcAccountMergeRedeem);
  initializer.registerRpc("tpx_client_event_track", rpcClientEventTrack);

  initializer.registerBeforeAuthenticateCustom(beforeAuthenticateCustom);
  initializer.registerBeforeAuthenticateDevice(beforeAuthenticateDevice);
  initializer.registerAfterAuthenticateCustom(afterAuthenticateCustom);
  initializer.registerAfterAuthenticateDevice(afterAuthenticateDevice);

  logger.info(
    "Color Crunch Nakama module loaded. Leaderboards open=%s pure=%s",
    MODULE_CONFIG.leaderboardIds.open,
    MODULE_CONFIG.leaderboardIds.pure
  );
}

function loadConfig(ctx) {
  var env = (ctx && ctx.env) || {};

  var timeout = toInt(env.TPX_HTTP_TIMEOUT_MS, 5000);
  if (timeout <= 0) {
    timeout = 5000;
  }

  return {
    leaderboardIds: {
      open:
        env.COLOR_CRUNCH_LEADERBOARD_ID_OPEN ||
        env.COLOR_CRUNCH_LEADERBOARD_ID ||
        DEFAULT_LEADERBOARD_ID_OPEN,
      pure:
        env.COLOR_CRUNCH_LEADERBOARD_ID_PURE ||
        DEFAULT_LEADERBOARD_ID_PURE,
    },
    authUrl: env.TPX_PLATFORM_AUTH_URL || "",
    eventUrl: env.TPX_PLATFORM_EVENT_URL || "",
    telemetryEventsUrl:
      env.TPX_PLATFORM_TELEMETRY_EVENTS_URL ||
      env.TPX_PLATFORM_TELEMETRY_URL ||
      "",
    identityNakamaAuthUrl: env.TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL || "",
    iapVerifyUrl: env.TPX_PLATFORM_IAP_VERIFY_URL || "",
    iapEntitlementsUrl: env.TPX_PLATFORM_IAP_ENTITLEMENTS_URL || "",
    iapCoinsAdjustUrl: env.TPX_PLATFORM_IAP_COINS_ADJUST_URL || "",
    accountMergeCodeUrl: env.TPX_PLATFORM_ACCOUNT_MERGE_CODE_URL || "",
    accountMergeRedeemUrl: env.TPX_PLATFORM_ACCOUNT_MERGE_REDEEM_URL || "",
    accountMagicLinkStartUrl: env.TPX_PLATFORM_MAGIC_LINK_START_URL || "",
    accountMagicLinkCompleteUrl: env.TPX_PLATFORM_MAGIC_LINK_COMPLETE_URL || "",
    usernameValidateUrl: env.TPX_PLATFORM_USERNAME_VALIDATE_URL || "",
    internalServiceKey: env.TPX_PLATFORM_INTERNAL_KEY || "",
    usernameModerationFailOpen: toBool(env.TPX_USERNAME_MODERATION_FAIL_OPEN, false),
    usernameChangeCooldownSeconds: toInt(
      env.TPX_USERNAME_CHANGE_COOLDOWN_SECONDS,
      DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS
    ),
    usernameChangeMaxPerDay: toInt(
      env.TPX_USERNAME_CHANGE_MAX_PER_DAY,
      DEFAULT_USERNAME_CHANGE_MAX_PER_DAY
    ),
    magicLinkNotifySecret: env.TPX_MAGIC_LINK_NOTIFY_SECRET || "",
    magicLinkNotifyRequireTimestamp: toBool(env.TPX_MAGIC_LINK_NOTIFY_REQUIRE_TIMESTAMP, true),
    magicLinkNotifyMaxSkewSeconds: Math.max(
      30,
      toInt(env.TPX_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS, DEFAULT_MAGIC_LINK_NOTIFY_MAX_SKEW_SECONDS)
    ),
    shopMaxPurchaseQuantity: Math.max(
      1,
      Math.min(100, toInt(env.TPX_SHOP_MAX_PURCHASE_QUANTITY, DEFAULT_SHOP_MAX_PURCHASE_QUANTITY))
    ),
    maxRunRewardsPerDay: Math.max(
      1,
      Math.min(200, toInt(env.TPX_MAX_RUN_REWARDS_PER_DAY, DEFAULT_MAX_RUN_REWARDS_PER_DAY))
    ),
    usernameChangeCostCoins: toInt(
      env.TPX_USERNAME_CHANGE_COST_COINS,
      DEFAULT_USERNAME_CHANGE_COST_COINS
    ),
    blockedUsernameTokens: parseBlockedUsernameTokens(
      env.TPX_USERNAME_BLOCKLIST,
      DEFAULT_BLOCKED_USERNAME_TOKENS
    ),
    gameId: env.TPX_GAME_ID || DEFAULT_GAME_ID,
    exportTarget: String(env.TPX_EXPORT_TARGET || "web").trim().toLowerCase(),
    apiKey: env.TPX_PLATFORM_API_KEY || "",
    httpTimeoutMs: timeout,
  };
}

function ensureLeaderboard(nk, logger, leaderboardIds) {
  ensureLeaderboardOne(
    nk,
    logger,
    String(leaderboardIds.open || "").trim(),
    { game: "Color Crunch", platform: "terapixel", mode: "open" }
  );
  ensureLeaderboardOne(
    nk,
    logger,
    String(leaderboardIds.pure || "").trim(),
    { game: "Color Crunch", platform: "terapixel", mode: "pure" }
  );
}

function ensureLeaderboardOne(nk, logger, leaderboardId, metadata) {
  if (!leaderboardId) {
    return;
  }
  try {
    nk.leaderboardCreate(
      leaderboardId,
      true,
      "descending",
      "best",
      null,
      metadata || {},
      true
    );
    logger.info("Created leaderboard %s", leaderboardId);
  } catch (err) {
    logger.info(
      "Leaderboard %s already exists or could not be created: %s",
      leaderboardId,
      err
    );
  }
}

function beforeAuthenticateCustom(ctx, logger, nk, request) {
  var externalId = request && request.account ? request.account.id || "" : "";
  verifyPlatformAuth(nk, logger, "custom", externalId, request.username || "");
  return request;
}

function beforeAuthenticateDevice(ctx, logger, nk, request) {
  var externalId = request && request.account ? request.account.id || "" : "";
  verifyPlatformAuth(nk, logger, "device", externalId, request.username || "");
  return request;
}

function afterAuthenticateCustom(ctx, logger, nk, session, request) {
  publishPlatformEvent(
    nk,
    logger,
    "auth_success",
    {
      provider: "custom",
      externalId: request && request.account ? request.account.id || "" : "",
      username: request && request.username ? request.username : "",
      created: session && session.created ? true : false,
    },
    ctx
  );
}

function afterAuthenticateDevice(ctx, logger, nk, session, request) {
  publishPlatformEvent(
    nk,
    logger,
    "auth_success",
    {
      provider: "device",
      externalId: request && request.account ? request.account.id || "" : "",
      username: request && request.username ? request.username : "",
      created: session && session.created ? true : false,
    },
    ctx
  );
}

function verifyPlatformAuth(nk, logger, provider, externalId, username) {
  if (!MODULE_CONFIG.authUrl) {
    if (provider === "custom") {
      logger.error(
        "Platform auth URL is required for custom auth. Set TPX_PLATFORM_AUTH_URL."
      );
      throw new Error("Custom authentication is not configured.");
    }
    return;
  }

  var headers = { "Content-Type": "application/json" };
  if (MODULE_CONFIG.apiKey) {
    headers.Authorization = "Bearer " + MODULE_CONFIG.apiKey;
  }

  var body = JSON.stringify({
    provider: provider,
    externalId: externalId,
    username: username,
    source: "colorcrunch-nakama",
  });

  var response = nk.httpRequest(
    MODULE_CONFIG.authUrl,
    "post",
    headers,
    body,
    MODULE_CONFIG.httpTimeoutMs,
    false
  );

  if (response.code < 200 || response.code >= 300) {
    logger.warn(
      "Platform auth verification rejected (%s) for provider=%s externalId=%s",
      response.code,
      provider,
      externalId
    );
    throw new Error("Authentication rejected by Terapixel platform.");
  }
}

function rpcSubmitScore(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);

  var data = parsePayload(payload);
  var score = toInt(data.score, NaN);
  if (!isFinite(score) || score < 0) {
    throw new Error("score must be a non-negative integer");
  }
  var mode = normalizeLeaderboardMode(data.mode || data.leaderboard_mode);
  var leaderboardId = leaderboardIdForMode(mode);
  var powerupsUsed = toInt(data.powerups_used, 0);
  if (!isFinite(powerupsUsed) || powerupsUsed < 0) {
    throw new Error("powerups_used must be a non-negative integer");
  }
  var coinsSpent = toInt(data.coins_spent, 0);
  if (!isFinite(coinsSpent) || coinsSpent < 0) {
    throw new Error("coins_spent must be a non-negative integer");
  }
  var runId = normalizeRunId(data.run_id || "");
  var runDurationMs = toInt(data.run_duration_ms, -1);
  if (runDurationMs < 0) {
    runDurationMs = -1;
  }

  var metadata = data.metadata;
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) {
    metadata = {};
  }
  if (!runId) {
    runId = normalizeRunId(metadata.run_id || "");
  }
  if (runDurationMs < 0) {
    runDurationMs = toInt(metadata.run_duration_ms, -1);
    if (runDurationMs < 0) {
      runDurationMs = -1;
    }
  }
  metadata.mode = mode.toUpperCase();
  metadata.powerups_used = powerupsUsed;
  metadata.coins_spent = coinsSpent;
  if (runId) {
    metadata.run_id = runId;
  }
  if (runDurationMs >= 0) {
    metadata.run_duration_ms = runDurationMs;
  }

  var flaggedReasons = [];
  if (mode === "pure" && powerupsUsed > 0) {
    flaggedReasons.push("pure_with_powerups_used");
  }
  if (mode === "pure" && coinsSpent > 0) {
    flaggedReasons.push("pure_with_coins_spent");
  }
  var metadataPowerupsUsed = extractMetadataPowerupsUsed(metadata);
  if (mode === "pure" && metadataPowerupsUsed > 0) {
    flaggedReasons.push("pure_with_metadata_powerups");
  }
  if (flaggedReasons.length > 0) {
    logger.warn(
      "Suspicious score submission flagged. userId=%s mode=%s reasons=%s runId=%s",
      ctx.userId,
      mode,
      flaggedReasons.join(","),
      runId
    );
    publishPlatformEvent(
      nk,
      logger,
      "score_submission_flagged",
      {
        leaderboardId: leaderboardId,
        mode: mode,
        score: score,
        powerups_used: powerupsUsed,
        coins_spent: coinsSpent,
        metadata_powerups_used: metadataPowerupsUsed,
        reasons: flaggedReasons,
        run_id: runId,
      },
      ctx
    );
  }
  if (mode === "pure" && powerupsUsed > 0) {
    throw new Error("PURE mode submissions cannot include powerups_used > 0");
  }
  var subscore = Math.max(0, LEADERBOARD_SUBSCORE_BASE - powerupsUsed);

  var currentUsername = resolveCurrentUsername(nk, ctx);
  var record = nk.leaderboardRecordWrite(
    leaderboardId,
    ctx.userId,
    currentUsername,
    score,
    subscore,
    metadata,
    "best"
  );

  writePlayerHighScore(nk, ctx.userId, record);
  if (runId) {
    recordRunSubmission(nk, ctx.userId, runId, score, mode);
  }

  publishPlatformEvent(
    nk,
    logger,
    "score_submitted",
    {
      leaderboardId: leaderboardId,
      mode: mode,
      score: record.score,
      subscore: record.subscore,
      rank: record.rank,
      metadata: metadata,
    },
    ctx
  );

  return JSON.stringify({
    leaderboardId: leaderboardId,
    leaderboardMode: mode.toUpperCase(),
    record: record,
  });
}

function resolveCurrentUsername(nk, ctx) {
  var fallback = String((ctx && ctx.username) || "").trim();
  if (!ctx || !ctx.userId) {
    return fallback;
  }
  try {
    var users = nk.usersGetId([ctx.userId]);
    if (users && users.length > 0) {
      var user = users[0] || {};
      var liveUsername = String(user.username || "").trim();
      if (liveUsername) {
        return liveUsername;
      }
    }
  } catch (_err) {
    // Fall back to session username if user lookup fails.
  }
  return fallback;
}

function rpcGetMyHighScore(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var mode = normalizeLeaderboardMode(data.mode || data.leaderboard_mode);
  var leaderboardId = leaderboardIdForMode(mode);

  var records = nk.leaderboardRecordsList(
    leaderboardId,
    [ctx.userId],
    1
  );
  var ownerRecord = null;
  if (records.ownerRecords && records.ownerRecords.length > 0) {
    ownerRecord = records.ownerRecords[0];
  } else if (records.records && records.records.length > 0) {
    ownerRecord = records.records[0];
  }

  var storage = nk.storageRead([
    {
      collection: PLAYER_STATS_COLLECTION,
      key: PLAYER_STATS_KEY,
      userId: ctx.userId,
    },
  ]);

  return JSON.stringify({
    leaderboardId: leaderboardId,
    leaderboardMode: mode.toUpperCase(),
    highScore: ownerRecord,
    playerStats:
      storage && storage.length > 0 && storage[0].value ? storage[0].value : {},
  });
}

function rpcListLeaderboard(ctx, logger, nk, payload) {
  var data = parsePayload(payload);
  var mode = normalizeLeaderboardMode(data.mode || data.leaderboard_mode);
  var leaderboardId = leaderboardIdForMode(mode);
  var limit = toInt(data.limit, 25);
  if (!isFinite(limit) || limit <= 0) {
    limit = 25;
  }
  if (limit > 100) {
    limit = 100;
  }

  var cursor =
    typeof data.cursor === "string" && data.cursor.length > 0
      ? data.cursor
      : undefined;

  var list = nk.leaderboardRecordsList(
    leaderboardId,
    undefined,
    limit,
    cursor
  );

  return JSON.stringify({
    leaderboardId: leaderboardId,
    leaderboardMode: mode.toUpperCase(),
    records: list.records || [],
    nextCursor: list.nextCursor || "",
    prevCursor: list.prevCursor || "",
    rankCount: list.rankCount || 0,
  });
}

function rpcIapPurchaseStart(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertIapConfigured("purchase verify");

  var data = parsePayload(payload);
  var productId = String(data.product_id || "").trim().toLowerCase();
  if (!productId) {
    throw new Error("product_id is required");
  }
  var provider = String(data.provider || providerForExportTarget(MODULE_CONFIG.exportTarget))
    .trim()
    .toLowerCase();
  if (!provider) {
    provider = "web";
  }

  var platformSession = exchangePlatformSession(ctx, nk);
  var body = {
    game_id: MODULE_CONFIG.gameId,
    provider: provider,
    product_id: productId,
    export_target: String(data.export_target || MODULE_CONFIG.exportTarget || "web")
      .trim()
      .toLowerCase(),
    payload: normalizeObject(data.payload),
  };
  var response = platformPost(
    nk,
    MODULE_CONFIG.iapVerifyUrl,
    body,
    "",
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    logger.warn(
      "IAP purchase verify failed. code=%s userId=%s productId=%s",
      response.code,
      ctx.userId,
      productId
    );
    throw new Error("iap purchase verify failed");
  }

  var parsed = parseHttpResponseJson(response.body);
  if (!parsed || typeof parsed !== "object") {
    throw new Error("invalid iap response");
  }
  var entitlements = parsed.entitlements || {};
  persistIapSnapshot(nk, ctx.userId, entitlements);
  return JSON.stringify({
    provider: provider,
    productId: productId,
    purchase: parsed.purchase || {},
    entitlements: entitlements,
    deduplicated: parsed.deduplicated === true,
  });
}

function rpcIapSyncEntitlements(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertIapConfigured("entitlement sync");
  var result = fetchAndPersistEntitlements(ctx, logger, nk);
  return JSON.stringify(result);
}

function rpcIapGetEntitlements(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var forceRefresh = Boolean(data.force_refresh);
  if (forceRefresh) {
    assertIapConfigured("entitlement fetch");
    var synced = fetchAndPersistEntitlements(ctx, logger, nk);
    return JSON.stringify(synced);
  }

  var storage = nk.storageRead([
    {
      collection: IAP_COLLECTION,
      key: IAP_KEY,
      userId: ctx.userId,
    },
  ]);
  var entitlements = {};
  var updatedAt = 0;
  if (storage && storage.length > 0 && storage[0].value) {
    entitlements = storage[0].value.entitlements || {};
    updatedAt = toInt(storage[0].value.updatedAt, 0);
  }
  return JSON.stringify({
    gameId: MODULE_CONFIG.gameId,
    entitlements: entitlements,
    coinBalance: extractCoinBalance(entitlements, MODULE_CONFIG.gameId),
    updatedAt: updatedAt,
  });
}

function rpcWalletGet(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var forceRefresh = Boolean(data.force_refresh);
  var entitlements = {};
  var updatedAt = 0;
  if (forceRefresh) {
    assertIapConfigured("wallet fetch");
    var synced = fetchAndPersistEntitlements(ctx, logger, nk);
    entitlements = synced.entitlements;
    updatedAt = synced.updatedAt;
  } else {
    var storage = nk.storageRead([
      {
        collection: IAP_COLLECTION,
        key: IAP_KEY,
        userId: ctx.userId,
      },
    ]);
    if (storage && storage.length > 0 && storage[0].value) {
      entitlements = storage[0].value.entitlements || {};
      updatedAt = toInt(storage[0].value.updatedAt, 0);
    }
  }
  var shopState = readOrInitShopState(nk, ctx.userId);
  return JSON.stringify({
    gameId: MODULE_CONFIG.gameId,
    entitlements: entitlements,
    coinBalance: extractCoinBalance(entitlements, MODULE_CONFIG.gameId),
    shop: shopState,
    updatedAt: updatedAt,
  });
}

function rpcWalletClaimRunReward(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertIapConfigured("wallet reward claim");
  var data = parsePayload(payload);
  var runId = normalizeRunId(data.run_id || "");
  if (!runId) {
    throw new Error("run_id is required");
  }
  var now = Math.floor(Date.now() / 1000);
  var runHistory = readRunHistory(nk, ctx.userId);
  var runEntry = findRunHistoryEntry(runHistory, runId);
  if (!runEntry) {
    return JSON.stringify({
      granted: false,
      rewardCoins: 0,
      coinBalance: extractCoinBalance(fetchCachedEntitlements(nk, ctx.userId), MODULE_CONFIG.gameId),
      reason: "unknown_run_id",
    });
  }
  if (toInt(runEntry.rewardClaimedAt, 0) > 0) {
    return JSON.stringify({
      granted: false,
      rewardCoins: 0,
      coinBalance: extractCoinBalance(fetchCachedEntitlements(nk, ctx.userId), MODULE_CONFIG.gameId),
      reason: "already_claimed",
      deduplicated: true,
    });
  }
  var claimedCount = countRunRewardsClaimedSince(runHistory, now - 86400);
  if (claimedCount >= MODULE_CONFIG.maxRunRewardsPerDay) {
    return JSON.stringify({
      granted: false,
      rewardCoins: 0,
      coinBalance: extractCoinBalance(fetchCachedEntitlements(nk, ctx.userId), MODULE_CONFIG.gameId),
      reason: "daily_limit_reached",
    });
  }
  var authoritativeScore = Math.max(0, toInt(runEntry.score, 0));
  var reward = calculateRunReward(authoritativeScore, 0, true, false);
  if (reward <= 0) {
    return JSON.stringify({
      granted: false,
      rewardCoins: 0,
      coinBalance: extractCoinBalance(fetchCachedEntitlements(nk, ctx.userId), MODULE_CONFIG.gameId),
      reason: "no_reward",
    });
  }
  var adjust = adjustCoinsPlatform(
    ctx,
    nk,
    reward,
    "run_reward",
    "run_reward:" + ctx.userId + ":" + runId
  );
  persistIapSnapshot(nk, ctx.userId, adjust.entitlements || {});
  markRunRewardClaimed(nk, ctx.userId, runId, now, reward);
  return JSON.stringify({
    granted: true,
    rewardCoins: reward,
    coinBalance: extractCoinBalance(adjust.entitlements || {}, MODULE_CONFIG.gameId),
    deduplicated: adjust.deduplicated === true,
  });
}

function rpcShopPurchaseTheme(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertIapConfigured("theme purchase");
  var data = parsePayload(payload);
  var themeId = String(data.theme_id || "").trim().toLowerCase();
  if (!themeId) {
    throw new Error("theme_id is required");
  }
  var cost = toInt(THEME_COSTS[themeId], 0);
  if (cost <= 0) {
    throw new Error("invalid theme cost");
  }
  var shopState = readOrInitShopState(nk, ctx.userId);
  if (hasThemeAccess(shopState, themeId)) {
    return JSON.stringify({
      purchased: false,
      alreadyOwned: true,
      shop: shopState,
      coinBalance: extractCoinBalance(fetchCachedEntitlements(nk, ctx.userId), MODULE_CONFIG.gameId),
    });
  }
  var adjust = adjustCoinsPlatform(
    ctx,
    nk,
    -cost,
    "theme_purchase:" + themeId,
    "theme_purchase:" + ctx.userId + ":" + themeId
  );
  persistIapSnapshot(nk, ctx.userId, adjust.entitlements || {});
  addOwnedTheme(shopState, themeId);
  shopState.equippedTheme = themeId;
  writeShopState(nk, ctx.userId, shopState);
  return JSON.stringify({
    purchased: true,
    themeId: themeId,
    shop: shopState,
    coinBalance: extractCoinBalance(adjust.entitlements || {}, MODULE_CONFIG.gameId),
  });
}

function rpcShopEquipTheme(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var themeId = String(data.theme_id || "").trim().toLowerCase();
  if (!themeId) {
    throw new Error("theme_id is required");
  }
  var shopState = readOrInitShopState(nk, ctx.userId);
  if (!hasThemeAccess(shopState, themeId)) {
    throw new Error("theme is not owned");
  }
  shopState.equippedTheme = themeId;
  writeShopState(nk, ctx.userId, shopState);
  return JSON.stringify({
    equipped: true,
    themeId: themeId,
    shop: shopState,
  });
}

function rpcShopRentThemeAd(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var themeId = String(data.theme_id || "").trim().toLowerCase();
  if (!themeId) {
    throw new Error("theme_id is required");
  }
  var now = Math.floor(Date.now() / 1000);
  var expiresAt = now + (24 * 60 * 60);
  var shopState = readOrInitShopState(nk, ctx.userId);
  if (!shopState.themeRentals || typeof shopState.themeRentals !== "object") {
    shopState.themeRentals = {};
  }
  shopState.themeRentals[themeId] = expiresAt;
  shopState.equippedTheme = themeId;
  writeShopState(nk, ctx.userId, shopState);
  return JSON.stringify({
    rented: true,
    themeId: themeId,
    expiresAt: expiresAt,
    shop: shopState,
  });
}

function rpcShopPurchasePowerup(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertIapConfigured("powerup purchase");
  var data = parsePayload(payload);
  var powerupType = String(data.powerup_type || "").trim().toLowerCase();
  if (!powerupType) {
    throw new Error("powerup_type is required");
  }
  var qty = toInt(data.quantity, 1);
  if (qty <= 0) {
    qty = 1;
  }
  var maxQty = Math.max(1, toInt(MODULE_CONFIG.shopMaxPurchaseQuantity, DEFAULT_SHOP_MAX_PURCHASE_QUANTITY));
  if (qty > maxQty) {
    throw new Error("quantity exceeds max allowed");
  }
  var unitCost = toInt(POWERUP_COSTS[powerupType], 0);
  if (unitCost <= 0) {
    throw new Error("invalid powerup cost");
  }
  var totalCost = unitCost * qty;
  var purchaseId = sanitizeIdempotencyFragment(data.purchase_id || "", 64);
  var idempotency =
    "powerup_purchase:" +
    ctx.userId +
    ":" +
    powerupType +
    ":" +
    String(qty) +
    ":" +
    purchaseId;
  var adjust = adjustCoinsPlatform(
    ctx,
    nk,
    -totalCost,
    "powerup_purchase:" + powerupType,
    idempotency
  );
  persistIapSnapshot(nk, ctx.userId, adjust.entitlements || {});
  var shopState = readOrInitShopState(nk, ctx.userId);
  if (!shopState.powerups || typeof shopState.powerups !== "object") {
    shopState.powerups = {};
  }
  var current = toInt(shopState.powerups[powerupType], 0);
  shopState.powerups[powerupType] = current + qty;
  writeShopState(nk, ctx.userId, shopState);
  return JSON.stringify({
    purchased: true,
    powerupType: powerupType,
    quantity: qty,
    shop: shopState,
    coinBalance: extractCoinBalance(adjust.entitlements || {}, MODULE_CONFIG.gameId),
  });
}

function rpcShopConsumePowerup(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var powerupType = String(data.powerup_type || "").trim().toLowerCase();
  if (!powerupType) {
    throw new Error("powerup_type is required");
  }
  var qty = toInt(data.quantity, 1);
  if (qty <= 0) {
    qty = 1;
  }
  var shopState = readOrInitShopState(nk, ctx.userId);
  if (!shopState.powerups || typeof shopState.powerups !== "object") {
    shopState.powerups = {};
  }
  var current = toInt(shopState.powerups[powerupType], 0);
  var consumed = Math.min(current, qty);
  shopState.powerups[powerupType] = Math.max(0, current - consumed);
  writeShopState(nk, ctx.userId, shopState);
  return JSON.stringify({
    consumed: consumed,
    remaining: toInt(shopState.powerups[powerupType], 0),
    shop: shopState,
  });
}

function rpcAccountMagicLinkStart(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var email = sanitizeEmailAddress(data.email || "");
  if (!email) {
    throw new Error("valid email is required");
  }
  var startUrl =
    MODULE_CONFIG.accountMagicLinkStartUrl ||
    ((ctx && ctx.env && ctx.env.TPX_PLATFORM_MAGIC_LINK_START_URL) || "");
  if (!startUrl) {
    throw new Error("magic link start URL is not configured");
  }
  clearMagicLinkStatus(nk, ctx.userId);
  writeMagicLinkPending(nk, ctx.userId, {
    email: email,
    startedAt: Math.floor(Date.now() / 1000),
  });
  writeMagicLinkLookupByEmail(nk, email, ctx.userId);
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = platformPost(
    nk,
    startUrl,
    {
      email: email,
      game_id: MODULE_CONFIG.gameId,
      nakama_user_id: ctx.userId,
    },
    "",
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to start magic link: " + extractHttpErrorDetail(response));
  }
  var parsed = parseHttpResponseJson(response.body);
  return JSON.stringify(parsed || { ok: true });
}

function rpcAccountMagicLinkComplete(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var token = sanitizeMagicLinkToken(data.ml_token || data.magic_link_token || "");
  if (!token) {
    throw new Error("ml_token is required");
  }
  var completeUrl =
    MODULE_CONFIG.accountMagicLinkCompleteUrl ||
    ((ctx && ctx.env && ctx.env.TPX_PLATFORM_MAGIC_LINK_COMPLETE_URL) || "");
  if (!completeUrl) {
    throw new Error("magic link complete URL is not configured");
  }
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = platformPost(
    nk,
    completeUrl,
    {
      ml_token: token,
    },
    "",
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to complete magic link: " + extractHttpErrorDetail(response));
  }
  return JSON.stringify(parseHttpResponseJson(response.body) || {});
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
    logger.warn(
      "magic_link_notify rejected: invalid payload shape=%s err=%s",
      describePayloadShape(payload),
      String(err || "")
    );
    throw err;
  }
  logger.info("magic_link_notify received: %s", summarizeMagicLinkNotifyPayload(data));
  var expectedSecret =
    String(MODULE_CONFIG.magicLinkNotifySecret || "").trim() ||
    String((ctx && ctx.env && ctx.env.TPX_MAGIC_LINK_NOTIFY_SECRET) || "").trim();
  if (!expectedSecret) {
    logger.error("magic_link_notify rejected: notify secret is not configured (env=TPX_MAGIC_LINK_NOTIFY_SECRET)");
    throw new Error("magic link notify secret is not configured (set TPX_MAGIC_LINK_NOTIFY_SECRET)");
  }
  var providedSecret = String(data.secret || "").trim();
  if (!providedSecret || !secureEquals(providedSecret, expectedSecret)) {
    logger.warn("magic_link_notify rejected: invalid secret. payload=%s", summarizeMagicLinkNotifyPayload(data));
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
    logger.warn("magic_link_notify rejected: could not resolve user id. payload=%s", summarizeMagicLinkNotifyPayload(data));
    throw new Error("nakama_user_id is required");
  }
  var incomingGameId = String(data.game_id || data.gameId || "").trim().toLowerCase();
  if (incomingGameId && incomingGameId !== String(MODULE_CONFIG.gameId || "").trim().toLowerCase()) {
    logger.warn(
      "magic_link_notify rejected: game_id mismatch. incoming=%s expected=%s payload=%s",
      incomingGameId,
      String(MODULE_CONFIG.gameId || "").trim().toLowerCase(),
      summarizeMagicLinkNotifyPayload(data)
    );
    throw new Error("game_id mismatch");
  }
  var status = String(data.status || data.link_status || "").trim().toLowerCase();
  if (!status) {
    logger.warn("magic_link_notify rejected: missing status. payload=%s", summarizeMagicLinkNotifyPayload(data));
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
  logger.info(
    "magic_link_notify stored status for userId=%s status=%s gameId=%s source=%s primaryProfileId=%s secondaryProfileId=%s",
    userId,
    row.status,
    incomingGameId || String(MODULE_CONFIG.gameId || ""),
    resolved.source || "",
    row.primaryProfileId || "",
    row.secondaryProfileId || ""
  );
  return JSON.stringify({
    ok: true,
    userId: userId,
    status: row.status,
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
  var moderation = validateUsernameModeration(nk, logger, normalized);
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
  var isFreeChange = !state.hasUsedFreeChange;
  var coinCost = isFreeChange ? 0 : Math.max(0, MODULE_CONFIG.usernameChangeCostCoins);
  var coinBalance = extractCoinBalance(fetchCachedEntitlements(nk, ctx.userId), MODULE_CONFIG.gameId);
  var updatedCoinBalance = coinBalance;
  if (coinCost > 0) {
    assertIapConfigured("username change");
    var charge = adjustCoinsPlatform(
      ctx,
      nk,
      -coinCost,
      "username_change",
      "username_change:" + ctx.userId + ":" + normalized
    );
    persistIapSnapshot(nk, ctx.userId, charge.entitlements || {});
    updatedCoinBalance = extractCoinBalance(charge.entitlements || {}, MODULE_CONFIG.gameId);
  }

  try {
    nk.accountUpdateId(ctx.userId, normalized, null, null, null, null, null, null);
  } catch (err) {
    if (coinCost > 0) {
      try {
        var refund = adjustCoinsPlatform(
          ctx,
          nk,
          coinCost,
          "username_change_refund",
          "username_change_refund:" + ctx.userId + ":" + normalized
        );
        persistIapSnapshot(nk, ctx.userId, refund.entitlements || {});
        updatedCoinBalance = extractCoinBalance(refund.entitlements || {}, MODULE_CONFIG.gameId);
      } catch (_refundErr) {
        logger.warn("username change refund failed for userId=%s", ctx.userId);
      }
    }
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
  appendUsernameAudit(nk, ctx.userId, {
    at: now,
    oldUsername: currentNormalized,
    newUsername: normalized,
    coinCost: coinCost,
    moderationSource: moderation.source || "unknown",
  });

  return JSON.stringify({
    ok: true,
    changed: true,
    username: normalized,
    coinCost: coinCost,
    coinBalance: updatedCoinBalance,
    usernamePolicy: buildUsernameStatusResponse(state),
  });
}

function rpcAccountMergeCode(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertMergeConfigured("create merge code");
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = platformPost(
    nk,
    MODULE_CONFIG.accountMergeCodeUrl,
    {},
    "",
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to create merge code");
  }
  var parsed = parseHttpResponseJson(response.body);
  return JSON.stringify({
    merge_code: parsed.merge_code || "",
    expires_at: parsed.expires_at || 0,
  });
}

function rpcAccountMergeRedeem(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  assertMergeConfigured("redeem merge code");
  var data = parsePayload(payload);
  var mergeCode = String(data.merge_code || "").trim();
  if (!mergeCode) {
    throw new Error("merge_code is required");
  }
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = platformPost(
    nk,
    MODULE_CONFIG.accountMergeRedeemUrl,
    { merge_code: mergeCode },
    "",
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("failed to redeem merge code");
  }
  var parsed = parseHttpResponseJson(response.body);
  return JSON.stringify(parsed || {});
}

function rpcClientEventTrack(ctx, logger, nk, payload) {
  assertAuthenticated(ctx);
  var data = parsePayload(payload);
  var eventName = normalizeClientEventName(data.event_name || data.eventName || "");
  if (!eventName) {
    throw new Error("event_name is required");
  }
  var eventTime = toInt(
    data.event_time || data.eventTime,
    Math.floor(Date.now() / 1000)
  );
  var eventProperties = ensurePlainObject(data.properties, {});
  var requestPayload = {
    eventName: eventName,
    eventTime: eventTime,
    sessionId: String(data.session_id || data.sessionId || "").trim(),
    seq: toInt(data.seq, -1),
    properties: eventProperties,
  };

  if (!MODULE_CONFIG.telemetryEventsUrl && !MODULE_CONFIG.eventUrl) {
    return JSON.stringify({
      ok: true,
      accepted: false,
      transport: "none",
      reason: "no_platform_event_endpoint_configured",
      event_name: requestPayload.eventName,
    });
  }

  if (MODULE_CONFIG.telemetryEventsUrl) {
    var platformSession = exchangePlatformSession(ctx, nk);
    var telemetryResponse = platformPost(
      nk,
      MODULE_CONFIG.telemetryEventsUrl,
      {
        game_id: MODULE_CONFIG.gameId,
        profile_id: String((ctx && ctx.userId) || "").trim(),
        session_id: requestPayload.sessionId,
        events: [
          {
            event_name: requestPayload.eventName,
            event_time: requestPayload.eventTime,
            seq: requestPayload.seq >= 0 ? requestPayload.seq : undefined,
            properties: withClientEventContext(ctx, requestPayload.properties),
          },
        ],
      },
      "",
      platformSession
    );
    if (telemetryResponse.code < 200 || telemetryResponse.code >= 300) {
      throw new Error(
        "failed to ingest client telemetry: " +
          extractHttpErrorDetail(telemetryResponse)
      );
    }
    return JSON.stringify({
      ok: true,
      transport: "telemetry",
      event_name: requestPayload.eventName,
    });
  }

  publishPlatformEvent(
    nk,
    logger,
    "client_event",
    {
      eventName: requestPayload.eventName,
      eventTime: requestPayload.eventTime,
      sessionId: requestPayload.sessionId,
      seq: requestPayload.seq,
      properties: withClientEventContext(ctx, requestPayload.properties),
    },
    ctx
  );
  return JSON.stringify({
    ok: true,
    transport: "event",
    event_name: requestPayload.eventName,
  });
}

function writePlayerHighScore(nk, userId, record) {
  nk.storageWrite([
    {
      collection: PLAYER_STATS_COLLECTION,
      key: PLAYER_STATS_KEY,
      userId: userId,
      value: {
        bestScore: record.score,
        bestSubscore: record.subscore,
        rank: record.rank,
        leaderboardId: record.leaderboardId,
        updatedAt: record.updateTime,
      },
      permissionRead: 1,
      permissionWrite: 0,
    },
  ]);
}

function publishPlatformEvent(nk, logger, eventType, payload, ctx) {
  if (!MODULE_CONFIG.eventUrl) {
    return;
  }

  var headers = { "Content-Type": "application/json" };
  if (MODULE_CONFIG.apiKey) {
    headers.Authorization = "Bearer " + MODULE_CONFIG.apiKey;
  }

  var body = JSON.stringify({
    eventType: eventType,
    source: "colorcrunch-nakama",
    occurredAtUnix: Math.floor(Date.now() / 1000),
    userId: ctx && ctx.userId ? ctx.userId : "",
    username: ctx && ctx.username ? ctx.username : "",
    payload: payload,
  });

  try {
    var response = nk.httpRequest(
      MODULE_CONFIG.eventUrl,
      "post",
      headers,
      body,
      MODULE_CONFIG.httpTimeoutMs,
      false
    );
    if (response.code < 200 || response.code >= 300) {
      logger.warn(
        "Platform event not accepted. code=%s eventType=%s",
        response.code,
        eventType
      );
    }
  } catch (err) {
    logger.warn("Platform event publish failed. eventType=%s err=%s", eventType, err);
  }
}

function fetchAndPersistEntitlements(ctx, logger, nk) {
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = nk.httpRequest(
    MODULE_CONFIG.iapEntitlementsUrl,
    "get",
    {
      Authorization: "Bearer " + platformSession,
      "Content-Type": "application/json",
    },
    "",
    MODULE_CONFIG.httpTimeoutMs,
    false
  );

  if (response.code < 200 || response.code >= 300) {
    logger.warn(
      "IAP entitlement fetch failed. code=%s userId=%s",
      response.code,
      ctx.userId
    );
    throw new Error("iap entitlement fetch failed");
  }
  var parsed = parseHttpResponseJson(response.body);
  persistIapSnapshot(nk, ctx.userId, parsed || {});
  return {
    gameId: MODULE_CONFIG.gameId,
    entitlements: parsed || {},
    coinBalance: extractCoinBalance(parsed || {}, MODULE_CONFIG.gameId),
    updatedAt: Math.floor(Date.now() / 1000),
  };
}

function fetchCachedEntitlements(nk, userId) {
  var storage = nk.storageRead([
    {
      collection: IAP_COLLECTION,
      key: IAP_KEY,
      userId: userId,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value) {
    return storage[0].value.entitlements || {};
  }
  return {};
}

function persistIapSnapshot(nk, userId, entitlements) {
  var now = Math.floor(Date.now() / 1000);
  nk.storageWrite([
    {
      collection: IAP_COLLECTION,
      key: IAP_KEY,
      userId: userId,
      value: {
        gameId: MODULE_CONFIG.gameId,
        entitlements: entitlements,
        updatedAt: now,
      },
      permissionRead: 1,
      permissionWrite: 0,
    },
  ]);
}

function exchangePlatformSession(ctx, nk) {
  var authUrl =
    MODULE_CONFIG.identityNakamaAuthUrl ||
    ((ctx && ctx.env && ctx.env.TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL) || "");
  if (!authUrl) {
    throw new Error("identity exchange URL is not configured");
  }
  var response = platformPost(
    nk,
    authUrl,
    {
      game_id: MODULE_CONFIG.gameId,
      nakama_user_id: ctx.userId,
      display_name: ctx.username || "",
    },
    "",
    ""
  );
  if (response.code < 200 || response.code >= 300) {
    throw new Error("identity exchange failed");
  }
  var parsed = parseHttpResponseJson(response.body);
  if (!parsed.session_token) {
    throw new Error("identity exchange missing session token");
  }
  var platformProfileId = String(parsed.player_id || parsed.playerId || "").trim();
  if (platformProfileId && ctx && ctx.userId) {
    writeMagicLinkLookupByProfile(nk, platformProfileId, ctx.userId);
  }
  return String(parsed.session_token);
}

function adjustCoinsPlatform(ctx, nk, delta, reason, idempotencyKey) {
  if (!MODULE_CONFIG.iapCoinsAdjustUrl) {
    throw new Error("iap coins adjust URL is not configured");
  }
  var platformSession = exchangePlatformSession(ctx, nk);
  var response = platformPost(
    nk,
    MODULE_CONFIG.iapCoinsAdjustUrl,
    {
      game_id: MODULE_CONFIG.gameId,
      delta: delta,
      reason: reason,
      idempotency_key: idempotencyKey,
    },
    "",
    platformSession
  );
  if (response.code < 200 || response.code >= 300) {
    var parsedErr = parseHttpResponseJson(response.body);
    var msg = "coin adjust failed";
    if (parsedErr && parsedErr.error && parsedErr.error.message) {
      msg = parsedErr.error.message;
    }
    throw new Error(msg);
  }
  return parseHttpResponseJson(response.body);
}

function platformPost(nk, url, body, adminKey, bearerToken) {
  var headers = { "Content-Type": "application/json" };
  if (adminKey) {
    headers["x-admin-key"] = adminKey;
  }
  if (bearerToken) {
    headers.Authorization = "Bearer " + bearerToken;
  }
  return nk.httpRequest(
    url,
    "post",
    headers,
    JSON.stringify(body || {}),
    MODULE_CONFIG.httpTimeoutMs,
    false
  );
}

function withClientEventContext(ctx, properties) {
  var out = ensurePlainObject(properties, {});
  out.nakama_user_id = String((ctx && ctx.userId) || "").trim();
  out.nakama_username = String((ctx && ctx.username) || "").trim();
  out.game_id = MODULE_CONFIG.gameId;
  out.export_target = MODULE_CONFIG.exportTarget;
  return out;
}

function normalizeClientEventName(value) {
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

function parseHttpResponseJson(body) {
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
  var parsed = parseHttpResponseJson((response && response.body) || "");
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

function normalizeObject(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return {};
  }
  return input;
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

function summarizeMagicLinkNotifyPayload(data) {
  var keys = Object.keys(normalizeObject(data)).sort();
  return JSON.stringify({
    keys: keys,
    gameId: String(data.game_id || data.gameId || "").trim(),
    nakamaUserId: String(data.nakama_user_id || data.nakamaUserId || "").trim(),
    profileId: String(data.profile_id || data.profileId || "").trim(),
    primaryProfileId: String(data.primary_profile_id || data.primaryProfileId || "").trim(),
    secondaryProfileId: String(data.secondary_profile_id || data.secondaryProfileId || "").trim(),
    status: String(data.status || data.link_status || "").trim(),
    hasSecret: String(data.secret || "").trim() ? true : false,
    hasEmail: String(data.email || "").trim() ? true : false,
  });
}

function asArray(value) {
  if (!value || !Array.isArray(value)) {
    return [];
  }
  return value;
}

function assertIapConfigured(actionLabel) {
  if (
    !MODULE_CONFIG.identityNakamaAuthUrl ||
    !MODULE_CONFIG.iapVerifyUrl ||
    !MODULE_CONFIG.iapEntitlementsUrl
  ) {
    throw new Error("IAP is not configured for " + actionLabel + ".");
  }
}

function assertMergeConfigured(actionLabel) {
  if (
    !MODULE_CONFIG.identityNakamaAuthUrl ||
    !MODULE_CONFIG.accountMergeCodeUrl ||
    !MODULE_CONFIG.accountMergeRedeemUrl
  ) {
    throw new Error("Merge is not configured for " + actionLabel + ".");
  }
}

function calculateRunReward(score, streakDays, completedByGameplay, doubleReward) {
  if (!completedByGameplay) {
    return 0;
  }
  var minScore = 60;
  if (score < minScore) {
    return 0;
  }
  var base = Math.floor(score / 20);
  if (base <= 0) {
    return 0;
  }
  var streakBonusSteps = Math.min(Math.max(streakDays, 0), 5);
  var streakMultiplier = 1.0 + (0.1 * streakBonusSteps);
  var reward = Math.floor(base * streakMultiplier);
  if (doubleReward) {
    reward *= 2;
  }
  reward = Math.min(MAX_RUN_REWARD_COINS, reward);
  return Math.max(0, reward);
}

function readOrInitShopState(nk, userId) {
  var storage = nk.storageRead([
    {
      collection: SHOP_COLLECTION,
      key: SHOP_KEY,
      userId: userId,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value) {
    var current = storage[0].value;
    if (!current.ownedThemes || !Array.isArray(current.ownedThemes)) {
      current.ownedThemes = ["default"];
    }
    if (!current.equippedTheme) {
      current.equippedTheme = "default";
    }
    if (!current.themeRentals || typeof current.themeRentals !== "object") {
      current.themeRentals = {};
    }
    if (!current.powerups || typeof current.powerups !== "object") {
      current.powerups = {};
    }
    return current;
  }
  var initial = {
    ownedThemes: ["default"],
    equippedTheme: "default",
    themeRentals: {},
    powerups: {
      undo: 0,
      prism: 0,
      shuffle: 0,
    },
  };
  writeShopState(nk, userId, initial);
  return initial;
}

function writeShopState(nk, userId, state) {
  nk.storageWrite([
    {
      collection: SHOP_COLLECTION,
      key: SHOP_KEY,
      userId: userId,
      value: state,
      permissionRead: 1,
      permissionWrite: 0,
    },
  ]);
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

function readRunHistory(nk, userId) {
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: RUN_HISTORY_KEY,
      userId: userId,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value && Array.isArray(storage[0].value.entries)) {
    return storage[0].value.entries;
  }
  return [];
}

function writeRunHistory(nk, userId, entries) {
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: RUN_HISTORY_KEY,
      userId: userId,
      value: {
        entries: entries || [],
      },
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function recordRunSubmission(nk, userId, runId, score, mode) {
  var normalizedRunId = normalizeRunId(runId);
  if (!normalizedRunId) {
    return;
  }
  var now = Math.floor(Date.now() / 1000);
  var entries = readRunHistory(nk, userId);
  var previous = null;
  var nextEntries = [];
  for (var i = 0; i < entries.length; i++) {
    var row = entries[i];
    if (row && normalizeRunId(row.runId || "") === normalizedRunId) {
      previous = row;
      continue;
    }
    if (row && typeof row === "object") {
      nextEntries.push(row);
    }
  }
  nextEntries.unshift({
    runId: normalizedRunId,
    score: Math.max(0, toInt(score, 0)),
    mode: normalizeLeaderboardMode(mode),
    submittedAt: now,
    rewardClaimedAt: previous ? Math.max(0, toInt(previous.rewardClaimedAt, 0)) : 0,
    rewardCoins: previous ? Math.max(0, toInt(previous.rewardCoins, 0)) : 0,
  });
  if (nextEntries.length > MAX_RUN_HISTORY_ENTRIES) {
    nextEntries = nextEntries.slice(0, MAX_RUN_HISTORY_ENTRIES);
  }
  writeRunHistory(nk, userId, nextEntries);
}

function findRunHistoryEntry(entries, runId) {
  var normalizedRunId = normalizeRunId(runId);
  if (!normalizedRunId || !Array.isArray(entries)) {
    return null;
  }
  for (var i = 0; i < entries.length; i++) {
    var row = entries[i];
    if (row && normalizeRunId(row.runId || "") === normalizedRunId) {
      return row;
    }
  }
  return null;
}

function countRunRewardsClaimedSince(entries, sinceUnix) {
  if (!Array.isArray(entries)) {
    return 0;
  }
  var count = 0;
  for (var i = 0; i < entries.length; i++) {
    var claimedAt = Math.max(0, toInt(entries[i] && entries[i].rewardClaimedAt, 0));
    if (claimedAt >= sinceUnix) {
      count += 1;
    }
  }
  return count;
}

function markRunRewardClaimed(nk, userId, runId, claimedAt, rewardCoins) {
  var normalizedRunId = normalizeRunId(runId);
  if (!normalizedRunId) {
    return;
  }
  var entries = readRunHistory(nk, userId);
  for (var i = 0; i < entries.length; i++) {
    var row = entries[i];
    if (!row || normalizeRunId(row.runId || "") !== normalizedRunId) {
      continue;
    }
    row.rewardClaimedAt = Math.max(0, toInt(claimedAt, Math.floor(Date.now() / 1000)));
    row.rewardCoins = Math.max(0, toInt(rewardCoins, 0));
    break;
  }
  writeRunHistory(nk, userId, entries);
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
  var currentUsername = String(
    (value && value.currentUsername) || fallbackUsername || ""
  )
    .trim()
    .toLowerCase();
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
    nextChangeCostCoins: freeChangeAvailable ? 0 : Math.max(0, MODULE_CONFIG.usernameChangeCostCoins),
    changeCount: Math.max(0, toInt(state.changeCount, 0)),
    lastChangedAt: Math.max(0, toInt(state.lastChangedAt, 0)),
    cooldownSeconds: Math.max(0, toInt(MODULE_CONFIG.usernameChangeCooldownSeconds, DEFAULT_USERNAME_CHANGE_COOLDOWN_SECONDS)),
    maxChangesPerDay: Math.max(1, toInt(MODULE_CONFIG.usernameChangeMaxPerDay, DEFAULT_USERNAME_CHANGE_MAX_PER_DAY)),
  };
}

function appendUsernameAudit(nk, userId, eventRow) {
  var current = readUsernameAudit(nk, userId);
  current.unshift({
    at: toInt(eventRow.at, Math.floor(Date.now() / 1000)),
    oldUsername: String(eventRow.oldUsername || ""),
    newUsername: String(eventRow.newUsername || ""),
    coinCost: toInt(eventRow.coinCost, 0),
    moderationSource: String(eventRow.moderationSource || ""),
  });
  if (current.length > 20) {
    current = current.slice(0, 20);
  }
  nk.storageWrite([
    {
      collection: ACCOUNT_COLLECTION,
      key: USERNAME_AUDIT_KEY,
      userId: userId,
      value: {
        entries: current,
      },
      permissionRead: 0,
      permissionWrite: 0,
    },
  ]);
}

function readUsernameAudit(nk, userId) {
  var storage = nk.storageRead([
    {
      collection: ACCOUNT_COLLECTION,
      key: USERNAME_AUDIT_KEY,
      userId: userId,
    },
  ]);
  if (storage && storage.length > 0 && storage[0].value && Array.isArray(storage[0].value.entries)) {
    return storage[0].value.entries;
  }
  return [];
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

function validateUsernameModeration(nk, logger, username) {
  if (!MODULE_CONFIG.usernameValidateUrl) {
    return {
      allowed: !containsBlockedUsernameToken(username),
      source: "local_fallback",
    };
  }

  var headers = { "Content-Type": "application/json" };
  if (MODULE_CONFIG.internalServiceKey) {
    headers["x-admin-key"] = MODULE_CONFIG.internalServiceKey;
  }

  try {
    var response = nk.httpRequest(
      MODULE_CONFIG.usernameValidateUrl,
      "post",
      headers,
      JSON.stringify({
        game_id: MODULE_CONFIG.gameId,
        username: username,
      }),
      MODULE_CONFIG.httpTimeoutMs,
      false
    );
    if (response.code < 200 || response.code >= 300) {
      logger.warn(
        "username moderation endpoint rejected. code=%s user=%s",
        response.code,
        username
      );
      if (MODULE_CONFIG.usernameModerationFailOpen) {
        return {
          allowed: !containsBlockedUsernameToken(username),
          source: "local_fail_open",
        };
      }
      return { allowed: false, source: "platform_error" };
    }
    var parsed = parseHttpResponseJson(response.body);
    return {
      allowed: parsed.allowed === true,
      source: "platform",
    };
  } catch (err) {
    logger.warn("username moderation request failed. err=%s", err);
    if (MODULE_CONFIG.usernameModerationFailOpen) {
      return {
        allowed: !containsBlockedUsernameToken(username),
        source: "local_fail_open",
      };
    }
    return { allowed: false, source: "platform_error" };
  }
}

function containsBlockedUsernameToken(input) {
  var compact = String(input || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  if (!compact) {
    return true;
  }
  var blocked = MODULE_CONFIG.blockedUsernameTokens || DEFAULT_BLOCKED_USERNAME_TOKENS;
  for (var i = 0; i < blocked.length; i++) {
    if (compact.indexOf(blocked[i]) >= 0) {
      return true;
    }
  }
  return false;
}

function parseBlockedUsernameTokens(rawValue, fallback) {
  var tokens = [];
  var raw = String(rawValue || "").trim();
  if (!raw) {
    return fallback.slice(0);
  }
  if (raw[0] === "[") {
    try {
      var parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        for (var i = 0; i < parsed.length; i++) {
          var normalized = normalizeBlockedToken(parsed[i]);
          if (normalized) {
            tokens.push(normalized);
          }
        }
      }
    } catch (_err) {
      // Fall through to CSV parse.
    }
  }
  if (tokens.length === 0) {
    var parts = raw.split(",");
    for (var j = 0; j < parts.length; j++) {
      var csvToken = normalizeBlockedToken(parts[j]);
      if (csvToken) {
        tokens.push(csvToken);
      }
    }
  }
  if (tokens.length === 0) {
    return fallback.slice(0);
  }
  return dedupeStrings(tokens);
}

function normalizeBlockedToken(value) {
  var out = String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  return out;
}

function dedupeStrings(values) {
  var out = [];
  var seen = {};
  for (var i = 0; i < values.length; i++) {
    var key = String(values[i] || "");
    if (!key || seen[key]) {
      continue;
    }
    seen[key] = true;
    out.push(key);
  }
  return out;
}

function hasThemeAccess(shopState, themeId) {
  if (themeId === "default") {
    return true;
  }
  if (Array.isArray(shopState.ownedThemes) && shopState.ownedThemes.indexOf(themeId) >= 0) {
    return true;
  }
  var now = Math.floor(Date.now() / 1000);
  var rentals = shopState.themeRentals || {};
  var expiresAt = toInt(rentals[themeId], 0);
  return expiresAt > now;
}

function addOwnedTheme(shopState, themeId) {
  if (!Array.isArray(shopState.ownedThemes)) {
    shopState.ownedThemes = ["default"];
  }
  if (shopState.ownedThemes.indexOf(themeId) < 0) {
    shopState.ownedThemes.push(themeId);
  }
}

function extractCoinBalance(entitlements, gameId) {
  if (!entitlements || typeof entitlements !== "object") {
    return 0;
  }
  var coins = entitlements.coins;
  if (!coins || typeof coins !== "object") {
    return 0;
  }
  var entry = coins[gameId];
  if (!entry || typeof entry !== "object") {
    return 0;
  }
  return Math.max(0, toInt(entry.balance, 0));
}

function providerForExportTarget(exportTarget) {
  var target = String(exportTarget || "web").trim().toLowerCase();
  if (target === "ios") {
    return "apple";
  }
  if (target === "android") {
    return "google";
  }
  return "paypal_web";
}

function normalizeRunId(value) {
  var runId = String(value || "").trim();
  if (!runId) {
    return "";
  }
  if (!/^[A-Za-z0-9._:-]+$/.test(runId)) {
    return "";
  }
  if (runId.length > 128) {
    runId = runId.substring(0, 128);
  }
  return runId;
}

function sanitizeIdempotencyFragment(value, maxLength) {
  var raw = String(value || "").trim();
  if (!raw) {
    return "none";
  }
  var out = raw.replace(/[^A-Za-z0-9._:-]/g, "_");
  var limit = Math.max(8, toInt(maxLength, 64));
  if (out.length > limit) {
    out = out.substring(0, limit);
  }
  if (!out) {
    return "none";
  }
  return out;
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

function extractMetadataPowerupsUsed(metadata) {
  if (!metadata || typeof metadata !== "object") {
    return 0;
  }
  var total = 0;
  var direct = toInt(metadata.powerups_used, -1);
  if (direct >= 0) {
    total = Math.max(total, direct);
  }
  var breakdown = metadata.powerup_breakdown;
  if (breakdown && typeof breakdown === "object" && !Array.isArray(breakdown)) {
    var keys = Object.keys(breakdown);
    var sum = 0;
    for (var i = 0; i < keys.length; i++) {
      sum += Math.max(0, toInt(breakdown[keys[i]], 0));
    }
    total = Math.max(total, sum);
  }
  return total;
}

function normalizeLeaderboardMode(value) {
  var mode = String(value || "open").trim().toLowerCase();
  if (mode === "pure") {
    return "pure";
  }
  return "open";
}

function leaderboardIdForMode(mode) {
  var normalizedMode = normalizeLeaderboardMode(mode);
  if (normalizedMode === "pure") {
    return String(MODULE_CONFIG.leaderboardIds.pure || "").trim();
  }
  return String(MODULE_CONFIG.leaderboardIds.open || "").trim();
}

function assertAuthenticated(ctx) {
  if (!ctx || !ctx.userId) {
    throw new Error("User session is required.");
  }
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
  } catch (err) {
    throw new Error("invalid JSON payload");
  }
}

function describePayloadShape(payload) {
  if (payload === null || payload === undefined) {
    return "nullish";
  }
  if (typeof payload === "string") {
    return "string(len=" + payload.length + ")";
  }
  if (typeof payload === "object") {
    var keys = Object.keys(payload);
    return "object(keys=" + JSON.stringify(keys.sort()) + ")";
  }
  return typeof payload;
}

function toInt(value, fallback) {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
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

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    rpcSubmitScore: rpcSubmitScore,
    rpcGetMyHighScore: rpcGetMyHighScore,
    rpcListLeaderboard: rpcListLeaderboard,
    normalizeLeaderboardMode: normalizeLeaderboardMode,
    leaderboardIdForMode: leaderboardIdForMode,
    extractMetadataPowerupsUsed: extractMetadataPowerupsUsed,
    __setModuleConfigForTests: function (partialConfig) {
      partialConfig = partialConfig || {};
      MODULE_CONFIG = Object.assign({}, MODULE_CONFIG, partialConfig);
      MODULE_CONFIG.leaderboardIds = Object.assign(
        {},
        MODULE_CONFIG.leaderboardIds || {},
        partialConfig.leaderboardIds || {}
      );
    },
  };
}
