// PreferenceView.swift

import SwiftUI

struct PreferenceView: View {
    // 你的TMDB API密钥
    private let apiKey = "98d8f2af5358cfadfa95d2784e0a58db"

    @State private var genres: [Genre] = []
    @State private var statusMessage = "正在加载电影类型..."
    
    // --- 新增状态 ---
    // 1. 使用 Set 来存储多个已选中的类型ID，Set可以自动处理重复问题
    @State private var selectedGenreIDs: Set<Int> = []
    // 2. 一个布尔值，用来触发导航到下一个页面
    @State private var navigateToMovies = false

    // --- 界面美化：定义网格布局 ---
    // 创建一个自适应的网格，每列最小宽度150，SwiftUI会自动计算一行能放几列
    let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 150))
    ]

    var body: some View {
        // NavigationStack 是实现页面跳转的关键
        NavigationStack {
            VStack {
                // --- 标题 ---
                Text("想看点什么？")
                    .font(.largeTitle).fontWeight(.bold)
                Text("可多选，或直接点击下方按钮随机推荐")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)

                // --- 网格区域 ---
                if genres.isEmpty {
                    ProgressView().padding()
                    Text(statusMessage)
                } else {
                    // 使用 ScrollView + LazyVGrid 来创建可滚动的网格
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(genres) { genre in
                                GenreCardView(genre: genre, isSelected: selectedGenreIDs.contains(genre.id))
                                    .onTapGesture {
                                        // --- 多选逻辑 ---
                                        toggleSelection(for: genre)
                                    }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()

                // --- 确认按钮 ---
                Button(action: {
                    // 点击按钮时，触发导航状态
                    navigateToMovies = true
                }) {
                    // 使用 Label 可以同时展示图标和文字
                    Label("我选好了，开始推荐！", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                }
                .padding()
            }
            .task {
                await fetchGenres()
            }
            // --- 导航目标 ---
            // 当 `MapsToMovies` 变为 true 时，自动跳转到 MovieView
            .navigationDestination(isPresented: $navigateToMovies) {
                // 把用户选择的类型ID集合传递给下一个页面
                MovieView(selectedGenreIDs: selectedGenreIDs)
            }
        }
    }

    // --- 功能函数 ---
    
    func toggleSelection(for genre: Genre) {
        if selectedGenreIDs.contains(genre.id) {
            selectedGenreIDs.remove(genre.id) // 如果已选中，就取消选中
        } else {
            selectedGenreIDs.insert(genre.id) // 如果未选中，就加入选中集合
        }
    }

    func fetchGenres() async {
        // ... (获取类型的函数和之前一样，无需改动)
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

// --- 界面美化：为类型创建一个单独的卡片视图 ---
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
                // 如果选中，显示一个边框
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? .blue.opacity(0.5) : .clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0) // 选中时稍微放大
            .animation(.spring(), value: isSelected) // 添加灵动的动画
    }
}


// --- 数据模型 (和之前一样) ---
struct Genre: Identifiable, Codable {
    let id: Int
    let name: String
}

struct GenreResponse: Codable {
    let genres: [Genre]
}
