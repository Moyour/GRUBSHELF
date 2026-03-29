module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const raw =
    process.env.GROQ_API_KEY ||
    process.env.GROQ_KEY ||
    process.env.GROQ_SECRET;
  const apiKey = typeof raw === 'string' ? raw.trim() : '';
  if (!apiKey) {
    return res.status(500).json({
      error:
        'GROQ_API_KEY not configured. In Vercel: Project → Settings → Environment Variables → add GROQ_API_KEY (your Groq API key), enable Production (and Preview if needed), save, then Redeploy Production.',
      hint:
        'Open GET /api/health-groq on this deployment — groqKeyConfigured should be true after a successful redeploy.',
    });
  }

  try {
    const { messages, model } = req.body || {};
    if (!messages || !Array.isArray(messages)) {
      return res.status(400).json({ error: 'messages array required' });
    }

    const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: model || 'llama-3.3-70b-versatile',
        messages,
        temperature: 0.8,
        max_tokens: 2048,
        response_format: { type: 'json_object' },
      }),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      return res.status(groqRes.status).json({ error: 'Groq API error: ' + errText });
    }

    const data = await groqRes.json();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
