import React, { useState } from 'react'
import Sidebar from '../components/Sidebar.jsx'
import Header from '../components/Header.jsx'
import '../styles/payments.css'

export default function Payments() {
  // demo ride with mother & child
  const ride = {
    id: 'ride1',
    passengers: [
      { id: 'p1', name: 'Regular', fare: 40 },
      { id: 'p2', name: 'Discount', fare: 35 }
    ]
  }
  const [selected, setSelected] = useState({})
  const toggle = id => setSelected(s => ({ ...s, [id]: !s[id] }))
  const total = ride.passengers.reduce((sum,p) => sum + (selected[p.id] ? p.fare : 0), 0)
  const pay = () => {
    if (total === 0) return alert('Select at least one passenger to pay for')
    alert(`Pretend payment processed for ₱${total}. (UI-only demo)`)
  }

  return (
    <div>
      <div className="app-root">
        <Sidebar />
        <div className="main">
          <Header title="Payments" />
          <div className="main-inner" style={{ padding: 24 }}>
            <div className="card" style={{ maxWidth: 760 }}>
              <h3 className="h1" style={{color: 'white'}}>Pay for passengers</h3>
              <div style={{ marginTop: 12, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
                <div style={{ flex: '1 1 280px' }}>
                  {ride.passengers.map(p => (
                    <label key={p.id} style={{ display: 'flex', justifyContent:'space-between', padding: 10, marginBottom: 8, background:'#f9fafb', borderRadius:8 }}>
                      <span style={{ display:'flex', alignItems:'center' }}>
                        <input type="button" alt='Decrease' style={{backgroundColor:'red', height:'5px'}} checked={!!selected[p.id]} onClick={() => toggle(p.id - 1)} /> 
                        <input type="button" alt='increase' style={{backgroundColor:'green', height:'5px'}} checked={!!selected[p.id]} onChange={() => toggle(p.id)} />
                        <strong style={{marginLeft:8}}>{p.name}</strong></span>
                        <span>₱{p.fare}</span>
                    </label>  
                  ))}
                </div>
                <div style={{width:'2px', height:'90', backgroundColor:'black'}}></div>
                <div style={{ width: 320 }}>
                  <div style={{ marginBottom: 8, color:'white'}} className="muted">Card</div>
                  <input placeholder="4123 4123 4123 4123" />
                  <input placeholder="MM/YY" style={{ marginTop:8 }} />
                  <input placeholder="CVV" style={{ marginTop:8 }} />
                  <div style={{ marginTop: 12, fontWeight:700, color:'white'  }}>Total: ₱{total}</div>
                  <button style={{ marginTop: 8, color:'white' }} onClick={pay}>Pay Now</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div></div>
  )
}
