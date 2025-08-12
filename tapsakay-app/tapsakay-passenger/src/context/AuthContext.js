import React, { createContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import api from '../api/api';

export const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const loadUser = async () => {
    try {
      const token = await AsyncStorage.getItem('token');
      if (!token) { setLoading(false); return; }
      const res = await api.get('/user/me');
      setUser(res.data);
    } catch (err) {
      await AsyncStorage.removeItem('token'); setUser(null);
    } finally { setLoading(false); }
  };

  useEffect(() => { loadUser(); }, []);

  const register = async (full_name, email, password) => {
    const res = await api.post('/auth/register', { full_name, email, password });
    await AsyncStorage.setItem('token', res.data.token);
    setUser(res.data.user);
  };

  const login = async (email, password) => {
    const res = await api.post('/auth/login', { email, password });
    await AsyncStorage.setItem('token', res.data.token);
    setUser(res.data.user);
  };

  const logout = async () => {
    await AsyncStorage.removeItem('token');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, setUser, loading, register, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};
