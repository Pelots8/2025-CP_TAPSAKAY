import React, { useState, useContext } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Image } from 'react-native';
import { AuthContext } from '../context/AuthContext';

export default function LoginScreen() {
  const { login } = useContext(AuthContext);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  return (
    <View style={styles.container}>
      <View style={styles.loginBox}>
        <Image source={require('../assets/logo.png')} style={styles.logo} />
        <Text style={styles.title}>Login</Text>
        <TextInput style={styles.input} placeholder="Email" placeholderTextColor="#ccc" value={email} onChangeText={setEmail} />
        <TextInput style={styles.input} placeholder="Password" placeholderTextColor="#ccc" secureTextEntry value={password} onChangeText={setPassword} />
        <TouchableOpacity style={styles.loginButton} onPress={() => login(email, password)}>
          <Text style={styles.loginButtonText}>Login</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:{flex:1,backgroundColor:'#0A4E99',justifyContent:'center',alignItems:'center'},
  loginBox:{backgroundColor:'#183351',padding:20,borderRadius:12,width:'85%',alignItems:'center'},
  logo:{width:80,height:80,resizeMode:'contain',marginBottom:10},
  title:{fontSize:24,fontWeight:'700',color:'#fff',marginBottom:10},
  input:{width:'100%',height:45,backgroundColor:'#fff',borderRadius:8,paddingHorizontal:10,marginBottom:10},
  loginButton:{backgroundColor:'#76A3E9',paddingVertical:12,paddingHorizontal:20,borderRadius:8,width:'100%',alignItems:'center'},
  loginButtonText:{color:'#fff',fontSize:16,fontWeight:'700'}
});
