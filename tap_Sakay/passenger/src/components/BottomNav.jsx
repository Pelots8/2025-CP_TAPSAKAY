import React from 'react'
import { Link } from 'react-router-dom'

export default function BottomNav(){
  return (
    <div className="bottom-nav">
      <div className="bottom-nav-inner">
        <Link to="/">Home</Link>
        <Link to="/trips">Trips</Link>
        <Link to="/wallet">Wallet</Link>
        <Link to="/profile">Profile</Link>
      </div>
    </div>
  )
}
