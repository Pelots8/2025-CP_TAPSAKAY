import React from 'react'
import Sidebar from '../components/Sidebar.jsx'
import Header from '../components/Header.jsx'
import '../styles/rides.css'

export default function Rides() {
  // static UI-only list
  const rides = [
    { id: 1, date: '2025-09-01', passenger: 'Juan Dela Cruz', fare: 50, status: 'Completed' },
    { id: 2, date: '2025-09-02', passenger: 'Maria Clara', fare: 30, status: 'Completed' },
  ]
  return (
    <div>
      <div className="app-root" style={{color: 'white'}}>
        <Sidebar />
        <div className="main">
          <Header title="Past Transactions" />
          <div className="main-inner" style={{ padding: 24 }}>
            <div className="card">
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ textAlign: 'left', borderBottom: '1px solid #eee' }}>
                    <th>Date</th><th>Passenger</th><th>Fare</th><th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {rides.map(r => (
                    <tr key={r.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                      <td style={{ padding: '12px 0' }}>{r.date}</td>
                      <td>{r.passenger}</td>
                      <td>₱{r.fare}</td>
                      <td>{r.status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
