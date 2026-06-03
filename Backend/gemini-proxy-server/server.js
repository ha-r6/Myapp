const http = require("node:http");

const port = Number(process.env.PORT || 8787);
const geminiApiKey = process.env.GEMINI_API_KEY || "";

function sendJson(res, statusCode, body) {
  const json = JSON.stringify(body);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(json);
}

function buildPrompt({ query, colorName }) {
  return `
あなたはカラコン（カラーコンタクトレンズ）のスペック確認アシスタントです。
商品名から、信頼できる公開情報を確認したうえで、できるだけ正確にスペックを調べてください。
必要なら Web 検索を使って確認してください。

入力:
- query: ${query}
- colorName: ${colorName || "null"}

出力JSONスキーマ（キー名はこの通り）:
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
- 数値は文字列ではなく number で返す
- 数値スペックを推定しない
- URLの新規生成・推測・補完を禁止する
- 実際にページ内に存在し、「カラコン」または「レンズ」と書かれているリンク先のみ参照する
- 公式ブランドサイト、公式商品ページ、公式通販サイトを最優先にする
- 公式情報が見つからない場合だけ、大手カラコン通販の公式サイトを使ってよい
- 参照先が公式か曖昧な場合、そのページは使わない
- 着色直径は、「着色直径」「GDIA」「G.DIA」のいずれかの表記を確認できた場合のみ graphicDiameter に入れる
- 情報が見つからない、複数ソースで値が食い違う、色違いか商品違いの可能性がある、少しでも曖昧な場合は、その項目を null にする
- 推測で補完しない
- sourceURL には実際に値を確認したページのURLを1つだけ入れる
- note には、「公式で確認」「公式通販で確認」「着色直径はGDIA表記を確認」「値が曖昧なので未入力」など判断理由を短く入れる
- 注意書きとして「AIの情報は全て正しいわけではありません。公式サイトの情報もあわせてご確認ください。」という趣旨が伝わる短い文を note に含めてよい
  `.trim();
}

async function lookupLensSpec({ query, colorName }) {
  const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": geminiApiKey,
    },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: buildPrompt({ query, colorName }) }] }],
      tools: [{ google_search: {} }],
      generationConfig: {
        temperature: 0.2,
        responseMimeType: "application/json",
      },
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    const error = new Error(`Gemini error: ${response.status}`);
    error.statusCode = 502;
    error.detail = text;
    throw error;
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.map((part) => part.text || "").join("") || "";

  try {
    return JSON.parse(text);
  } catch {
    const error = new Error("Gemini returned non-JSON output.");
    error.statusCode = 502;
    throw error;
  }
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      });
      res.end();
      return;
    }

    const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

    if (url.pathname === "/health") {
      sendJson(res, 200, { ok: true });
      return;
    }

    if (url.pathname !== "/lens-lookup" || req.method !== "GET") {
      sendJson(res, 404, { note: "Not found" });
      return;
    }

    if (!geminiApiKey) {
      sendJson(res, 500, { note: "GEMINI_API_KEY is not set on the server." });
      return;
    }

    const query = String(url.searchParams.get("q") || "").trim();
    const colorName = String(url.searchParams.get("colorName") || "").trim();

    if (!query) {
      sendJson(res, 400, { note: "Missing q query parameter." });
      return;
    }

    const result = await lookupLensSpec({ query, colorName });
    sendJson(res, 200, result);
  } catch (error) {
    sendJson(res, error.statusCode || 500, {
      note: String(error.message || error),
      detail: error.detail || null,
    });
  }
});

server.listen(port, () => {
  console.log(`Gemini proxy listening on http://localhost:${port}`);
});
