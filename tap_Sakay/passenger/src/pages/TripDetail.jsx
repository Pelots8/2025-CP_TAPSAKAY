import React, { useContext } from 'react'
import { useParams } from 'react-router-dom'
import { LocalContext } from '../context/LocalContext'

export default function TripDetail(){
  const { id } = useParams()
  const { trips } = useContext(LocalContext)
  const trip = trips.find(t => t.id === id)

  if (!trip) return <div className="card">Trip not found</div>

  return (
    <div className="card">
      <h2 className="h2">Trip details</h2>
      <div className="mt-2 text-sm">{new Date(trip.date).toLocaleString()}</div>
      <div style={{marginTop:10, fontWeight:700}}>{trip.pickup} → {trip.dropoff}</div>
      <div style={{marginTop:8}}>Driver: {trip.driver?.name || 'Not assigned yet'}</div>
      <div style={{marginTop:8}}>Status: {trip.status}</div>
      <div style={{marginTop:8}}>Fare: ₱{trip.fare}</div>
    </div>
  )
}
