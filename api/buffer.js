module.exports = async function handler(req, res) {
  // CORS — allow any origin so the browser can call this
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Buffer token' });
  }

  const token = authHeader.replace('Bearer ', '').trim();
  const body = req.body;

  try {
    const bufferRes = await fetch('https://api.buffer.com/graphql', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(body),
    });

    const data = await bufferRes.json();
    return res.status(bufferRes.status).json(data);
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Proxy error' });
  }
}
