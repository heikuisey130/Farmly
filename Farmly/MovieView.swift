// MovieView.swift

import SwiftUI

struct MovieView: View {
    private let apiKey = "98d8f2af5358cfadfa95d2784e0a58db"
    let selectedGenreIDs: Set<Int>
    @Environment(\.dismiss) private var dismiss
    
    @State private var allMovies: [Movie] = []
    @State private var currentMovie: Movie?
    @State private var statusMessage = "正在加载电影..."
    
    @State private var preloadedMovie: Movie?
    
    @State private var isFlipped = false
    @State private var detailedMovie: MovieDetail?
    @State private var isFetchingDetails = false

    var body: some View {
        VStack(spacing: 15) {
            Text("为你推荐")
                .font(.largeTitle).fontWeight(.bold)
                .padding(.top)

            ZStack {
                if let movie = currentMovie {
                    FlippableCardView(
                        movie: movie,
                        detailedMovie: detailedMovie,
                        isFlipped: $isFlipped,
                        isFetchingDetails: isFetchingDetails
                    )
                    // --- 1. 将 onTapGesture 的调用改为异步任务 <-- ---
                    .onTapGesture {
                        Task {
                            await handleFlip(for: movie.id)
                        }
                    }
                    .scaleEffect(0.85)
                    .transition(.scale(scale: 0.8, anchor: .center).combined(with: .opacity))
                    .id(movie.id)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentMovie?.id)
                    
                } else {
                    Text(statusMessage)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .frame(height: 450)
            .padding(.top, 20)

            Spacer()

            HStack(spacing: 20) {
                Button(action: markAsWatchedAndRecommendNext) {
                    Label("我看过了", systemImage: "eye.slash.fill")
                }
                .font(.headline).padding().frame(maxWidth: .infinity)
                .background(Color.green).foregroundColor(.white).cornerRadius(15)
                .disabled(currentMovie == nil)

                Button("换一部推荐") {
                    recommendNextMovie()
                }
                .font(.headline).padding().frame(maxWidth: .infinity)
                .background(Color.blue).foregroundColor(.white).cornerRadius(15)
                .disabled(allMovies.count <= 1 && currentMovie != nil)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .task { await fetchMovies(for: selectedGenreIDs) }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) { Label("重新选择", systemImage: "chevron.left") }
            }
        }
    }
    
    // --- 2. 重写 handleFlip 函数，实现“先加载，再翻转” <-- ---
    func handleFlip(for movieID: Int) async {
        // 如果卡片已经是翻转状态，直接执行翻转动画回去
        if isFlipped {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isFlipped = false
            }
            return
        }
        
        // 如果是翻向背面
        // 检查是否已经加载过这份详情，如果加载过，直接翻转
        if detailedMovie?.id == movieID {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isFlipped = true
            }
            return
        }
        
        // 如果没有加载过，则先开始加载
        isFetchingDetails = true
        self.detailedMovie = await fetchMovieDetails(for: movieID)
        isFetchingDetails = false
        
        // 当加载结束后（无论成功失败），再执行翻转动画
        if self.detailedMovie != nil {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isFlipped = true
            }
        }
    }
    
    func fetchMovieDetails(for movieID: Int) async -> MovieDetail? {
        let urlString = "https://api.themoviedb.org/3/movie/\(movieID)?api_key=\(apiKey)&language=zh-CN&append_to_response=credits"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(MovieDetail.self, from: data)
        } catch {
            print("获取详情失败: \(error)")
            return nil
        }
    }

    func markAsWatchedAndRecommendNext() {
        guard let movieToWatch = currentMovie else { return }
        WatchedList.add(movieID: movieToWatch.id)
        allMovies.removeAll { $0.id == movieToWatch.id }
        recommendNextMovie()
    }
    
    func recommendNextMovie() {
        isFlipped = false
        detailedMovie = nil
        
        let movieToShow = preloadedMovie
        
        let potentialNextMovies = allMovies.filter { $0.id != movieToShow?.id }
        preloadedMovie = potentialNextMovies.randomElement()
        
        if movieToShow != nil {
            currentMovie = movieToShow
            Task {
                await ImagePrefetcher.prefetch(url: preloadedMovie?.posterURL)
            }
        } else {
            currentMovie = nil
            statusMessage = "该类型下已没有可推荐的电影了"
        }
    }
    
    func fetchMovies(for genreIDs: Set<Int>) async {
        let watchedIDs = WatchedList.getIDs()
        var urlString: String
        if genreIDs.isEmpty {
            urlString = "https://api.themoviedb.org/3/movie/popular?api_key=\(apiKey)&language=zh-CN"
        } else {
            let genreIDString = genreIDs.map(String.init).joined(separator: ",")
            urlString = "https://api.themoviedb.org/3/discover/movie?api_key=\(apiKey)&language=zh-CN&with_genres=\(genreIDString)"
        }
        guard let url = URL(string: urlString) else { return }
        do {
            var fetchedMovies = [Movie]()
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(MovieResponse.self, from: data)
            fetchedMovies = response.results.filter { !watchedIDs.contains($0.id) && $0.posterPath != nil }
            
            guard !fetchedMovies.isEmpty else {
                statusMessage = "该类型下已没有可推荐的电影了"; currentMovie = nil; preloadedMovie = nil; allMovies = []; return
            }
            
            allMovies = fetchedMovies
            currentMovie = allMovies.removeFirst()
            preloadedMovie = allMovies.first
            
            Task {
                await ImagePrefetcher.prefetch(url: preloadedMovie?.posterURL)
            }
            
        } catch {
            statusMessage = "加载失败: \(error.localizedDescription)"
        }
    }
}

// --- 3. 修改 FlippableCardView，在正面增加加载指示器 <-- ---
struct FlippableCardView: View {
    let movie: Movie
    let detailedMovie: MovieDetail?
    @Binding var isFlipped: Bool
    let isFetchingDetails: Bool
    
    var body: some View {
        ZStack {
            CardFaceView(movie: movie, detailedMovie: detailedMovie, isFetchingDetails: isFetchingDetails)
                .opacity(isFlipped ? 1.0 : 0.0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))

            // 将海报和加载圈放在一个 ZStack 里
            ZStack {
                CachedAsyncImage(url: movie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                
                // 如果正在获取详情，就在海报上叠加一个半透明的加载指示
                if isFetchingDetails {
                    Color.black.opacity(0.4)
                    ProgressView().tint(.white)
                }
            }
            .cornerRadius(15).shadow(radius: 10)
            .opacity(isFlipped ? 0.0 : 1.0)
            .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
        }
    }
}

struct CardFaceView: View {
    let movie: Movie
    let detailedMovie: MovieDetail?
    let isFetchingDetails: Bool

    var body: some View {
        ZStack {
            CachedAsyncImage(url: movie.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .blur(radius: 30, opaque: true)
            .overlay(.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 10)
            
            // 这里的内容现在只会在加载完成后才显示
            if let detail = detailedMovie {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(detail.title).font(.largeTitle).fontWeight(.black)
                        
                        if let tagline = detail.tagline, !tagline.isEmpty {
                            Text("\"\(tagline)\"")
                                .font(.headline).fontWeight(.light).italic()
                        }
                        
                        Divider().overlay(.white.opacity(0.5))
                        
                        Text(detail.overview ?? "暂无简介。").font(.body).lineSpacing(5)
                        
                        Divider().overlay(.white.opacity(0.5))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRowView(icon: "calendar", label: "上映日期", value: detail.releaseDate ?? "未知")
                            InfoRowView(icon: "clock", label: "片长", value: detail.runtime != nil ? "\(detail.runtime!) 分钟" : "未知")
                            InfoRowView(icon: "globe.asia.australia.fill", label: "国家", value: detail.productionCountries?.map(\.name).joined(separator: ", ") ?? "未知")
                        }
                        
                        Divider().overlay(.white.opacity(0.5))
                        
                        Text("主要演员").font(.title3).fontWeight(.bold)
                        
                        Text(detail.credits.cast.prefix(5).map(\.name).joined(separator: " / "))
                            .font(.subheadline).fontWeight(.light)
                        
                    }
                    .padding(25)
                }
            }
            // 注意：我们不再需要在CardFaceView里处理加载状态了，
            // 因为只有加载完成后，卡片才会翻转过来看到它。
        }
        .foregroundColor(.white)
        .shadow(radius: 2)
    }
}

struct InfoRowView: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .font(.subheadline)
                .frame(width: 25, alignment: .center)
            
            Text(label)
                .font(.subheadline).bold()
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WatchedList {
    private static let userDefaultsKey = "watchedMovieIDs"
    static func getIDs() -> Set<Int> {
        let defaults = UserDefaults.standard
        let array = defaults.array(forKey: userDefaultsKey) as? [Int] ?? []
        return Set(array)
    }
    static func add(movieID: Int) {
        let defaults = UserDefaults.standard
        var currentSet = getIDs()
        currentSet.insert(movieID)
        defaults.set(Array(currentSet), forKey: userDefaultsKey)
    }
}

struct Movie: Identifiable, Codable {
    let id: Int
    let title: String
    let posterPath: String?
    var posterURL: URL? {
        if let path = posterPath {
            return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
        }
        return nil
    }
}

struct MovieResponse: Codable {
    let results: [Movie]
}

struct MovieDetail: Identifiable, Codable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let runtime: Int?
    let tagline: String?
    let productionCountries: [ProductionCountry]?
    let credits: Credits
}

struct ProductionCountry: Identifiable, Codable {
    var id: String { name }
    let name: String
}

struct Credits: Codable {
    let cast: [CastMember]
}

struct CastMember: Identifiable, Codable {
    let id: Int
    let name: String
    let character: String?
}
