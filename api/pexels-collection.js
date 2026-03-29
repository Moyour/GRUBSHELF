/** Photo collection (feed, story, etc.) */
const COLLECTION_ID = 'ioh70af';
/** Reels / shorts — https://www.pexels.com/collections/grubby-video-w3wbuhe/ */
const COLLECTION_VIDEO_ID = 'w3wbuhe';

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const apiKey = process.env.PEXELS_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'PEXELS_API_KEY not configured' });
  }

  const page = parseInt(req.query.page) || 1;
  const perPage = Math.min(parseInt(req.query.per_page) || 40, 80);
  const mediaType = req.query.type === 'videos' ? 'videos' : 'photos';
  const collectionId = mediaType === 'videos' ? COLLECTION_VIDEO_ID : COLLECTION_ID;

  try {
    const url = `https://api.pexels.com/v1/collections/${collectionId}?type=${mediaType}&per_page=${perPage}&page=${page}`;
    const pxRes = await fetch(url, {
      headers: { Authorization: apiKey },
    });

    if (!pxRes.ok) {
      return res.status(pxRes.status).json({ error: 'Pexels API error' });
    }

    const data = await pxRes.json();
    res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=600');
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
