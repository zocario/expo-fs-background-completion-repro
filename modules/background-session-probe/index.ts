import { requireNativeModule } from 'expo-modules-core';

type BackgroundSessionProbe = {
  startUpload(url: string): string;
};

export default requireNativeModule<BackgroundSessionProbe>('BackgroundSessionProbe');
