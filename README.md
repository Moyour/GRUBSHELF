# GrubShelf — Vercel Deployment

## Files in this folder
- `index.html` — the GrubShelf app
- `api/buffer.js` — serverless proxy (fixes Buffer CORS)
- `vercel.json` — Vercel config

## Deploy in 3 steps

### Option A — Vercel CLI (fastest)
```bash
npm i -g vercel
cd grubshelf-vercel
vercel --prod
```
Done. Vercel gives you a live URL like `grubshelf.vercel.app`.

### Option B — Drag and drop (no terminal)
1. Go to vercel.com → New Project → drag this whole folder in
2. Hit Deploy
3. Done

## After deploying
1. Open your live Vercel URL
2. Add your Groq key (free at console.groq.com)
3. Add your Buffer token (buffer.com → Settings → API → Create API Key)
4. Generate a post → hit "Schedule on Instagram" → done, it goes straight to Buffer with the image
