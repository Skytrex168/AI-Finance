# AI Documentation

Every feature follows: Problem -> Input -> Model -> Output -> Evaluation.

## 1. Automatic categorisation
- **Problem:** users should not categorise every payment by hand ("$5.50 restaurant" -> Food).
- **Input:** transaction description text.
- **Model:** keyword rules first (confidence 0.95), then a Naive Bayes text classifier (trained on seed phrases at startup) as fallback; below 0.40 probability -> "Other".
- **Output:** `{category, confidence, method}`; stored with the transaction (`ai_confidence`).
- **Evaluation:** `python -m tests.evaluate` -> accuracy on a 20-phrase labelled set. The set is small and overlaps with the keyword rules, so treat the number as a smoke test, not a benchmark. Limitation: slang or non-English merchants fall to "Other"; users can always set the category manually.

## 2. Anomaly detection
- **Problem:** flag unusual spending (normal $20-$50, suddenly $800).
- **Input:** new amount + the user's last 90 days of expenses in the same category.
- **Model:** robust z-score using median and MAD (resistant to past outliers). Anomaly if z >= 3.5; needs >= 5 historical items.
- **Output:** `{score 0-1, is_anomaly, reason}`; creates an entry in `recommendations`.
- **Evaluation:** synthetic data (500 trials, 30% injected outliers at 6-25x normal). Run the script for current numbers: precision, recall and false-positive rate are printed. Limitation: synthetic data is easier than real life; a real evaluation needs labelled real transactions.

## 3. AI budget advisor
- **Problem:** "I want to save $2,000 in six months."
- **Input:** goal, months, average monthly income/expense (last 90 days), expense by category.
- **Model:** deterministic arithmetic (required = (goal - saved) / months) + rule-based ranking of flexible categories (Entertainment, Shopping, Food, Transport), suggesting ~25% cuts.
- **Output:** required monthly saving, surplus, gap, suggestions. Numbers are never produced by an LLM, so they cannot be hallucinated.

## 4. Grounded assistant (chat)
- **Problem:** answer "How much did I spend on food this month?" from real data.
- **Input:** question + this month's aggregated numbers (built by the backend from the database).
- **Model:** default = rule-based intent matching over those numbers. If `ANTHROPIC_API_KEY` is set on the AI service, an LLM answers using only the supplied JSON; on any failure it falls back to rules.
- **Output:** `{reply, source: rules | llm | rules-fallback}`.
- **Safety:** the key stays on the server; only aggregated data is sent; the LLM prompt forbids answering outside the data and says "not financial advice".
- **Limitation:** rule mode understands a limited set of questions; LLM mode can still phrase things imperfectly, so verify important numbers on the dashboard.

## 5. Allocation suggestion (investment simulator)
Maps risk tolerance 1-5 to a simulated stock/fund/bond/crypto split. Educational only; no real trading.

## Prompt used in LLM mode
`You are a personal finance assistant. Answer ONLY from the JSON data provided. If the data does not contain the answer, say you do not know. This is educational, not financial advice. Data: {...}`

Not implemented: RAG (optional "advanced teams" item), see Future improvements in README.
