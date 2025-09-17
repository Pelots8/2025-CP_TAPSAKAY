import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { LocalProvider } from './context/LocalContext'
import './styles/global.css'

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <LocalProvider>
        <App />
      </LocalProvider>
    </BrowserRouter>
  </React.StrictMode>
)
