import React, { useState, useContext } from 'react'
import { LocalContext } from '../context/LocalContext'
import { useNavigate } from 'react-router-dom'

export default function Register(){
  const { register } = useContext(LocalContext)
  const [name,setName]=useState('')
  const [email,setEmail]=useState('')
  const [phone,setPhone]=useState('')
  const [password,setPassword]=useState('')
  const [err,setErr]=useState('')
  const nav = useNavigate()

  const handle = (e) => {
    e.preventDefault()
    try {
      if (!name || !email || !password) throw new Error('Name, email and password are required')
      register({ name, email, phone, password })
      nav('/')
    } catch (error) {
      setErr(error.message)
    }
  }

  return (
    <div style={{maxWidth:420, margin:'6px auto'}}>
      <div className="card">
        <h2 className="h1 center">Create account</h2>
        <form onSubmit={handle} style={{marginTop:12, display:'grid', gap:10}}>
          <input className="input" placeholder="Full name" value={name} onChange={e=>setName(e.target.value)} />
          <input className="input" placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)} />
          <input className="input" placeholder="Phone (optional)" value={phone} onChange={e=>setPhone(e.target.value)} />
          <input className="input" type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)} />
          <button className="btn btn-green">Sign up</button>
        </form>
        {err && <div className="mt-2" style={{color:'crimson'}}>{err}</div>}
      </div>
    </div>
  )
}
