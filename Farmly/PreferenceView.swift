// PreferenceView.swift

import SwiftUI

enum RecommendationSource: Hashable {
    case tmdbGenres(ids: Set<Int>)
    case doubanTop250
}

struct PreferenceView: View {
    private let apiKey = "98d8f2af5358cfadfa95d2784e0a58db"

    @State private var genres: [Genre] = []
    @State private var statusMessage = "正在加载电影类型..."
    
    @State private var selectedGenreIDs: Set<Int> = []
    @State private var path = NavigationPath()

    let columns: [GridItem] = [ GridItem(.adaptive(minimum: 150)) ]

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Text("想看点什么？")
                    .font(.largeTitle).fontWeight(.bold)
                Text("可选择豆瓣Top250，或多选下方类型")
                    .font(.subheadline).foregroundColor(.gray)
                    .padding(.bottom)

                if genres.isEmpty {
                    ProgressView().padding(); Text(statusMessage)
                } else {
                    ScrollView {
                        Text("精选列表")
                            .font(.title2).bold().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                        
                        doubanTop250Button
                            .padding(.horizontal)

                        Divider().padding(.vertical)
                        
                        Text("按类型筛选 (TMDB)")
                            .font(.title2).bold().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(genres) { genre in
                                GenreCardView(genre: genre, isSelected: selectedGenreIDs.contains(genre.id))
                                    .onTapGesture { toggleGenreSelection(for: genre) }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()

                Button(action: {
                    let genreSelection = RecommendationSource.tmdbGenres(ids: selectedGenreIDs)
                    path.append(genreSelection)
                }) {
                    Label("按类型推荐", systemImage: "sparkles")
                        .font(.headline).foregroundColor(.white).padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
            }
            .task { await fetchGenres() }
            .navigationDestination(for: RecommendationSource.self) { source in
                MovieView(source: source)
            }
            .navigationTitle("偏好选择")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var doubanTop250Button: some View {
        Button(action: {
            path.append(RecommendationSource.doubanTop250)
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text("豆瓣 Top 250")
                        .font(.headline).fontWeight(.heavy)
                    Text("来自所有影迷的终极选择")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "crown.fill")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.yellow.opacity(0.2))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(.yellow, lineWidth: 2)
            )
        }
        .tint(.primary)
    }
    
    func toggleGenreSelection(for genre: Genre) {
        if selectedGenreIDs.contains(genre.id) {
            selectedGenreIDs.remove(genre.id)
        } else {
            selectedGenreIDs.insert(genre.id)
        }
    }

    func fetchGenres() async {
        let urlString = "https://api.themoviedb.org/3/genre/movie/list?api_key=\(apiKey)&language=zh-CN"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GenreResponse.self, from: data)
            genres = response.genres
        } catch {
            statusMessage = "类型加载失败: \(error.localizedDescription)"
        }
    }
}


struct GenreCardView: View {
    let genre: Genre
    let isSelected: Bool

    var body: some View {
        Text(genre.name)
            .font(.headline)
            .foregroundColor(isSelected ? .white : .primary)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? .blue.opacity(0.5) : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(), value: isSelected)
    }
}

struct Genre: Identifiable, Codable {
    let id: Int
    let name: String
}

struct GenreResponse: Codable {
    let genres: [Genre]
}
