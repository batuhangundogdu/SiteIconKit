//
//  SiteIconKit.swift
//  SiteIconKit
//
//  Created by Batuhan GÜNDOĞDU on 7.02.2025.
//

import UIKit
import Combine

/// Represents possible errors that can occur during site icon fetching
public enum SiteIconError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case responseDecodingFailed
    case responseFailedValidation

    public var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .responseDecodingFailed:
            return "Response Decoding Failed"
        case .invalidResponse:
            return "Invalid Response"
        case .responseFailedValidation:
            return "Response Failed Validation"
        }
    }
}

/// Represents the progress states during icon loading
public enum SiteIconLoadingProgress {
    /// Loading has started
    case started
    /// Loading is in progress with a progress value between 0 and 1
    case loading(Double)
    /// Loading completed successfully with the fetched image
    case completed(UIImage)
    /// Loading failed with an error
    case failed(Error)
}

/// Service responsible for fetching and caching website icons (favicons)
public final class SiteIconService {
    
    /// In-memory cache to store fetched images.
    private static let memoryCache = NSCache<NSString, UIImage>()
    
    /// The directory where icons will be cached on disk.
    private static let diskCacheURL: URL = {
        // Typically, you'll store cache data in the .cachesDirectory.
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let folderURL = cacheDir.appendingPathComponent("WebPageIconCache", isDirectory: true)
        // Create the folder if it doesn't exist.
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
        }
        return folderURL
    }()
    
    /// Fetches the icon for a given website URL.
    /// - Parameter website: The website domain (e.g., "apple.com", "github.com")
    /// - Returns: A UIImage containing the website's icon
    /// - Throws: `SiteIconError` if the fetch fails
    /// 
    /// The fetch process follows this order:
    /// 1. Check in-memory cache
    /// 2. Check disk cache
    /// 3. Fetch from network if not cached
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     let icon = try await SiteIconService.fetchIcon(for: "apple.com")
    /// } catch {
    ///     print("Failed to fetch icon: \(error)")
    /// }
    /// ```
    public static func fetchIcon(for website: String) async throws -> UIImage {
        // 1. Check the in-memory cache first.
        if let cachedImage = memoryCache.object(forKey: website as NSString) {
            return cachedImage
        }
        
        // 2. Check the disk cache.
        let diskFileURL = diskCacheURL.appendingPathComponent(sanitizedFilename(for: website))
        if let dataOnDisk = try? Data(contentsOf: diskFileURL),
           let imageOnDisk = UIImage(data: dataOnDisk) {
            // If found on disk, add it to the in-memory cache for faster subsequent access.
            memoryCache.setObject(imageOnDisk, forKey: website as NSString)
            return imageOnDisk
        }
        
        // 3. If not found in cache, fetch from network using DuckDuckGo's favicon service.
        guard let encodedURLString = website.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let url = URL(string: "https://icons.duckduckgo.com/ip3/\(encodedURLString).ico")
        else {
            throw SiteIconError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SiteIconError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw SiteIconError.responseFailedValidation
            }
            
            guard let fetchedImage = UIImage(data: data) else {
                throw SiteIconError.responseDecodingFailed
            }
            
            // 4. Store in memory cache.
            memoryCache.setObject(fetchedImage, forKey: website as NSString)
            
            // 5. Also persist to disk cache (best effort; ignore errors for simplicity).
            try? data.write(to: diskFileURL, options: .atomic)
            
            return fetchedImage
        } catch {
            throw SiteIconError.networkError(error)
        }
    }
    
    /// Creates a Combine publisher that emits icon loading progress events.
    /// - Parameter website: The website domain (e.g., "apple.com")
    /// - Returns: A publisher that never fails and emits `SiteIconLoadingProgress` events
    ///
    /// The publisher will emit these events in order:
    /// 1. `.started`
    /// 2. `.completed(UIImage)` or `.failed(Error)`
    public static func iconPublisher(for website: String) -> AnyPublisher<SiteIconLoadingProgress, Never> {
        // Handle empty website string
        guard !website.isEmpty else {
            return Just(.failed(SiteIconError.invalidURL))
                .eraseToAnyPublisher()
        }
        
        return Deferred {
            Future<SiteIconLoadingProgress, Never> { promise in
                Task {
                    do {
                        let image = try await fetchIcon(for: website)
                        promise(.success(.completed(image)))
                    } catch {
                        promise(.success(.failed(error)))
                    }
                }
            }
        }
        .prepend(.started)
        .eraseToAnyPublisher()
    }
    
    /// Creates an async sequence that emits icon loading progress events.
    /// - Parameter website: The website domain (e.g., "apple.com")
    /// - Returns: An async sequence that emits `SiteIconLoadingProgress` events
    /// - Throws: `SiteIconError` if the fetch fails
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     for try await progress in SiteIconService.iconStream(for: "apple.com") {
    ///         switch progress {
    ///         case .started: print("Started loading")
    ///         case .completed(let image): // Handle image
    ///         case .failed(let error): // Handle error
    ///         }
    ///     }
    /// } catch {
    ///     print("Stream failed: \(error)")
    /// }
    /// ```
    public static func iconStream(for website: String) -> AsyncThrowingStream<SiteIconLoadingProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.started)
                
                do {
                    let image = try await fetchIcon(for: website)
                    continuation.yield(.completed(image))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Generates a filesystem-friendly filename for the disk cache.
    private static func sanitizedFilename(for website: String) -> String {
        // Replace special characters that aren't valid in filenames.
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?*|<>")
        let sanitized = website.unicodeScalars.map { invalidCharacters.contains($0) ? "_" : Character($0) }
        return String(sanitized) + ".ico"
    }
}
