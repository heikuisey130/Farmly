//
//  RSSParser.swift
//  Farmly
//
//  Created by 王鹏 on 2025/6/23.
//
// RSSParser.swift

import Foundation

// MovieTitleParserDelegate 专门用来解析RSS中的电影标题
class MovieTitleParserDelegate: NSObject, XMLParserDelegate {
    private var movieTitles: [String] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var isParsingTitle = false

    // 当解析器找到一个元素的开始标签时调用
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "title" {
            currentTitle = ""
            isParsingTitle = true
        }
    }

    // 当解析器找到标签之间的字符时调用
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isParsingTitle {
            currentTitle += string
        }
    }

    // 当解析器找到一个元素的结束标签时调用
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "title" {
            // 清理标题，例如 "1. 肖申克的救赎 The Shawshank Redemption" -> "肖申克的救赎"
            // 这个正则表达式会尝试匹配中文标题
            if let range = currentTitle.range(of: #"(?<=^\d+\.\s).*?(?=\s The)"#, options: .regularExpression) {
                let cleanedTitle = String(currentTitle[range])
                movieTitles.append(cleanedTitle)
            } else if let range = currentTitle.range(of: #"(?<=^\d+\.\s).*"#, options: .regularExpression) {
                // 如果上面的正则没匹配到（比如纯英文标题），就用这个备用方案
                 let cleanedTitle = String(currentTitle[range])
                 movieTitles.append(cleanedTitle)
            }
            isParsingTitle = false
        }
    }
    
    // 返回最终解析出的标题数组
    func getTitles() -> [String] {
        // 第一个 title 是频道的标题，我们把它去掉
        if !movieTitles.isEmpty {
            return Array(movieTitles.dropFirst())
        }
        return []
    }
}

// RSSParser 是我们对外使用的工具
class RSSParser {
    func parse(url: URL) async -> [String] {
        let delegate = MovieTitleParserDelegate()
        return await withCheckedContinuation { continuation in
            let parser = XMLParser(contentsOf: url)
            parser?.delegate = delegate
            if parser?.parse() == true {
                continuation.resume(returning: delegate.getTitles())
            } else {
                continuation.resume(returning: [])
            }
        }
    }
}
