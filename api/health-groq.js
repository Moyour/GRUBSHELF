/**
 * GET /api/health-groq — safe diagnostics: only whether Groq key is injected (no secret leaked).
 */
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'GET only' });
  }
  const k =
    process.env.GROQ_API_KEY ||
    process.env.GROQ_KEY ||
    process.env.GROQ_SECRET;
  const trimmed = typeof k === 'string' ? k.trim() : '';
  return res.status(200).json({
    groqKeyConfigured: trimmed.length > 0,
    vercelEnv: process.env.VERCEL_ENV || null,
  });
};
