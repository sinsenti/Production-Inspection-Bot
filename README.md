
# Production Inspection Bot

A fullstack application for production equipment and cleanliness inspections, with FastAPI backend and React frontend, running locally in Docker.

---

## Quick Start

### 1. Clone the repository

```
git clone https://github.com/sinsenti/Production-Inspection-Bot.git
cd Production-Inspection-Bot
```

### 2. Install Frontend Dependencies

Before you use Docker for the **first time**, run (in the `frontend/` directory):

```
cd frontend
# npm install # i hope not needed
cd ..
```

> This step generates the `node_modules` directory and `package-lock.json` for the React app build.

### 3. Start All Services

From the project root, run:

```
docker-compose up --build
```

- This will:
  - Build both backend and frontend Docker images.
  - Launch both services.
  - Persist uploads and database locally.

### 4. Access the App


- **Backend API docs (FastAPI):**  
  [http://localhost:8000/docs](http://localhost:8000/docs)

> [!NOTE]
> This i suppose not needed
- **Frontend (React):**  
  [http://localhost:5173](http://localhost:5173)

---

## Folder Structure

```
your-project-root/
├── docker-compose.yml
├── production_inspection_bot/
│   ├── Dockerfile
│   ├── main.py
│   ├── models.py
│   ├── database.py
│   ├── requirements.txt
│   ├── local.db (created at runtime)
│   └── static/photos/ (uploaded photos)
└── frontend/
    ├── Dockerfile
    ├── package.json
    ├── vite.config.js
    ├── index.html
    ├── public/
    └── src/
        ├── App.jsx
        └── main.jsx
```

---

## Common Commands

- **Rebuild after code changes:**  
  `docker-compose up --build`

---

**Developed with FastAPI, React, Docker, and SQLite.**
