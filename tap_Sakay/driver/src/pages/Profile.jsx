import React, { useState } from 'react'
import Sidebar from '../components/Sidebar.jsx'
import Header from '../components/Header.jsx'
import '../styles/profile.css'

export default function Profile() {
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState({ name: 'Test Driver', email: 'driver@example.com', vehicle: 'Jeepney', plate: 'ABC-1234' })

  return (
    <div>
      <div className="app-root" style={{color: 'white'}}>
        <Sidebar />
        <div className="main">
          <Header title="Profile" />
          <div className="main-inner" style={{ padding: 24 }}>
            <div className="card" style={{ maxWidth: 900, display:'flex', gap:20 }}>
              <div style={{ width: 240, textAlign: 'center' }}>
                <img src="/assets/bg.png" style={{ width:140, height:140, borderRadius:12 }} alt="avatar" />
                <div style={{ marginTop: 12, fontWeight:700 }}>{form.name}</div>
                <div className="muted">{form.email}</div>
              </div>
              
              <div style={{ flex: 1 }}>
                <h1 style={{fontSize:'20px', marginLeft:'-25px', marginTop:'-2px'}}>Status</h1>
                {!editing && (
                  <div>
                    <p><strong>Vehicle:</strong> {form.vehicle}</p>
                    <p><strong>Plate:</strong> {form.plate}</p>
                    <button onClick={() => setEditing(true)}>Edit Profile</button>
                  </div>
                )}

                {editing && (
                  <form onSubmit={(e) => { e.preventDefault(); setEditing(false); alert('Profile updated (UI-only)') }}>
                    <label>Name</label>
                    <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} />
                    <label>Email</label>
                    <input value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} />
                    <label>Vehicle</label>
                    <input value={form.vehicle} onChange={e => setForm({ ...form, vehicle: e.target.value })} />
                    <label>Plate</label>
                    <input value={form.plate} onChange={e => setForm({ ...form, plate: e.target.value })} />
                    <div style={{ marginTop: 12 }}>
                      <button type="submit">Save</button>
                      <button type="button" className="secondary" onClick={() => setEditing(false)} style={{ marginLeft: 8 }}>Cancel</button>
                    </div>
                  </form>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
