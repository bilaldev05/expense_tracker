import asyncio
from calendar import calendar
import hashlib
from unittest import result
from fastapi import FastAPI, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pymongo import MongoClient
from typing import List, Optional
from datetime import datetime, timedelta
from collections import defaultdict
import base64
import uuid
import os
import re
from fastapi.encoders import jsonable_encoder
import io

import pymongo
from PIL import Image
import pytesseract
import pandas as pd
from sklearn.linear_model import LinearRegression
from bson import ObjectId
from db import get_all_expenses
from db import expense_collection
from bson.errors import InvalidId
import dateparser
import re
import spacy
from models import Expense
from crud import add_expense
from nlp_utils import parse_expense_text
from fastapi import FastAPI, Query
from datetime import datetime
from bson import ObjectId
from pymongo import MongoClient
import speech_recognition as sr
from fastapi import FastAPI, File, UploadFile
import openai 
import requests
from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
import torch
from typing import Dict, List
import traceback
from concurrent.futures import ThreadPoolExecutor
import logging
from transformers import (
    pipeline,
    AutoTokenizer,
    AutoModelForSeq2SeqLM 
)
import random
import calendar as cal
from fastapi import HTTPException
import io, base64, tempfile, traceback
import matplotlib.pyplot as plt
from gtts import gTTS
from fastapi.responses import JSONResponse


app = FastAPI()
_executor = ThreadPoolExecutor(max_workers=2)


logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# MongoDB setup
client = MongoClient("mongodb://localhost:27017")
db = client["expense_db"]
collection = db["expenses"]
budget_collection = db["budget"]
bills_collection = db["bills"]

openai.api_key = os.getenv("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")
model_name = "google/flan-t5-base"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSeq2SeqLM.from_pretrained(model_name, torch_dtype=torch.float16)
model.eval()

client = MongoClient("mongodb://localhost:27017")
db = client["expense_db"]
expenses = db["expenses"]

# -----------------------------------------------------
# Cache
# -----------------------------------------------------
cache = {}
def get_cache_key(user_query: str):
    return hashlib.md5(user_query.lower().encode()).hexdigest()

# -----------------------------------------------------
# Request Schema
# -----------------------------------------------------
class ChatRequest(BaseModel):
    message: str

# -----------------------------------------------------
# Detect Date Range from User Query
# -----------------------------------------------------
def detect_date_range(user_query: str):
    now = datetime.now()
    q = user_query.lower()
    start, end = None, None

    if "today" in q:
        start = end = now
    elif "yesterday" in q:
        start = end = now - timedelta(days=1)
    elif "this week" in q:
        start = now - timedelta(days=now.weekday())
        end = now
    elif "last week" in q:
        last_monday = now - timedelta(days=now.weekday() + 7)
        start = last_monday
        end = last_monday + timedelta(days=6)
    elif "this month" in q:
        start = now.replace(day=1)
        end = now
    elif "last month" in q:
        first_day_this_month = now.replace(day=1)
        last_month_end = first_day_this_month - timedelta(days=1)
        start = last_month_end.replace(day=1)
        end = last_month_end
    else:
        # Month name check
        months = [
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december"
        ]
        for i, m in enumerate(months, start=1):
            if m in q:
                year = now.year if i <= now.month else now.year - 1
                start = datetime(year, i, 1)
                if i == 12:
                    end = datetime(year, 12, 31)
                else:
                    end = datetime(year, i + 1, 1) - timedelta(days=1)
                break

    if not start or not end:
        return {}

    return {"date": {"$gte": start.strftime("%Y-%m-%d"), "$lte": end.strftime("%Y-%m-%d")}}

# -----------------------------------------------------
# Chart + Voice Generation Helpers
# -----------------------------------------------------
def generate_chart(categories: dict):
    if not categories:
        return None
    fig, ax = plt.subplots(figsize=(4, 4))
    ax.pie(categories.values(), labels=categories.keys(), autopct="%1.1f%%", startangle=90)
    buf = io.BytesIO()
    plt.savefig(buf, format="png", bbox_inches="tight")
    buf.seek(0)
    img_b64 = base64.b64encode(buf.read()).decode("utf-8")
    plt.close(fig)
    return img_b64

def generate_voice_safe(text: str, filename: str):
    """Generate and save MP3 voice file for Flutter playback."""
    try:
        os.makedirs("voices", exist_ok=True)
        filepath = os.path.join("voices", f"{filename}.mp3")
        tts = gTTS(text=text, lang="en", slow=False)
        tts.save(filepath)
        return f"/voices/{filename}.mp3"
    except Exception as e:
        print("❌ Voice generation failed:", e)
        return None


# -----------------------------------------------------
# Summarize User Expense Data
# -----------------------------------------------------
def summarize_text_local(query: str):
    query = query.lower()
    query_filter = detect_date_range(query)

    # Last expense
    if any(k in query for k in ["last expense", "recent expense", "latest expense"]):
        last_doc = expenses.find_one(sort=[("_id", -1)])
        if not last_doc:
            return {"text": "No recorded expenses found.", "has_data": False}
        text = f"Your last expense was {last_doc.get('category', 'Unknown')} — PKR {last_doc.get('amount')} for {last_doc.get('description', 'no description')}."
        return {"text": text, "has_data": True, "categories": {last_doc.get('category', 'Unknown'): float(last_doc.get('amount', 0))}}

    # Date range expenses
    docs = list(expenses.find(query_filter)) if query_filter else list(expenses.find())
    if not docs:
        return {"text": "No expenses found in that period.", "has_data": False}

    total = sum(float(d.get("amount", 0)) for d in docs)
    cats = {}
    for d in docs:
        cat = d.get("category", "Other")
        cats[cat] = cats.get(cat, 0) + float(d.get("amount", 0))

    breakdown = ", ".join([f"{c}: {amt:.2f}" for c, amt in cats.items()])
    text = f"Total spent: {total:.2f} PKR. Breakdown: {breakdown}."
    return {"text": text, "has_data": True, "categories": cats}

os.makedirs("voices", exist_ok=True)

# Mount the static directory
app.mount("/voices", StaticFiles(directory="voices"), name="voices")

# -----------------------------------------------------
# Chat Endpoint (Main)
# -----------------------------------------------------
@app.post("/ai-chat")
async def ai_chat(request: ChatRequest):
    try:
        user_query = request.message.strip()
        cache_key = get_cache_key(user_query)

        # --- Check Cache ---
        if cache_key in cache:
            return JSONResponse(content=cache[cache_key])

        loop = asyncio.get_event_loop()
        summary = await loop.run_in_executor(None, summarize_text_local, user_query)

        # --- Create Natural Reply ---
        if "no expenses" in summary["text"].lower():
            reply = "I couldn’t find any recorded expenses for that period. Try checking another range."
        else:
            reply = f"Here’s your expense insight: {summary['text']} Keep tracking your spending wisely!"

        # --- Voice + Chart ---
        filename = f"voice_{abs(hash(user_query))}"
        voice_url = generate_voice_safe(reply, filename)
        chart_b64 = generate_chart(summary.get("categories", {})) if summary.get("has_data") else None

        # --- Response Payload ---
        result = {
            "response": reply,
            "voice_url": voice_url,          # ✅ Flutter will now use this
            "chart_base64": chart_b64,
        }

        cache[cache_key] = result
        print(f"✅ Reply: {reply[:100]} | 🎙️ Voice: {'Yes' if voice_url else 'No'} | 📊 Chart: {'Yes' if chart_b64 else 'No'}")

        return JSONResponse(content=result)

    except Exception as e:
        import traceback
        traceback.print_exc()
        return JSONResponse(
            content={"response": f"Error: {str(e)}", "voice_url": None, "chart_base64": None},
            status_code=500,
        )


# -----------------------------------------------------
# Serve Audio (if needed)
# -----------------------------------------------------
@app.get("/audio/{filename}")
async def get_audio(filename: str):
    path = os.path.join("audio", filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Audio not found")
    return FileResponse(path, media_type="audio/mpeg")

# Upload directory
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class BillUpload(BaseModel):
    image_base64: str
    user_id: str
# OCR setup
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Enable CORS
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic models

class ExpenseBase(BaseModel):
    title: str
    amount: float
    category: str
    date: str

class ExpenseCreate(ExpenseBase):
    pass  # for creating expenses (no id needed)

class Expense(ExpenseBase):
    id: Optional[str] = None 


class Budget(BaseModel):
    amount: float

class ExpenseInput(BaseModel):
    title: str
    amount: float
    category: str
    date: str

class Expense(ExpenseInput):
    id: str  

class ChatRequest(BaseModel):
    message: str    




class SpendingData(BaseModel):
    month: str  # e.g., "2025-10"
    total_amount: float
    by_category: Dict[str, float]

@app.post("/ai-recommendations", response_model=List[str])
async def ai_recommendations(spending: SpendingData):
    """
    Generate AI-based recommendations based on monthly spending.
    """
    # Prepare the prompt for AI
    prompt = f"""
    You are a financial assistant. Here is the user's monthly spending data:
    Month: {spending.month}
    Total Spending: Rs. {spending.total_amount}
    Breakdown by category:
    {chr(10).join([f"{cat}: Rs. {amt}" for cat, amt in spending.by_category.items()])}

    Provide 3-5 actionable recommendations for the user to optimize their spending, 
    reduce unnecessary expenses, and save more money. Return each recommendation as a short string.
    """

    try:
        response = openai.ChatCompletion.create(
           model="gpt-3.5-turbo", 

            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            max_tokens=200,
        )
        # Extract recommendations
        text = response.choices[0].message.content.strip()
        # Split by newlines or numbered list
        recommendations = [line.strip("-–0123456789. ").strip() for line in text.split("\n") if line.strip()]
        return recommendations[:5]  # limit to 5 recommendations
    except Exception as e:
        return [f"Error generating recommendations: {str(e)}"]
# Expense Endpoints
@app.post("/expenses")
def add_expense(expense: ExpenseInput):
    result = collection.insert_one(expense.dict())
    return {"message": "Expense added", "id": str(result.inserted_id)}


@app.get("/expenses", response_model=List[Expense])
def get_expenses():
    try:
        expenses = []
        for doc in collection.find():
            expense = {
                "id": str(doc.get("_id", "")), 
                "title": str(doc.get("title") or ""),
                "amount": float(doc.get("amount", 0)),
                "category": str(doc.get("category") or ""),
                "date": doc.get("date").isoformat() if isinstance(doc.get("date"), datetime) else str(doc.get("date"))
            }
            expenses.append(expense)
        return expenses
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load expenses: {str(e)}")
    

@app.delete("/expenses/{expense_id}")
async def delete_expense(expense_id: str):
    try:
        obj_id = ObjectId(expense_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="Invalid expense ID format")

    result = await expense_collection.delete_one({"_id": obj_id})
    if result.deleted_count == 1:
        return {"message": "Expense deleted"}
    raise HTTPException(status_code=404, detail="Expense not found")






@app.put("/expenses/{id}")
def update_expense(id: int, updated: Expense):
    result = collection.update_one({"id": id}, {"$set": updated.dict()})
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Expense not found or unchanged")
    return {"message": "Expense updated"}

@app.get("/summary/{month}")
def get_monthly_summary(month: str):
    expenses = list(collection.find({"date": {"$regex": f"^{month}"}}))
    total = sum(e["amount"] for e in expenses)
    count = len(expenses)

    summary = f"📊 Summary for {month}\n"
    summary += f"• Total Expenses: Rs.{total}\n"
    summary += f"• Number of Entries: {count}"

    if expenses:
        highest = max(expenses, key=lambda x: x["amount"])
        summary += f"\n• Highest Expense: {highest['title']} (Rs.{highest['amount']}) on {highest['date']}"

    return {"summary": summary}

@app.get("/insights")
def get_expense_insights():
    try:
        # Category aggregation: total amount and count per category
        pipeline = [
            {
                "$group": {
                    "_id": "$category",
                    "total": {"$sum": "$amount"},
                    "count": {"$sum": 1}
                }
            },
            {"$sort": {"total": -1}}
        ]
        category_result = list(collection.aggregate(pipeline))

        # Weekly trend
        weekly_totals = defaultdict(float)
        for doc in collection.find():
            try:
                date_str = doc.get("date")
                amount = doc.get("amount", 0)

                if not date_str or not isinstance(amount, (int, float)):
                    continue

                try:
                    # Parse and convert date
                    date_obj = datetime.strptime(date_str.split("T")[0], "%Y-%m-%d")
                    week_key = f"{date_obj.year}-W{date_obj.isocalendar().week}"
                    weekly_totals[week_key] += float(amount)
                except Exception:
                    continue

            except Exception:
                continue

        return {
            "by_category": category_result,
            "weekly_trend": dict(sorted(weekly_totals.items()))
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch insights: {str(e)}")

@app.post("/budget")
def set_budget(budget: Budget):
    existing = budget_collection.find_one({})
    if existing:
        budget_collection.update_one({}, {"$set": {"amount": budget.amount}})
    else:
        budget_collection.insert_one({"amount": budget.amount})
    return {"message": "Budget set successfully."}

@app.get("/budget")
def get_budget():
    budget = budget_collection.find_one({})
    return {"amount": budget["amount"] if budget else 0.0}

@app.post("/budget/{month}")
def set_monthly_budget(month: str, budget: Budget):
    db.budget.update_one({"month": month}, {"$set": {"amount": budget.amount}}, upsert=True)
    return {"message": "Monthly budget set successfully."}

@app.get("/budget/{month}")
def get_monthly_budget(month: str):
    budget_data = db.budget.find_one({"month": month})
    return {"month": month, "amount": budget_data["amount"] if budget_data else 0.0}

@app.get("/daily-limit")
def get_daily_spending_limit():
    today = datetime.today()
    year, month = today.year, today.month
    next_month = month % 12 + 1
    year += (month + 1) // 13
    first_day_next_month = datetime(year, next_month, 1)
    remaining_days = (first_day_next_month - today).days

    budget_doc = budget_collection.find_one({})
    total_budget = float(budget_doc.get("amount", 0.0)) if budget_doc else 0.0

    expenses = list(collection.find())
    total_spent = sum(float(e.get("amount", 0.0)) for e in expenses)

    remaining_budget = total_budget - total_spent
    daily_limit = remaining_budget / remaining_days if remaining_days > 0 else 0.0

    return {
        "limit": round(daily_limit, 2),
        "remaining_budget": round(remaining_budget, 2),
        "remaining_days": remaining_days
    }

@app.get("/forecast")
def forecast_budget():
    expenses = list(collection.find({}, {"_id": 0}))
    if not expenses:
        return {"forecast": 0.0}

    try:
        df = pd.DataFrame(expenses)
        if 'amount' not in df or 'date' not in df:
            return {"forecast": 0.0}

        df['date'] = pd.to_datetime(df['date'], errors='coerce')
        df = df.dropna(subset=['date', 'amount'])

        df['month'] = df['date'].dt.to_period("M").astype(str)
        monthly = df.groupby('month')['amount'].sum().reset_index()

        if monthly.empty:
            return {"forecast": 0.0}
        if len(monthly) < 2:
            return {"forecast": round(monthly['amount'].iloc[-1], 2)}

        monthly['month_num'] = range(len(monthly))
        model = LinearRegression()
        model.fit(monthly[['month_num']], monthly[['amount']])

        next_month = [[monthly['month_num'].max() + 1]]
        forecast = model.predict(next_month)[0][0]

        return {"forecast": round(float(forecast), 2)}
    except Exception as e:
        return {"forecast": 0.0, "error": str(e)}

@app.get("/graph-data")
async def get_graph_data():
    try:
        data = await get_all_expenses()
        graph_data = []
        for item in data:
            if "date" in item and "amount" in item:
                date_val = item["date"]
                if isinstance(date_val, datetime):
                    date_str = date_val.strftime("%Y-%m-%d")
                else:
                    date_str = str(date_val).split("T")[0] if "T" in str(date_val) else str(date_val)

                graph_data.append({
                    "date": date_str,
                    "amount": float(item["amount"])
                })

        return {"graph_data": graph_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load graph data: {str(e)}")

@app.post("/upload_bill")
async def upload_bill(data: BillUpload):
    try:
        # --- Decode Base64 Image ---
        if "," in data.image_base64:
            _, encoded = data.image_base64.split(",", 1)
        else:
            encoded = data.image_base64
        image_data = base64.b64decode(encoded)
        filename = f"{uuid.uuid4()}.jpg"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(image_data)

        # --- OCR Text Extraction ---
        image = Image.open(filepath)
        text = pytesseract.image_to_string(image)

        # For debugging - log the extracted text
        print("OCR Extracted Text:")
        print(text)
        print("--- End OCR Text ---")

        # --- Title Extraction ---
        lines = [line.strip() for line in text.strip().splitlines() if line.strip()]
        title = lines[0] if lines else "Auto Expense"

        # --- Improved Total Amount Extraction ---
        amount = 0.0

        # Strategy 1: Look for common total patterns with context
        total_patterns = [
            r"(?:net\s+total|total\s+amount|amount\s+payable|grand\s+total|total\s+payable|total)\s*[:|]?\s*[^\d]*([\d,]+\.?\d{0,2})",
            r"\|.*\|.*\|.*\|.*([\d,]+\.\d{2})\s*\|$",  # For tabular data with proper decimal
            r"([\d,]+\.\d{2})\s*$",  # Amount with decimal at end of line
            r"total.*?(\d+\.\d{2})",  # Total followed by amount with decimal
        ]
        for pattern in total_patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                try:
                    amount_str = match.group(1).replace(",", "").strip()
                    candidate = float(amount_str)
                    # Validate it's a reasonable amount (not too large)
                    if 0 < candidate < 100000:  # Assuming no single item exceeds $100,000
                        amount = candidate
                        print(f"Found amount using pattern '{pattern}': {amount}")
                        break
                except:
                    continue
            if amount > 0:
                break

        # Strategy 2: If patterns didn't work, find all monetary values and take the largest reasonable one
        if amount == 0.0:
            # Look for numbers with decimal points (likely prices)
            price_pattern = r"(\d{1,3}(?:,\d{3})*\.\d{2})|(\d+\.\d{2})"
            prices = []
            for match in re.finditer(price_pattern, text):
                price_str = match.group(0).replace(",", "")
                try:
                    price = float(price_str)
                    # Filter out unreasonable values (too small or too large)
                    if 1 <= price <= 10000:
                        prices.append(price)
                except:
                    continue
            if prices:
                amount = max(prices)
                print(f"Found amount from prices: {amount}")

        # Strategy 3: As a last resort, find all numbers and take the largest reasonable one
        if amount == 0.0:
            all_numbers = re.findall(r"(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)", text)
            reasonable_numbers = []
            for num_str in all_numbers:
                try:
                    num = float(num_str.replace(",", ""))
                    # Filter out numbers that are too small (quantities) or too large (errors)
                    if 10 <= num <= 10000:
                        reasonable_numbers.append(num)
                except:
                    continue
            if reasonable_numbers:
                amount = max(reasonable_numbers)
                print(f"Found amount from reasonable numbers: {amount}")

        # --- Date Extraction ---
        date_str = None
        date_patterns = [
            r"date[^\d]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})",
            r"date[^\d]*(\d{1,2}[-/][a-z]{3,}[-/]\d{2,4})",
            r"(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})",
            r"(\d{1,2}[-/][a-z]{3,}[-/]\d{2,4})"
        ]
        for pattern in date_patterns:
            date_match = re.search(pattern, text, re.IGNORECASE)
            if date_match:
                date_str = date_match.group(1)
                break

        if not date_str:
            date_str = datetime.today().strftime("%d-%b-%Y")

        try:
            # Try different date formats
            for fmt in ("%d-%b-%Y", "%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%d %b %Y"):
                try:
                    date = datetime.strptime(date_str, fmt)
                    break
                except ValueError:
                    continue
            else:
                # If none of the formats worked, use today's date
                date = datetime.today()
        except:
            date = datetime.today()

        # --- Construct Expense Document ---
        expense = {
            "user_id": data.user_id,
            "title": title,
            "amount": amount,
            "date": date.strftime("%Y-%m-%d"),
            "category": "Shopping",
            "created_at": datetime.utcnow()
        }

        result = collection.insert_one(expense)
        expense["_id"] = str(result.inserted_id)
        expense["created_at"] = expense["created_at"].isoformat()

        return {
            "message": "Bill uploaded and expense added successfully",
            "data": expense,
            "raw_text": text
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unhandled server error: {e}")


class ChatRequest(BaseModel):
    message: str


def parse_expense_text(message: str):
    message = message.lower()

    # --- Detect date ---
    if "yesterday" in message:
        date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    else:
        date = datetime.now().strftime("%Y-%m-%d")

    # --- Detect amount ---
    amount_match = re.search(r'(\d+(\.\d{1,2})?)', message)
    amount = float(amount_match.group()) if amount_match else 0.0

    # --- Categories ---
    categories = {
        "food": ["pizza", "burger", "restaurant", "dinner", "lunch", "breakfast", "ate", "ordered", "meal"],
        "shopping": ["shirt", "jeans", "dress", "clothes", "tshirt", "pant", "shopping", "shoes", "bag"],
        "transport": ["uber", "bus", "train", "taxi", "petrol", "fuel"],
        "entertainment": ["movie", "netflix", "game", "concert", "cinema"],
        "bills": ["gym", "fee", "electricity", "water", "wifi", "internet", "bill", "rent", "subscription"],
    }

    category = "other"
    for cat, keywords in categories.items():
        if any(word in message for word in keywords):
            category = cat
            break

    # --- Extract title ---
    title = "expense"
    # Look for verbs + capture following words (up to 3)
    title_match = re.search(
        r"(?:ate|had|ordered|bought|got|paid|spent|purchased)\s+(?:a\s+|an\s+|the\s+)?([\w\s]+?)(?:\s+of|\s+for|$|\d)",
        message
    )
    if title_match:
        title = title_match.group(1).strip()
    else:
        # Fallback: use first category keyword found in the message
        for cat, keywords in categories.items():
            for word in keywords:
                if word in message:
                    title = word
                    break
            if title != "expense":
                break

    return {
        "title": title,
        "amount": amount,
        "category": category,
        "date": date,
    }


@app.post("/chat-expense")
async def chat_expense(request: ChatRequest):
    parsed = parse_expense_text(request.message)
    return {"data": parsed}

@app.post("/confirm-expense") 
async def confirm_expense(expense: ExpenseInput):
    result = collection.insert_one(expense.dict())
    return {"message": "Expense added", "id": str(result.inserted_id)}
    

@app.get("/expenses/summary")
def get_month_summary(month: int = Query(...), year: int = Query(...)):
    start_date = datetime(year, month, 1)
    end_month = month + 1 if month < 12 else 1
    end_year = year if month < 12 else year + 1
    end_date = datetime(end_year, end_month, 1)

    expenses = list(collection.find({
        "date": {"$gte": start_date.strftime("%Y-%m-%d"), "$lt": end_date.strftime("%Y-%m-%d")}
    }))

    total = sum(float(e.get("amount", 0)) for e in expenses)
    count = len(expenses)

    # Group by category
    category_summary = {}
    for e in expenses:
        cat = e.get("category", "other")
        category_summary[cat] = category_summary.get(cat, 0) + float(e.get("amount", 0))

    # Group by day
    daily_summary = {}
    for e in expenses:
        day = e.get("date")
        daily_summary[day] = daily_summary.get(day, 0) + float(e.get("amount", 0))

    # Convert ObjectId to string
    for e in expenses:
        e["_id"] = str(e["_id"])

    return {
        "month": month,
        "year": year,
        "total_amount": total,
        "total_entries": count,
        "by_category": category_summary,
        "by_day": daily_summary,
        "entries": expenses,
    }

@app.post("/voice_expense")
async def voice_to_expense(file: UploadFile = File(...)):
    recognizer = sr.Recognizer()
    with sr.AudioFile(file.file) as source:
        audio = recognizer.record(source)
        text = recognizer.recognize_google(audio)

    
    amount = re.findall(r'\d+', text)
    category = "food" if "food" in text or "groceries" in text else "misc"

    expense = {
        "text": text,
        "amount": float(amount[0]) if amount else 0,
        "category": category,
        "date": "today"
    }
    return {"status": "success", "parsed_expense": expense}

@app.post("/chat-expense/confirm")
async def confirm_expense(data: dict):
    # Save confirmed expense in DB
    expense = Expense(**data)
    db.expenses.insert_one(expense.dict())
    return {"message": "Expense added successfully"}

# ThreadPoolExecutor for running blocking generation
_executor = ThreadPoolExecutor(max_workers=1)





    #  python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload