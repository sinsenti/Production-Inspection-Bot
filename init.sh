#!/bin/bash

set -e

PROJ_ROOT="your-project-root"
BACKEND="$PROJ_ROOT/production_inspection_bot"
FRONTEND="$PROJ_ROOT/frontend"

# Create folder structure
mkdir -p "$BACKEND/static/photos"
mkdir -p "$FRONTEND/public"
mkdir -p "$FRONTEND/src"

# --- docker-compose.yml ---
cat >"$PROJ_ROOT/docker-compose.yml" <<EOF
version: "3.9"
services:
  backend:
    build: ./production_inspection_bot
    volumes:
      - ./production_inspection_bot/static:/app/static
      - ./production_inspection_bot/local.db:/app/local.db
    ports:
      - "8000:8000"
    restart: always
  frontend:
    build: ./frontend
    ports:
      - "5173:80"
    depends_on:
      - backend
EOF

# --- Backend: requirements.txt ---
cat >"$BACKEND/requirements.txt" <<EOF
fastapi
uvicorn
sqlalchemy
pydantic
python-multipart
EOF

# --- Backend: Dockerfile ---
cat >"$BACKEND/Dockerfile" <<EOF
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# --- Backend: database.py ---
cat >"$BACKEND/database.py" <<EOF
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "sqlite:///./local.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
EOF

# --- Backend: models.py ---
cat >"$BACKEND/models.py" <<EOF
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    fio = Column(String, unique=True, index=True)
    role = Column(String)  # admin/checker/observer

class Section(Base):
    __tablename__ = "sections"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)

class Checklist(Base):
    __tablename__ = "checklists"
    id = Column(Integer, primary_key=True, index=True)
    section_id = Column(Integer, ForeignKey("sections.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    date = Column(DateTime, default=datetime.utcnow)
    time = Column(String)
    score = Column(Integer)
    comments = Column(Text)
    section = relationship("Section")
    user = relationship("User")
    photos = relationship("Photo", back_populates="checklist")

class Photo(Base):
    __tablename__ = "photos"
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String)
    checklist_id = Column(Integer, ForeignKey("checklists.id"))
    checklist = relationship("Checklist", back_populates="photos")
    comment = Column(Text)
EOF

# --- Backend: main.py ---
cat >"$BACKEND/main.py" <<EOF
import os
from fastapi import FastAPI, UploadFile, File, Form, Depends
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from database import SessionLocal, engine, Base
import models

from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
EOF

# --- Frontend: Dockerfile ---
cat >"$FRONTEND/Dockerfile" <<EOF
FROM node:20 AS build
WORKDIR /app
COPY . .
RUN npm install && npm run build

FROM nginx:1.25
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
EOF

# --- Frontend: package.json ---
cat >"$FRONTEND/package.json" <<EOF
{
  "name": "frontend",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.6.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^4.4.9"
  }
}
EOF

# --- Frontend: vite.config.js ---
cat >"$FRONTEND/vite.config.js" <<EOF
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173
  }
});
EOF

# --- Frontend: src/App.jsx ---
cat >"$FRONTEND/src/App.jsx" <<EOF
import React, { useState } from 'react';
import axios from 'axios';

function App() {
  const [fio, setFio] = useState('');
  const [role, setRole] = useState('checker');
  const [userId, setUserId] = useState(null);
  const [sectionId, setSectionId] = useState(1);
  const [score, setScore] = useState(0);
  const [comments, setComments] = useState('');
  const [photos, setPhotos] = useState([]);
  const [result, setResult] = useState(null);

  async function registerUser() {
    const response = await axios.post('http://localhost:8000/users/', { fio, role });
    setUserId(response.data.id);
  }

  async function handlePhotoChange(e) {
    setPhotos(e.target.files);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!userId) {
      alert('Register user first!');
      return;
    }
    const formData = new FormData();
    formData.append('section_id', sectionId);
    formData.append('user_id', userId);
    formData.append('score', score);
    formData.append('comments', comments);
    for (let i=0; i < photos.length; i++) formData.append('photos', photos[i]);
    const res = await axios.post('http://localhost:8000/checklists/', formData, {headers: {'Content-Type': 'multipart/form-data'}});
    setResult(res.data);
  }

  return (
    <div style={{margin: 40}}>
      <h2>Checklist Submission</h2>
      <div>
        <input placeholder="ФИО" value={fio} onChange={e => setFio(e.target.value)} />
        <select value={role} onChange={e => setRole(e.target.value)}>
          <option value="checker">Проверяющий</option>
          <option value="admin">Админ</option>
          <option value="observer">Наблюдатель</option>
        </select>
        <button onClick={registerUser}>Зарегистрировать/Выбрать пользователя</button>
      </div>
      <form onSubmit={handleSubmit} style={{marginTop: '2em'}}>
        <div>
          <label>Section ID:</label>
          <input type="number" value={sectionId} onChange={e => setSectionId(Number(e.target.value))} />
        </div>
        <div>
          <label>Score:</label>
          <input type="number" value={score} onChange={e => setScore(Number(e.target.value))} />
        </div>
        <div>
          <label>Комментарий:</label>
          <textarea value={comments} onChange={e => setComments(e.target.value)} />
        </div>
        <div>
          <label>Фото:</label>
          <input type="file" onChange={handlePhotoChange} multiple />
        </div>
        <button type="submit">Отправить чеклист</button>
      </form>
      {result && (
        <div style={{color:'green', marginTop:'1em'}}>
          <b>Результат отправки:</b> {JSON.stringify(result)}
        </div>
      )}
    </div>
  );
}

export default App;
EOF

# --- Frontend: src/main.jsx ---
cat >"$FRONTEND/src/main.jsx" <<EOF
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF

# --- Frontend: public/index.html ---
cat >"$FRONTEND/public/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Checklist Frontend</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

echo "Project structure was created in $PROJ_ROOT."
echo "Next steps:"
echo "1. cd $PROJ_ROOT/frontend && npm install"
echo "2. cd $PROJ_ROOT && docker-compose up --build"
