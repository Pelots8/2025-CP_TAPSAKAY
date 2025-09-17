// src/pages/Wallet.jsx
import React, { useContext } from 'react'
import { LocalContext } from '../context/LocalContext'
import BottomNav from '../components/BottomNav'

export default function Wallet(){
  // Defensive: if context is undefined, fallback to defaults
  const ctx = useContext(LocalContext) || {}
  const walletBalance = ctx.walletBalance ?? 0
  const walletHistory = Array.isArray(ctx.walletHistory) ? ctx.walletHistory : []
  const topUp = typeof ctx.topUp === 'function' ? ctx.topUp : () => {}

  const handleTopUp = () => {
    topUp(200)
    alert('₱200 added (mock)')
  }

  const max = walletHistory.length ? Math.max(...walletHistory.map(h => Math.abs(h.amount || 0)), 50) : 50

  return (
    <div>
      <div style={{backgroundColor:'#D9D9D9', height:'20%'}}>
        <p style={{color:'black', paddingLeft: '5px', font:'inter'}}>Wallet</p>
      </div>
      <div className="card">
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
          <div>
            <div style={{fontSize:13, color:'#6B7280'}}>Wallet balance</div>
            <div style={{fontSize:24, fontWeight:700}}>₱{Number(walletBalance).toLocaleString()}</div>
          </div>
          <button className="btn btn-primary" onClick={handleTopUp}>Top up</button>
        </div>
      </div>

      <div className="card mt-4">
        <h3 style={{margin:0, fontSize:16, fontWeight:600}}>Recent activity</h3>

        <div style={{marginTop:12, display:'grid', gap:8}}>
          {walletHistory.length === 0 ? (
            <div className="card" style={{padding:12}}>No activity yet</div>
          ) : (
            walletHistory.map(h => (
              <div key={h.id} style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
                <div>
                  <div style={{fontWeight:600}}>{h.amount > 0 ? 'Top-up' : 'Payment'}</div>
                  <div style={{fontSize:13, color:'#6B7280'}}>{new Date(h.date).toLocaleDateString()}</div>
                </div>
                <div style={{fontWeight:700, color: h.amount > 0 ? '#065f46' : '#991b1b'}}>₱{h.amount}</div>
              </div>
            ))
          )}
        </div>

        <div style={{marginTop:14}}>
          <div style={{fontSize:13, color:'#6B7280'}}>Usage visual (mock)</div>
          <div style={{display:'flex', gap:6, marginTop:8, alignItems:'end'}}>
            {walletHistory.map(h => {
              const amount = Math.abs(h.amount || 0)
              const height = Math.max(12, (amount / max) * 80)
              return (
                <div
                  key={h.id}
                  title={`₱${h.amount}`}
                  style={{
                    width: 18,
                    height,
                    background: h.amount > 0 ? '#10B981' : '#F97316',
                    borderRadius: 6
                  }}
                />
              )
            })}
          </div>
        </div>
      </div>
      <BottomNav />
    </div>
  )
}
