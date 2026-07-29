import Foundation

// MARK: - TavilySearchError

enum TavilySearchError: LocalizedError {
    case invalidAPIKey
    case networkFailure(underlying: Error)
    case noResults
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Tavily API Key 无效或未填写。"
        case .networkFailure(let err):
            return "网页搜索时发生网络错误：\(err.localizedDescription)"
        case .noResults:
            return "网页搜索没有返回结果。"
        case .decodingFailed:
            return "无法解析网页搜索响应。"
        }
    }
}

// MARK: - Tavily Response Models

private struct TavilyResponse: Decodable {
    let results: [TavilyResult]
}

private struct TavilyResult: Decodable {
    let title: String
    let url: String
    let content: String
}

// MARK: - TavilySearchService

/// Sends a query to the Tavily Search API and returns a formatted text block
/// suitable for injection into a chat context window.
final class TavilySearchService {

    static let shared = TavilySearchService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 15
        config.httpAdditionalHeaders = ["User-Agent": "MinimalAIChat/1.0 iOS"]
        self.session = URLSession(configuration: config)
    }

    /// Searches the web via Tavily and returns a formatted result block.
    /// - Parameters:
    ///   - query: The search query string.
    ///   - apiKey: The user's Tavily API key.
    /// - Returns: A formatted multi-line String summarising the top results.
    /// - Throws: `TavilySearchError` on any failure.
    func search(query: String, apiKey: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw TavilySearchError.invalidAPIKey }

        guard let url = URL(string: "https://api.tavily.com/search") else {
            throw TavilySearchError.networkFailure(underlying: URLError(.badURL))
        }

        let body: [String: Any] = [
            "api_key": trimmedKey,
            "query": query,
            "max_results": 5,
            "search_depth": "basic"
        ]

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw TavilySearchError.networkFailure(underlying: error)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw TavilySearchError.networkFailure(underlying: urlError)
        } catch {
            throw TavilySearchError.networkFailure(underlying: error)
        }

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw TavilySearchError.invalidAPIKey
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
                throw TavilySearchError.networkFailure(
                    underlying: NSError(domain: "TavilySearch", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errStr)"])
                )
            }
        }

        let decodedResponse: TavilyResponse
        do {
            decodedResponse = try JSONDecoder().decode(TavilyResponse.self, from: data)
        } catch {
            throw TavilySearchError.decodingFailed
        }

        guard !decodedResponse.results.isEmpty else { throw TavilySearchError.noResults }

        // Format results as a readable text block for context injection
        var lines = ["Search results for '\(query)':\n"]
        for (index, result) in decodedResponse.results.enumerated() {
            lines.append("\(index + 1). \(result.title)")
            lines.append(result.content)
            lines.append("Source: \(result.url)\n")
        }
        return lines.joined(separator: "\n")
    }
}
