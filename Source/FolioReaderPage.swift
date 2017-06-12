//
//  FolioReaderPage.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SafariServices
import MenuItemKit
import JSQWebViewController
import JavaScriptCore

@objc protocol FolioPageDelegate {
    @objc optional func pageDidLoad(_ page: FolioReaderPage)
}

class FolioReaderPage: UICollectionViewCell, UIWebViewDelegate, UIGestureRecognizerDelegate,FolioReaderAudioPlayerDelegate {
    
    var pageNumber: Int!
    var webView: UIWebView!
    var delegate: FolioPageDelegate!
    fileprivate var shouldShowBar = true
    fileprivate var menuIsVisible = false
    
    // MARK: - View life cicle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.white
        print("Create page")
        if webView == nil {
            webView = UIWebView(frame: contentView.bounds)
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.dataDetectorTypes = .link
            webView.backgroundColor = UIColor.clear
            webView.paginationMode = UIWebPaginationMode.leftToRight
            webView.paginationBreakingMode = UIWebPaginationBreakingMode.page
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.showsHorizontalScrollIndicator = false
            webView.scrollView.isPagingEnabled = true
            webView.scrollView.bounces = false
            webView.delegate = self

            self.contentView.addSubview(webView)
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(FolioReaderPage.handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        webView.addGestureRecognizer(tapGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func webViewFrame() -> CGRect {
        if readerConfig.shouldHideNavigationOnTap == false {
            let statusbarHeight = UIApplication.shared.statusBarFrame.size.height
            let navBarHeight = FolioReader.sharedInstance.readerCenter.navigationController?.navigationBar.frame.size.height
            let navTotal = statusbarHeight + navBarHeight!
            let newFrame = CGRect(x: self.bounds.origin.x, y: self.bounds.origin.y+navTotal, width: self.bounds.width, height: self.bounds.height-navTotal)
            return newFrame
        } else {
            return self.bounds
        }
    }
    
    func loadHTMLString(_ string: String!, baseURL: URL!) {
        
        var html = (string as NSString)
        
        // Restore highlights
        let highlights = Highlight.allByBookId((kBookId as NSString).deletingPathExtension, andPage: pageNumber! as NSNumber)
        print("\(highlights)")
        if highlights.count > 0 {
            for item in highlights {
                let style = HighlightStyle.classForStyle(item.type)
                let tag = "<highlight id=\"\(item.highlightId)\" onclick=\"callHighlightURL(this);\" class=\"\(style)\">\(item.content)</highlight>"
                let locator = item.contentPre + item.content + item.contentPost
                let range: NSRange = html.range(of: locator, options: .literal)
                
                if range.location != NSNotFound {
                    let newRange = NSRange(location: range.location + item.contentPre.characters.count, length: item.content.characters.count)
                    html = html.replacingCharacters(in: newRange, with: tag) as (NSString)
                }
                else {
                    print("highlight range not found")
                }
            }
        }
        
        webView.alpha = 0
        webView.loadHTMLString(html as String, baseURL: baseURL)
    }
    
    // MARK: - FolioReaderAudioPlayerDelegate
    func didReadSentence() {
        self.readCurrentSentence();
    }
    
    // MARK: - UIWebView Delegate
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        if (!book.hasAudio()) {
            FolioReader.sharedInstance.readerAudioPlayer.delegate = self;
            _ = self.webView.js("wrappingSentencesWithinPTags()");
            if (FolioReader.sharedInstance.readerAudioPlayer.isPlaying()) {
                readCurrentSentence()
            }
        }

        webView.scrollView.contentSize = CGSize(width: webView.scrollView.contentSize.width, height: pageHeight)
        
        if scrollDirection == .left && isScrolling {
            let bottomOffset = CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0)
            if bottomOffset.x >= 0 {
                DispatchQueue.main.async(execute: {
                    webView.scrollView.setContentOffset(bottomOffset, animated: false)
                })
            }
        }
        
        UIView.animate(withDuration: 0.2, animations: {webView.alpha = 1}, completion: { finished in
            webView.isColors = false
            self.webView.createMenu(options: false)
        }) 

        delegate.pageDidLoad!(self)
        
        
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        print("shouldStartLoadWithRequest \(String(describing: request.url))  \(String(describing: request.url?.scheme))")
        let url = request.url
        
        if url?.scheme == "highlight" {
            
            shouldShowBar = false
            
            let decoded = url?.absoluteString.removingPercentEncoding as String!
            let rect = CGRectFromString(decoded!.substring(from: decoded!.index(decoded!.startIndex, offsetBy: 12)))
            
            webView.createMenu(options: true)
            webView.setMenuVisible(true, andRect: rect)
            menuIsVisible = true
            
            return false
        } else if url?.scheme == "play-audio" {
            let decoded = url!.absoluteString.removingPercentEncoding as String!
            let playID = decoded!.substring(from: decoded!.index(decoded!.startIndex, offsetBy: 13))
            print("playID = " + playID)
            FolioReader.sharedInstance.readerCenter.playAudio(playID)

            return false
        } else if url?.scheme == "file" {
            
            let anchorFromURL = url?.fragment
            
            // Handle internal url
            if (url!.path as NSString).pathExtension != "" {
                let base = (book.opfResource.href as NSString).deletingLastPathComponent
                let path = url?.path
                let splitedPath = path!.components(separatedBy: base.isEmpty ? kBookId : base)
                
                // Return to avoid crash
                if splitedPath.count <= 1 || splitedPath[1].isEmpty {
                    return true
                }
                
                let href = splitedPath[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let hrefPage = FolioReader.sharedInstance.readerCenter.findPageByHref(href)+1
                
                if hrefPage == pageNumber {
                    // Handle internal #anchor
                    if anchorFromURL != nil {
                        handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animating: true)
                        return false
                    }
                } else {
                    FolioReader.sharedInstance.readerCenter.changePageWith(href: href, animated: true)
                }
                
                return false
            }
            
            // Handle internal #anchor
            if anchorFromURL != nil {
                handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animating: true)
                return false
            }
            
            return true
        } else if url?.scheme == "mailto" {
            print("Email")
            return true
        } else if request.url!.absoluteString != "about:blank" && navigationType == .linkClicked {
            let safariVC = SFSafariViewController(url: request.url!)
            safariVC.view.tintColor = readerConfig.tintColor
            FolioReader.sharedInstance.readerCenter.present(safariVC, animated: true, completion: nil)
            
            return false
        }
        
        return true
    }
    
    // MARK: Gesture recognizer
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.view is UIWebView {
            if otherGestureRecognizer is UILongPressGestureRecognizer {
                if UIMenuController.shared.isMenuVisible {
                    webView.setMenuVisible(false)
                }
                return false
            }
            return true
        }
        return false
    }
    
    func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
//        webView.setMenuVisible(false)
//        
//        if FolioReader.sharedInstance.readerCenter.navigationController!.navigationBarHidden {
//            let menuIsVisibleRef = menuIsVisible
//            
//            let selected = webView.js("getSelectedText()")
//
//            if selected == nil || selected!.characters.count == 0 {
//                let seconds = 0.4
//                let delay = seconds * Double(NSEC_PER_SEC)  // nanoseconds per seconds
//                let dispatchTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
//
//                dispatch_after(dispatchTime, dispatch_get_main_queue(), {
//                    
//                    if self.shouldShowBar && !menuIsVisibleRef {
//                        FolioReader.sharedInstance.readerCenter.toggleBars()
//                    }
//                    self.shouldShowBar = true
//                })
//            }
//        } else if readerConfig.shouldHideNavigationOnTap == true {
//            FolioReader.sharedInstance.readerCenter.hideBars()
//        }
        FolioReader.sharedInstance.readerCenter.presentPlayerMenu(true)
        // Reset menu
        menuIsVisible = false
    }
    
    // MARK: - Scroll positioning
    
    func scrollPageToOffset(_ offset: String, animating: Bool) {
        let jsCommand = "window.scrollTo(0,\(offset));"
        if animating {
            UIView.animate(withDuration: 0.35, animations: {
                _ = self.webView.js(jsCommand)
            })
        } else {
            _ = webView.js(jsCommand)
        }
    }
    
    func handleAnchor(_ anchor: String,  avoidBeginningAnchors: Bool, animating: Bool) {
        if !anchor.isEmpty {
            if let offset = getAnchorOffset(anchor) {
                let isBeginning = CGFloat((offset as NSString).floatValue) > self.frame.height/2
                
                if !avoidBeginningAnchors {
                    scrollPageToOffset(offset, animating: animating)
                } else if avoidBeginningAnchors && isBeginning {
                    scrollPageToOffset(offset, animating: animating)
                }
            }
        }
    }
    
    func getAnchorOffset(_ anchor: String) -> String? {
        let jsAnchorHandler = "(function() {var target = '\(anchor)';var elem = document.getElementById(target); if (!elem) elem=document.getElementsByName(target)[0];return elem.offsetTop;})();"
        return webView.js(jsAnchorHandler)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if UIMenuController.shared.menuItems?.count == 0 {
            webView.isColors = false
            webView.createMenu(options: false)
        }
        
        return super.canPerformAction(action, withSender: sender)
    }

    func playAudio(){
		if (book.hasAudio()) {
            _ = webView.js("playAudio()")
		} else {
			readCurrentSentence()
		}
    }
    
    func playAudioFromPageBegin(){
        removeAllAudioMarks()
        if (book.hasAudio()) {
            _ = webView.js("playAudio()")
        } else {
            readCurrentSentence()
        }
    }
    
    func speakSentence(){
        let sentence = self.webView.js("getSentenceWithIndex('\(book.playbackActiveClass())')")
        if sentence != nil {
            let chapter = FolioReader.sharedInstance.readerCenter.getCurrentChapter()
            let href = chapter != nil ? chapter!.href : "";
            FolioReader.sharedInstance.readerAudioPlayer.playText(href!, text: sentence!)
        } else {
            if(FolioReader.sharedInstance.readerCenter.isLastPage()){
                FolioReader.sharedInstance.readerAudioPlayer.stop()
            } else{
                FolioReader.sharedInstance.readerCenter.changePageToNext()
            }
        }
    }
    
	func readCurrentSentence() {
		if (FolioReader.sharedInstance.readerAudioPlayer.synthesizer == nil ) {
            speakSentence()
		} else {
            if(FolioReader.sharedInstance.readerAudioPlayer.synthesizer.isPaused){
                FolioReader.sharedInstance.readerAudioPlayer.synthesizer.continueSpeaking()
            }else{
                if(FolioReader.sharedInstance.readerAudioPlayer.synthesizer.isSpeaking){
                    FolioReader.sharedInstance.readerAudioPlayer.stopSynthesizer({ () -> Void in
                        _ = self.webView.js("resetCurrentSentenceIndex()")
                        self.speakSentence()
                    })
                }else{
                    speakSentence()
                }
            }
		}
	}

    func audioMarkID(_ ID: String){
        //print("audioMarkID('\(book.playbackActiveClass())    \(ID)")
        _ = self.webView.js("audioMarkID('\(book.playbackActiveClass())','\(ID)')");
    }
    
    func removeAllAudioMarks() {
        _ = self.webView.js("removeAllAudioMarks()");
    }
}

// MARK: - WebView Highlight and share implementation

private var cAssociationKey: UInt8 = 0
private var sAssociationKey: UInt8 = 0

extension UIWebView {
    
    var isColors: Bool {
        get { return objc_getAssociatedObject(self, &cAssociationKey) as? Bool ?? false }
        set(newValue) {
            objc_setAssociatedObject(self, &cAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    var isShare: Bool {
        get { return objc_getAssociatedObject(self, &sAssociationKey) as? Bool ?? false }
        set(newValue) {
            objc_setAssociatedObject(self, &sAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        // menu on existing highlight
        if isShare {
            if action == #selector(UIWebView.colors(_:)) || (action == #selector(UIWebView.share(_:)) && readerConfig.allowSharing == true) || action == #selector(UIWebView.remove(_:)) {
                return true
            }
            return false

        // menu for selecting highlight color
        } else if isColors {
            if action == #selector(UIWebView.setYellow(_:)) || action == #selector(UIWebView.setGreen(_:)) || action == #selector(UIWebView.setBlue(_:)) || action == #selector(UIWebView.setPink(_:)) || action == #selector(UIWebView.setUnderline(_:)) {
                return true
            }
            return false

        // default menu
        } else {
            if action == #selector(UIWebView.highlight(_:))
            || (action == #selector(UIWebView.define(_:)) && (js("getSelectedText()"))!.components(separatedBy: " ").count == 1)
            || (action == #selector(UIWebView.translate(_:))) 
            || (action == #selector(UIWebView.play(_:)) && (book.hasAudio() || readerConfig.enableTTS))
            || (action == #selector(UIWebView.share(_:)) && readerConfig.allowSharing == true)
            || (action == #selector(copy(_:)) && readerConfig.allowSharing == true) {
                return true
            }
            return false
        }
    }
    
    open override var canBecomeFirstResponder : Bool {
        return true
    }
    
    func share(_ sender: UIMenuController) {
        
        if isShare {
            if let textToShare = js("getHighlightContent()") {
                FolioReader.sharedInstance.readerCenter.shareHighlight(textToShare, rect: sender.menuFrame)
            }
        } else {
            if let textToShare = js("getSelectedText()") {
                FolioReader.sharedInstance.readerCenter.shareHighlight(textToShare, rect: sender.menuFrame)
            }
        }
        
        setMenuVisible(false)
    }
    
    func colors(_ sender: UIMenuController?) {
        isColors = true
        createMenu(options: false)
        setMenuVisible(true)
    }
    
    func remove(_ sender: UIMenuController?) {
        if let removedId = js("removeThisHighlight()") {
            Highlight.removeById(removedId)
        }
        
        setMenuVisible(false)
    }
    
    func highlight(_ sender: UIMenuController?) {
        let highlightAndReturn = js("highlightString('\(HighlightStyle.classForStyle(FolioReader.sharedInstance.currentHighlightStyle))')")
        let jsonData = highlightAndReturn?.data(using: String.Encoding.utf8)
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData!, options: []) as! NSArray
            let dic = json.firstObject as! [String: String]
            let rect = CGRectFromString(dic["rect"]!)
            
            // Force remove text selection
            isUserInteractionEnabled = false
            isUserInteractionEnabled = true

            createMenu(options: true)
            setMenuVisible(true, andRect: rect)
            
            // Persist
            let html = js("getHTML()")
            if let highlight = FRHighlight.matchHighlight(html, andId: dic["id"]!) {
                Highlight.persistHighlight(highlight, completion: nil)
            }
        } catch {
            print("Could not receive JSON")
        }
        
    }

    func define(_ sender: UIMenuController?) {
        let selectedText = js("getSelectedText()")
        
        setMenuVisible(false)
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
        
        let vc = UIReferenceLibraryViewController(term: selectedText! )
        vc.view.tintColor = readerConfig.tintColor
        FolioReader.sharedInstance.readerContainer.show(vc, sender: nil)
    }
    
    func translate(_ sender: UIMenuController?) {
        let selectedText = js("getSelectedText()")
        let selectedTextRectString = js("getRectForSelectedText()")
        let selectedTextRect = CGRectFromString(selectedTextRectString!)
        let selectedTextSize = Float(js("getFontSize()")!)
        
        setMenuVisible(false)
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
        
        //FolioReader.sharedInstance.readerCenter.presentGoogleTranslate(selectedText!)
        FolioReader.sharedInstance.readerCenter.presentGoogleTranslate(selectedText!, rect: selectedTextRect, fontSize: CGFloat(selectedTextSize!))
    }

    func play(_ sender: UIMenuController?) {
        FolioReader.sharedInstance.readerCenter.currentPage.playAudio()

        // Force remove text selection
        // @NOTE: this doesn't seem to always work
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
    }


    // MARK: - Set highlight styles
    
    func setYellow(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .yellow)
    }
    
    func setGreen(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .green)
    }
    
    func setBlue(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .blue)
    }
    
    func setPink(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .pink)
    }
    
    func setUnderline(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .underline)
    }

    func changeHighlightStyle(_ sender: UIMenuController?, style: HighlightStyle) {
        FolioReader.sharedInstance.currentHighlightStyle = style.rawValue

        if let updateId = js("setHighlightStyle('\(HighlightStyle.classForStyle(style.rawValue))')") {
            Highlight.updateById(updateId, type: style)
        }
        colors(sender)
    }
    
    // MARK: - Create and show menu
    
    func createMenu(options: Bool) {
        isShare = options
        
        let translateItem = UIMenuItem(title: readerConfig.localizedTranslateMenu, action: #selector(UIWebView.translate(_:)))
        
        /*let colors = UIImage(readerImageNamed: "colors-marker")
        let share = UIImage(readerImageNamed: "share-marker")
        let remove = UIImage(readerImageNamed: "no-marker")
        let yellow = UIImage(readerImageNamed: "yellow-marker")
        let green = UIImage(readerImageNamed: "green-marker")
        let blue = UIImage(readerImageNamed: "blue-marker")
        let pink = UIImage(readerImageNamed: "pink-marker")
        let underline = UIImage(readerImageNamed: "underline-marker")
        
        let highlightItem = UIMenuItem(title: readerConfig.localizedHighlightMenu, action: #selector(UIWebView.highlight(_:)))
        let playAudioItem = UIMenuItem(title: readerConfig.localizedPlayMenu, action: #selector(UIWebView.play(_:)))
        let defineItem = UIMenuItem(title: readerConfig.localizedDefineMenu, action: #selector(UIWebView.define(_:)))
        let colorsItem = UIMenuItem(title: "C", image: colors!, action: #selector(UIWebView.colors(_:)))
        let shareItem = UIMenuItem(title: "S", image: share!, action: #selector(UIWebView.share(_:)))
        let removeItem = UIMenuItem(title: "R", image: remove!, action: #selector(UIWebView.remove(_:)))
        let yellowItem = UIMenuItem(title: "Y", image: yellow!, action: #selector(UIWebView.setYellow(_:)))
        let greenItem = UIMenuItem(title: "G", image: green!, action: #selector(UIWebView.setGreen(_:)))
        let blueItem = UIMenuItem(title: "B", image: blue!, action: #selector(UIWebView.setBlue(_:)))
        let pinkItem = UIMenuItem(title: "P", image: pink!, action: #selector(UIWebView.setPink(_:)))
        let underlineItem = UIMenuItem(title: "U", image: underline!, action: #selector(UIWebView.setUnderline(_:)))*/
        
        let menuItems = [translateItem] //[playAudioItem, highlightItem, defineItem, colorsItem, removeItem, yellowItem, greenItem, blueItem, pinkItem, underlineItem, shareItem]

        UIMenuController.shared.menuItems = menuItems
    }
    
    func setMenuVisible(_ menuVisible: Bool, animated: Bool = true, andRect rect: CGRect = CGRect.zero) {
        if !menuVisible && isShare || !menuVisible && isColors {
            isColors = false
            isShare = false
        }
        
        if menuVisible  {
            if !rect.equalTo(CGRect.zero) {
                UIMenuController.shared.setTargetRect(rect, in: self)
            }
        }
        
        UIMenuController.shared.setMenuVisible(menuVisible, animated: animated)
    }
    
    func js(_ script: String) -> String? {
        let callback = self.stringByEvaluatingJavaScript(from: script)
        if callback!.isEmpty { return nil }
        return callback
    }
}

//extension UIMenuItem {
//    convenience init(title: String, image: UIImage, action: Selector) {
//        self.init(title: title, action: action)
//        self.cxa_init(withTitle: title, action: action, image: image, hidesShadow: true)
//    }
//}
