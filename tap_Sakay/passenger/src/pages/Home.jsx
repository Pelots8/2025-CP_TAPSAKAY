import React, { useContext, useState } from 'react'
import MapPlaceholder from '../components/MapPlaceholder'
import { LocalContext } from '../context/LocalContext'
import { useNavigate } from 'react-router-dom'
import BottomNav from '../components/BottomNav'

export default function Home(){
  const { trips } = useContext(LocalContext)
  const [nearby] = useState([
    { model: 'Toyota Innova', eta: '2 min', plate: 'ABC-123' },
    { model: 'Vios', eta: '4 min', plate: 'XYZ-987' },
  ])
  const [fareEstimate, setFareEstimate] = useState(null)
  const nav = useNavigate()

  const quickBook = () => nav('/booking')

  const calcFare = () => {
    // mock estimate
    const fare = { fare: '₱120 - ₱160', distance: '4.2 km' }
    setFareEstimate(fare)
  }

  return (
    <div>
      <div style={{backgroundColor:'#D9D9D9', height:'20%'}}>
        <p style={{color:'black', paddingLeft: '5px', font:'inter'}}>Home</p>
      </div>
      <MapPlaceholder />
      <div style={{marginTop:12}} className="card">
        <div className="space-between">
          <div>
            <div className="h2">Nearby vehicles</div>
            <div className="text-sm mt-2">{nearby.length} available</div>
          </div>
          <div style={{textAlign:'right'}} className="text-sm">Trips: {trips.length}</div>
        </div>

        <div style={{marginTop:12, display:'flex', gap:10}}>
          <button className="btn btn-primary" style={{flex:1}} onClick={quickBook}>Quick Book</button>
          <button className="btn" style={{flex:0}} onClick={calcFare}>Fare est.</button>
        </div>

        {fareEstimate && (
          <div className="mt-4">
            <div className="h2">Estimated fare</div>
            <div className="text-sm mt-1">{fareEstimate.fare} • {fareEstimate.distance}</div>
          </div>
        )}
      </div>
      <BottomNav />
    </div>
  )
}
