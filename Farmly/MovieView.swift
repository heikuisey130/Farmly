// MovieView.swift

import SwiftUI

struct MovieView: View {
    private let apiKey = "98d8f2af5358cfadfa95d2784e0a58db"
    let source: RecommendationSource
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
                    .onTapGesture {
                        Task {
                            await handleFlip(for: movie.id)
                        }
                    }
                    .scaleEffect(0.85)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
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
        .task {
            await fetchMovies()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) { Label("重新选择", systemImage: "chevron.left") }
            }
        }
    }
    
    func handleFlip(for movieID: Int) async {
        if isFlipped {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { isFlipped = false }
            return
        }
        if detailedMovie?.id == movieID {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { isFlipped = true }
            return
        }
        isFetchingDetails = true
        self.detailedMovie = await fetchMovieDetails(for: movieID)
        isFetchingDetails = false
        if self.detailedMovie != nil {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { isFlipped = true }
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
    
    func fetchMovies() async {
        let watchedIDs = WatchedList.getIDs()
        var fetchedMovies: [Movie] = []

        switch source {
        case .tmdbGenres(let genreIDs):
            fetchedMovies = await fetchMoviesFromTMDB(for: genreIDs, watchedIDs: watchedIDs)
        case .doubanTop250:
            statusMessage = "正在加载豆瓣Top250..."
            fetchedMovies = await fetchMoviesFromDoubanCSV(watchedIDs: watchedIDs)
        }
        
        allMovies = fetchedMovies
        
        guard !allMovies.isEmpty else {
            statusMessage = "该来源下已没有可推荐的电影了"; currentMovie = nil; preloadedMovie = nil; allMovies = []; return
        }
        
        currentMovie = allMovies.removeFirst()
        preloadedMovie = allMovies.first
        
        Task {
            await ImagePrefetcher.prefetch(url: preloadedMovie?.posterURL)
        }
    }

    func fetchMoviesFromTMDB(for genreIDs: Set<Int>, watchedIDs: Set<Int>) async -> [Movie] {
        var urlString: String
        if genreIDs.isEmpty {
            urlString = "https://api.themoviedb.org/3/movie/popular?api_key=\(apiKey)&language=zh-CN"
        } else {
            let genreIDString = genreIDs.map(String.init).joined(separator: ",")
            urlString = "https://api.themoviedb.org/3/discover/movie?api_key=\(apiKey)&language=zh-CN&with_genres=\(genreIDString)"
        }
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(MovieResponse.self, from: data)
            return response.results.filter { !watchedIDs.contains($0.id) && $0.posterPath != nil }
        } catch {
            print("🚨 TMDB 数据解析失败: \(error)")
            DispatchQueue.main.async { statusMessage = "加载失败: \(error.localizedDescription)" }
            return []
        }
    }
    
    func fetchMoviesFromDoubanCSV(watchedIDs: Set<Int>) async -> [Movie] {
        let localMovies = loadTitlesFromCSV()
        var movies: [Movie] = []
        await withTaskGroup(of: Movie?.self) { group in
            for localMovie in localMovies {
                group.addTask {
                    return await self.searchMovieOnTMDB(for: localMovie.title, year: localMovie.year)
                }
            }
            for await movie in group {
                if let movie = movie, !watchedIDs.contains(movie.id), movie.posterPath != nil {
                    movies.append(movie)
                }
            }
        }
        return movies
    }

    func loadTitlesFromCSV() -> [(title: String, year: String)] {
        guard let filepath = Bundle.main.path(forResource: "top250_movie", ofType: "csv") else {
            print("错误：在项目中找不到 top250_movie.csv 文件。")
            return []
        }
        do {
            let contents = try String(contentsOfFile: filepath, encoding: .utf8)
            let lines = contents.split(separator: "\n").dropFirst()
            var movies = [(title: String, year: String)]()
            for line in lines {
                let columns = line.split(separator: ",", maxSplits: 2).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if columns.count >= 3 {
                    let title = columns[1]
                    let year = columns[2]
                    movies.append((title: title, year: year))
                }
            }
            return movies
        } catch {
            print("错误：读取CSV文件失败 - \(error)")
            return []
        }
    }

    func searchMovieOnTMDB(for title: String, year: String) async -> Movie? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlString = "https://api.themoviedb.org/3/search/movie?api_key=\(apiKey)&language=zh-CN&query=\(encodedTitle)&primary_release_year=\(year)"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(MovieResponse.self, from: data)
            return response.results.first
        } catch {
            return nil
        }
    }
}

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

            CachedAsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .cornerRadius(15).shadow(radius: 10)
            .opacity(isFlipped ? 0.0 : 1.0)
            .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
        }
    }
}

// --- 3. 修改 CardFaceView，增加评分显示 <-- ---
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
            
            if isFetchingDetails {
                ProgressView().tint(.white)
            } else if let detail = detailedMovie {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(detail.title).font(.largeTitle).fontWeight(.black)
                        
                        if let tagline = detail.tagline, !tagline.isEmpty {
                            Text("\"\(tagline)\"")
                                .font(.headline).fontWeight(.light).italic()
                        }
                        
                        // --- 在这里增加评分区域 ---
                        VStack(alignment: .leading) {
                            Text("综合评分").font(.headline).bold()
                            HStack(spacing: 10) {
                                StarRatingView(rating: detail.voteAverage ?? 0)
                                Text(String(format: "%.1f / 10", detail.voteAverage ?? 0))
                                    .font(.title2).bold()
                                Text("(\(detail.voteCount ?? 0)人评价)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
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
            } else {
                Text("无法加载电影详情").font(.headline)
            }
        }
        .foregroundColor(.white)
        .shadow(radius: 2)
    }
}

// --- 2. 新增一个独立的“星星评分”视图 <-- ---
struct StarRatingView: View {
    let rating: Double // 传入的评分是10分制
    
    var body: some View {
        HStack(spacing: 2) {
            // 将10分制转换为5星制
            let starCount = round(rating / 2)
            
            ForEach(1...5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .foregroundColor(Double(index) <= starCount ? .yellow : .gray.opacity(0.5))
            }
        }
        .font(.title3)
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
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
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
    let voteAverage: Double? // 平均分
    let voteCount: Int? // 评分人数
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
