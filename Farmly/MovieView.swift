import SwiftUI

// --- 1. 数据模型 (Data Model) ---
// 我们创建一个自定义的 Movie 结构体，用来存放一部电影的多个信息。
// - Identifiable: 能让 SwiftUI 在列表中唯一识别每个元素。
// - Codable: 能让我们轻松地把从网上下载的JSON数据自动转换成这个结构体。
struct Movie: Identifiable, Codable {
    let id: Int
    let title: String
    let posterPath: String? // 海报路径，API返回的可能为空，所以是可选类型

    // 为了方便，我们创建一个计算属性来直接生成完整的海报URL
    var posterURL: URL? {
        if let path = posterPath {
            // TMDB的图片基础URL + 图片尺寸(w500是中等大小) + 具体的图片路径
            return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
        }
        return nil
    }
}

// 这个结构体用来匹配 TMDB API 返回的JSON的整体结构
// API返回的不是一个电影列表，而是一个包含"results"字段的对象，"results"里才是电影列表
struct MovieResponse: Codable {
    let results: [Movie]
}


// --- 2. 界面视图 (View) ---
struct ContentView: View {
    
    // 你的TMDB API密钥，请在这里粘贴
    private let apiKey = "98d8f2af5358cfadfa95d2784e0a58db"
    
    // 用来存储从API获取到的所有电影
    @State private var allMovies: [Movie] = []
    
    // 用来存储当前界面上正在推荐的电影
    @State private var currentMovie: Movie?
    
    // 用来显示加载状态或错误信息
    @State private var statusMessage = "正在加载热门电影..."

    var body: some View {
        VStack(spacing: 20) {
            
            Text("今日推荐")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            // --- 图片显示区域 ---
            // 如果 currentMovie 有值，就显示电影信息
            if let movie = currentMovie {
                // AsyncImage 是专门用来从URL异步加载并显示图片的视图
                AsyncImage(url: movie.posterURL) { image in
                    // 图片加载成功后，我们对图片进行一些修饰
                    image
                        .resizable() // 允许图片缩放
                        .aspectRatio(contentMode: .fit) // 保持宽高比填充
                        .cornerRadius(15) // 设置圆角
                        .shadow(radius: 10) // 添加阴影
                } placeholder: {
                    // 在图片正式加载完成前，显示一个占位符
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.3))
                        ProgressView() // 显示一个加载中的圈圈
                    }
                }
                .frame(height: 400) // 给图片区域一个固定的高度

                Text(movie.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

            } else {
                // 如果 currentMovie 为空（初始状态），就显示状态信息
                Spacer()
                Text(statusMessage)
                    .font(.title2)
                Spacer()
            }

            // --- 按钮区域 ---
            Button("推荐下一部") {
                recommendRandomMovie()
            }
            .font(.headline)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            // 如果电影列表还没加载好，按钮就不能点击
            .disabled(allMovies.isEmpty)
        }
        .padding()
        // .task 是一个修饰符，它会在视图出现时，自动执行里面的异步任务
        // 非常适合用来在界面一加载时就去请求网络数据
        .task {
            await fetchMovies()
        }
    }
    
    // --- 3. 核心功能 (Core Logic) ---
    
    // 异步功能：从TMDB的API获取热门电影数据
    func fetchMovies() async {
        // 1. 准备URL
        let urlString = "https://api.themoviedb.org/3/movie/popular?api_key=\(apiKey)&language=zh-CN&page=1"
        guard let url = URL(string: urlString) else {
            statusMessage = "错误：无法创建URL"
            return
        }
        
        // 2. 发起网络请求
        do {
            // `URLSession.shared.data(from: url)` 是一个异步操作，我们用 await 来等待它完成
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 3. 解析JSON数据
            let decoder = JSONDecoder()
            // API返回的字段是下划线命名(poster_path)，Swift是驼峰命名(posterPath)，设置这个策略可以自动转换
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(MovieResponse.self, from: data)
            
            // 4. 更新状态
            allMovies = response.results
            statusMessage = "点击按钮开始推荐"
            // 获取成功后，立刻推荐第一部电影
            recommendRandomMovie()
            
        } catch {
            // 如果中间任何一步出错，就在界面上显示错误信息
            statusMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    // 同步功能：从已下载的电影列表中随机选一部
    func recommendRandomMovie() {
        // `randomElement()` 从数组中随机取一个元素
        currentMovie = allMovies.randomElement()
    }
}


// --- 预览代码 ---
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
