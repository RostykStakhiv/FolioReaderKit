//
//  FolioReaderFontsMenu.swift
//  FolioReaderKit
//
//  Created by Kevin Jantzer on 1/6/16.
//  Copyright (c) 2016 Folio Reader. All rights reserved.
//

import UIKit
import MBProgressHUD

class FolioReaderPlayerMenu: UIViewController, SMSegmentViewDelegate, UIGestureRecognizerDelegate {
    
    //======= Custom Vars =======
    var dropView: KGDropView!
    var loadingNotification: MBProgressHUD?
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var shareButton: InspectableButton!
    @IBOutlet weak var totalPagesNumberLabel: UILabel!
    
    @IBOutlet weak var quizButton: InspectableButton!
    let bookServices = KGBookServices()
    //===========================
    
    var menuView: UIView!
    var playPauseBtn: UIButton!
    var styleOptionBtns = [UIButton]()
    var viewDidAppear = false

    fileprivate var readerConfig: FolioReaderConfig
    fileprivate var folioReader: FolioReader

    init(folioReader: FolioReader, readerConfig: FolioReaderConfig) {
        self.readerConfig = readerConfig
        self.folioReader = folioReader

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //======= Custom Code =======
        if self.folioReader.readerCenter?.loadingView.isHidden == false {
            
            loadingNotification = MBProgressHUD.showAdded(to: self.view, animated: true)
            loadingNotification?.mode = MBProgressHUDMode.indeterminate
            loadingNotification?.label.text = "Please wait, the book is loading"
        }
        
        dropView = KGDropView(frame: CGRect(x: slider.bounds.origin.x,y: slider.bounds.origin.y,width: 35,height: 40))
        view.addSubview(dropView)
        
        setSliderUI()
        calculatePositionDropView()
        
        if self.folioReader.kgTranslationModel?.amountOfQuestions == 0 {
            quizButton.isHidden = true
        }
        //===========================

        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.clear

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(FolioReaderPlayerMenu.tapGesture))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        // Menu view
        menuView = UIView(frame: CGRect(x: 0, y: view.frame.height-165, width: view.frame.width, height: view.frame.height))
        menuView.backgroundColor = self.folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white)
        menuView.autoresizingMask = .flexibleWidth
        menuView.layer.shadowColor = UIColor.black.cgColor
        menuView.layer.shadowOffset = CGSize(width: 0, height: 0)
        menuView.layer.shadowOpacity = 0.3
        menuView.layer.shadowRadius = 6
        menuView.layer.shadowPath = UIBezierPath(rect: menuView.bounds).cgPath
        menuView.layer.rasterizationScale = UIScreen.main.scale
        menuView.layer.shouldRasterize = true
        view.addSubview(menuView)

        let normalColor = UIColor(white: 0.5, alpha: 0.7)
        let selectedColor = self.readerConfig.tintColor
        let size = 55
        let padX = 32
        // @NOTE: could this be improved/simplified with autolayout?
        let gutterX = (Int(view.frame.width) - (size * 3 ) - (padX * 4) ) / 2

        //let btnX = (Int(view.frame.width) - (size * 3)) / 4

        // get icon images
        ////======= Custom Code =======
        let play = UIImage(readerImageNamed: "playAudioButton")
        let pause = UIImage(readerImageNamed: "pauseAudioButton")
        
        playPauseButton.setImage(play, for: UIControlState())
        playPauseButton.setImage(pause, for: .selected)
        playPauseButton.titleLabel!.font = UIFont(name: "Avenir", size: 22)!
        
        
        if let isPlaying = self.folioReader.readerAudioPlayer?.isPlaying() {
            playPauseButton.isSelected = true
        }
        
        setTotalPagesNumber()
        setupUIForAuthorizationStatus()
        //=============================
    }


    override func viewDidAppear(_ animated: Bool) {
        viewDidAppear = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        viewDidAppear = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Status Bar

    override var prefersStatusBarHidden : Bool {
        return (self.readerConfig.shouldHideNavigationOnTap == true)
    }

    // MARK: - SMSegmentView delegate

    func segmentView(_ segmentView: SMSegmentView, didSelectSegmentAtIndex index: Int) {
        guard viewDidAppear else { return }

        if let audioPlayer = self.folioReader.readerAudioPlayer, (segmentView.tag == 2) {
            audioPlayer.setRate(index)
            self.folioReader.currentAudioRate = index
        }
    }

    func prevChapter(_ sender: UIButton!) {
        self.folioReader.readerAudioPlayer?.playPrevChapter()
    }

    func nextChapter(_ sender: UIButton!) {
        self.folioReader.readerAudioPlayer?.playNextChapter()
    }

    func togglePlay(_ sender: UIButton!) {
        sender.isSelected = sender.isSelected != true
        self.folioReader.readerAudioPlayer?.togglePlay()
        closeView()
    }

    func changeStyle(_ sender: UIButton!) {
        self.folioReader.currentMediaOverlayStyle = MediaOverlayStyle(rawValue: sender.tag)!

        // select the proper style button
        for btn in styleOptionBtns {
            btn.isSelected = btn == sender

            if btn.tag == MediaOverlayStyle.default.rawValue {
                btn.subviews.first?.backgroundColor = (btn.isSelected ? self.readerConfig.tintColor : UIColor(white: 0.5, alpha: 0.7))
            }
        }

        // update the current page style
        if let currentPage = self.folioReader.readerCenter?.currentPage {
            currentPage.webView.js("setMediaOverlayStyle(\"\(self.folioReader.currentMediaOverlayStyle.className())\")")
        }
    }

    func closeView() {
        self.dismiss()

        if (self.readerConfig.shouldHideNavigationOnTap == false) {
            self.folioReader.readerCenter?.showBars()
        }
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
    
    //MARK: Custom Added Methods
    func setSliderUI() {
        // less obtrusive knob and fixes jump: http://stackoverflow.com/a/22301039/484780
        let thumbImg = UIImage(readerImageNamed: "knob")
        let thumbImgColor = thumbImg!.imageTintColor(readerConfig.tintColor)?.withRenderingMode(.alwaysOriginal)
        slider.setThumbImage(thumbImgColor, for: UIControlState())
        slider.setThumbImage(thumbImgColor, for: .selected)
        slider.setThumbImage(thumbImgColor, for: .highlighted)
        slider.minimumTrackTintColor = readerConfig.tintColor
        slider.maximumTrackTintColor = self.folioReader.isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
        setSliderValue()
    }
    
    func calculatePositionDropView() {
        if let pageWidth = self.folioReader.readerCenter?.pageWidth,
            let pageHeight = self.folioReader.readerCenter?.pageHeight {
            
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
    }
    
    func setTotalPagesNumber() {
        totalPagesNumberLabel.text = String(describing: self.folioReader.readerCenter?.collectionView.numberOfItems(inSection: 0))
    }
    
    private func setupUIForAuthorizationStatus() {
        if KGTokenManager.sharedInstance.userAuthenticated == false {
            self.quizButton.isEnabled = false
        }
    }
    
    func setSliderValue() {
        if let pageWidth = self.folioReader.readerCenter?.pageWidth,
            let offset = self.folioReader.readerCenter?.collectionView.contentOffset,
            let totalPages = self.folioReader.readerCenter?.collectionView.numberOfItems(inSection: 0) {
            
            let currentPage = Int(offset.x / pageWidth)
            dropView.countLabel.text = String("\(currentPage + 1)")
            slider.value = Float(currentPage) / Float(totalPages - 1)
            calculatePositionDropView()
        }
    }
}
