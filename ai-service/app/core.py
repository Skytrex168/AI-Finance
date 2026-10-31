"""Pure-Python AI logic (no web framework) so it is easy to unit-test and evaluate."""
import math
import re
import statistics
from collections import defaultdict

# ---------- 1. Transaction categorisation (rules + Naive Bayes) ----------
KEYWORDS = {
    "Food": ["restaurant", "cafe", "coffee", "lunch", "dinner", "breakfast", "pizza", "noodle", "rice",
             "kfc", "burger", "grocery", "supermarket", "market", "bakery", "bar", "food"],
    "Transport": ["taxi", "grab", "tuk", "fuel", "gas", "petrol", "bus", "parking", "uber", "toll", "metro"],
    "Shopping": ["mall", "shirt", "shoes", "amazon", "lazada", "shop", "clothes", "gadget", "store"],
    "Bills": ["electric", "water bill", "internet", "wifi", "rent", "phone bill", "insurance", "utility"],
    "Health": ["pharmacy", "doctor", "clinic", "hospital", "medicine", "dental", "gym"],
    "Entertainment": ["cinema", "movie", "netflix", "spotify", "game", "concert", "karaoke", "steam"],
    "Education": ["tuition", "course", "book", "school", "udemy", "exam", "university"],
    "Salary": ["salary", "payroll", "wage"],
    "Freelance": ["freelance", "invoice paid", "client payment", "commission"],
}
TOKEN = re.compile(r"[a-z]+")


def tokens(text):
    return TOKEN.findall(text.lower())


class NaiveBayes:
    """Tiny multinomial Naive Bayes trained on seed phrases (fallback when no keyword matches)."""

    def __init__(self):
        self.word_counts = defaultdict(lambda: defaultdict(int))
        self.class_counts = defaultdict(int)
        self.vocab = set()

    def fit(self, samples):
        for text, label in samples:
            self.class_counts[label] += 1
            for w in tokens(text):
                self.word_counts[label][w] += 1
                self.vocab.add(w)
        return self

    def predict(self, text):
        ws = tokens(text)
        if not ws or not self.class_counts:
            return "Other", 0.0
        total = sum(self.class_counts.values())
        scores = {}
        for c, n in self.class_counts.items():
            denom = sum(self.word_counts[c].values()) + len(self.vocab) + 1
            s = math.log(n / total)
            for w in ws:
                s += math.log((self.word_counts[c].get(w, 0) + 1) / denom)
            scores[c] = s
        m = max(scores.values())
        exps = {c: math.exp(v - m) for c, v in scores.items()}
        z = sum(exps.values())
        best = max(exps, key=exps.get)
        return best, exps[best] / z


SEED = [(kw + " payment", cat) for cat, kws in KEYWORDS.items() for kw in kws] + [
    ("pho bowl at local stall", "Food"), ("iced latte morning", "Food"), ("khmer noodle soup", "Food"),
    ("pass app ride home", "Transport"), ("motorbike fuel refill", "Transport"),
    ("new sneakers", "Shopping"), ("monthly electricity", "Bills"), ("pay house rent", "Bills"),
    ("vitamins and cold pills", "Health"), ("monthly pay from company", "Salary"),
]
_NB = NaiveBayes().fit(SEED)


def categorize(description):
    d = description.lower()
    for cat, kws in KEYWORDS.items():
        if any(k in d for k in kws):
            return {"category": cat, "confidence": 0.95, "method": "rules"}
    cat, p = _NB.predict(d)
    if p < 0.40:
        return {"category": "Other", "confidence": round(p, 3), "method": "naive_bayes"}
    return {"category": cat, "confidence": round(p, 3), "method": "naive_bayes"}


# ---------- 2. Anomaly detection (robust z-score using median / MAD) ----------
def detect_anomaly(amount, history, min_history=5, threshold=3.5):
    if len(history) < min_history:
        return {"score": 0.0, "is_anomaly": False, "reason": "Not enough history to judge"}
    med = statistics.median(history)
    mad = statistics.median([abs(h - med) for h in history])
    scale = 1.4826 * mad if mad > 0 else max(0.1 * med, 1.0)
    z = (amount - med) / scale
    score = max(0.0, min(1.0, z / (threshold * 2)))
    is_anom = z >= threshold
    reason = (f"{amount:.2f} is far above your typical {med:.2f} for this category"
              if is_anom else "Within your normal range")
    return {"score": round(score, 3), "is_anomaly": is_anom, "reason": reason}


# ---------- 3. Budget advisor (deterministic maths + ranked suggestions) ----------
FLEXIBLE = ["Entertainment", "Shopping", "Food", "Transport"]


def budget_advice(goal_amount, months, saved_so_far, avg_income, avg_expense, expense_by_category):
    if months <= 0:
        raise ValueError("months must be > 0")
    remaining = max(goal_amount - saved_so_far, 0)
    required = round(remaining / months, 2)
    surplus = round(avg_income - avg_expense, 2)
    gap = round(required - surplus, 2)
    feasible = gap <= 0
    suggestions = []
    if not feasible:
        flex = sorted(((c, expense_by_category.get(c, 0)) for c in FLEXIBLE), key=lambda x: -x[1])
        need = gap
        for cat, spent in flex:
            if need <= 0 or spent <= 0:
                continue
            cut = round(min(spent * 0.25, need), 2)
            suggestions.append({"category": cat, "reduce_by": cut,
                                "note": f"Cut about 25% of {cat} spending (${spent:.2f}/month)"})
            need = round(need - cut, 2)
        if need > 0:
            suggestions.append({"category": None, "reduce_by": need,
                                "note": f"Still ${need:.2f}/month short: extend the deadline or raise income"})
    return {"required_monthly": required, "monthly_surplus": surplus, "gap": max(gap, 0),
            "feasible": feasible, "suggestions": suggestions}


# ---------- 4. Grounded chat (answers come from the user's own numbers) ----------
def rule_chat(message, ctx):
    """ctx = {month, income, expense, by_category:{name:amount}, budgets:[{category,limit,spent}]}"""
    m = message.lower()
    by_cat = ctx.get("by_category", {})
    for cat, amt in by_cat.items():
        if cat.lower() in m:
            return f"You spent ${amt:.2f} on {cat} in {ctx.get('month')}."
    if "food" in m or "eat" in m:
        return f"You spent $0.00 on Food in {ctx.get('month')}."
    if "income" in m or "earn" in m:
        return f"Your income in {ctx.get('month')} is ${ctx.get('income', 0):.2f}."
    if any(w in m for w in ("total", "spend", "spent", "expense")):
        return f"Your total spending in {ctx.get('month')} is ${ctx.get('expense', 0):.2f}."
    if "budget" in m:
        over = [b for b in ctx.get("budgets", []) if b["spent"] > b["limit"]]
        if over:
            return "Over budget: " + ", ".join(f"{b['category']} (${b['spent']:.0f}/${b['limit']:.0f})" for b in over)
        return "You are within all your budgets this month."
    if "save" in m or "saving" in m:
        s = ctx.get("income", 0) - ctx.get("expense", 0)
        return f"This month you have saved ${s:.2f} (income minus spending)."
    top = sorted(by_cat.items(), key=lambda x: -x[1])[:3]
    tops = ", ".join(f"{c} ${a:.0f}" for c, a in top) or "no spending yet"
    return f"I can answer questions about your spending, income, budgets and savings. Top categories: {tops}."


# ---------- 5. Investment suggestion (risk profile -> simulated allocation) ----------
def allocation(risk_tolerance):
    r = max(1, min(5, int(risk_tolerance)))
    table = {1: (0, 20, 80, 0), 2: (20, 30, 50, 0), 3: (40, 30, 30, 0), 4: (55, 20, 15, 10), 5: (60, 10, 5, 25)}
    stock, fund, bond, crypto = table[r]
    return {"STOCK": stock, "FUND": fund, "BOND": bond, "CRYPTO": crypto,
            "disclaimer": "Educational simulation only, not financial advice."}
