const path = require('path');
const CopyPlugin = require('copy-webpack-plugin');

module.exports = {
  entry: {
    serviceWorker: './src/background/serviceWorker.ts',
    contentScript: './src/content/contentScript.ts',
    panel: './src/panel/panel.ts'
  },
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].js',
    clean: true
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: 'ts-loader',
        exclude: /node_modules/
      },
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader']
      }
    ]
  },
  resolve: {
    extensions: ['.ts', '.js']
  },
  plugins: [
    new CopyPlugin({
      patterns: [
        { from: 'manifest.json', to: 'manifest.json' },
        { from: 'src/panel/panel.html', to: 'panel.html' },
        { from: 'src/panel/panel.css', to: 'panel.css' },
        { from: 'icons', to: 'icons', noErrorOnMissing: true }
      ]
    })
  ],
  optimization: {
    minimize: false // Easier debugging
  }
};
