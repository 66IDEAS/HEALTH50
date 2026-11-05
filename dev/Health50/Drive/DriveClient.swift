import Foundation

enum DriveError: Error, Equatable {
    /// Google no longer accepts the sign-in; the user must reconnect.
    case needsReconnect
    /// No usable connection, or the connection dropped.
    case network
    case http(Int)
}

/// The few Google Drive calls Health50 needs. Talks to Google directly; there is no server in between.
struct DriveClient: Sendable {
    let auth: GoogleAuth
    let session: URLSession

    init(auth: GoogleAuth = .shared, allowsCellular: Bool) {
        self.auth = auth
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = allowsCellular
        configuration.allowsExpensiveNetworkAccess = allowsCellular
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 30
        session = URLSession(configuration: configuration)
    }

    private static let api = "https://www.googleapis.com/drive/v3"
    private static let uploadAPI = "https://www.googleapis.com/upload/drive/v3"
    private static let folderType = "application/vnd.google-apps.folder"

    // MARK: Calls

    /// Email address of the connected account, shown in the Google Drive sheet.
    func email() async throws -> String {
        struct About: Decodable { struct User: Decodable { let emailAddress: String }; let user: User }
        let (data, _) = try await send(request("\(Self.api)/about?fields=user(emailAddress)"))
        return try JSONDecoder().decode(About.self, from: data).user.emailAddress
    }

    /// The export folder in My Drive. Reuses a folder of that name the app created earlier, else creates it.
    func ensureFolder(named name: String) async throws -> String {
        let query = "name = '\(Self.escaped(name))' and mimeType = '\(Self.folderType)' and 'root' in parents and trashed = false"
        if let existing = try await firstID(matching: query) { return existing }
        var create = request("\(Self.api)/files?fields=id", method: "POST")
        create.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        create.httpBody = try JSONSerialization.data(withJSONObject: ["name": name, "mimeType": Self.folderType, "parents": ["root"]])
        let (data, _) = try await send(create)
        return try JSONDecoder().decode(FileID.self, from: data).id
    }

    func findFile(named name: String, in folderID: String) async throws -> String? {
        try await firstID(matching: "name = '\(Self.escaped(name))' and '\(folderID)' in parents and trashed = false")
    }

    /// Uploads a file. With `existingID` the file in Drive is replaced in place; Drive keeps the old
    /// content until the new upload has completed. Returns the file's ID.
    func upload(file: URL, name: String, folderID: String, existingID: String?) async throws -> String {
        do {
            return try await resumableUpload(file: file, name: name, folderID: folderID, existingID: existingID)
        } catch DriveError.http(404) where existingID != nil {
            // The file was removed in Drive: create it again.
            return try await resumableUpload(file: file, name: name, folderID: folderID, existingID: nil)
        }
    }

    // MARK: Internals

    private struct FileID: Decodable { let id: String }

    private func resumableUpload(file: URL, name: String, folderID: String, existingID: String?) async throws -> String {
        var start: URLRequest
        if let existingID {
            start = request("\(Self.uploadAPI)/files/\(existingID)?uploadType=resumable&fields=id", method: "PATCH")
            start.httpBody = Data("{}".utf8)
        } else {
            start = request("\(Self.uploadAPI)/files?uploadType=resumable&fields=id", method: "POST")
            start.httpBody = try JSONSerialization.data(withJSONObject: ["name": name, "parents": [folderID], "mimeType": "application/json"])
        }
        start.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        start.setValue("application/json", forHTTPHeaderField: "X-Upload-Content-Type")
        let (_, response) = try await send(start)
        guard let location = response.value(forHTTPHeaderField: "Location"), let uploadURL = URL(string: location) else {
            throw DriveError.http(response.statusCode)
        }

        var put = URLRequest(url: uploadURL)
        put.httpMethod = "PUT"
        put.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data: Data
        let putResponse: URLResponse
        do {
            (data, putResponse) = try await session.upload(for: put, fromFile: file)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DriveError.network
        }
        guard let http = putResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DriveError.http((putResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(FileID.self, from: data).id
    }

    private func firstID(matching query: String) async throws -> String? {
        struct List: Decodable { let files: [FileID] }
        var components = URLComponents(string: "\(Self.api)/files")!
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "fields", value: "files(id)"),
            .init(name: "pageSize", value: "1"),
            .init(name: "spaces", value: "drive"),
        ]
        let (data, _) = try await send(URLRequest(url: components.url!))
        return try JSONDecoder().decode(List.self, from: data).files.first?.id
    }

    private func request(_ url: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return request
    }

    /// Sends a request with the access key. Renews the key once when Google rejects it.
    private func send(_ original: URLRequest) async throws -> (Data, HTTPURLResponse) {
        for attempt in 0..<2 {
            var request = original
            let token: String
            do {
                token = try await auth.token(forceRefresh: attempt == 1)
            } catch GoogleAuthError.needsReconnect, GoogleAuthError.notConfigured {
                throw DriveError.needsReconnect
            } catch {
                throw DriveError.network
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw DriveError.network
            }
            guard let http = response as? HTTPURLResponse else { throw DriveError.network }
            if http.statusCode == 401, attempt == 0 { continue }
            if http.statusCode == 401 { throw DriveError.needsReconnect }
            guard (200...299).contains(http.statusCode) else { throw DriveError.http(http.statusCode) }
            return (data, http)
        }
        throw DriveError.needsReconnect
    }

    private static func escaped(_ name: String) -> String {
        name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
    }
}
