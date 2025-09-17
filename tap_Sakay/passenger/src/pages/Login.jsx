import React, { useState, useContext } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { LocalContext } from '../context/LocalContext'

export default function Login(){
  const { login } = useContext(LocalContext)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [err, setErr] = useState('')
  const nav = useNavigate()

  const handleSubmit = (e) => {
    e.preventDefault()
    try {
      if (!email || !password) throw new Error('Email and password required')
      login({ email, password })
      nav('/')
    } catch (error) {
      setErr(error.message)
    }
  }

  return (  
    <div style={{maxWidth:420, margin:'6px auto', justifyContent:'center'}}>
      <div className="card login-card">
        <h2 className="h1 center">Login</h2>
        <form onSubmit={handleSubmit} style={{marginTop:12, display:'grid', gap:10}}>
          <input className="input" placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} />
          <input className="input" type="password" placeholder="Password" value={password} onChange={e => setPassword(e.target.value)} />
          <button className="btn btn-primary">Login</button>
        </form>
        {err && <div className="mt-2" style={{color:'crimson'}}>{err}</div>}
        <div style={{marginTop:12, textAlign:'center'}}>
          <Link to="/register" style={{color:'#2563EB'}}>Create an account</Link>
        </div>
      </div>
    </div>
  )
}