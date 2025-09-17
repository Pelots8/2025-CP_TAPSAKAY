import React, { useContext } from 'react'
import { LocalContext } from '../context/LocalContext'
import { Navigate } from 'react-router-dom'

export default function ProtectedRoute({ children }){
  const { currentUser } = useContext(LocalContext)
  if (!currentUser) return <Navigate to="/login" replace />
  return children
}
