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
from PIL import Image
import pytesseract
import pandas as pd
from sklearn.linear_model import LinearRegression
from bson import ObjectId
from db import get_all_expenses
from db import expense_collection
from bson.errors import InvalidId
import dateparser

# MongoDB setup
client = MongoClient("mongodb://localhost:27017")
db = client["expense_db"]
collection = db["expenses"]
budget_collection = db["budget"]

# FastAPI instance
app = FastAPI()

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

class Expense(BaseModel):
    id: str
    title: str
    amount: float
    category: str
    date: str

class Budget(BaseModel):
    amount: float

class ExpenseInput(BaseModel):
    title: str
    amount: float
    category: str
    date: str

class Expense(ExpenseInput):
    id: str  



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
                "id": str(doc.get("_id", "")),  # Convert ObjectId to string
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
                    if 1 <= price <= 10000:  # Reasonable price range
                        prices.append(price)
                except:
                    continue
            
            if prices:
                # Take the largest price that's likely the total
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
                    if 10 <= num <= 10000:  # Reasonable amount range
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
            "category": "Shopping",  # Default category
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
    

CATEGORY_KEYWORDS = {
    "Food": [
        "eat", "ate", "lunch", "dinner", "breakfast", "snack",
        "burger", "biryani", "pizza", "kfc", "mcdonald", "coffee",
        "restaurant", "meal", "chai", "tea"
    ],
    "Transport": [
        "uber", "careem", "taxi", "bus", "train", "fuel", "petrol",
        "diesel", "ride", "cab", "fare"
    ],
    "Bills": [
        "bill", "electricity", "gas", "water", "internet", "wifi",
        "phone", "rent"
    ],
    "Shopping": [
        "grocery", "groceries", "clothes", "shirt", "shoes", "mall",
        "amazon", "daraz", "market", "shopping"
    ],
}

DEFAULT_CATEGORY = "Other"

def guess_category(text: str) -> str:
    t = text.lower()
    for cat, keywords in CATEGORY_KEYWORDS.items():
        if any(k in t for k in keywords):
            return cat
    return DEFAULT_CATEGORY

def extract_amount(text: str) -> Optional[float]:
    # Try “rs 500”, “500 rs”, “pkr 1,250”, “1250”
    patterns = [
        r'(?:rs\.?|pkr)\s*([\d,]+(?:\.\d{1,2})?)',
        r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|pkr)'
    ]
    for pat in patterns:
        m = re.search(pat, text, flags=re.IGNORECASE)
        if m:
            try:
                return float(m.group(1).replace(",", ""))
            except:
                pass
    # fallback: first reasonable number
    m = re.search(r'(\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?', text)
    if m:
        try:
            return float(m.group(0).replace(",", ""))
        except:
            return None
    return None

def extract_merchant(text: str) -> Optional[str]:
    # “at KFC”, “from Imtiaz”
    for pat in [r'\bat\s+([a-z0-9&\'\-\s]+)', r'\bfrom\s+([a-z0-9&\'\-\s]+)']:
        m = re.search(pat, text, flags=re.IGNORECASE)
        if m:
            return m.group(1).strip().title()
    return None

def extract_item(text: str) -> Optional[str]:
    # “I ate a burger ...”, “Bought shoes ...”, “Paid electricity bill ...”
    patterns = [
        r'\b(?:ate|had|ordered|bought|purchased|got|paid)\s+(?:a|an|the\s+)?([a-z\s]+?)(?:\s+for|\s+of|\s+at|\s+from|\s+\d|\.|$)',
    ]
    for pat in patterns:
        m = re.search(pat, text, flags=re.IGNORECASE)
        if m:
            return m.group(1).strip().title()
    return None

def extract_date(text: str) -> datetime:
    # Understand natural language dates. Defaults to today if not found.
    dt = dateparser.parse(
        text,
        settings={
            "PREFER_DATES_FROM": "past",
            "RELATIVE_BASE": datetime.now(),  # Asia/Karachi environment time
            "DATE_ORDER": "DMY"
        },
    )
    return dt or datetime.now()

class ChatExpenseIn(BaseModel):
    text: str
    user_id: Optional[str] = "user123"

@app.post("/chat/expense")
def create_expense_from_text(payload: ChatExpenseIn):
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Empty text")

    amount = extract_amount(text)
    if amount is None:
        raise HTTPException(status_code=422, detail="Could not detect amount")

    when = extract_date(text).strftime("%Y-%m-%d")
    merchant = extract_merchant(text)
    item = extract_item(text)

    # Title strategy: prefer item + merchant
    if item and merchant:
        title = f"{item} @ {merchant}"
    elif item:
        title = item
    elif merchant:
        title = merchant
    else:
        # fallback: first few words
        title = text[:40].strip().rstrip(".")
        if not title:
            title = "Expense"

    category = guess_category(text)

    doc = {
        "user_id": payload.user_id,
        "title": title,
        "amount": float(amount),
        "category": category,
        "date": when,
        "created_at": datetime.utcnow(),
        "source": "chat",
        "raw_text": text,
    }
    result = collection.insert_one(doc)

    expense_out = {
        "id": str(result.inserted_id),
        "title": doc["title"],
        "amount": doc["amount"],
        "category": doc["category"],
        "date": doc["date"],
    }

    return {
        "message": "Expense created from chat",
        "expense": expense_out,
        "parsed": {
            "amount": amount,
            "date": when,
            "merchant": merchant,
            "item": item,
            "category": category,
        },
    }        

    #  python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload