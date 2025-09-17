import React, { useContext, useState } from 'react'
import { LocalContext } from '../context/LocalContext'
import { Link } from 'react-router-dom'
import BottomNav from '../components/BottomNav'

export default function Trips(){
  const { trips } = useContext(LocalContext)
  const [query, setQuery] = useState('')
  const [date, setDate] = useState('')

  const filtered = trips.filter(t => {
    if (query && !(t.pickup.toLowerCase().includes(query.toLowerCase()) || t.dropoff.toLowerCase().includes(query.toLowerCase()))) return false
    if (date) {
      const dTrip = new Date(t.date).toISOString().slice(0,10)
      if (dTrip !== date) return false
    }
    return true
  })

  return (
    <div>
      <div style={{backgroundColor:'#D9D9D9', height:'20%'}}>
        <p style={{color:'black', paddingLeft: '5px', font:'inter'}}>Trips</p>
      </div>
      <div className="card">
        <div className="space-between">
          <div className="h2">Trips</div>
          <div className="text-sm">Total: {trips.length}</div>
        </div>

        <div style={{marginTop:12, display:'flex', gap:8}}>
          <input className="input" placeholder="Search pickup or dropoff" value={query} onChange={e=>setQuery(e.target.value)} />
          <input className="input" type="date" value={date} onChange={e=>setDate(e.target.value)} style={{width:80}} />
        </div>

        <div style={{marginTop:12, display:'grid', gap:10}}>
          {filtered.length === 0 ? <div className="card">No trips found</div> :
            filtered.map(t => (
              <Link key={t.id} to={`/trips/${t.id}`} className="card" style={{textDecoration:'none', color:'inherit'}}>
                <div className="space-between">
                  <div>
                    <div style={{fontWeight:700}}>{t.pickup} → {t.dropoff}</div>
                    <div className="text-sm">{new Date(t.date).toLocaleString()}</div>
                  </div>
                  <div style={{textAlign:'right'}}>
                    <div style={{fontWeight:700}}>₱{t.fare}</div>
                    <div className="text-sm">{t.status}</div>
                  </div>
                </div>
              </Link>
            ))
          }
        </div>
      </div>
      <BottomNav />
    </div>
  )
}
