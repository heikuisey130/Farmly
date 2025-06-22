//
//  ContentView.swift
//  Farmly
//
//  Created by 王鹏 on 2025/6/22.
//
// ContentView.swift

// ContentView.swift

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 我们的App现在总是从偏好选择页开始
        PreferenceView()
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
