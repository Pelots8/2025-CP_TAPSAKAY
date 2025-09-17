import React, { useState } from 'react'
import { clearToken } from '../utils/auth.js'
import { useNavigate } from "react-router-dom";
import { NavLink } from 'react-router-dom'
import './Sidebar.css'

export default function Sidebar() {

  const navigate = useNavigate();

  const handleLogout = () => {
    clearToken();         
    navigate("/login"); 
  };


  return (
    <aside className={`sidebar`}>
      <div className="sidebar-top">
        <img alt="logo" className="logo" src='./assets/logo.png' />
      </div>

      <nav className="nav">
        <NavLink to="/dashboard">Dashboard</NavLink>
        <NavLink to="/rides">Past Transaction</NavLink>
        <NavLink to="/payments">Payments</NavLink>
        <NavLink to="/profile">Profile</NavLink>
      </nav>

        
      <div className="sidebar-footer">
        <button className="logout-btn" onClick={handleLogout}>
          Logout
        </button>
      </div>
    </aside>
  )
}
