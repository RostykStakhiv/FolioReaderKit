//
//  FolioReaderCenter.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import ZFDragableModalTransition
import Popover
import AVFoundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


let reuseIdentifier = "Cell"
var isScrolling = false
var recentlyScrolled = false
var recentlyScrolledDelay = 2.0 // 2 second delay until we clear recentlyScrolled
var recentlyScrolledTimer: Timer!
var scrollDirection = ScrollDirection()
var pageWidth: CGFloat!
var pageHeight: CGFloat!
var previousPageNumber: Int!
var currentPageNumber: Int! = 1
var nextPageNumber: Int!
private var tempReference: FRTocReference?

enum ScrollDirection: Int {
    case none
    case right
    case left
    case up
    case down
    
    init() {
        self = .none
    }
}


class ScrollScrubber: NSObject, UIScrollViewDelegate {
    
    var delegate: FolioReaderCenter!
    var showSpeed = 0.6
    var hideSpeed = 0.6
    var hideDelay = 1.0
    
    var visible = false
    var usingSlider = false
    var slider: UISlider!
    var hideTimer: Timer!
    var scrollStart: CGFloat!
    var scrollDelta: CGFloat!
    var scrollDeltaTimer: Timer!
    
    init(frame:CGRect) {
        super.init()
        
        slider = UISlider()
        slider.layer.anchorPoint = CGPoint(x: 0, y: 0)
        //slider.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        slider.frame = frame
        slider.alpha = 0
        
        updateColors()
        
        // less obtrusive knob and fixes jump: http://stackoverflow.com/a/22301039/484780
        let thumbImg = UIImage(readerImageNamed: "knob")
        let thumbImgColor = thumbImg!.imageTintColor(readerConfig.tintColor).withRenderingMode(.alwaysOriginal)
        slider.setThumbImage(thumbImgColor, for: UIControlState())
        slider.setThumbImage(thumbImgColor, for: .selected)
        slider.setThumbImage(thumbImgColor, for: .highlighted)
        
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderChange(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchDown(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchUp(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchUp(_:)), for: .touchUpOutside)
    }
    
    func updateColors() {
        slider.minimumTrackTintColor = readerConfig.tintColor
        slider.maximumTrackTintColor = isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
    }
    
    // MARK: - slider events
    
    func sliderTouchDown(_ slider:UISlider) {
        usingSlider = true
        show()
    }
    
    func sliderTouchUp(_ slider:UISlider) {
        usingSlider = false
        
        /*var contentOffset = scrollView().contentOffset
        contentOffset = CGPointMake(CGFloat(Int(contentOffset.x) / Int(pageWidth) * Int(pageWidth)), contentOffset.y)
        scrollView().setContentOffset(contentOffset, animated: false)*/
        let contentSize = FolioReader.sharedInstance.readerCenter.collectionView.contentSize
        let offset = contentSize.width * CGFloat(slider.value)
        let page = Int(offset / pageWidth)
        let totalPages = FolioReader.sharedInstance.readerCenter.collectionView.numberOfItems(inSection: 0)
        if page < totalPages {
            let indexPath = IndexPath(row: page, section: 0)
            FolioReader.sharedInstance.readerCenter.collectionView.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.right, animated: false)
        }
        //hideAfterDelay()
    }
    
    func sliderChange(_ slider: UISlider) {
        //print("\(slider.value)")
        //let offset = CGPointMake(height() * CGFloat(slider.value) , 0)
        //print("\(offset)")
        //scrollView().setContentOffset(offset, animated: false)
        //FolioReader.sharedInstance.readerCenter.collectionView.
        
        let contentSize = FolioReader.sharedInstance.readerCenter.collectionView.contentSize
        let offset = contentSize.width * CGFloat(slider.value)
        let page = Int(offset / pageWidth)
        let totalPages = FolioReader.sharedInstance.readerCenter.collectionView.numberOfItems(inSection: 0)
        if page < totalPages {
            let indexPath = IndexPath(row: page, section: 0)
            FolioReader.sharedInstance.readerCenter.collectionView.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.right, animated: false)
        }
    }
    
    // MARK: - show / hide
    
    func show() {
        
        cancelHide()
        
        visible = true
        
        if slider.alpha <= 0 {
            UIView.animate(withDuration: showSpeed, animations: {
                
                self.slider.alpha = 1
                
                }, completion: { (Bool) -> Void in
                    self.hideAfterDelay()
            })
        } else {
            slider.alpha = 1
            if usingSlider == false {
                hideAfterDelay()
            }
        }
    }
    
    
    func hide() {
        visible = false
        resetScrollDelta()
        UIView.animate(withDuration: hideSpeed, animations: {
            self.slider.alpha = 0
        })
    }
    
    func hideAfterDelay() {
        cancelHide()
        hideTimer = Timer.scheduledTimer(timeInterval: hideDelay, target: self, selector: #selector(ScrollScrubber.hide), userInfo: nil, repeats: false)
    }
    
    func cancelHide() {
        
        if hideTimer != nil {
            hideTimer.invalidate()
            hideTimer = nil
        }
        
        if visible == false {
            slider.layer.removeAllAnimations()
        }
        
        visible = true
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        if scrollDeltaTimer != nil {
            scrollDeltaTimer.invalidate()
            scrollDeltaTimer = nil
        }
        
        if scrollStart == nil {
            scrollStart = scrollView.contentOffset.x
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if visible && usingSlider == false {
            setSliderVal()
        }
        
        if( slider.alpha > 0 ){
            
            show()
            
        } else if delegate.currentPage != nil && scrollStart != nil {
            scrollDelta = scrollView.contentOffset.x - scrollStart
            
            if scrollDeltaTimer == nil && scrollDelta > (pageWidth * 0.2 ) || (scrollDelta * -1) > (pageWidth * 0.2) {
                show()
                resetScrollDelta()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        resetScrollDelta()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollDeltaTimer = Timer(timeInterval:0.5, target: self, selector: #selector(ScrollScrubber.resetScrollDelta), userInfo: nil, repeats: false)
        RunLoop.current.add(scrollDeltaTimer, forMode: RunLoopMode.commonModes)
    }
    
    
    func resetScrollDelta(){
        if scrollDeltaTimer != nil {
            scrollDeltaTimer.invalidate()
            scrollDeltaTimer = nil
        }
        
        scrollStart = scrollView().contentOffset.x
        scrollDelta = 0
    }
    
    
    func setSliderVal(){
        slider.value = Float(Float(currentPageNumber - 1) / Float(delegate.totalPages - 1))//Float(scrollTop() / height())
        
    }
    
    func setSliderValue() {
        let offset = FolioReader.sharedInstance.readerCenter.collectionView.contentOffset
        let currentPage = Int(offset.x / pageWidth)
        let totalPages = FolioReader.sharedInstance.readerCenter.collectionView.numberOfItems(inSection: 0)
        slider.value = Float(currentPage) / Float(totalPages - 1)
    }
    
    // MARK: - utility methods
    
    fileprivate func scrollView() -> UIScrollView {
        return delegate.currentPage.webView.scrollView
    }
    
    fileprivate func height() -> CGFloat {
        return delegate.currentPage.webView.scrollView.contentSize.width - pageWidth
    }
    
    fileprivate func scrollTop() -> CGFloat {
        return delegate.currentPage.webView.scrollView.contentOffset.x
    }
    
}



class FolioReaderCenter: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, FolioPageDelegate, FolioReaderContainerDelegate {
    /**
     Notifies when the user selected some item on menu.
     */
    func container(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference) {
        let item = findPageByResource(reference)
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: false, completion: { () -> Void in
            self.updateCurrentPage()
        })
        tempReference = reference
    }

    
    fileprivate var isFirstLoad = true
    var collectionView: UICollectionView!
    var loadingView: UIActivityIndicatorView!
    var pages: [String]!
    var totalPages: Int!
    var tempFragment: String?
    var currentPage: FolioReaderPage!
    var folioReaderContainer: FolioReaderContainer!
    var animator: ZFModalTransitionAnimator!
    var pageIndicatorView: FolioReaderPageIndicator!
    var bookShareLink: String?
    var audioPlayer: AVAudioPlayer!
    
    var scrollScrubber: ScrollScrubber!
    
    fileprivate var screenBounds: CGRect!
    fileprivate var pointNow = CGPoint.zero
    fileprivate let pageIndicatorHeight = 20 as CGFloat
    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //playSound()
        screenBounds = UIScreen.main.bounds
        setPageSize(UIApplication.shared.statusBarOrientation)
        
        // Layout
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets.zero
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = UICollectionViewScrollDirection.horizontal
        
        let background = isNight(readerConfig.nightModeBackground, UIColor.white)
        view.backgroundColor = background
        
        // CollectionView
        collectionView = UICollectionView(frame: screenBounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = background
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        view.addSubview(collectionView)
        
        if #available(iOS 10.0, *) {
            collectionView.isPrefetchingEnabled = false
        }
        
        // Register cell classes
        collectionView!.register(FolioReaderPage.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Delegate container
        folioReaderContainer.delegate = self
        totalPages = book.spine.spineReferences.count
        
        // Configure navigation bar and layout
        automaticallyAdjustsScrollViewInsets = false
        extendedLayoutIncludesOpaqueBars = true
        configureNavBar()
        
        // Page indicator view
        pageIndicatorView = FolioReaderPageIndicator(frame: CGRect(x: 0, y: view.frame.height-pageIndicatorHeight, width: view.frame.width, height: pageIndicatorHeight))
        //view.addSubview(pageIndicatorView)
        
        //let scrubberY: CGFloat = readerConfig.shouldHideNavigationOnTap == true ? 50 : 74
        scrollScrubber = ScrollScrubber(frame: CGRect(x: 40, y: pageHeight - 40, width: pageWidth - 80, height: 40))
        scrollScrubber.delegate = self
        //view.addSubview(scrollScrubber.slider)
        
        // Loading indicator
        let style: UIActivityIndicatorViewStyle = isNight(.white, .gray)
        loadingView = UIActivityIndicatorView(activityIndicatorStyle: style)
        loadingView.center = view.center
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        view.addSubview(loadingView)
       
        //BAD BAD BAD
        presentPlayerMenu(false)
    }
    
    func playSound() {
        let path = Bundle.main.path(forResource: "1.mp3", ofType:nil)!
        let url = URL(fileURLWithPath: path)
        
        do {
            let sound = try AVAudioPlayer(contentsOf: url)
            audioPlayer = sound
            audioPlayer.numberOfLoops = -1
            audioPlayer.play()
        } catch {
            // couldn't load file :(
        }
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reset load
        //isFirstLoad = true
        
        // Update pages
        pagesForCurrentPage(currentPage)
        pageIndicatorView.reloadView(updateShadow: true)
        //reloadData()
    }

    func configureNavBar() {
        //let navBackground = isNight(readerConfig.nightModeMenuBackground, UIColor.whiteColor())
        //let tintColor = readerConfig.tintColor
        //let navText = isNight(UIColor.whiteColor(), UIColor.blackColor())
        //let font = UIFont(name: "Avenir-Light", size: 17)!
        //setTranslucentNavigation(color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
    }
    
    func configureNavBarButtons() {

        // Navbar buttons
        let shareIcon = UIImage(readerImageNamed: "btn-navbar-share")!.imageTintColor(readerConfig.tintColor).withRenderingMode(.alwaysOriginal)
        let audioIcon = UIImage(readerImageNamed: "man-speech-icon")!.imageTintColor(readerConfig.tintColor).withRenderingMode(.alwaysOriginal)
        let menuIcon = UIImage(readerImageNamed: "btn-navbar-menu")!.imageTintColor(readerConfig.tintColor).withRenderingMode(.alwaysOriginal)
        

        navigationItem.leftBarButtonItem = UIBarButtonItem(image: menuIcon, style: UIBarButtonItemStyle.plain, target: self, action:#selector(FolioReaderCenter.toggleMenu(_:)))

        var rightBarIcons = [UIBarButtonItem]()

        if readerConfig.allowSharing {
            rightBarIcons.append(UIBarButtonItem(image: shareIcon, style: UIBarButtonItemStyle.plain, target: self, action:#selector(FolioReaderCenter.shareChapter(_:))))
        }

        if book.hasAudio() /*|| readerConfig.enableTTS*/ {
            rightBarIcons.append(UIBarButtonItem(image: audioIcon, style: UIBarButtonItemStyle.plain, target: self, action:#selector(FolioReaderCenter.togglePlay(_:))))
        }

        navigationItem.rightBarButtonItems = rightBarIcons
    }

    func reloadData() {
        loadingView.stopAnimating()
        bookShareLink = readerConfig.localizedShareWebLink
        totalPages = book.spine.spineReferences.count

        collectionView.reloadData()
        if let audioPlayerMenu = self.presentedViewController as? FolioReaderPlayerMenu {
            audioPlayerMenu.view.isUserInteractionEnabled = true
            audioPlayerMenu.hideHUD()
            audioPlayerMenu.setTotalPagesNumber()
            
        }
        configureNavBarButtons()
        
       /* if let position = FolioReader.defaults.valueForKey(kBookId) as? NSDictionary,
            let pageNumber = position["pageNumber"] as? Int where pageNumber > 0 {
            changePageWith(page: pageNumber)
            currentPageNumber = pageNumber
            return
        }*/
        
        currentPageNumber = 1
    }
    
    // MARK: Status bar and Navigation bar
    
    func hideBars() {

        if readerConfig.shouldHideNavigationOnTap == false { return }

        let shouldHide = true
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = true
        
        UIView.animate(withDuration: 0.25, animations: {
            FolioReader.sharedInstance.readerContainer.setNeedsStatusBarAppearanceUpdate()
            
            // Show minutes indicator
//            self.pageIndicatorView.minutesLabel.alpha = 0
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }
    
    func showBars() {
        configureNavBar()
        
        let shouldHide = false
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = true
        
        UIView.animate(withDuration: 0.25, animations: {
            FolioReader.sharedInstance.readerContainer.setNeedsStatusBarAppearanceUpdate()
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }
    
    func toggleBars() {
        if readerConfig.shouldHideNavigationOnTap == false { return }
        
        let shouldHide = !navigationController!.isNavigationBarHidden
        if !shouldHide { configureNavBar() }
        
        FolioReader.sharedInstance.readerContainer.shouldHideStatusBar = true
        
        UIView.animate(withDuration: 0.25, animations: {
            FolioReader.sharedInstance.readerContainer.setNeedsStatusBarAppearanceUpdate()
            
            // Show minutes indicator
//            self.pageIndicatorView.minutesLabel.alpha = shouldHide ? 0 : 1
        })
        navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }

    func togglePlay(_ sender: UIBarButtonItem) {
        presentPlayerMenu(true)
    }

    // MARK: Toggle menu
    
    func toggleMenu(_ sender: UIBarButtonItem) {
        FolioReader.sharedInstance.readerContainer.toggleLeftPanel()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalPages
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FolioReaderPage
        //cell.webView.loadRequest(NSURLRequest(URL: NSURL(string: "about:blank")!))
        cell.pageNumber = indexPath.row+1
        cell.webView.scrollView.delegate = self
        cell.delegate = self
        cell.backgroundColor = UIColor.clear
        
        // Configure the cell
        let resource = book.spine.spineReferences[indexPath.row].resource
        var html = try? String(contentsOfFile: resource!.fullHref, encoding: String.Encoding.utf8)
        let mediaOverlayStyleColors = "\"\(readerConfig.mediaOverlayColor.hexString(false))\", \"\(readerConfig.mediaOverlayColor.highlightColor().hexString(false))\""

        // Inject CSS
        let jsFilePath = Bundle.frameworkBundle().path(forResource: "Bridge", ofType: "js")
        let cssFilePath = Bundle.frameworkBundle().path(forResource: "Style", ofType: "css")
        let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
        let jsTag = "<script type=\"text/javascript\" src=\"\(jsFilePath!)\"></script>" +
                    "<script type=\"text/javascript\">setMediaOverlayStyleColors(\(mediaOverlayStyleColors))</script>"
        
        let toInject = "\n\(cssTag)\n\(jsTag)\n</head>"
        html = html?.replacingOccurrences(of: "</head>", with: toInject)
        
        // Font class name
        var classes = ""
        let currentFontName = FolioReader.sharedInstance.currentFontName
        switch currentFontName {
        case 0:
            classes = "andada"
            break
        case 1:
            classes = "lato"
            break
        case 2:
            classes = "lora"
            break
        case 3:
            classes = "raleway"
            break
        default:
            break
        }
        
        classes += " "+FolioReader.sharedInstance.currentMediaOverlayStyle.className()
        
        // Night mode
        if (FolioReader.sharedInstance.nightMode == nil) {
            classes += " nightMode"
        }
        
        // Font Size
        let currentFontSize = FolioReader.sharedInstance.currentFontSize
        switch currentFontSize {
        case 0:
            classes += " textSizeOne"
            break
        case 1:
            classes += " textSizeTwo"
            break
        case 2:
            classes += " textSizeThree"
            break
        case 3:
            classes += " textSizeFour"
            break
        case 4:
            classes += " textSizeFive"
            break
        default:
            break
        }
        
        html = html?.replacingOccurrences(of: "<html ", with: "<html class=\"\(classes)\"")
        
        cell.loadHTMLString(html, baseURL: URL(fileURLWithPath: resource!.fullHref!).deletingLastPathComponent())
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: pageWidth, height: pageHeight)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let layout =  collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        if size.height > size.width {
            setPageSize(UIInterfaceOrientation.portrait)
        } else {
            setPageSize(UIInterfaceOrientation.landscapeLeft)
        }
        layout.itemSize = CGSize(width: pageWidth, height: pageHeight)
        
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.contentSize = CGSize(width: pageWidth * CGFloat(self.totalPages), height: pageHeight)
        collectionView.setContentOffset(CGPoint(x: CGFloat(currentPageNumber - 1) * pageWidth, y: pageHeight), animated: false)
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FolioReaderPage
//        cell.webView.loadRequest(URLRequest(url: URL(string: "")!))
//        cell.webView.delegate = nil
//        URLCache.shared.removeAllCachedResponses()
//        URLCache.shared.diskCapacity = 0
//        URLCache.shared.memoryCapacity = 0
//        cell.webView.removeFromSuperview()
    }
    
    // MARK: - Device rotation
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        setPageSize(toInterfaceOrientation)
        updateCurrentPage()
        
        var pageIndicatorFrame = pageIndicatorView.frame
        pageIndicatorFrame.origin.y = pageHeight-pageIndicatorHeight
        pageIndicatorFrame.origin.x = 0
        pageIndicatorFrame.size.width = pageWidth
        
        var scrollScrubberFrame = scrollScrubber.slider.frame;
        scrollScrubberFrame.origin.x = pageWidth + 10
        scrollScrubberFrame.size.height = pageHeight - 100
        
        UIView.animate(withDuration: duration, animations: {
            
            // Adjust page indicator view
            self.pageIndicatorView.frame = pageIndicatorFrame
            self.pageIndicatorView.reloadView(updateShadow: true)
            
            // adjust scroll scrubber slider
            self.scrollScrubber.slider.frame = scrollScrubberFrame
            
            // Adjust collectionView
            self.collectionView.contentSize = CGSize(width: pageWidth, height: pageHeight * CGFloat(self.totalPages))
            //self.collectionView.setContentOffset(self.frameForPage(currentPageNumber).origin, animated: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        // Update pages
        pagesForCurrentPage(currentPage)
        
        scrollScrubber.setSliderVal()
    }
    
    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        if currentPageNumber+1 >= totalPages {
            UIView.animate(withDuration: duration, animations: {
                //self.collectionView.setContentOffset(self.frameForPage(currentPageNumber).origin, animated: false)
            })
        }
    }
    
    
    // MARK: - Page
    
    func setPageSize(_ orientation: UIInterfaceOrientation) {
        if orientation.isPortrait {
            if screenBounds.size.width < screenBounds.size.height {
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height
            } else {
                pageWidth = screenBounds.size.height
                pageHeight = screenBounds.size.width
            }
        } else {
            if screenBounds.size.width > screenBounds.size.height {
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height
            } else {
                pageWidth = screenBounds.size.height
                pageHeight = screenBounds.size.width
            }
        }
    }
    
    func updateCurrentPage(_ completion: (() -> Void)? = nil) {
        updateCurrentPage(nil) { () -> Void in
            if (completion != nil) { completion!() }
        }
    }
    
    func updateCurrentPage(_ page: FolioReaderPage!, completion: (() -> Void)? = nil) {
        if let page = page {
            currentPage = page
            previousPageNumber = page.pageNumber-1
            currentPageNumber = page.pageNumber
            print("\(currentPageNumber)")
        } else {
            let currentIndexPath = getCurrentIndexPath()
            
            if let page = collectionView.cellForItem(at: currentIndexPath) as? FolioReaderPage
 {
                currentPage = page
            }
            
            let curPageNum = currentIndexPath.row+1
            print("new current page = \(curPageNum)")
            print("old current page = \(currentPageNumber)")

            //Play audio if page was changed
            if currentPageNumber != curPageNum {
                if FolioReader.sharedInstance.readerAudioPlayer.isPlaying() {
                    FolioReader.sharedInstance.readerAudioPlayer.playAudio()

                }
            }
            previousPageNumber = currentIndexPath.row
            currentPageNumber = currentIndexPath.row+1
        }
        nextPageNumber = currentPageNumber+1 <= totalPages ? currentPageNumber+1 : currentPageNumber
        
        // Set navigation title
        if let chapterName = getCurrentChapterName() {
            title = chapterName
        } else { title = ""}
        
        // Set pages
        if let page = currentPage {
            page.webView.becomeFirstResponder()
           
            scrollScrubber.setSliderVal()
            if let audioPlayerMenu = self.presentedViewController as? FolioReaderPlayerMenu {
                audioPlayerMenu.setSliderValue()
            }
            
            if let readingTime = page.webView.js("getReadingTime()") {
                pageIndicatorView.totalMinutes = Int(readingTime)!
                pagesForCurrentPage(page)
            }
        }
        
        if (completion != nil) { completion!() }
    }
    
    func pagesForCurrentPage(_ page: FolioReaderPage?) {
        if let page = page {
            pageIndicatorView.totalPages = Int(ceil(page.webView.scrollView.contentSize.width/pageWidth))
            let webViewPage = pageForOffset(currentPage.webView.scrollView.contentOffset.x, pageHeight: pageWidth)
            pageIndicatorView.currentPage = webViewPage
        }
    }
    
    func pageForOffset(_ offset: CGFloat, pageHeight height: CGFloat) -> Int {
        let page = Int(ceil(offset / height))+1
        return page
    }
    
    func getCurrentIndexPath() -> IndexPath {
        let state = UIApplication.shared.applicationState

        if state != UIApplicationState.active {
            let indexPaths = collectionView.indexPathsForVisibleItems
            var indexPath = IndexPath()
            
            if indexPaths.count > 1 {
                let first = indexPaths.first! as IndexPath
                let last = indexPaths.last! as IndexPath
                
                switch scrollDirection {
                case .left:
                    if (first as NSIndexPath).compare(last) == ComparisonResult.orderedAscending {
                        indexPath = first
                    } else {
                        indexPath = last
                    }
                default:
                    if (first as NSIndexPath).compare(last) == ComparisonResult.orderedAscending {
                        indexPath = last
                    } else {
                        indexPath = first
                    }
                    
                }
            } else {
                indexPath = indexPaths.last ?? IndexPath(row: 0, section: 0)
            }
            
            return indexPath

        } else {
            
            let curPageNumber = collectionView.contentOffset.x / pageWidth
            let currentIndexPath = IndexPath(item: Int(curPageNumber), section: 0)
            return currentIndexPath
        }
    }
    
    func frameForPage(_ page: Int) -> CGRect {
        return CGRect(x: 0, y: pageHeight, width: pageWidth * CGFloat(page-1), height: pageHeight)
    }
    
    func changePageWith(page: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        if page > 0 && page-1 < totalPages {
            let indexPath = IndexPath(row: page-1, section: 0)
            changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    if (completion != nil) { completion!() }
                })
            })
        }
    }
    
    func changePageWith(page: Int, andFragment fragment: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        if currentPageNumber == page {
            if fragment != "" && currentPage != nil {
                currentPage.handleAnchor(fragment, avoidBeginningAnchors: true, animating: animated)
                if (completion != nil) { completion!() }
            }
        } else {
            tempFragment = fragment
            changePageWith(page: page, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    if (completion != nil) { completion!() }
                })
            })
        }
    }
    
    func changePageWith(href: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        let item = findPageByHref(href)
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
            self.updateCurrentPage({ () -> Void in
                if (completion != nil) { completion!() }
            })
        })
    }

    func changePageWith(href: String, andAudioMarkID markID: String) {
        print("changePageWith \(recentlyScrolled)")
        if recentlyScrolled { return } // if user recently scrolled, do not change pages or scroll the webview

        let item = findPageByHref(href)
        let pageUpdateNeeded = item+1 != currentPage.pageNumber
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: true) { () -> Void in
            if pageUpdateNeeded {
                self.updateCurrentPage({ () -> Void in
                    DispatchQueue.main.async(execute: {
                        self.currentPage.audioMarkID(markID)
                    })
                })
            } else {
                self.currentPage.audioMarkID(markID);
            }
        }
    }

    func changePageWith(indexPath: IndexPath, animated: Bool = false, completion: (() -> Void)? = nil) {
        //print("changePageWith = \(indexPath)")
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
            //print("Row = \(indexPath.row)")
            self.collectionView.scrollToItem(at: indexPath, at: .right, animated: false)
            }) { (finished: Bool) -> Void in
                if (completion != nil) { completion!() }
        }
    }
    
    func isLastPage() -> Bool{
        return currentPageNumber == nextPageNumber
    }

    func changePageToNext(_ completion: (() -> Void)? = nil) {
        changePageWith(page: nextPageNumber, animated: true) { () -> Void in
            if (completion != nil) { completion!() }
        }
    }
    
    func changePageToPrevious(_ completion: (() -> Void)? = nil) {
        changePageWith(page: previousPageNumber, animated: true) { () -> Void in
            if (completion != nil) { completion!() }
        }
    }

    /**
    Find a page by FRTocReference.
    */
    func findPageByResource(_ reference: FRTocReference) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if item.resource.href == reference.resource.href {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
    Find a page by href.
    */
    func findPageByHref(_ href: String) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if item.resource.href == href {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
    Find and return the current chapter resource.
    */
    func getCurrentChapter() -> FRResource? {
        if let currentPageNumber = currentPageNumber {
            for item in FolioReader.sharedInstance.readerSidePanel.tocItems {
                if let reference = book.spine.spineReferences[safe: currentPageNumber-1],
                    item.resource.href == reference.resource.href {
                    return item.resource
                }
            }
        }
        return nil
    }

    /**
     Find and return the current chapter name.
     */
    func getCurrentChapterName() -> String? {
        if let currentPageNumber = currentPageNumber {
            if FolioReader.sharedInstance.readerSidePanel != nil {
                for item in FolioReader.sharedInstance.readerSidePanel.tocItems {
                    if let reference = book.spine.spineReferences[safe: currentPageNumber-1], item.resource.href == reference.resource.href {
                        if let title = item.title {
                            return title
                        }
                        return nil
                    }
                }
            }
           
        }
        return nil
    }
    
    // MARK: - Audio Playing

    func playAudio(_ fragmentID: String){
        let chapter = getCurrentChapter()
        let href = chapter != nil ? chapter!.href : "";
        FolioReader.sharedInstance.readerAudioPlayer.playAudio(href!, fragmentID: fragmentID)
    }

    func audioMark(href: String, fragmentID: String) {
        changePageWith(href: href, andAudioMarkID: fragmentID)
    }

    // MARK: - Sharing
    
    /**
    Sharing chapter method.
    */
    func shareChapter(_ sender: UIBarButtonItem) {
        
        if let chapterText = currentPage.webView.js("getBodyText()") {
            
            let htmlText = chapterText.replacingOccurrences(of: "[\\n\\r]+", with: "<br />", options: .regularExpression)

            var subject = readerConfig.localizedShareChapterSubject
            var html = ""
            var text = ""
            var bookTitle = ""
            var chapterName = ""
            var authorName = ""
            
            // Get book title
            if let title = book.title() {
                bookTitle = title
                subject += " “\(title)”"
            }
            
            // Get chapter name
            if let chapter = getCurrentChapterName() {
                chapterName = chapter
            }
            
            // Get author name
            if let author = book.metadata.creators.first {
                authorName = author.name
            }
            
            // Sharing html and text
            html = "<html><body>"
            html += "<br /><hr> <p>\(htmlText)</p> <hr><br />"
            html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
            html += "<b>\(bookTitle)</b><br />"
            html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
            if (bookShareLink != nil) { html += "<a href=\"\(bookShareLink!)\">\(bookShareLink!)</a>" }
            html += "</center></body></html>"
            text = "\(chapterName)\n\n“\(chapterText)” \n\n\(bookTitle) \nby \(authorName)"
            if (bookShareLink != nil) { text += " \n\(bookShareLink!)" }
            
            
            let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
            let shareItems = [act, ""] as [Any]
            let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToVimeo, UIActivityType.postToFacebook]
            
            // Pop style on iPad
            if let actv = activityViewController.popoverPresentationController {
                actv.barButtonItem = sender
            }
            
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    /**
    Sharing highlight method.
    */
    func shareHighlight(_ string: String, rect: CGRect) {
        
        var subject = readerConfig.localizedShareHighlightSubject
        var html = ""
        var text = ""
        var bookTitle = ""
        var chapterName = ""
        var authorName = ""
        
        // Get book title
        if let title = book.title() {
            bookTitle = title
            subject += " “\(title)”"
        }
        
        // Get chapter name
        if let chapter = getCurrentChapterName() {
            chapterName = chapter
        }
        
        // Get author name
        if let author = book.metadata.creators.first {
            authorName = author.name
        }
        
        // Sharing html and text
        html = "<html><body>"
        html += "<br /><hr> <p>\(chapterName)</p>"
        html += "<p>\(string)</p> <hr><br />"
        html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
        html += "<b>\(bookTitle)</b><br />"
        html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
        if (bookShareLink != nil) { html += "<a href=\"\(bookShareLink!)\">\(bookShareLink!)</a>" }
        html += "</center></body></html>"
        text = "\(chapterName)\n\n“\(string)” \n\n\(bookTitle) \nby \(authorName)"
        if (bookShareLink != nil) { text += " \n\(bookShareLink!)" }
        
        
        let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
        let shareItems = [act, ""] as [Any]
        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToVimeo, UIActivityType.postToFacebook]
        
        // Pop style on iPad
        if let actv = activityViewController.popoverPresentationController {
            actv.sourceView = currentPage
            actv.sourceRect = rect
        }
        
        present(activityViewController, animated: true, completion: nil)
    }
    
    // MARK: - Folio Page Delegate
    
    func pageDidLoad(_ page: FolioReaderPage) {
        print("\(self)")
        if let position = FolioReader.defaults.value(forKey: kBookId) as? NSDictionary,
            let pageNumber = position["pageNumber"] as? Int,
            let pageOffset = position["pageOffset"] as? CGFloat {
            
            if isFirstLoad {
                updateCurrentPage(page)
                isFirstLoad = false
                
                if currentPageNumber == pageNumber && pageOffset > 0 {
                    page.scrollPageToOffset("\(pageOffset)", animating: false)
                }
            }
            
        } else if isFirstLoad {
            updateCurrentPage(page)
            isFirstLoad = false
        }
        
        // Go to fragment if needed
        if let fragment = tempFragment, fragment != "" && currentPage != nil {
            currentPage.handleAnchor(fragment, avoidBeginningAnchors: true, animating: true)
            tempFragment = nil
        }
    }
    
    // MARK: - ScrollView Delegate
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
        clearRecentlyScrolled()
        recentlyScrolled = true
        pointNow = scrollView.contentOffset
        
        if let currentPage = currentPage {
            currentPage.webView.createMenu(options: true)
            currentPage.webView.setMenuVisible(false)
        }
        
        scrollScrubber.scrollViewWillBeginDragging(scrollView)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        if !navigationController!.isNavigationBarHidden {
            toggleBars()
        }
        
        scrollScrubber.scrollViewDidScroll(scrollView)
        
        // Update current reading page
        if scrollView is UICollectionView {
        } else {
            if let page = currentPage, page.webView.scrollView.contentOffset.x + pageWidth <= page.webView.scrollView.contentSize.width {
                let webViewPage = pageForOffset(page.webView.scrollView.contentOffset.x, pageHeight: pageWidth)
                if pageIndicatorView.currentPage != webViewPage {
                    pageIndicatorView.currentPage = webViewPage
                    currentPage.playAudio()
                }
            }
        }
        
        scrollDirection = scrollView.contentOffset.x < pointNow.x ? .left : .right
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrolling = false
        recentlyScrolled = false
        if scrollView is UICollectionView {
            if totalPages > 0 {
                self.updateCurrentPage({
                })
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        recentlyScrolledTimer = Timer(timeInterval:recentlyScrolledDelay, target: self, selector: #selector(FolioReaderCenter.clearRecentlyScrolled), userInfo: nil, repeats: false)
        RunLoop.current.add(recentlyScrolledTimer, forMode: RunLoopMode.commonModes)
    }

    func clearRecentlyScrolled(){
        if( recentlyScrolledTimer != nil ){
            recentlyScrolledTimer.invalidate()
            recentlyScrolledTimer = nil
        }
        recentlyScrolled = false
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollScrubber.scrollViewDidEndScrollingAnimation(scrollView)
    }
    
    // MARK: - Container delegate
    
    func container(didExpandLeftPanel sidePanel: FolioReaderSidePanel) {
        collectionView.isUserInteractionEnabled = false
        FolioReader.saveReaderState()
    }
    
    func container(didCollapseLeftPanel sidePanel: FolioReaderSidePanel) {
        collectionView.isUserInteractionEnabled = true
        updateCurrentPage()
        
        // Move to #fragment
        if tempReference != nil {
            if tempReference!.fragmentID != "" && currentPage != nil {
                currentPage.handleAnchor(tempReference!.fragmentID!, avoidBeginningAnchors: true, animating: true)
            }
            tempReference = nil
        }
    }
    
    // MARK: - Fonts Menu
    
    func presentFontsMenu() {
        hideBars()
        
        let menu = FolioReaderFontsMenu()
        menu.modalPresentationStyle = .custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = false
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        menu.transitioningDelegate = animator
        present(menu, animated: true, completion: nil)
    }
    
    // MARK: - Highlights List
    
    func presentHighlightsList() {
        let menu = UINavigationController(rootViewController: FolioReaderHighlightList())
        present(menu, animated: true, completion: nil)
    }


    // MARK: - Audio Player Menu

    func presentPlayerMenu(_ enable: Bool) {
        hideBars()
        
        let storyboard = UIStoryboard(name: "FolioReader", bundle: nil)
        let playerMenu = storyboard.instantiateViewController(withIdentifier: "FolioReaderPlayerMenu") as! FolioReaderPlayerMenu
        playerMenu.modalPresentationStyle = .custom

        animator = ZFModalTransitionAnimator(modalViewController: playerMenu)
        animator.isDragable = true
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        playerMenu.transitioningDelegate = animator
        present(playerMenu, animated: true) {
            playerMenu.view.isUserInteractionEnabled = enable
        }
    }
    
    func presentGoogleTranslate(_ text: String, rect: CGRect, fontSize: CGFloat) {
        hideBars()
        
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            //Magic: make frame for popup
            let minWidth: CGFloat = 70
            let maxWidth: CGFloat = pageWidth - minWidth
            let minHeight: CGFloat = 70
            
            let font = UIFont.systemFont(ofSize: 11)
            var width = text.widthWithConstrainedHeight(10, font: font)
            
            var rect = CGSize.zero
            if width > maxWidth {
                width = maxWidth
            } else {
                if width < minWidth {
                    width = minWidth * 2
                }
            }
            var height = text.heightWithConstrainedWidth(width, font: font)
            if height < minHeight {
                height = minHeight
            }
            
            height = height * 2
            
            rect = CGSize(width: width, height: height)
            
            let frame = UIMenuController.shared.menuFrame
            
            var y = frame.origin.y + frame.size.height - height
            if y < 0 {
                y = frame.origin.y
            } else if y > pageHeight {
                y = pageHeight - height
            }
            
            let startPoint = CGPoint(x: frame.origin.x, y: y)
            let aView = KGGoogleTranslateView(frame:CGRect(x: 0,y: 0,width: rect.width,height: rect.height))
            aView.sourceText = text
            aView.translate()
            
            let popover = Popover()
            popover.arrowSize = CGSize.zero;
            popover.show(aView, point: startPoint)
        } else {
            let titleButton = "LANGUAGEAG"
            let addHeight = titleButton.heightWithConstrainedWidth(200, font: UIFont.systemFont(ofSize: fontSize))
            var minWidth = titleButton.widthWithConstrainedHeight(addHeight, font: UIFont.systemFont(ofSize: fontSize))
            minWidth = minWidth + 14 >= rect.size.width ? minWidth + 14 : rect.size.width + 8
            let newRect = CGRect(x: 0, y: 0, width: minWidth, height: (rect.size.height + addHeight + 20) * 2)
            let frame = UIMenuController.shared.menuFrame
            
            var y = frame.origin.y + frame.size.height - (rect.size.height + addHeight * 2)
            if y < 0 {
                y = frame.origin.y
            } else if y > pageHeight {
                y = pageHeight - (rect.size.height + addHeight * 2)
            }
            
            let startPoint = CGPoint(x: frame.origin.x, y: y)
            let aView = KGGoogleTranslateView(frame:newRect)
            aView.sourceText = text
            aView.sourceTextView.font = UIFont.systemFont(ofSize: fontSize)
            aView.targetTextView.font = UIFont.systemFont(ofSize: fontSize)
            
            aView.sourceLanguageButton.titleLabel?.font = UIFont.systemFont(ofSize: fontSize)
            aView.targetLanguageButton.titleLabel?.font = UIFont.systemFont(ofSize: fontSize)
            
            aView.translate()
            
            let popover = Popover()
            popover.arrowSize = CGSize.zero;
            popover.show(aView, point: startPoint)        }
    }
}
