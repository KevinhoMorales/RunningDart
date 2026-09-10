const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
  ecuadorIsoWeekKey,
  isCheckInWindowOpen,
  DEFAULT_CHECK_IN_POINTS,
} = require("../activity_attendance");

describe("activity_attendance helpers", () => {
  it("defaults check-in points to 10", () => {
    assert.equal(DEFAULT_CHECK_IN_POINTS, 10);
  });

  it("ecuadorIsoWeekKey is stable for tue/thu same week", () => {
    // 2026-09-08 19:00 ECT = 2026-09-09 00:00Z
    const tue = new Date("2026-09-09T00:00:00.000Z");
    // 2026-09-10 19:00 ECT = 2026-09-11 00:00Z
    const thu = new Date("2026-09-11T00:00:00.000Z");
    assert.equal(ecuadorIsoWeekKey(tue), ecuadorIsoWeekKey(thu));
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
