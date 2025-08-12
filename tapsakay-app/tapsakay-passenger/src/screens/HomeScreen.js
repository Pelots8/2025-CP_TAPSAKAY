import React, { useContext, useEffect, useState } from 'react';
import { View, Text, StyleSheet, Image, TouchableOpacity, ScrollView } from 'react-native';
import { AuthContext } from '../context/AuthContext';
import api from '../api/api';
require('../assets/logo.png')



export default function HomeScreen({ navigation }) {
  const { user, logout } = useContext(AuthContext);
  const [transactions, setTransactions] = useState([]);

  useEffect(() => {
    const load = async () => {
      try { const res = await api.get('/user/transactions'); setTransactions(res.data); } catch (e) {}
    }; load();
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Image source={require('../assets/logo.png')} style={styles.logo} />
        <Text style={styles.headerTitle}>TapSakay</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.welcomeBox}><Text style={styles.welcomeText}>Welcome, {user?.full_name}</Text></View>

        <View style={styles.balanceBox}><Text style={styles.boxTitle}>Balance</Text><Text style={styles.balanceAmount}>₱{Number(user?.balance||0).toFixed(2)}</Text></View>

        <View style={styles.historyBox}>
          <Text style={styles.boxTitle}>Transaction History</Text>
          {transactions.length === 0 ? <Text style={styles.historyItem}>No transactions yet</Text> :
            transactions.map(tx => (<Text key={tx._id} style={styles.historyItem}>{new Date(tx.date).toLocaleString()} | {tx.type} | {tx.location||'—'} | ₱{tx.amount.toFixed(2)}</Text>))}
        </View>

        <View style={styles.goToBox}>
          <Text style={styles.boxTitle}>Go To</Text>
          <View style={styles.buttonRow}>
            <TouchableOpacity style={styles.goToButton} onPress={() => navigation.navigate('NFC')}><Text style={styles.buttonText}>NFC</Text></TouchableOpacity>
            <TouchableOpacity style={styles.goToButton} onPress={() => navigation.navigate('TopUp')}><Text style={styles.buttonText}>Top-up</Text></TouchableOpacity>
            <TouchableOpacity style={styles.goToButton} onPress={() => navigation.navigate('Profile')}><Text style={styles.buttonText}>Account</Text></TouchableOpacity>
            <TouchableOpacity style={styles.goToButton} onPress={() => navigation.navigate('Map')}><Text style={styles.buttonText}>Map</Text></TouchableOpacity>
          </View>
          <View style={{marginTop:14}}><TouchableOpacity style={styles.logoutBtn} onPress={logout}><Text style={styles.logoutText}>Logout</Text></TouchableOpacity></View>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container:{flex:1,backgroundColor:'#0A4E99'},
  header:{position:'absolute',top:10,left:10,flexDirection:'row',alignItems:'center',zIndex:10},
  logo:{width:44,height:44,resizeMode:'contain',marginRight:8},
  headerTitle:{color:'#fff',fontSize:20,fontWeight:'700'},
  scrollContent:{alignItems:'center',paddingTop:70,paddingBottom:30},

  welcomeBox:{backgroundColor:'#6591D7',height:35,width:356,justifyContent:'center',paddingHorizontal:12,borderRadius:12,marginBottom:12},
  welcomeText:{color:'#fff',fontSize:16,fontWeight:'700'},

  balanceBox:{backgroundColor:'#6591D7',height:198,width:356,borderRadius:12,justifyContent:'center',alignItems:'center',marginBottom:12},
  boxTitle:{color:'#fff',fontSize:18,fontWeight:'700',marginBottom:8},
  balanceAmount:{color:'#fff',fontSize:30,fontWeight:'800'},

  historyBox:{backgroundColor:'#6591D7',height:198,width:356,borderRadius:12,padding:12,marginBottom:12},
  historyItem:{color:'#fff',fontSize:13,marginBottom:6},

  goToBox:{backgroundColor:'#6591D7',height:198,width:356,borderRadius:12,padding:12,alignItems:'center'},
  buttonRow:{flexDirection:'row',justifyContent:'space-between',width:'100%',marginTop:8,paddingHorizontal:6},
  goToButton:{backgroundColor:'#0A4E99',paddingVertical:12,paddingHorizontal:8,borderRadius:8,width:74,alignItems:'center'},
  buttonText:{color:'#fff',fontWeight:'700'},
  logoutBtn:{backgroundColor:'#FF6B6B',paddingVertical:10,paddingHorizontal:14,borderRadius:8,alignItems:'center'},
  logoutText:{color:'#fff',fontWeight:'700'}
});
