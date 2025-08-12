import React, { useContext, useEffect, useState } from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { AuthContext } from '../context/AuthContext';
import api from '../api/api';

export default function ProfileScreen() {
  const { user } = useContext(AuthContext);
  const [me, setMe] = useState(user);

  useEffect(() => { const load = async () => { try { const res = await api.get('/user/me'); setMe(res.data); } catch (e) {} }; load(); }, []);

  return (
    <View style={styles.container}>
      <Image source={require('../assets/logo.png')} style={styles.logo} />
      <View style={styles.titleBox}><Text style={styles.title}>Profile</Text></View>

      <View style={styles.infoBox}>
        <Image source={require('../assets/profile.png')} style={styles.profileImage} />
        <View style={styles.infoArea}>
          <Text style={styles.infoText}>Card ID: {me?.nfc_card_id || '—'}</Text>
          <Text style={styles.infoText}>Name: {me?.full_name}</Text>
          <Text style={styles.infoText}>Email: {me?.email}</Text>
          <Text style={styles.infoText}>Phone: {me?.phone || '—'}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:{flex:1,backgroundColor:'#0A4E99',alignItems:'center',paddingTop:20},
  logo:{position:'absolute',top:10,left:10,width:50,height:50,resizeMode:'contain'},
  titleBox:{width:'95%',height:35,backgroundColor:'#D9D9D9',justifyContent:'center',alignItems:'center',marginTop:60,borderRadius:6},
  title:{fontSize:18,fontWeight:'700',color:'#000'},
  infoBox:{width:'95%',height:'80%',backgroundColor:'#76A3E9',marginTop:15,alignItems:'center',paddingTop:20,borderRadius:10},
  profileImage:{width:120,height:120,borderRadius:60,marginBottom:12},
  infoArea:{width:'92%',marginTop:6},
  infoText:{fontSize:16,color:'#000',marginBottom:8}
});
