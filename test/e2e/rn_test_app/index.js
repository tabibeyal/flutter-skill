/**
 * @format
 */

import {AppRegistry} from 'react-native';
import App from './App';
import {name as appName} from './app.json';

// Initialize flutter-skill bridge (dev only)
if (__DEV__) {
  const { initFlutterSkill } = require('./FlutterSkill');
  initFlutterSkill({ appName: 'RNTestApp' });
}

AppRegistry.registerComponent(appName, () => App);
