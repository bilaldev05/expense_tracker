import re
import spacy
from datetime import datetime

nlp = spacy.load("en_core_web_sm")

def parse_expense_text(text: str):
    doc = nlp(text)

    # Default values
    amount = None
    category = "Other"
    title = None
    date = datetime.now().strftime("%Y-%m-%d")

    # Extract amount (regex for numbers + rs)
    match = re.search(r'(\d+)\s?(rs|inr|rupees)?', text.lower())
    if match:
        amount = float(match.group(1))

    # Extract named entities (like KFC, Burger)
    for ent in doc.ents:
        if ent.label_ in ["ORG", "GPE", "PRODUCT"]:
            title = ent.text

    
    if any(word in text.lower() for word in ["burger", "pizza", "kfc", "restaurant", "meal", "food"]):
        category = "Food"
    elif any(word in text.lower() for word in ["uber", "bus", "taxi", "fuel", "petrol"]):
        category = "Transport"
    elif any(word in text.lower() for word in ["movie", "netflix", "cinema"]):
        category = "Entertainment"

    return {
        "title": title or "Unknown Expense",
        "amount": amount or 0,
        "category": category,
        "date": date,
    }
