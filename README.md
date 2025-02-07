# SiteIconKit

A lightweight Swift library to fetch and display favicons (website icons) with caching and SwiftUI integration.

## Features

- **Easy Favicon Fetching: Retrieves website icons via DuckDuckGo’s favicon service.**
- **Automatic Caching:**
- **In-memory caching using NSCache.**
- **Disk caching in your app’s Caches directory.**
- **Async/Await & Combine: Offers both modern async/await APIs and a Combine publisher.**
- **SwiftUI Integration: SiteIconView for seamless icon loading within your SwiftUI apps.**
- **Error Handling: Clear error cases (SiteIconError) for network issues, decoding failures, invalid responses, and more.**

## Installation

Swift Package Manager

1. Select File > Swift Packages > Add Package Dependency
2. Enter the repository URL for SiteIconKit `https://github.com/batuhangundogdu/SiteIconKit.git`
3. Choose Version, Branch, or Commit as needed, then Add Package
4. In your Swift code, `import SiteIconKit`

Alternatively, in your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/batuhangundogdu/SiteIconKit.git", from: "1.0.0")
]
```

## Quick Start

Once added to your project:

```swift
import SiteIconKit
import SwiftUI

struct ContentView: View {
@State private var website = "apple.com"

    var body: some View {
        SiteIconView(website: $website)
            .frame(width: 40, height: 40)
    }

}
```

This single line displays an icon for apple.com with default caching and a built-in loading state.

## Async/Await Usage

If you’re building a feature outside of SwiftUI or prefer direct control, you can fetch icons via the async/await API:

```swift
import SiteIconKit

func loadFavicon(for website: String) async {
    do {
        let icon = try await SiteIconService.fetchIcon(for: website)
        // do something with icon, e.g., display in UIImageView
    } catch {
        print("Failed to fetch icon: \(error)")
    }
}
```

How It Works

1. In-Memory Cache: Checks if website is already cached in memory.
2. Disk Cache: If not in memory, checks the WebPageIconCache folder in Caches.
3. Network Fetch: If nothing is cached, it fetches from https://icons.duckduckgo.com/ip3/{website}.ico.
4. Update Caches: Stores the newly retrieved image in both in-memory and disk cache.

## Combine Usage

For reactive apps or existing Combine pipelines, use the Combine publisher:

```swift
import SiteIconKit
import Combine

class FaviconViewModel: ObservableObject {
    @Published var favicon: UIImage?
    @Published var loadingError: Error?

    private var cancellables = Set<AnyCancellable>()

    func loadFavicon(for website: String) {
        SiteIconService.iconPublisher(for: website)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                switch progress {
                case .started:
                    // Maybe show a loading indicator
                    break
                case .completed(let image):
                    self?.favicon = image
                case .failed(let error):
                    self?.loadingError = error
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

}

```

**Publisher Emissions**

- `.started` : Loading has begun.
- `.completed(image)` : Successfully fetched an icon.
- `.failed(error)` : An error occurred.

## SwiftUI Usage

SiteIconView makes SwiftUI integration straightforward. Provide a Binding to a String representing the website domain:

```swift
import SiteIconKit
import SwiftUI

struct ContentView: View {
@State private var website = "apple.com"

    var body: some View {
        VStack {
            SiteIconView(website: $website, size: 50)
            TextField("Enter website", text: $website)
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        .padding()
    }

}
```

### Customizing the Placeholder

By default, a globe SF Symbol shows when the icon is loading or if an error occurs. To customize:

```swift
SiteIconView(
    website: $website,
    size: 60,
    placeholder: AnyView(
        Image(systemName: "exclamationmark.circle")
        .font(.system(size: 24))
        .foregroundColor(.red)
    )
)
```

## Advanced Topics

### Cache Management

- **In-Memory Cache:** Uses NSCache<NSString, UIImage>; automatically evicts items under memory pressure.
- **Disk Cache:** Icons are stored under the WebPageIconCache folder inside your app’s Caches directory.

### Potential improvements:

- Add manual invalidation methods to remove specific or all cached icons (both memory and disk).
- Implement a time-based eviction policy if you need to expire icons periodically.

### Error Handling

SiteIconError covers these cases:

1. `.invalidURL` : The string could not be turned into a valid URL.
2. `.networkError(Error)` : A low-level network error occurred.
3. `.invalidResponse` : The response was not an HTTP response.
4. `.responseFailedValidation` : The server returned a non-200 status code.
5. `.responseDecodingFailed` : Could not decode the fetched .ico data into a valid UIImage.

If an error occurs, SwiftUI usage automatically displays the placeholder. For async/await or Combine, handle errors in catch blocks or `.failed(error)` states.

## Example

### Async:

```swift
Task {
    do {
        let icon = try await SiteIconService.fetchIcon(for: "github.com")
        // Display or process 'icon'
    } catch {
        print("Failed to fetch icon: \(error)")
    }
}
```

### Combine:

```swift
SiteIconService.iconPublisher(for: "github.com")
    .sink { progress in
        switch progress {
            case .started: print("Loading...")
            case .completed(let image): print("Got icon: \(image)")
            case .failed(let error): print("Error: \(error)")
            default: break
        }
    }.store(in: &cancellables)
```

### SwiftUI:

```swift
struct ContentView: View {
    @State private var website = "github.com"

    var body: some View {
        SiteIconView(website: $website, size: 32)
    }

}
```

## Requirements

- iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ (depending on your SwiftUI/Combine usage).
- Swift 5.5+ for async/await features.
- An active internet connection to fetch icons the first time.

## License

**MIT License**

**Copyright (c) 2025 Batuhan Gundogdu**
