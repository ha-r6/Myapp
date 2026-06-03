const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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

async function callGeminiWithRetry({ apiKey, prompt, useGoogleSearch, maxAttempts = 3 }) {
  let lastResponse = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const response = await callGemini({ apiKey, prompt, useGoogleSearch });
    if (response.ok) {
      return response;
    }

    lastResponse = response;
    if (response.status !== 503 || attempt === maxAttempts) {
      return response;
    }

    await sleep(800 * attempt);
  }

  return lastResponse;
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
- URLの新規生成・推測・補完を禁止する
- 実際にページ内に存在し、「カラコン」または「レンズ」と書かれているリンク先のみ参照する
- 公式ブランドサイト、公式商品ページ、公式通販サイトを最優先にする
- 公式情報が見つからない場合だけ、大手カラコン通販の公式サイトを使ってよい
- 参照先が公式か曖昧な場合、そのページは使わない
- 着色直径は、「着色直径」「GDIA」「G.DIA」のいずれかの表記を確認できた場合のみ graphicDiameter に入れる
- 情報が見つからない、複数ソースで値が食い違う、色違いか商品違いの可能性がある、少しでも曖昧な場合は、その項目を null にする
- 推測で補完しない
- sourceURL には、実際に値を確認したページのURLを1つだけ入れる
- note には、「公式で確認」「公式通販で確認」「着色直径はGDIA表記を確認」「値が曖昧なので未入力」など判断理由を短く入れる
- 注意書きとして「AIの情報は全て正しいわけではありません。公式サイトの情報もあわせてご確認ください。」という趣旨が伝わる短い文を note に含めてよい
- 不明なものは null
`.trim();

    let geminiResp = await callGeminiWithRetry({
      apiKey,
      prompt,
      useGoogleSearch: true,
    });

    if (!geminiResp.ok) {
      const firstErrorText = await geminiResp.text();

      geminiResp = await callGeminiWithRetry({
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
