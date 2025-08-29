# bill_upload.py or inside main.py
import pytesseract
from fastapi import APIRouter, File, UploadFile, HTTPException
from PIL import Image
import io
from db import expense_collection  # Make sure this import works

router = APIRouter()

@router.post("/upload-bill/")
async def upload_bill(file: UploadFile = File(...)):
    if not file.filename.lower().endswith((".png", ".jpg", ".jpeg")):
        raise HTTPException(status_code=400, detail="Only image files are allowed.")

    contents = await file.read()
    try:
        image = Image.open(io.BytesIO(contents))
        extracted_text = pytesseract.image_to_string(image)
        
        # Optional: save extracted bill to MongoDB
        bill_data = {
            "filename": file.filename,
            "extracted_text": extracted_text
        }
        await expense_collection.insert_one(bill_data)

        return {"extracted_text": extracted_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing image: {e}")
