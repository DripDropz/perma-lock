// pages/api/meshProxy.js

export default async function handler(req, res) {
    // Import your mesh library and set it up here
    // Perform the mesh operations using the data from req.body or req.query
  
    // For example:
    const response = await meshOperation(); // Your mesh operation
    res.status(200).json(response);
  }
  