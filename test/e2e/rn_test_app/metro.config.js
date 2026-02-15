const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');
const path = require('path');

const config = {
  projectRoot: __dirname,
  watchFolders: [path.resolve(__dirname)],
  watcher: {
    additionalExts: [],
  },
  resolver: {
    blockList: [
      // Block parent directories from being watched
      /\.\.\/\.\.\/.*/,
      /node_modules\/.*\/node_modules\/.*/,
      /\.git\/.*/,
      /android\/.*/,
      /ios\/build\/.*/,
      /ios\/Pods\/.*/,
    ],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
