from db import expense_collection
from models import Expense

def expense_helper(expense) -> dict:
    return {
        "id": expense["id"],
        "title": expense["title"],
        "amount": expense["amount"],
        "date": expense["date"],
    }

async def fetch_expenses():
    expenses = []
    async for doc in expense_collection.find():
        expenses.append(expense_helper(doc))
    return expenses

from bson import ObjectId

async def update_expense(expense_id: str, data: dict):
    updated_expense = await expense_collection.find_one_and_update(
        {"_id": ObjectId(expense_id)},
        {"$set": data},
        return_document=True
    )
    return updated_expense


async def add_expense(expense: Expense):
    await expense_collection.insert_one(expense.dict())

async def delete_expense(expense_id: int):
    await expense_collection.delete_one({"id": expense_id})

from bson import ObjectId

def serialize_expense(expense):
    expense['_id'] = str(expense['_id']) 
    return expense

