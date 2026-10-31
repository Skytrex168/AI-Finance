"""Offline evaluation: python -m tests.evaluate  (run from ai-service/)."""
import random
from app import core

random.seed(7)
LABELLED = [
    ("Lunch at KFC", "Food"), ("Starbucks coffee", "Food"), ("Tesco grocery run", "Food"), ("khmer noodle soup", "Food"),
    ("Grab ride to office", "Transport"), ("fuel refill", "Transport"), ("parking fee", "Transport"),
    ("Lazada order shoes", "Shopping"), ("new shirt at mall", "Shopping"),
    ("Electric bill", "Bills"), ("Internet wifi payment", "Bills"), ("monthly rent", "Bills"),
    ("pharmacy medicine", "Health"), ("dentist clinic", "Health"),
    ("Netflix subscription", "Entertainment"), ("cinema tickets", "Entertainment"),
    ("university tuition", "Education"), ("Udemy course", "Education"),
    ("monthly payroll", "Salary"), ("Freelance commission", "Freelance"),
]
ok = sum(core.categorize(t)["category"] == c for t, c in LABELLED)
print(f"Categorisation accuracy: {ok}/{len(LABELLED)} = {ok/len(LABELLED):.2%}")

tp = fp = fn = tn = 0
for _ in range(500):
    base = random.uniform(15, 60)
    hist = [max(1, random.gauss(base, base * 0.2)) for _ in range(30)]
    if random.random() < 0.3:
        amt, truth = base * random.uniform(6, 25), True
    else:
        amt, truth = max(1, random.gauss(base, base * 0.2)), False
    pred = core.detect_anomaly(amt, hist)["is_anomaly"]
    tp += pred and truth; fp += pred and not truth; fn += (not pred) and truth; tn += (not pred) and not truth
prec = tp / (tp + fp) if tp + fp else 0
rec = tp / (tp + fn) if tp + fn else 0
fpr = fp / (fp + tn) if fp + tn else 0
print(f"Anomaly detection  precision={prec:.3f} recall={rec:.3f} false_positive_rate={fpr:.3f}  (TP={tp} FP={fp} FN={fn} TN={tn})")
