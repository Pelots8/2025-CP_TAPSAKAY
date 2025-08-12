import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';

export default function MapScreen() {
  return (
    <View style={styles.container}>
      <Image source={require('../assets/logo.png')} style={styles.logo} />
      <View style={styles.titleBox}><Text style={styles.title}>Map</Text></View>
      <View style={styles.mapBox}><Text style={{color:'#fff'}}>Map placeholder — integrate react-native-maps as needed</Text></View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:{flex:1,backgroundColor:'#0A4E99',alignItems:'center',paddingTop:20},
  logo:{position:'absolute',top:10,left:10,width:50,height:50,resizeMode:'contain'},
  titleBox:{width:'95%',height:35,backgroundColor:'#D9D9D9',justifyContent:'center',alignItems:'center',marginTop:60,borderRadius:6},
  title:{fontSize:18,fontWeight:'700',color:'#000'},
  mapBox:{width:'95%',height:'80%',backgroundColor:'#76A3E9',marginTop:15,borderRadius:10,justifyContent:'center',alignItems:'center'}
});
