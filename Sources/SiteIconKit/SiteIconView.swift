//
//  SiteIconView.swift
//  SiteIconKit
//
//  Created by Batuhan GÜNDOĞDU on 7.02.2025.
//

import SwiftUI
import Combine

/// A SwiftUI view that asynchronously loads and displays a website's favicon.
/// The view handles loading states, errors, and caching automatically.
///
/// Example usage:
/// ```swift
/// struct ContentView: View {
///     @State private var website = "apple.com"
///     
///     var body: some View {
///         SiteIconView(website: $website, size: 32)
///     }
/// }
/// ```
public struct SiteIconView: View {
    @Binding var website: String
    let size: CGFloat
    let placeholder: AnyView
    
    @StateObject private var viewModel = SiteIconViewModel()
    
    /// Creates a new WebPageIconView with the specified parameters.
    /// - Parameters:
    ///   - website: Binding to the website URL to fetch the icon for (e.g., "apple.com")
    ///   - size: The size of the icon view (both width and height)
    ///   - placeholder: A view to display while loading or if an error occurs
    public init(
        website: Binding<String>,
        size: CGFloat = 30,
        placeholder: AnyView = AnyView(
            Image(systemName: "globe")
                .font(.system(size: 30))
                .foregroundColor(.gray)
        )
    ) {
        self._website = website
        self.size = size
        self.placeholder = placeholder
    }
    
    public var body: some View {
        Group {
            if website.isEmpty {
                placeholder
            } else if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if viewModel.isLoading {
                ProgressView()
            } else if viewModel.error != nil {
                placeholder
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .onChange(of: website) { newValue in
            viewModel.website = newValue
        }
        .onAppear {
            viewModel.website = website
        }
    }
}

/// View model that handles the icon loading logic for SiteIconView
fileprivate class SiteIconViewModel: ObservableObject {
    /// The current website URL to fetch the icon for
    @Published var website: String = ""
    
    /// The loaded icon image, if any
    @Published var image: UIImage?
    
    /// Whether the icon is currently being loaded
    @Published var isLoading = false
    
    /// The last error that occurred during loading, if any
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        $website
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] website in
                guard let self = self else { return }
                
                if website.isEmpty {
                    self.reset()
                } else {
                    Task {
                        await self.loadIcon(for: website)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func reset() {
        image = nil
        error = nil
        isLoading = false
    }
    
    @MainActor
    private func loadIcon(for website: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        image = nil
        
        do {
            image = try await SiteIconService.fetchIcon(for: website)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var website1 = "apple.com"
        @State private var website2 = "github.com"
        @State private var website3 = ""
        
        var body: some View {
            VStack(spacing: 20) {
                // Example with default settings
                SiteIconView(website: $website1)
                
                // Example with custom size
                SiteIconView(website: $website2, size: 50)
                
                // Example with empty website (shows placeholder)
                SiteIconView(website: $website3)
            }
        }
    }
    
    return PreviewWrapper()
}
