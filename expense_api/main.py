import asyncio
from calendar import calendar
import hashlib
from unittest import result
from fastapi import FastAPI, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
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


app = FastAPI()


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

# -----------------------------------------------------
# 2️⃣ Database Connection
# -----------------------------------------------------
client = MongoClient("mongodb://localhost:27017")
db = client["expense_db"]
expenses = db["expenses"]

# -----------------------------------------------------
# 3️⃣ Simple In-memory Cache
# -----------------------------------------------------
cache = {}

def get_cache_key(user_query: str):
    return hashlib.md5(user_query.lower().encode()).hexdigest()

# -----------------------------------------------------
# 4️⃣ Request Schema
# -----------------------------------------------------
class ChatRequest(BaseModel):
    message: str

# -----------------------------------------------------
# 5️⃣ Expense Summary Generator
# -----------------------------------------------------
def summarize_expenses(query_filter):
    data = list(expenses.find(query_filter))
    if not data:
        return "No expenses found in that period."

    total = sum(item["amount"] for item in data)
    categories = {}
    for item in data:
        cat = item.get("category", "Other")
        categories[cat] = categories.get(cat, 0) + item["amount"]

    breakdown = ", ".join([f"{cat}: {amt}" for cat, amt in categories.items()])
    return f"Total spent: {total} PKR. Breakdown: {breakdown}"

# -----------------------------------------------------
# 6️⃣ Time Range Detector
# -----------------------------------------------------
def detect_date_range(user_query: str):
    """
    Detects the date range (start, end) based on the user's query.
    Returns a MongoDB-style filter: {"date": {"$gte": start, "$lte": end}}
    """
    now = datetime.now()
    user_query = user_query.lower()

    start_date, end_date = None, None

    # --- Today ---
    if "today" in user_query:
        start_date = end_date = now

    # --- Yesterday ---
    elif "yesterday" in user_query:
        start_date = end_date = now - timedelta(days=1)

    # --- This Week ---
    elif "this week" in user_query:
        start_date = now - timedelta(days=now.weekday())  # Monday
        end_date = now

    # --- Last Week ---
    elif "last week" in user_query:
        last_monday = now - timedelta(days=now.weekday() + 7)
        start_date = last_monday
        end_date = last_monday + timedelta(days=6)

    # --- This Month ---
    elif "this month" in user_query or "october" in user_query:  # Added direct month word matching
        start_date = now.replace(day=1)
        end_date = now

    # --- Last Month ---
    elif "last month" in user_query or "previous month" in user_query:
        first_day_this_month = now.replace(day=1)
        last_month_end = first_day_this_month - timedelta(days=1)
        start_date = last_month_end.replace(day=1)
        end_date = last_month_end

    # --- This Year ---
    elif "this year" in user_query:
        start_date = datetime(now.year, 1, 1)
        end_date = now

    # --- Last Year ---
    elif "last year" in user_query or "previous year" in user_query:
        start_date = datetime(now.year - 1, 1, 1)
        end_date = datetime(now.year - 1, 12, 31)

    # --- Month Names (like "in September", "from March") ---
    else:
        months = [
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december"
        ]
        for i, month in enumerate(months, start=1):
            if month in user_query:
                year = now.year
                # If month is greater than current, assume previous year
                if i > now.month:
                    year -= 1
                start_date = datetime(year, i, 1)
                # Compute last day of month
                if i == 12:
                    end_date = datetime(year, 12, 31)
                else:
                    end_date = datetime(year, i + 1, 1) - timedelta(days=1)
                break

    # --- Fallback: All Data ---
    if not start_date or not end_date:
        return {}

    # Format for MongoDB
    return {
        "date": {
            "$gte": start_date.strftime("%Y-%m-%d"),
            "$lte": end_date.strftime("%Y-%m-%d")
        }
    }
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


@app.post("/ai-chat")
async def ai_chat(request: ChatRequest):
    """
    Improved ai_chat:
    - robust date & category detection
    - safe prompts for flan-t5-base
    - rule-based fallback for advice and short/echoed outputs
    - handles "last expense" correctly
    """
    user_query = request.message.strip()
    cache_key = get_cache_key(user_query)

    # Return cached response if exists
    if cache_key in cache:
        return {"response": cache[cache_key]["text"], "cached": True}

    # ---------- Helper: small rule-based advice generator ----------
    def rule_based_advice(summary_dict):
        total = summary_dict.get("total", 0)
        cats = summary_dict.get("categories", {})
        tips = []

        # Tip 1: target largest category
        if cats:
            top_cat = max(cats.items(), key=lambda x: x[1])[0]
            tips.append(f"You're spending most on *{top_cat}*. Try reducing that category by 10% next month.")
        else:
            tips.append("Start by tracking all purchases for a week so we can spot easy savings.")

        # Tip 2: general spending rule
        if total > 20000:
            tips.append("Your total spending is high — set a weekly limit and review subscriptions.")
        else:
            tips.append("You're within a reasonable range — keep tracking and try a small weekly budget to save more.")

        # Tip 3: simple habit
        tips.append("Avoid impulse buys: wait 24 hours before non-essential purchases over 2,000 PKR.")

        return " ".join(tips)

    # ---------- Summarization logic (runs in executor to avoid blocking) ----------
    def summarize_text_local(user_query: str):
        # detect period & categories (uses your existing detect_date_range())
        query_filter = detect_date_range(user_query)

        # detect categories
        categories_list = [
            "food", "transport", "shopping", "groceries", "bills",
            "entertainment", "health", "rent", "education", "travel", "utilities"
        ]
        detected_categories = [c for c in categories_list if c in user_query.lower()]

        # build mongo filter for categories if needed
        if detected_categories:
            # preserve existing date filter possibly empty dict
            if isinstance(query_filter, dict):
                query_filter = dict(query_filter)  # shallow copy
            else:
                query_filter = {}
            query_filter["category"] = {"$in": detected_categories}

        # last-expense detection
        if any(k in user_query.lower() for k in ["last expense", "recent expense", "latest expense", "what was my last expense"]):
            last_doc = db.expenses.find_one(sort=[("_id", -1)])
            if not last_doc:
                return {"text": "No recorded expenses found.", "has_data": False, "detected_categories": []}
            # build nice output and structured dict
            dd = {
                "text": f"Last expense: {last_doc.get('category', 'Unknown')} — PKR {float(last_doc.get('amount', 0))} for {last_doc.get('description', last_doc.get('title','no description'))}.",
                "has_data": True,
                "total": float(last_doc.get("amount", 0)),
                "categories": { last_doc.get("category", "Unknown"): float(last_doc.get("amount", 0)) },
                "detected_categories": [ last_doc.get("category", "Unknown") ]
            }
            return dd

        # expense vs advice detection
        expense_keywords = ["total", "spent", "expense", "summary", "report", "how much", "spending", "cost", "money", "this week", "last month", "today", "yesterday", "this month", "week", "month"]
        advice_keywords = ["advice", "suggest", "tips", "how to save", "how can i save", "help me save", "recommend"]

        if any(w in user_query.lower() for w in expense_keywords):
            # query DB using query_filter (which might be {} meaning all data)
            qf = query_filter if isinstance(query_filter, dict) else {}
            docs = list(db.expenses.find(qf))
            if not docs:
                return {"text": "No expenses found in that period.", "has_data": False, "total": 0, "categories": {}, "detected_categories": detected_categories}

            total = sum(float(d.get("amount", 0)) for d in docs)
            categories = {}
            for d in docs:
                cat = d.get("category", "Other")
                categories[cat] = categories.get(cat, 0) + float(d.get("amount", 0))

            summary_text = f"Total spent: {total:.2f} PKR. Breakdown: " + ", ".join([f"{c}: {amt:.2f}" for c, amt in categories.items()])
            return {"text": summary_text, "has_data": True, "total": total, "categories": categories, "detected_categories": detected_categories}

        if any(w in user_query.lower() for w in advice_keywords):
            # return marker telling main flow we need advice
            # but provide structured recent-month summary to base advice on
            # default to last 30 days
            now = datetime.now()
            start_30 = now - timedelta(days=30)
            docs = list(db.expenses.find({"date": {"$gte": start_30, "$lte": now}}))
            if not docs:
                return {"text": "No recent expenses to analyze for advice.", "has_data": False, "total": 0, "categories": {}, "detected_categories": []}

            total = sum(float(d.get("amount", 0)) for d in docs)
            categories = {}
            for d in docs:
                cat = d.get("category", "Other")
                categories[cat] = categories.get(cat, 0) + float(d.get("amount", 0))

            return {"text": "advice_request", "has_data": True, "total": total, "categories": categories, "detected_categories": detected_categories}

        # Non-expense / fallback: no structured data
        return None

    # run summarizer in executor
    loop = asyncio.get_event_loop()
    summary = await loop.run_in_executor(_executor, summarize_text_local, user_query)

    # ---------- Build prompt / handle different types ----------
    # If advice request, prefer rule-based advice to avoid model echoing instructions
    if summary and summary.get("text") == "advice_request":
        # use rule-based advice using structured data to guarantee useful output
        reply = rule_based_advice(summary)
        cache[cache_key] = {"text": reply, "has_data": True}
        return {"response": reply, "cached": False, "has_expense_data": True}

    # If we have a last-expense or summary dict, craft a compact instruction for the model
    if summary:
        # use the structured summary text but keep instruction minimal and explicit
        model_prompt = (
            f"USER QUERY: {user_query}\n\n"
            f"DATA: {summary['text']}\n\n"
            "INSTRUCTION: Answer the user's question concisely using the DATA above. "
            "Do NOT repeat these instructions. Provide numbers where available.\n\n"
            "RESPONSE:"
        )
    else:
        # general chat fallback
        model_prompt = (
            f"USER QUERY: {user_query}\n\n"
            "INSTRUCTION: Provide a short helpful answer. If you need expense data, ask the user to add it.\n\n"
            "RESPONSE:"
        )

    # ---------- Call the model (flan-t5-base) ----------
    try:
        inputs = tokenizer(model_prompt, return_tensors="pt", truncation=True, padding=True)
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=160,
                do_sample=False,     # deterministic
                temperature=0.0,
                early_stopping=True
            )
        reply = tokenizer.decode(outputs[0], skip_special_tokens=True).strip()
    except Exception as e:
        reply = f"AI error: {e}"

    # ---------- Post-check: detect instruction-echo or too-short output ----------
    lower_reply = reply.lower()
    # simple heuristic: if model echoed instruction text or is too short, fallback to rule-based
    if len(reply) < 12 or "instruction" in lower_reply or "do not" in lower_reply or "do not repeat" in lower_reply or "if the user" in lower_reply:
        # If we have structured data, create a short deterministic response
        if summary and summary.get("has_data"):
            # Build a short factual reply
            total = summary.get("total", 0)
            cats = summary.get("categories", {})
            if total and cats:
                top = max(cats.items(), key=lambda x: x[1])
                reply = f"You spent {total:.2f} PKR. Top category: {top[0]} ({top[1]:.2f} PKR)."
            elif total:
                reply = f"You spent {total:.2f} PKR."
            else:
                reply = summary.get("text", "No expenses found.")
        else:
            reply = "I couldn't generate a good answer. Please try a shorter question or specify a date range (e.g., 'this month')."

    # save to cache and return
    cache[cache_key] = {"text": reply, "has_data": bool(summary and summary.get("has_data", False))}
    return {
        "response": reply,
        "cached": False,
        "has_expense_data": bool(summary and summary.get("has_data", False)),
        "detected_categories": summary.get("detected_categories", []) if summary else []
    }


    #  python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload