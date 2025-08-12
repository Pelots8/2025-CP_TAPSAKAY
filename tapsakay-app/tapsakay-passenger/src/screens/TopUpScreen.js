import React, { useState, useContext, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Image, FlatList } from 'react-native';
import { AuthContext } from '../context/AuthContext';
import api from '../api/api';

const QUICK = [50,100,200,500];

export default function TopUpScreen() {
  const { setUser } = useContext(AuthContext);
  const [amount, setAmount] = useState('');
  const [selectedQuick, setSelectedQuick] = useState(null);
  const [method, setMethod] = useState('GCash');
  const [history, setHistory] = useState([]);

  useEffect(() => { loadHistory(); }, []);
  const loadHistory = async () => { try { const res = await api.get('/user/transactions'); setHistory(res.data.filter(t=>t.type==='top_up')); } catch (e) {} };

  const selectQuick = (val) => { setSelectedQuick(val); setAmount(String(val)); };
  const confirm = async () => {
    try {
      await api.post('/user/topup', { amount, method });
      const me = await api.get('/user/me'); setUser(me.data); setAmount(''); setSelectedQuick(null); loadHistory();
    } catch (e) { alert('Top up failed'); }
  };

  return (
    <View style={styles.container}>
      <Image source={require('../assets/logo.png')} style={styles.logo} />
      <View style={styles.titleBox}><Text style={styles.title}>Top Up</Text></View>

      <View style={styles.formBox}>
        <Text style={styles.label}>Enter Amount</Text>
        <TextInput style={styles.input} keyboardType="numeric" value={amount} onChangeText={t=>{setAmount(t); setSelectedQuick(null);}} />

        <Text style={[styles.label,{marginTop:12}]}>Quick Top-up</Text>
        <View style={styles.quickRow}>
          {QUICK.map(q => (
            <TouchableOpacity key={q} style={[styles.quickBtn, selectedQuick===q && styles.quickBtnSelected]} onPress={()=>selectQuick(q)}>
              <Text style={[styles.quickTxt, selectedQuick===q && {color:'#fff'}]}>₱{q}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={[styles.label,{marginTop:12}]}>Payment Method</Text>
        <TouchableOpacity style={[styles.methodBtn, method==='GCash' && styles.methodSelected]} onPress={()=>setMethod('GCash')}>
          <Text style={[styles.methodTxt, method==='GCash' && {color:'#fff'}]}>GCash</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.confirmBtn} onPress={confirm}><Text style={styles.confirmTxt}>Confirm</Text></TouchableOpacity>
      </View>

      <View style={styles.historyBox}>
        <Text style={styles.titleSmall}>History</Text>
        <FlatList data={history} keyExtractor={i=>i._id} renderItem={({item})=>(
          <View style={styles.hRow}><Text style={styles.hDate}>{new Date(item.date).toLocaleString()}</Text><Text style={styles.hAmount}>₱{item.amount.toFixed(2)}</Text><Text style={styles.hMethod}>{item.location||'GCash'}</Text></View>
        )} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:{flex:1,backgroundColor:'#0A4E99',alignItems:'center',paddingTop:20},
  logo:{position:'absolute',top:10,left:10,width:50,height:50,resizeMode:'contain'},
  titleBox:{width:'95%',height:35,backgroundColor:'#D9D9D9',justifyContent:'center',alignItems:'center',marginTop:60,borderRadius:6},
  title:{fontSize:18,fontWeight:'700',color:'#000'},
  formBox:{width:'95%',height:358,backgroundColor:'#76A3E9',borderRadius:10,padding:12,marginTop:12},
  label:{color:'#000',fontWeight:'700',marginBottom:6},
  input:{width:'80%',height:28,backgroundColor:'#fff',borderRadius:6,paddingHorizontal:8},
  quickRow:{flexDirection:'row',marginTop:6},
  quickBtn:{backgroundColor:'#D1D7E3',padding:10,borderRadius:8,marginRight:8},
  quickBtnSelected:{backgroundColor:'#30455B'},
  quickTxt:{fontWeight:'700'},
  methodBtn:{backgroundColor:'#D1D7E3',padding:10,width:'40%',borderRadius:8,marginTop:6},
  methodSelected:{backgroundColor:'#30455B'},
  methodTxt:{fontWeight:'700'},
  confirmBtn:{position:'absolute',right:16,bottom:16,backgroundColor:'#30455B',paddingVertical:10,paddingHorizontal:16,borderRadius:8},
  confirmTxt:{color:'#fff',fontWeight:'700'},

  historyBox:{width:'95%',backgroundColor:'#fff',marginTop:12,borderRadius:8,padding:10,flex:1},
  titleSmall:{fontWeight:'700',marginBottom:8},
  hRow:{flexDirection:'row',justifyContent:'space-between',paddingVertical:6,borderBottomWidth:0.5,borderColor:'#ddd'},
  hDate:{flex:2,color:'#333'}, hAmount:{flex:1,textAlign:'center',color:'#333'}, hMethod:{flex:1,textAlign:'right',color:'#333'}
});
