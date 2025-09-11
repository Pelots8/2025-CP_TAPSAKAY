import React, { createContext, useState } from 'react';

export const LocalContext = createContext(null);

export function LocalProvider({ children }) {
  const [currentUser, setCurrentUser] = useState(null);
  const [trips, setTrips] = useState([]);

  const login = ({ email, password }) => {
    // simple in-memory demo: accept any non-empty email/password
    if (!email || !password) throw new Error('Invalid credentials');
    const user = { id: 'u' + Date.now(), name: 'Demo User', email };
    setCurrentUser(user);
    return user;
  };

  const logout = () => setCurrentUser(null);

  const createTrip = ({ pickup, dropoff }) => {
    const trip = { id: 't' + Date.now(), pickup, dropoff, date: new Date().toISOString(), fare: 100 };
    setTrips(prev => [trip, ...prev]);
    return trip;
  };

  return (
    <LocalContext.Provider value={{ currentUser, login, logout, trips, createTrip }}>
      {children}
    </LocalContext.Provider>
  );
}
