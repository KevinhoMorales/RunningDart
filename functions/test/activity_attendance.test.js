const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
  ecuadorIsoWeekKey,
  ecuadorMonthKey,
  leagueStandingId,
  isCheckInWindowOpen,
  DEFAULT_CHECK_IN_POINTS,
} = require("../activity_attendance");

describe("activity_attendance helpers", () => {
  it("defaults check-in points to 10", () => {
    assert.equal(DEFAULT_CHECK_IN_POINTS, 10);
  });

  it("ecuadorIsoWeekKey is stable for tue/thu same week", () => {
    const tue = new Date("2026-09-09T00:00:00.000Z");
    const thu = new Date("2026-09-11T00:00:00.000Z");
    assert.equal(ecuadorIsoWeekKey(tue), ecuadorIsoWeekKey(thu));
  });

  it("ecuadorMonthKey uses Ecuador calendar month", () => {
    // 2026-09-01 00:30 UTC = 2026-08-31 19:30 ECT → August
    assert.equal(ecuadorMonthKey(new Date("2026-09-01T00:30:00.000Z")), "2026-08");
    // 2026-09-01 06:00 UTC = 2026-09-01 01:00 ECT → September
    assert.equal(ecuadorMonthKey(new Date("2026-09-01T06:00:00.000Z")), "2026-09");
  });

  it("leagueStandingId joins period and user", () => {
    assert.equal(leagueStandingId("2026-09", "u1"), "2026-09_u1");
  });

  it("isCheckInWindowOpen respects enabled flag and window", () => {
    const now = new Date("2026-09-10T00:00:00.000Z");
    assert.equal(
      isCheckInWindowOpen(
        {
          checkInEnabled: false,
          checkInOpensAt: new Date("2026-09-09T23:00:00.000Z"),
          checkInClosesAt: new Date("2026-09-10T02:00:00.000Z"),
        },
        now,
      ),
      false,
    );
    assert.equal(
      isCheckInWindowOpen(
        {
          checkInEnabled: true,
          checkInOpensAt: new Date("2026-09-09T23:00:00.000Z"),
          checkInClosesAt: new Date("2026-09-10T02:00:00.000Z"),
        },
        now,
      ),
      true,
    );
    assert.equal(
      isCheckInWindowOpen(
        {
          checkInEnabled: true,
          checkInOpensAt: new Date("2026-09-10T01:00:00.000Z"),
          checkInClosesAt: new Date("2026-09-10T02:00:00.000Z"),
        },
        now,
      ),
      false,
    );
  });
});
