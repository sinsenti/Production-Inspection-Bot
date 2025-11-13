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
