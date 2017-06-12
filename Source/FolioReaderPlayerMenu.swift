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
        return readerConfig.shouldHideNavigationOnTap == true
    }

    // MARK: - SMSegmentView delegate

    func segmentView(_ segmentView: SMSegmentView, didSelectSegmentAtIndex index: Int) {

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
            }
        }
        
        // update the current page style
        if let currentPage = FolioReader.sharedInstance.readerCenter.currentPage {
            _ = currentPage.webView.js("setMediaOverlayStyle(\"\(FolioReader.sharedInstance.currentMediaOverlayStyle.className())\")")
        }
    }

    func closeView() {
        dismiss(animated: true, completion: nil)

        if readerConfig.shouldHideNavigationOnTap == false {
            FolioReader.sharedInstance.readerCenter.showBars()
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


    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
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
