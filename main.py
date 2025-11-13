import os
from fastapi import FastAPI, UploadFile, File, Form, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from database import SessionLocal, engine, Base
import models

from pydantic import BaseModel

app = FastAPI()
Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class UserCreate(BaseModel):
    fio: str
    role: str

@app.post("/users/")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = models.User(**user.dict())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.post("/checklists/")
async def create_checklist(
    section_id: int = Form(...),
    user_id: int = Form(...),
    score: int = Form(...),
    comments: str = Form(""),
    photos: list[UploadFile] = File([]),
    db: Session = Depends(get_db)
):
    db_checklist = models.Checklist(
        section_id=section_id, user_id=user_id, score=score, comments=comments
    )
    db.add(db_checklist)
    db.commit()
    db.refresh(db_checklist)
    photo_objs = []
    for photo in photos:
        folder = "static/photos/"
        os.makedirs(folder, exist_ok=True)
        filepath = os.path.join(folder, photo.filename)
        with open(filepath, "wb") as image_file:
            image_file.write(await photo.read())
        db_photo = models.Photo(filename=photo.filename, checklist_id=db_checklist.id)
        db.add(db_photo)
        photo_objs.append(db_photo)
    db.commit()
    return {"checklist_id": db_checklist.id, "photos": [p.filename for p in photo_objs]}

@app.get("/photo/{filename}")
def get_photo(filename: str):
    folder = "static/photos/"
    filepath = os.path.join(folder, filename)
    return FileResponse(filepath)

# You can add endpoints for reporting, filtering, checklist analytics, etc.
