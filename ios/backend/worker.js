// Piano Journal — service de recherche IA (Cloudflare Worker).
// Reçoit { query, mode: "search" | "expand", lang } et renvoie { items: [...] }.
// Variables à définir dans Cloudflare : ANTHROPIC_API_KEY (secret), APP_KEY (secret, identique à Config.aiAppKey),
// MODEL (facultatif, modèle Claude à utiliser).

const SYSTEM = `Tu es le bibliothécaire d'un catalogue mondial de partitions pour piano : œuvres classiques, recueils, méthodes, songbooks, musiques de film, chansons.
Réponds UNIQUEMENT par un objet JSON valide, sans texte autour, de la forme :
{"items":[{"title":"","composer":"","kind":"piece|collection|method","period":"baroque|classique|romantique|moderne|contemporain|populaire","level":1,"genre":"","pieces":[""]}]}
Règles :
- "kind" vaut "collection" pour un recueil ou un album, "method" pour une méthode d'apprentissage, sinon "piece".
- "level" va de 1 (débutant) à 5 (virtuose) ; omets-le si tu ne sais pas.
- "pieces" liste, dans l'ordre de l'édition, les pièces d'un recueil ou d'une méthode. Titres exacts, avec numéro, tonalité et numéro d'opus quand ils existent.
- N'invente jamais. Si tu ne connais pas avec certitude le contenu d'un recueil, renvoie "pieces": [].
- Ne propose que des partitions qui existent réellement. Si rien ne correspond, renvoie {"items":[]}.
- Écris les titres dans la langue demandée quand un titre usuel existe dans cette langue, sinon garde le titre original.`;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json; charset=utf-8" } });

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") return new Response("Piano Journal AI", { status: 200 });
    if (env.APP_KEY && request.headers.get("X-App-Key") !== env.APP_KEY) return json({ error: "unauthorized" }, 401);

    let body;
    try { body = await request.json(); } catch { return json({ error: "bad request" }, 400); }
    const query = String(body.query || "").trim().slice(0, 200);
    const mode = body.mode === "expand" ? "expand" : "search";
    const lang = String(body.lang || "fr").slice(0, 5);
    if (query.length < 2) return json({ items: [] });

    // Cache : une même recherche n'est payée qu'une fois.
    const cacheKey = new Request(`https://cache.pianojournal.app/${mode}/${lang}/${encodeURIComponent(query.toLowerCase())}`);
    try {
      const hit = await caches.default.match(cacheKey);
      if (hit) return hit;
    } catch {}

    const user = mode === "expand"
      ? `Langue : ${lang}. Donne le contenu complet et ordonné de ce recueil (un seul élément dans "items") : ${query}`
      : `Langue : ${lang}. Trouve les partitions pour piano correspondant à cette recherche (8 résultats au plus, les plus probables d'abord ; détaille "pieces" pour les recueils) : ${query}`;

    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: env.MODEL || "claude-sonnet-5-5",
        max_tokens: 4000,
        system: SYSTEM,
        messages: [{ role: "user", content: user }],
      }),
    });
    if (!upstream.ok) return json({ error: "upstream", status: upstream.status }, 502);

    const data = await upstream.json();
    const text = (data.content || []).filter((b) => b.type === "text").map((b) => b.text).join("");
    let items = [];
    try {
      const parsed = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
      if (Array.isArray(parsed.items)) {
        items = parsed.items
          .filter((i) => i && typeof i.title === "string" && i.title.trim())
          .slice(0, 10)
          .map((i) => ({
            title: i.title.trim(),
            composer: typeof i.composer === "string" ? i.composer : "",
            kind: ["piece", "collection", "method"].includes(i.kind) ? i.kind : undefined,
            period: typeof i.period === "string" ? i.period : undefined,
            level: Number.isInteger(i.level) ? i.level : undefined,
            genre: typeof i.genre === "string" ? i.genre : undefined,
            pieces: Array.isArray(i.pieces) ? i.pieces.filter((p) => typeof p === "string" && p.trim()).slice(0, 300) : [],
          }));
      }
    } catch {
      return json({ error: "parse" }, 502);
    }

    const response = json({ items });
    response.headers.set("Cache-Control", "public, max-age=2592000");
    try { ctx.waitUntil(caches.default.put(cacheKey, response.clone())); } catch {}
    return response;
  },
};
