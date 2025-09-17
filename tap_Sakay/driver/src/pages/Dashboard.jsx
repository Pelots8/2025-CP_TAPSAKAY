import React from 'react'
import Sidebar from '../components/Sidebar.jsx'
import Header from '../components/Header.jsx'
import '../styles/dashboard.css'

export default function Dashboard() {
  return (
    <div>
      <div className="app-root" style={{color: 'white'}}>
        <Sidebar />
        <div className="main">
          <Header title="Dashboard" />
          <div className="main-inner" style={{ padding: 24 }}>
            <div className="grid-3" style={{ gap: 16 }}>
              <div className="card">
                <div className="h1">Total Passenger</div>
                <div style={{ marginTop: 8, fontSize: 20, fontWeight: 700 }}>24</div>
              </div>
              <div className="card">
                <div className="h1">Earnings</div>
                <div style={{ marginTop: 8, fontSize: 20, fontWeight: 700 }}>₱1,250</div>
              </div>
              <div className="card" style={{color: 'white'}}>
                <div className="h1">Active</div>
                <div style={{ marginTop: 8, fontSize: 20, fontWeight: 700 }}>3</div>
              </div>
            </div>

            <section style={{ marginTop: 20 }}>
              <div className="card">
                <h3 className="h1">Going To</h3>
                <div style={{ marginTop: 12 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <div>Ayala → Recodo</div>
                  </div>
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>
    </div>
  )
}
