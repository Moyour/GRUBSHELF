/** Curated search when collection picks have no keyword overlap with the caption. */
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const apiKey = process.env.PEXELS_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'PEXELS_API_KEY not configured' });
  }

  const q = String(req.query.q || 'groceries fresh food').trim().slice(0, 200);
  const perPage = Math.min(parseInt(req.query.per_page, 10) || 20, 40);
  const orientation = req.query.square === '1' ? 'square' : 'landscape';

  try {
    const url =
      'https://api.pexels.com/v1/search?query=' +
      encodeURIComponent(q) +
      '&per_page=' +
      perPage +
      '&orientation=' +
      orientation;
    const pxRes = await fetch(url, { headers: { Authorization: apiKey } });
    if (!pxRes.ok) {
      const t = await pxRes.text();
      return res.status(pxRes.status).json({ error: 'Pexels search failed', detail: t.slice(0, 200) });
    }
    const data = await pxRes.json();
    res.setHeader('Cache-Control', 'public, s-maxage=120, stale-while-revalidate=300');
    res.json({ photos: data.photos || [] });
  } catch (err) {
    res.status(500).json({ error: err.message || 'Search error' });
  }
};
