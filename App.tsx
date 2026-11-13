import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';

import BackgroundSessionProbe from './modules/background-session-probe';

// The Mac's localhost, reachable from the iOS simulator. Start `node server/slow-server.mjs` first.
const SLOW_URL = 'http://localhost:8099/slow';

export default function App() {
  const [status, setStatus] = useState('idle');

  return (
    <View style={styles.container}>
      <Text style={styles.title}>expo-file-system background completion repro</Text>
      <Button
        title="Start background upload"
        onPress={() => {
          const session = BackgroundSessionProbe.startUpload(SLOW_URL);
          setStatus(`upload started on ${session}; now background or terminate the app`);
        }}
      />
      <Text testID="status">{status}</Text>
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', alignItems: 'center', justifyContent: 'center', gap: 16, padding: 24 },
  title: { fontWeight: '600', textAlign: 'center' },
});
