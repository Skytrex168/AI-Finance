import os
from typing import Dict, List, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from . import core

app = FastAPI(title="Finance AI Service", version="1.0")
INTERNAL_KEY = os.getenv("AI_INTERNAL_KEY", "")


def check(key: Optional[str]):
    if INTERNAL_KEY and key != INTERNAL_KEY:
        raise HTTPException(status_code=401, detail="Invalid internal key")


class CatReq(BaseModel):
    description: str = Field(min_length=1, max_length=255)


class AnomalyReq(BaseModel):
    amount: float = Field(gt=0)
    history: List[float] = []


class AdvisorReq(BaseModel):
    goal_amount: float = Field(gt=0)
    months: int = Field(gt=0, le=600)
    saved_so_far: float = 0
    avg_income: float = 0
    avg_expense: float = 0
    expense_by_category: Dict[str, float] = {}


class ChatReq(BaseModel):
    message: str = Field(min_length=1, max_length=500)
    context: dict = {}


class AllocReq(BaseModel):
    risk_tolerance: int = 3


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/categorize")
def categorize(r: CatReq, x_internal_key: Optional[str] = Header(None)):
    check(x_internal_key)
    return core.categorize(r.description)


@app.post("/anomaly")
def anomaly(r: AnomalyReq, x_internal_key: Optional[str] = Header(None)):
    check(x_internal_key)
    return core.detect_anomaly(r.amount, r.history)


@app.post("/advisor")
def advisor(r: AdvisorReq, x_internal_key: Optional[str] = Header(None)):
    check(x_internal_key)
    return core.budget_advice(r.goal_amount, r.months, r.saved_so_far, r.avg_income,
                              r.avg_expense, r.expense_by_category)


@app.post("/allocation")
def allocation(r: AllocReq, x_internal_key: Optional[str] = Header(None)):
    check(x_internal_key)
    return core.allocation(r.risk_tolerance)


@app.post("/chat")
async def chat(r: ChatReq, x_internal_key: Optional[str] = Header(None)):
    check(x_internal_key)
    llm_key = os.getenv("ANTHROPIC_API_KEY")
    if not llm_key:
        return {"reply": core.rule_chat(r.message, r.context), "source": "rules"}
    system = ("You are a personal finance assistant. Answer ONLY from the JSON data provided. "
              "If the data does not contain the answer, say you do not know. "
              "This is educational, not financial advice. Data: " + str(r.context))
    try:
        async with httpx.AsyncClient(timeout=20) as c:
            resp = await c.post(
                "https://api.anthropic.com/v1/messages",
                headers={"x-api-key": llm_key, "anthropic-version": "2023-06-01"},
                json={"model": os.getenv("LLM_MODEL", "claude-sonnet-4-5"), "max_tokens": 400,
                      "system": system, "messages": [{"role": "user", "content": r.message}]})
            resp.raise_for_status()
            return {"reply": resp.json()["content"][0]["text"], "source": "llm"}
    except Exception:
        return {"reply": core.rule_chat(r.message, r.context), "source": "rules-fallback"}
