from app import core


def test_rules_category():
    assert core.categorize("Lunch at restaurant")["category"] == "Food"
    assert core.categorize("Grab ride")["category"] == "Transport"


def test_naive_bayes_fallback():
    r = core.categorize("pho bowl")
    assert r["category"] == "Food"


def test_unknown_is_other():
    assert core.categorize("zzzz qqqq")["category"] == "Other"


def test_anomaly_detected():
    hist = [20, 25, 30, 22, 28, 35, 27]
    assert core.detect_anomaly(800, hist)["is_anomaly"] is True
    assert core.detect_anomaly(30, hist)["is_anomaly"] is False


def test_anomaly_needs_history():
    assert core.detect_anomaly(800, [10, 20])["is_anomaly"] is False


def test_budget_example_from_assignment():
    r = core.budget_advice(2000, 6, 0, 1800, 1300, {"Food": 300, "Entertainment": 200})
    assert r["required_monthly"] == 333.33
    assert r["feasible"] is True


def test_budget_gap_suggestions():
    r = core.budget_advice(2000, 6, 0, 1000, 900, {"Entertainment": 400, "Shopping": 300})
    assert r["feasible"] is False and r["suggestions"]


def test_chat_grounded():
    ctx = {"month": "2026-10", "by_category": {"Food": 123.5}}
    assert "123.50" in core.rule_chat("How much did I spend on food this month?", ctx)
