//
//  FRHighlight.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 26/08/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

enum HighlightStyle: Int {
    case yellow
    case green
    case blue
    case pink
    case underline
    
    init () { self = .yellow }
    
    /**
    Return HighlightStyle for CSS class.
    */
    static func styleForClass(_ className: String) -> HighlightStyle {
        switch className {
        case "highlight-yellow":
            return .yellow
        case "highlight-green":
            return .green
        case "highlight-blue":
            return .blue
        case "highlight-pink":
            return .pink
        case "highlight-underline":
            return .underline
        default:
            return .yellow
        }
    }
    
    /**
    Return CSS class for HighlightStyle.
    */
    static func classForStyle(_ style: Int) -> String {
        switch style {
        case HighlightStyle.yellow.rawValue:
            return "highlight-yellow"
        case HighlightStyle.green.rawValue:
            return "highlight-green"
        case HighlightStyle.blue.rawValue:
            return "highlight-blue"
        case HighlightStyle.pink.rawValue:
            return "highlight-pink"
        case HighlightStyle.underline.rawValue:
            return "highlight-underline"
        default:
            return "highlight-yellow"
        }
    }
    
    /**
    Return CSS class for HighlightStyle.
    */
    static func colorForStyle(_ style: Int, nightMode: Bool = false) -> UIColor {
        switch style {
        case HighlightStyle.yellow.rawValue:
            return UIColor(red: 255/255, green: 235/255, blue: 107/255, alpha: nightMode ? 0.9 : 1)
        case HighlightStyle.green.rawValue:
            return UIColor(red: 192/255, green: 237/255, blue: 114/255, alpha: nightMode ? 0.9 : 1)
        case HighlightStyle.blue.rawValue:
            return UIColor(red: 173/255, green: 216/255, blue: 255/255, alpha: nightMode ? 0.9 : 1)
        case HighlightStyle.pink.rawValue:
            return UIColor(red: 255/255, green: 176/255, blue: 202/255, alpha: nightMode ? 0.9 : 1)
        case HighlightStyle.underline.rawValue:
            return UIColor(red: 240/255, green: 40/255, blue: 20/255, alpha: nightMode ? 0.6 : 1)
        default:
            return UIColor(red: 255/255, green: 235/255, blue: 107/255, alpha: nightMode ? 0.9 : 1)
        }
    }
}

class FRHighlight: NSObject {
    var id: String!
    var content: String!
    var contentPre: String!
    var contentPost: String!
    var date: Foundation.Date!
    var page: Int!
    var bookId: String!
    var type: HighlightStyle!
    
    /**
    Match a highlight on string.
    */
    static func matchHighlight(_ text: String!, andId id: String) -> FRHighlight? {
        let pattern = "<highlight id=\"\(id)\" onclick=\".*?\" class=\"(.*?)\">((.|\\s)*?)</highlight>"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) 
        let str = (text as NSString)
        
        let mapped = matches.map { (match) -> FRHighlight in
            var contentPre = str.substring(with: NSRange(location: match.range.location-kHighlightRange, length: kHighlightRange))
            var contentPost = str.substring(with: NSRange(location: match.range.location + match.range.length, length: kHighlightRange))
            
            // Normalize string before save
            
            if contentPre.range(of: ">") != nil {
                let regex = try! NSRegularExpression(pattern: "((?=[^>]*$)(.|\\s)*$)", options: [])
                let searchString = regex.firstMatch(in: contentPre, options: .reportProgress, range: NSRange(location: 0, length: contentPre.characters.count))
                
                if searchString!.range.location != NSNotFound {
                    contentPre = (contentPre as NSString).substring(with: searchString!.range)
                }
            }
            
            if contentPost.range(of: "<") != nil {
                let regex = try! NSRegularExpression(pattern: "^((.|\\s)*?)(?=<)", options: [])
                let searchString = regex.firstMatch(in: contentPost, options: .reportProgress, range: NSRange(location: 0, length: contentPost.characters.count))
                
                if searchString!.range.location != NSNotFound {
                    contentPost = (contentPost as NSString).substring(with: searchString!.range)
                }
            }
            
            let highlight = FRHighlight()
            highlight.id = id
            highlight.type = HighlightStyle.styleForClass(str.substring(with: match.rangeAt(1)))
            highlight.content = str.substring(with: match.rangeAt(2))
            highlight.contentPre = contentPre
            highlight.contentPost = contentPost
            highlight.page = currentPageNumber
            highlight.bookId = (kBookId as NSString).deletingPathExtension
            
            return highlight
        }
        return mapped.first
    }
    
    static func removeById(_ highlightId: String) -> String? {
        let currentPage = FolioReader.sharedInstance.readerCenter.currentPage
        
        if let removedId = currentPage?.webView.js("removeHighlightById('\(highlightId)')") {
            return removedId
        } else {
            print("Error removing Higlight from page")
            return nil
        }
    }
}
