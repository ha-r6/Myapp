const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

async function callGemini({ apiKey, prompt, useGoogleSearch }) {
  const endpoint =
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  const requestBody = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
    },
  };

  if (useGoogleSearch) {
    requestBody.tools = [{ google_search: {} }];
  }

  return fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify(requestBody),
  });
}

exports.lensLookup = onRequest({ secrets: [geminiApiKey] }, async (req, res) => {
  try {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      res.status(500).json({ note: "GEMINI_API_KEY is not set on the server." });
      return;
    }

    const q = String(req.query.q || "").trim();
    const colorName = String(req.query.colorName || "").trim();
    if (!q) {
      res.json({});
      return;
    }

    const prompt = `
あなたはカラコン（カラーコンタクトレンズ）のスペック確認アシスタントです。
次の入力に対して、信頼できる公開情報を確認したうえで、JSONだけで返してください。

商品名:
${q}

カラー名:
${colorName || "(未指定)"}

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
- 数値スペックを推定しない
- 公式サイト、公式商品ページ、メーカー情報を最優先にする
- 公式情報が見つからない場合だけ、大手販売ページを使ってよい
- 情報が見つからない、複数ソースで値が食い違う、色違いか商品違いの可能性がある場合は、その項目を null にする
- sourceURL には、実際に値を確認したページのURLを1つ入れる
- note には、「公式で確認」「販売ページで確認」「値が競合したので未入力」など判断理由を短く入れる
- 不明なものは null
`.trim();

    let geminiResp = await callGemini({
      apiKey,
      prompt,
      useGoogleSearch: true,
    });

    if (!geminiResp.ok) {
      const firstErrorText = await geminiResp.text();

      geminiResp = await callGemini({
        apiKey,
        prompt,
        useGoogleSearch: false,
      });

      if (!geminiResp.ok) {
        const secondErrorText = await geminiResp.text();
        res.status(502).json({
          note: `Gemini error: ${geminiResp.status}`,
          detail: secondErrorText || firstErrorText,
        });
        return;
      }
    }

    const data = await geminiResp.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.map((part) => part.text).join("") ?? "";

    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = null;
    }

    if (!parsed || typeof parsed !== "object") {
      res.status(502).json({
        note: "Gemini returned non-JSON output.",
        detail: text,
      });
      return;
    }

    res.set("Cache-Control", "no-store");
    res.json(parsed);
  } catch (error) {
    res.status(500).json({ note: String(error?.message || error) });
  }
});
