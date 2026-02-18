const test = require("node:test");
const assert = require("node:assert/strict");

const moduleUnderTest = require("../modules/colorcrunch.js");

function createMockLogger() {
  return {
    warnings: [],
    infos: [],
    warn(...args) {
      this.warnings.push(args.join(" "));
    },
    info(...args) {
      this.infos.push(args.join(" "));
    },
  };
}

function createMockNakama() {
  const state = {
    recordWrites: [],
    storageWrites: [],
    leaderboardCalls: [],
    eventPosts: [],
  };
  const nk = {
    _state: state,
    usersGetId(ids) {
      return [{ id: ids[0], username: "Tester" }];
    },
    leaderboardRecordWrite(leaderboardId, userId, username, score, subscore, metadata) {
      const record = {
        leaderboardId,
        ownerId: userId,
        username,
        score,
        subscore,
        rank: 1,
        updateTime: "2026-02-18T00:00:00Z",
        metadata,
      };
      state.recordWrites.push(record);
      return record;
    },
    storageWrite(rows) {
      state.storageWrites.push(...rows);
      return rows;
    },
    storageRead() {
      return [];
    },
    leaderboardRecordsList(leaderboardId, owners, limit, cursor) {
      state.leaderboardCalls.push({ leaderboardId, owners, limit, cursor });
      if (owners && owners.length > 0) {
        return {
          ownerRecords: [
            {
              leaderboardId,
              ownerId: owners[0],
              username: "Tester",
              score: 500,
              subscore: 999999,
              rank: 2,
            },
          ],
          records: [],
        };
      }
      return {
        records: [
          { rank: 1, username: "A", score: 1000, subscore: 999999 },
          { rank: 2, username: "B", score: 800, subscore: 999998 },
        ],
        nextCursor: "",
        prevCursor: "",
        rankCount: 2,
      };
    },
    httpRequest(url, method, headers, body) {
      state.eventPosts.push({ url, method, headers, body });
      return { code: 200, body: "{}" };
    },
  };
  return nk;
}

function createCtx() {
  return { userId: "u1", username: "Tester" };
}

test("submit score applies OPEN mode tie-breaker fields", () => {
  moduleUnderTest.__setModuleConfigForTests({
    leaderboardIds: { open: "cc_open", pure: "cc_pure" },
    eventUrl: "",
  });
  const nk = createMockNakama();
  const logger = createMockLogger();
  const result = JSON.parse(
    moduleUnderTest.rpcSubmitScore(
      createCtx(),
      logger,
      nk,
      JSON.stringify({
        score: 1200,
        mode: "open",
        powerups_used: 2,
        coins_spent: 180,
        run_id: "run-1",
        run_duration_ms: 32100,
        metadata: { source: "test" },
      })
    )
  );

  assert.equal(result.leaderboardId, "cc_open");
  assert.equal(result.leaderboardMode, "OPEN");
  assert.equal(result.record.subscore, 999998);
  assert.equal(result.record.metadata.mode, "OPEN");
  assert.equal(result.record.metadata.powerups_used, 2);
  assert.equal(result.record.metadata.coins_spent, 180);
  assert.equal(result.record.metadata.run_id, "run-1");
  assert.equal(result.record.metadata.run_duration_ms, 32100);
});

test("pure mode submission with powerups is rejected and flagged", () => {
  moduleUnderTest.__setModuleConfigForTests({
    leaderboardIds: { open: "cc_open", pure: "cc_pure" },
    eventUrl: "https://events.invalid",
  });
  const nk = createMockNakama();
  const logger = createMockLogger();

  assert.throws(() => {
    moduleUnderTest.rpcSubmitScore(
      createCtx(),
      logger,
      nk,
      JSON.stringify({
        score: 333,
        mode: "PURE",
        powerups_used: 1,
        metadata: {},
      })
    );
  }, /PURE mode submissions cannot include powerups_used > 0/);

  assert.ok(logger.warnings.length > 0);
  assert.ok(nk._state.eventPosts.length > 0);
  const eventBody = JSON.parse(nk._state.eventPosts[0].body);
  assert.equal(eventBody.eventType, "score_submission_flagged");
});

test("get/list leaderboard route by mode", () => {
  moduleUnderTest.__setModuleConfigForTests({
    leaderboardIds: { open: "cc_open", pure: "cc_pure" },
  });
  const nk = createMockNakama();
  const logger = createMockLogger();

  const mine = JSON.parse(
    moduleUnderTest.rpcGetMyHighScore(
      createCtx(),
      logger,
      nk,
      JSON.stringify({ mode: "PURE" })
    )
  );
  assert.equal(mine.leaderboardId, "cc_pure");
  assert.equal(mine.leaderboardMode, "PURE");

  const listed = JSON.parse(
    moduleUnderTest.rpcListLeaderboard(
      createCtx(),
      logger,
      nk,
      JSON.stringify({ mode: "OPEN", limit: 5 })
    )
  );
  assert.equal(listed.leaderboardId, "cc_open");
  assert.equal(listed.leaderboardMode, "OPEN");
  assert.equal(listed.records.length, 2);
});
