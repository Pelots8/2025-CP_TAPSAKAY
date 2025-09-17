import React, { useContext, useState } from 'react'
import { LocalContext } from '../context/LocalContext'
import { useNavigate } from 'react-router-dom'
import BottomNav from '../components/BottomNav'

export default function Profile(){
  const { currentUser, updateProfile, logout } = useContext(LocalContext)
  const [name, setName] = useState(currentUser?.name || '')
  const [phone, setPhone] = useState(currentUser?.phone || '')
  const [email, setEmail] = useState(currentUser?.email || '')
  const [pwdMode, setPwdMode] = useState(false)
  const [currentPwd, setCurrentPwd] = useState('')
  const [newPwd, setNewPwd] = useState('')
  const nav = useNavigate()

  const save = (e) => {
    e.preventDefault()
    updateProfile({ name, phone, email })
    alert('Profile updated (in-memory)')
  }

  const changePw = (e) => {
    e.preventDefault()
    // This demo does not change real password; just simulates
    if (!currentPwd || !newPwd) { alert('Fill both fields'); return }
    alert('Password changed (mock). You will be logged out to test.')
    logout()
    nav('/login')
  }

  return (
    <div>
      <div style={{backgroundColor:'#D9D9D9', height:'20%'}}>
        <p style={{color:'black', paddingLeft: '5px', font:'inter'}}>Profile</p>
      </div>
      <div className="card">
        <h2 className="h2">Profile</h2>
        <form onSubmit={save} style={{marginTop:12, display:'grid', gap:10}}>
          <input className="input" value={name} onChange={e=>setName(e.target.value)} placeholder="Full name" />
          <input className="input" value={phone} onChange={e=>setPhone(e.target.value)} placeholder="Phone" />
          <input className="input" value={email} onChange={e=>setEmail(e.target.value)} placeholder="Email" />
          <button className="btn btn-primary">Save profile</button>
        </form>
      </div>

      <div className="card mt-4">
        <h3 className="h2">Security</h3>
        {!pwdMode ? (
          <div style={{marginTop:12, display:'flex', gap:10}}>
            <button className="btn" onClick={()=>setPwdMode(true)}>Change password</button>
            <button className="btn" style={{background:'#EF4444', color:'#fff'}} onClick={() => { logout(); nav('/login') }}>Logout</button>
          </div>
        ) : (
          <form onSubmit={changePw} style={{marginTop:12, display:'grid', gap:10}}>
            <input className="input" type="password" placeholder="Current password" value={currentPwd} onChange={e=>setCurrentPwd(e.target.value)} />
            <input className="input" type="password" placeholder="New password" value={newPwd} onChange={e=>setNewPwd(e.target.value)} />
            <div style={{display:'flex', gap:8}}>
              <button className="btn btn-primary" style={{flex:1}}>Save</button>
              <button className="btn" type="button" onClick={()=>setPwdMode(false)}>Cancel</button>
            </div>
          </form>
        )}
      </div>
      <BottomNav />
    </div>
  )
}
