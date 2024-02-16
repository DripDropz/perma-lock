import httpProxyMiddleware from 'next-http-proxy-middleware';

export default (req, res) => httpProxyMiddleware(req, res, {
  // Target host
  target: 'https://your-external-api.com',
  // Change the origin of the host header to the target URL
  changeOrigin: true,
  // Path rewrite
  pathRewrite: [{
    patternStr: '^/api/proxy',
    replaceStr: ''
  }],
});
