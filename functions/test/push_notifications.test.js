const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const {
  tokensFromUserData,
  topicClubActivities,
  topicNewBusinesses,
  topicNewEvents,
} = require("../push_notifications");

describe("push_notifications helpers", () => {
  it("env-scopes topics", () => {
    assert.equal(topicNewBusinesses("dev"), "saints_new_businesses_dev");
    assert.equal(topicNewEvents("prod"), "saints_new_events_prod");
    assert.equal(
      topicClubActivities("dev"),
      "saints_club_activities_dev",
    );
  });

  it("tokensFromUserData reads unique string tokens", () => {
    assert.deepEqual(tokensFromUserData(null), []);
    assert.deepEqual(tokensFromUserData({}), []);
    assert.deepEqual(
      tokensFromUserData({ fcmTokens: ["a", "b", "a", "", null, 3] }),
      ["a", "b"],
    );
  });
});
