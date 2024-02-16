const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const port = 3001; // You can choose a port that does not conflict with your current setup

// Proxy endpoints setup
app.use('/api', createProxyMiddleware({
  target: 'https://api.koios.rest', // The target API you're having CORS issues with
  changeOrigin: true, // Needed for virtual hosted sites
  pathRewrite: {
    '^/api': '', // Rewrite the path so that '/api' is not passed to the API server
  },
}));

app.listen(port, () => {
  console.log(`Proxy server listening at http://localhost:${port}`);
});
