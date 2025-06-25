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
        // App的唯一入口就是偏好选择页
        PreferenceView()
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
