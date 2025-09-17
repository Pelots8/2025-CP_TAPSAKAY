import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { saveToken, TEMP_DRIVER_EMAIL, TEMP_DRIVER_PASSWORD } from '../utils/auth.js'
import '../styles/login.css'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const navigate = useNavigate()

  const handleSubmit = (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)

    setTimeout(() => {
      if ((email === TEMP_DRIVER_EMAIL && password === TEMP_DRIVER_PASSWORD) ||
          (email === 'driver@example.com' && password === 'password123')) {
        saveToken('demo-token')
        navigate('/dashboard')
      } else {
        setError('Invalid credentials. Use driver@example.com / password123')
      }
      setLoading(false)
    }, 700)
  }

  return (
    <div className="login-root">
      <div className="login-card">
        <div className="login-logo">
          <img src="/assets/logo.png" alt="TapSakay Logo" />
        </div>
        <h2 className="login-title">Driver Login</h2>

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              placeholder="Enter your email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              placeholder="Enter your password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              required
            />
          </div>

          <button type="submit" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>

        {error && <div className="error">{error}</div>}

        <div className="login-note">
          <p>Default login: <strong>driver@example.com</strong> / <strong>password123</strong></p>
        </div>
      </div>
    </div>
  )
}
