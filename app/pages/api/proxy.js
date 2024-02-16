// pages/api/proxy.js

export default async function handler(req, res) {
  const { url } = req.query; // Get the original API endpoint from the query parameter

  if (!url) {
    return res.status(400).json({ error: 'No URL provided' });
  }

  // Forward the request to the external API
  const response = await fetch(url, {
    method: req.method, // Forward the original request method
    headers: {
      'Content-Type': 'application/json',
      // Add any other headers required by the external API
    },
    body: req.method !== 'GET' ? JSON.stringify(req.body) : null,
  });

  const data = await response.json();

  // Return the external API's response to the original caller
  res.status(response.status).json(data);
}
