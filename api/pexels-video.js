/**
 * GET /api/pexels-video?id={numeric_id}
 * Proxies https://api.pexels.com/v1/videos/{id} (full video incl. video_files).
 */
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const apiKey = process.env.PEXELS_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'PEXELS_API_KEY not configured' });
  }

  const rawId = req.query.id;
  const id = parseInt(String(rawId), 10);
  if (!id || id < 1) {
    return res.status(400).json({ error: 'Invalid video id' });
  }

  try {
    const url = `https://api.pexels.com/v1/videos/${id}`;
    const pxRes = await fetch(url, {
      headers: { Authorization: apiKey },
    });

    if (!pxRes.ok) {
      return res.status(pxRes.status).json({ error: 'Pexels API error' });
    }

    const data = await pxRes.json();
    res.setHeader('Cache-Control', 'public, s-maxage=600, stale-while-revalidate=1200');
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
