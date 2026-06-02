// Firebase Functions sample (Node.js) for Gemini API.
// - Exposes GET /lens-lookup?q=...
// - Returns LensSpecLookupResult JSON expected by the iOS app.
//
// IMPORTANT:
// - Do NOT ship the Gemini API key in the iOS app.
// - Store GEMINI_API_KEY as a server-side secret / env var.

// This file is intentionally framework-light so you can paste it into your Functions source.
// Depending on whether your project is Functions v1/v2, the import style may differ.

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

exports.lensLookup = onRequest({ secrets: [geminiApiKey] }, async (req, res) => {
  try {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      res.status(500).json({ note: "GEMINI_API_KEY is not set on the server." });
      return;
    }

    const q = String(req.query.q || "").trim();
    if (!q) {
      res.json({});
      return;
    }

    const endpoint =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

    const prompt = `
あなたはカラコン（カラーコンタクトレンズ）のスペック抽出アシスタントです。
次の入力から、わかる範囲でスペックを推定して、JSONだけで返してください。

入力:
${q}

出力JSONスキーマ（キーはこの通り）:
{
  "brand": string|null,
  "bc": number|null,
  "dia": number|null,
  "graphicDiameter": number|null,
  "waterContentPercent": number|null,
  "replacementDays": number|null,
  "quantity": number|null,
  "sourceURL": string|null,
  "note": string|null
}

ルール:
- JSON以外は出力しない
- 不明なものは null
`.trim();

    const geminiResp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiResp.ok) {
      res.status(502).json({ note: `Gemini error: ${geminiResp.status}` });
      return;
    }

    const data = await geminiResp.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.map((p) => p.text).join("") ?? "";

    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = null;
    }

    if (!parsed || typeof parsed !== "object") {
      res.status(502).json({ note: "Gemini returned non-JSON output." });
      return;
    }

    res.set("Cache-Control", "no-store");
    res.json(parsed);
  } catch (e) {
    res.status(500).json({ note: String(e?.message || e) });
  }
});
