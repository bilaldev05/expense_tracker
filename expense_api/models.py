from pydantic import BaseModel
from pydantic import BaseModel
from typing import Optional

class UpdateExpense(BaseModel):
    title: Optional[str]
    amount: Optional[float]
    category: Optional[str]
    date: Optional[str]



class Expense(BaseModel):
    id: int
    title: str
    amount: float
    date: str
    category: str 

