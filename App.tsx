import { Directory, File, Paths } from 'expo-file-system';
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
      <Button
        title="Start expo-file-system background download"
        onPress={() => {
          // expo-file-system's own background session, to check that iOS gets its handler too.
          const destination = new Directory(Paths.cache, `fs-download-${Date.now()}`);
          destination.create();
          const task = File.createDownloadTask('http://localhost:8099/fs-download', destination, {
            sessionType: 'background',
          });
          task
            .downloadAsync()
            .then((file) => setStatus(`expo-file-system download finished: ${file?.uri}`))
            .catch((error) => setStatus(`expo-file-system download failed: ${error}`));
          setStatus('expo-file-system background download started; now background the app');
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
