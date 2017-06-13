//
//  FolioReaderFontsMenu.swift
//  FolioReaderKit
//
//  Created by Kevin Jantzer on 1/6/16.
//  Copyright (c) 2016 Folio Reader. All rights reserved.
//

import UIKit
import MBProgressHUD

class FolioReaderPlayerMenu: UIViewController, SMSegmentViewDelegate {

    var dropView: KGDropView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var shareButton: InspectableButton!
    @IBOutlet weak var totalPagesNumberLabel: UILabel!
    
    @IBOutlet weak var quizButton: InspectableButton!
    let bookServices = KGBookServices()
    var menuView: UIView!
    var scrollScruber: ScrollScrubber? = nil
    var playPauseBtn: UIButton!
    var styleOptionBtns = [UIButton]()
    var viewDidAppear = false
    var loadingNotification: MBProgressHUD?

//<<<<<<< HEAD
    
    //MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if FolioReader.sharedInstance.readerCenter.loadingView.isHidden == false {
            
            loadingNotification = MBProgressHUD.showAdded(to: self.view, animated: true)
            loadingNotification?.mode = MBProgressHUDMode.indeterminate
            loadingNotification?.label.text = "Please wait, the book is loading"
        }
       
        dropView = KGDropView(frame: CGRect(x: slider.bounds.origin.x,y: slider.bounds.origin.y,width: 35,height: 40))
        view.addSubview(dropView)

        setSliderUI()
        calculatePositionDropView()
        
        if FolioReader.kgTranslationModel?.amountOfQuestions == 0 {
            quizButton.isHidden = true
        }

        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.clear
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(FolioReaderPlayerMenu.tapGesture))
        tapGestureRecognizer.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGestureRecognizer)

        // get icon images
        let play = UIImage(readerImageNamed: "playAudioButton")
        let pause = UIImage(readerImageNamed: "pauseAudioButton")
        
        playPauseButton.setImage(play, for: UIControlState())
        playPauseButton.setImage(pause, for: .selected)
        playPauseButton.titleLabel!.font = UIFont(name: "Avenir", size: 22)!
        
        
        if FolioReader.sharedInstance.readerAudioPlayer.isPlaying() {
            playPauseButton.isSelected = true
        }
        
//        let tapOnce = UITapGestureRecognizer(target: self, action: #selector(FolioReaderPlayerMenu.prevButtonOncePressed))
//        let tapTwice = UITapGestureRecognizer(target: self, action: #selector(FolioReaderPlayerMenu.prevButtonDoublePressed));
//        
//        tapOnce.numberOfTapsRequired = 1;
//        tapTwice.numberOfTapsRequired = 2;
//        //stops tapOnce from overriding tapTwice
//        tapOnce.require(toFail: tapTwice)
//        
//        prevButton.addGestureRecognizer(tapOnce)
//        prevButton.addGestureRecognizer(tapTwice)

        setTotalPagesNumber()
        setupUIForAuthorizationStatus()
//=======
//    fileprivate var readerConfig: FolioReaderConfig
//    fileprivate var folioReader: FolioReader
//
//    init(folioReader: FolioReader, readerConfig: FolioReaderConfig) {
//        self.readerConfig = readerConfig
//        self.folioReader = folioReader
//
//        super.init(nibName: nil, bundle: nil)
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // Do any additional setup after loading the view.
//        self.view.backgroundColor = UIColor.clear
//
//        // Tap gesture
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(FolioReaderPlayerMenu.tapGesture))
//        tapGesture.numberOfTapsRequired = 1
//        tapGesture.delegate = self
//        view.addGestureRecognizer(tapGesture)
//
//        // Menu view
//        menuView = UIView(frame: CGRect(x: 0, y: view.frame.height-165, width: view.frame.width, height: view.frame.height))
//        menuView.backgroundColor = self.folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white)
//        menuView.autoresizingMask = .flexibleWidth
//        menuView.layer.shadowColor = UIColor.black.cgColor
//        menuView.layer.shadowOffset = CGSize(width: 0, height: 0)
//        menuView.layer.shadowOpacity = 0.3
//        menuView.layer.shadowRadius = 6
//        menuView.layer.shadowPath = UIBezierPath(rect: menuView.bounds).cgPath
//        menuView.layer.rasterizationScale = UIScreen.main.scale
//        menuView.layer.shouldRasterize = true
//        view.addSubview(menuView)
//
//        let normalColor = UIColor(white: 0.5, alpha: 0.7)
//        let selectedColor = self.readerConfig.tintColor
//        let size = 55
//        let padX = 32
//        // @NOTE: could this be improved/simplified with autolayout?
//        let gutterX = (Int(view.frame.width) - (size * 3 ) - (padX * 4) ) / 2
//
//        //let btnX = (Int(view.frame.width) - (size * 3)) / 4
//
//        // get icon images
//        let play = UIImage(readerImageNamed: "play-icon")
//        let pause = UIImage(readerImageNamed: "pause-icon")
//        let prev = UIImage(readerImageNamed: "prev-icon")
//        let next = UIImage(readerImageNamed: "next-icon")
//        let playSelected = play?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
//        let pauseSelected = pause?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
//
//        let prevNormal = prev?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
//        let nextNormal = next?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
//        let prevSelected = prev?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
//        let nextSelected = next?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
//
//        // prev button
//        let prevBtn = UIButton(frame: CGRect(x: gutterX + padX, y: 0, width: size, height: size))
//        prevBtn.setImage(prevNormal, for: UIControlState())
//        prevBtn.setImage(prevSelected, for: .selected)
//        prevBtn.addTarget(self, action: #selector(FolioReaderPlayerMenu.prevChapter(_:)), for: .touchUpInside)
//        menuView.addSubview(prevBtn)
//
//        // play / pause button
//        let playPauseBtn = UIButton(frame: CGRect(x: Int(prevBtn.frame.origin.x) + padX + size, y: 0, width: size, height: size))
//        playPauseBtn.setTitleColor(selectedColor, for: UIControlState())
//        playPauseBtn.setTitleColor(selectedColor, for: .selected)
//        playPauseBtn.setImage(playSelected, for: UIControlState())
//        playPauseBtn.setImage(pauseSelected, for: .selected)
//        playPauseBtn.titleLabel!.font = UIFont(name: "Avenir", size: 22)!
//        playPauseBtn.addTarget(self, action: #selector(FolioReaderPlayerMenu.togglePlay(_:)), for: .touchUpInside)
//        menuView.addSubview(playPauseBtn)
//
//        if let audioPlayer = self.folioReader.readerAudioPlayer , audioPlayer.isPlaying() {
//            playPauseBtn.isSelected = true
//        }
//
//        // next button
//        let nextBtn = UIButton(frame: CGRect(x: Int(playPauseBtn.frame.origin.x) + padX + size, y: 0, width: size, height: size))
//        nextBtn.setImage(nextNormal, for: UIControlState())
//        nextBtn.setImage(nextSelected, for: .selected)
//        nextBtn.addTarget(self, action: #selector(FolioReaderPlayerMenu.nextChapter(_:)), for: .touchUpInside)
//        menuView.addSubview(nextBtn)
//
//
//        // Separator
//        let line = UIView(frame: CGRect(x: 0, y: playPauseBtn.frame.height+playPauseBtn.frame.origin.y, width: view.frame.width, height: 1))
//        line.backgroundColor = self.readerConfig.nightModeSeparatorColor
//        menuView.addSubview(line)
//
//        // audio playback rate adjust
//        let playbackRate = SMSegmentView(frame: CGRect(x: 15, y: line.frame.height+line.frame.origin.y, width: view.frame.width-30, height: 55),
//                                         separatorColour: UIColor.clear,
//                                         separatorWidth: 0,
//                                         segmentProperties:  [
//                                            keySegmentOnSelectionColour: UIColor.clear,
//                                            keySegmentOffSelectionColour: UIColor.clear,
//                                            keySegmentOnSelectionTextColour: selectedColor,
//                                            keySegmentOffSelectionTextColour: normalColor,
//                                            keyContentVerticalMargin: 17 as AnyObject
//            ])
//        playbackRate.delegate = self
//        playbackRate.tag = 2
//        playbackRate.addSegmentWithTitle("½x", onSelectionImage: nil, offSelectionImage: nil)
//        playbackRate.addSegmentWithTitle("1x", onSelectionImage: nil, offSelectionImage: nil)
//        playbackRate.addSegmentWithTitle("1½x", onSelectionImage: nil, offSelectionImage: nil)
//        playbackRate.addSegmentWithTitle("2x", onSelectionImage: nil, offSelectionImage: nil)
//        playbackRate.segmentTitleFont = UIFont(name: "Avenir-Light", size: 17)!
//        playbackRate.selectSegmentAtIndex(Int(self.folioReader.currentAudioRate))
//        menuView.addSubview(playbackRate)
//
//
//        // Separator
//        let line2 = UIView(frame: CGRect(x: 0, y: playbackRate.frame.height+playbackRate.frame.origin.y, width: view.frame.width, height: 1))
//        line2.backgroundColor = self.readerConfig.nightModeSeparatorColor
//        menuView.addSubview(line2)
//
//
//        // Media overlay highlight styles
//        let style0 = UIButton(frame: CGRect(x: 0, y: line2.frame.height+line2.frame.origin.y, width: view.frame.width/3, height: 55))
//        style0.titleLabel!.textAlignment = .center
//        style0.titleLabel!.font = UIFont(name: "Avenir-Light", size: 17)
//        style0.setTitleColor(self.folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white), for: UIControlState())
//        style0.setTitleColor(self.folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white), for: .selected)
//        style0.setTitle(self.readerConfig.localizedPlayerMenuStyle, for: UIControlState())
//        menuView.addSubview(style0);
//        style0.titleLabel?.sizeToFit()
//        let style0Bgd = UIView(frame: style0.titleLabel!.frame)
//        style0Bgd.center = CGPoint(x: style0.frame.size.width  / 2, y: style0.frame.size.height / 2);
//        style0Bgd.frame.size.width += 8
//        style0Bgd.frame.origin.x -= 4
//        style0Bgd.backgroundColor = normalColor;
//        style0Bgd.layer.cornerRadius = 3.0;
//        style0Bgd.isUserInteractionEnabled = false
//        style0.insertSubview(style0Bgd, belowSubview: style0.titleLabel!)
//
//        let style1 = UIButton(frame: CGRect(x: view.frame.width/3, y: line2.frame.height+line2.frame.origin.y, width: view.frame.width/3, height: 55))
//        style1.titleLabel!.textAlignment = .center
//        style1.titleLabel!.font = UIFont(name: "Avenir-Light", size: 17)
//        style1.setTitleColor(normalColor, for: UIControlState())
//        style1.setAttributedTitle(NSAttributedString(string: "Style", attributes: [
//            NSForegroundColorAttributeName: normalColor,
//            NSUnderlineStyleAttributeName: NSUnderlineStyle.patternDot.rawValue|NSUnderlineStyle.styleSingle.rawValue,
//            NSUnderlineColorAttributeName: normalColor
//            ]), for: UIControlState())
//        style1.setAttributedTitle(NSAttributedString(string: self.readerConfig.localizedPlayerMenuStyle, attributes: [
//            NSForegroundColorAttributeName: self.folioReader.isNight(UIColor.white, UIColor.black),
//            NSUnderlineStyleAttributeName: NSUnderlineStyle.patternDot.rawValue|NSUnderlineStyle.styleSingle.rawValue,
//            NSUnderlineColorAttributeName: selectedColor
//            ]), for: .selected)
//        menuView.addSubview(style1);
//
//        let style2 = UIButton(frame: CGRect(x: view.frame.width/1.5, y: line2.frame.height+line2.frame.origin.y, width: view.frame.width/3, height: 55))
//        style2.titleLabel!.textAlignment = .center
//        style2.titleLabel!.font = UIFont(name: "Avenir-Light", size: 17)
//        style2.setTitleColor(normalColor, for: UIControlState())
//        style2.setTitleColor(selectedColor, for: .selected)
//        style2.setTitle(self.readerConfig.localizedPlayerMenuStyle, for: UIControlState())
//        menuView.addSubview(style2);
//
//        // add line dividers between style buttons
//        let style1line = UIView(frame: CGRect(x: style1.frame.origin.x, y: style1.frame.origin.y, width: 1, height: style1.frame.height))
//        style1line.backgroundColor = self.readerConfig.nightModeSeparatorColor
//        menuView.addSubview(style1line)
//        let style2line = UIView(frame: CGRect(x: style2.frame.origin.x, y: style2.frame.origin.y, width: 1, height: style2.frame.height))
//        style2line.backgroundColor = self.readerConfig.nightModeSeparatorColor
//        menuView.addSubview(style2line)
//
//        // select the current style
//        style0.isSelected = (self.folioReader.currentMediaOverlayStyle == .default)
//        style1.isSelected = (self.folioReader.currentMediaOverlayStyle == .underline)
//        style2.isSelected = (self.folioReader.currentMediaOverlayStyle == .textColor)
//        if style0.isSelected { style0Bgd.backgroundColor = selectedColor }
//
//        // hook up button actions
//        style0.tag = MediaOverlayStyle.default.rawValue
//        style1.tag = MediaOverlayStyle.underline.rawValue
//        style2.tag = MediaOverlayStyle.textColor.rawValue
//        style0.addTarget(self, action: #selector(FolioReaderPlayerMenu.changeStyle(_:)), for: .touchUpInside)
//        style1.addTarget(self, action: #selector(FolioReaderPlayerMenu.changeStyle(_:)), for: .touchUpInside)
//        style2.addTarget(self, action: #selector(FolioReaderPlayerMenu.changeStyle(_:)), for: .touchUpInside)
//
//        // store ref to buttons
//        styleOptionBtns.append(style0)
//        styleOptionBtns.append(style1)
//        styleOptionBtns.append(style2)
//>>>>>>> 0eb2770bf10e106fc1d9578dd455aad55bd1f130
    }

    override func viewDidAppear(_ animated: Bool) {
        viewDidAppear = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        viewDidAppear = false
    }
    
    //Set Slider 
    func setSliderUI() {
        // less obtrusive knob and fixes jump: http://stackoverflow.com/a/22301039/484780
        let thumbImg = UIImage(readerImageNamed: "knob")
        let thumbImgColor = thumbImg!.imageTintColor(readerConfig.tintColor).withRenderingMode(.alwaysOriginal)
        slider.setThumbImage(thumbImgColor, for: UIControlState())
        slider.setThumbImage(thumbImgColor, for: .selected)
        slider.setThumbImage(thumbImgColor, for: .highlighted)
        slider.minimumTrackTintColor = readerConfig.tintColor
        slider.maximumTrackTintColor = isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
        setSliderValue()

    }
    
    //
    func hideHUD() {
         loadingNotification?.hide(animated: true)
    }
    
    func setTotalPagesNumber() {
        totalPagesNumberLabel.text = String(FolioReader.sharedInstance.readerCenter.collectionView.numberOfItems(inSection: 0))
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "sQuiz" {
            if let quizVC = segue.destination as? KGQuizVC {
                quizVC.book = FolioReader.kgBookModel
                quizVC.translation = FolioReader.kgTranslationModel
                quizVC.delegate = self
            }
            
        }
    }

    // MARK: - Status Bar

    override var prefersStatusBarHidden : Bool {
        return (self.readerConfig.shouldHideNavigationOnTap == true)
    }

    // MARK: - SMSegmentView delegate

    func segmentView(_ segmentView: SMSegmentView, didSelectSegmentAtIndex index: Int) {
//<<<<<<< HEAD

        if( viewDidAppear != true ){ return }

        let audioPlayer = FolioReader.sharedInstance.readerAudioPlayer

        if segmentView.tag == 2 {
            audioPlayer?.setRate(index)
            FolioReader.sharedInstance.currentAudioRate = index
        }
    }
    
    func changeStyle(_ sender: UIButton!) {
        FolioReader.sharedInstance.currentMediaOverlayStyle = MediaOverlayStyle(rawValue: sender.tag)!
        
        // select the proper style button
        for btn in styleOptionBtns {
            btn.isSelected = btn == sender
            
            if btn.tag == MediaOverlayStyle.default.rawValue {
                btn.subviews.first?.backgroundColor = btn.isSelected ? readerConfig.tintColor : UIColor(white: 0.5, alpha: 0.7)
//=======
//        guard viewDidAppear else { return }
//
//        if let audioPlayer = self.folioReader.readerAudioPlayer, (segmentView.tag == 2) {
//            audioPlayer.setRate(index)
//            self.folioReader.currentAudioRate = index
//        }
//    }
//
//    func prevChapter(_ sender: UIButton!) {
//        self.folioReader.readerAudioPlayer?.playPrevChapter()
//    }
//
//    func nextChapter(_ sender: UIButton!) {
//        self.folioReader.readerAudioPlayer?.playNextChapter()
//    }
//
//    func togglePlay(_ sender: UIButton!) {
//        sender.isSelected = sender.isSelected != true
//        self.folioReader.readerAudioPlayer?.togglePlay()
//        closeView()
//    }
//
//    func changeStyle(_ sender: UIButton!) {
//        self.folioReader.currentMediaOverlayStyle = MediaOverlayStyle(rawValue: sender.tag)!
//
//        // select the proper style button
//        for btn in styleOptionBtns {
//            btn.isSelected = btn == sender
//
//            if btn.tag == MediaOverlayStyle.default.rawValue {
//                btn.subviews.first?.backgroundColor = (btn.isSelected ? self.readerConfig.tintColor : UIColor(white: 0.5, alpha: 0.7))
//>>>>>>> 0eb2770bf10e106fc1d9578dd455aad55bd1f130
            }
        }

        // update the current page style
        if let currentPage = self.folioReader.readerCenter?.currentPage {
            currentPage.webView.js("setMediaOverlayStyle(\"\(self.folioReader.currentMediaOverlayStyle.className())\")")
        }
    }

    func closeView() {
        dismiss(animated: true, completion: nil)

        if (self.readerConfig.shouldHideNavigationOnTap == false) {
            self.folioReader.readerCenter?.showBars()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func backButtonPressed(_ sender: AnyObject) {
        //FolioReader.sharedInstance.readerContainer.orientation = UIInterfaceOrientationMask.Portrait
        
        self.dismiss(animated: true, completion: {
            FolioReader.sharedInstance.isReaderOpen = false
            FolioReader.sharedInstance.isReaderReady = false
            FolioReader.sharedInstance.readerAudioPlayer.stop()
            DispatchQueue.main.async(execute: {
                
                FolioReader.sharedInstance.readerContainer.dismiss(animated: true, completion: nil)
            })
            
            
        })

    }
    @IBAction func playButtonPressed(_ sender: UIButton) {
        sender.isSelected = sender.isSelected != true
        FolioReader.sharedInstance.readerAudioPlayer.togglePlay()
        closeView()
    }
    @IBAction func nextButtonPressed(_ sender: AnyObject) {
        FolioReader.sharedInstance.readerAudioPlayer.playNextChapter()
        setSliderValue()
    }
    @IBAction func prevButtonPressed(_ sender: AnyObject) {
        FolioReader.sharedInstance.readerAudioPlayer.playPrevChapter()
        setSliderValue()

    }
    
//    @IBAction func prevButtonOncePressed(_ sender: AnyObject) {
//        FolioReader.sharedInstance.readerAudioPlayer.stopAndResetCurrentFragment()
//        FolioReader.sharedInstance.readerAudioPlayer.playAudioFromPageBegin()
//    }
    
    // MARK: - slider events
    
    @IBAction func sliderTouchDown(_ slider:UISlider) {
        
    }
    
    @IBAction func sliderTouchUp(_ slider:UISlider) {
//        let contentSize = FolioReader.sharedInstance.readerCenter.collectionView.contentSize
//        let offset = contentSize.width * CGFloat(slider.value)
//        let page = Int(offset / pageWidth)
//        let totalPages = FolioReader.sharedInstance.readerCenter.collectionView.numberOfItemsInSection(0)
//        if page < totalPages {
//            
//            if page > FolioReader.sharedInstance.readerCenter.currentPage.pageNumber {
//                self.nextButtonPressed(nextButton)
//
//            } else if page < FolioReader.sharedInstance.readerCenter.currentPage.pageNumber {
//                self.prevButtonDoublePressed(prevButton)
//            }
//            /*let indexPath = NSIndexPath(forRow: page, inSection: 0)
//            FolioReader.sharedInstance.readerCenter.collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: false)*/
//        }
        //hideAfterDelay()
    }
    
    @IBAction func shareButtonPressed(_ sender: UIButton) {
        let imagePath = FolioReader.sharedInstance.readerCenter.currentPage.webView.js("getPathToFirstImageInChapter()")
        let url = URL(string: imagePath!)
        //url  = url.//stringByDeletingPathExtension];
        let image = UIImage(contentsOfFile: url!.path)

        let textToShare = FolioReader.sharedInstance.readerCenter.currentPage.webView.js("getBodyText()")
        let bookTitle = book.title()
        
        let objectsToShare = [image!, bookTitle!, textToShare!] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        let excludeActivities = [UIActivityType.airDrop,
                                 UIActivityType.print,
                                 UIActivityType.assignToContact,
                                 UIActivityType.saveToCameraRoll,
                                 UIActivityType.addToReadingList,
                                 UIActivityType.postToFlickr,
                                 UIActivityType.postToVimeo,
                                 UIActivityType.message];
        
        activityVC.excludedActivityTypes = excludeActivities;
        activityVC.popoverPresentationController?.sourceView = sender
        self.present(activityVC, animated: true, completion: nil)
    }
    
    @IBAction func quizButtonPressed(_ sender: AnyObject) {
        performSegue(withIdentifier: "sQuiz", sender: self)
    }
    
    @IBAction func sliderChange(_ slider: UISlider) {
        let contentSize = FolioReader.sharedInstance.readerCenter.collectionView.contentSize
        let offset = contentSize.width * CGFloat(slider.value)
        let page = Int(offset / pageWidth)
        let totalPages = FolioReader.sharedInstance.readerCenter.collectionView.numberOfItems(inSection: 0)
        /*if page < totalPages {
            let indexPath = NSIndexPath(forRow: page, inSection: 0)
            FolioReader.sharedInstance.readerCenter.collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: false)
            
            dropView.countLabel.text = String(page + 1)

        }*/
        if page < totalPages {
            
            if page > FolioReader.sharedInstance.readerCenter.currentPage.pageNumber {
                self.nextButtonPressed(nextButton)
                
            } else if page < FolioReader.sharedInstance.readerCenter.currentPage.pageNumber {
                self.prevButtonPressed(prevButton)
            }
            dropView.countLabel.text = String(page + 1)
            /*let indexPath = NSIndexPath(forRow: page, inSection: 0)
             FolioReader.sharedInstance.readerCenter.collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: false)*/
        }

        calculatePositionDropView()
    }
    
    func setSliderValue() {
        let offset = FolioReader.sharedInstance.readerCenter.collectionView.contentOffset
        let currentPage = Int(offset.x / pageWidth)
        let totalPages = FolioReader.sharedInstance.readerCenter.collectionView.numberOfItems(inSection: 0)
        dropView.countLabel.text = String("\(currentPage + 1)")

        slider.value = Float(currentPage) / Float(totalPages - 1)
        calculatePositionDropView()
    }
    
    func calculatePositionDropView() {
        let value = slider.value
        let width = pageWidth - 40;
        
        let x: CGFloat
        if value == 0 {
            x = 20
        } else {
            x = width * CGFloat(value) + 18
        }
        dropView.center = CGPoint(x: x, y: pageHeight - 60)
    }
    
    // MARK: Orientation
    
    override func viewWillTransition(to size: CGSize,
                                    with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        calculatePositionDropView()
    }
    // MARK: - Gestures
    
    func tapGesture() {
        closeView()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer && touch.view == view {
            return true
        }
        return false
    }
    
    //MARK: Private Methods
    private func setupUIForAuthorizationStatus() {
        if KGTokenManager.sharedInstance.userAuthenticated == false {
            self.quizButton.isEnabled = false
        }
    }
}

extension FolioReaderPlayerMenu: KGQuizVCProtocol {
    func openBook() {
    }
    func dismissReader() {
        backButtonPressed(self)
    }
}
