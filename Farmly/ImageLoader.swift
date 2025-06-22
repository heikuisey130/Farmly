// ImageLoader.swift

import SwiftUI

// --- 1. 一个全局的图片缓存“仓库” ---
// NSCache 是一个类似字典的集合，专门用来缓存临时数据，当内存紧张时它会自动清理。
// 我们把它设为全局单例，这样整个App都可以共享这一个缓存。
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {}

    func get(forKey key: NSURL) -> UIImage? {
        return cache.object(forKey: key)
    }

    func set(forKey key: NSURL, image: UIImage) {
        cache.setObject(image, forKey: key)
    }
}


// --- 2. 我们自己的、带缓存功能的图片加载视图 ---
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    // 使用 @StateObject 来创建和管理图片加载器的实例
    @StateObject private var loader: ImageLoader

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }

    var body: some View {
        if let image = loader.image {
            content(image) // 如果图片已加载，就显示内容
        } else {
            placeholder() // 否则，显示占位符
        }
    }
}


// --- 3. 图片加载器的核心逻辑 ---
// 这个 ObservableObject 会在图片下载完成时通知视图刷新。
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    private let url: URL?

    init(url: URL?) {
        self.url = url
        // 当这个加载器被创建时，立即开始加载
        Task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else { return }
        
        // 1. 先去缓存“仓库”里找
        if let cachedImage = ImageCache.shared.get(forKey: url as NSURL) {
            self.image = Image(uiImage: cachedImage)
            // print("从缓存加载: \(url)")
            return
        }

        // 2. 如果仓库里没有，再去网络下载
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            
            // 3. 下载成功后，存入缓存“仓库”
            ImageCache.shared.set(forKey: url as NSURL, image: uiImage)
            self.image = Image(uiImage: uiImage)
            // print("从网络加载并缓存: \(url)")
        } catch {
            print("图片下载失败: \(error.localizedDescription)")
        }
    }
}

// --- 4. 一个独立的图片预热工具 ---
// 我们可以调用它来悄悄地把图片下载到缓存中，而不显示在界面上。
class ImagePrefetcher {
    static func prefetch(url: URL?) async {
        guard let url = url else { return }
        
        if ImageCache.shared.get(forKey: url as NSURL) != nil {
            // print("图片已在缓存中，无需预热: \(url)")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            ImageCache.shared.set(forKey: url as NSURL, image: uiImage)
            // print("图片预热成功: \(url)")
        } catch {
            // 预热失败是不要紧的，因为用户最终还是会尝试加载它
        }
    }
}
