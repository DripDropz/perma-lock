// utils/apiService.js

const baseUrl = '/api/proxy'; // Your Next.js proxy route

const apiService = async (endpoint, options = {}) => {
  // Prefix the request endpoint with the proxy route
  const url = `${baseUrl}?url=${encodeURIComponent(endpoint)}`;

  // Add any default options or headers you want to include in every request
  const defaultOptions = {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  };

  // Make the request through the fetch API, you can replace this with Axios or any other method if you prefer
  const response = await fetch(url, defaultOptions);
  const data = await response.json();
  return data;
};

export default apiService;
