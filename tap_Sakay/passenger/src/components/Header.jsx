import React from 'react'
import { Link } from 'react-router-dom'

export default function Header(){
  return (
    <header className="header">
      <div style={{width:'100%', maxWidth:420, display:'flex', justifyContent:'left'}}>
        <Link to="/">
          <img src="/logo.png" alt="TapSakay" />
        </Link>
      </div>
    </header>
  )
}
