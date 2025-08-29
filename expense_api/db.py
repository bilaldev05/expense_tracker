from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId

MONGO_URI = "mongodb://localhost:27017"  # local MongoDB Compass connection
client = AsyncIOMotorClient(MONGO_URI)

database = client.expense_db  # same name as in Compass
expense_collection = database.get_collection("expenses")


# ✅ This function will return all expenses as a list of dictionaries
async def get_all_expenses():
    expenses = []
    async for expense in expense_collection.find():
        expense["_id"] = str(expense["_id"])  # Convert ObjectId to string
        expenses.append(expense)
    return expenses
