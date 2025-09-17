import React from 'react'
import './Header.css'

export default function Header({ title, onHamburger }) {
  return (
    <header className="app-header">
      <div className="header-title">{title}</div>
    </header>
  )
}
