import Foundation

enum AppConfig {
    /// Firebase Functions の `lensLookup` エンドポイントURLを設定してください。
    ///
    /// 例:
    /// `https://<region>-<project>.cloudfunctions.net/lensLookup`
    ///
    /// 注意:
    /// - Gemini の API キーは **絶対にアプリに入れない** でください（Functions 側に置きます）
    static let aiSpecLookupEndpoint = ""
}

