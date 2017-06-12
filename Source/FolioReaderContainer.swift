//
//  FolioReaderContainer.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import FontBlaster

var readerConfig: FolioReaderConfig!
var epubPath: String?
var book: FRBook!

enum SlideOutState {
    case BothCollapsed
    case LeftPanelExpanded
    case Expanding
    
    init () {
        self = .BothCollapsed
    }
}

protocol FolioReaderContainerDelegate {
    /**
    Notifies that the menu was expanded.
    */
    func container(didExpandLeftPanel sidePanel: FolioReaderSidePanel)
    
    /**
    Notifies that the menu was closed.
    */
    func container(didCollapseLeftPanel sidePanel: FolioReaderSidePanel)
    
    /**
    Notifies when the user selected some item on menu.
    */
    func container(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference)
}

class FolioReaderContainer: UIViewController, FolioReaderSidePanelDelegate {
    var delegate: FolioReaderContainerDelegate!
    var centerNavigationController: UINavigationController!
    var centerViewController: FolioReaderCenter!
    var leftViewController: FolioReaderSidePanel!
    var audioPlayer: FolioReaderAudioPlayer!
    var centerPanelExpandedOffset: CGFloat = 70
    var currentState = SlideOutState()
    var shouldHideStatusBar = true
    private var errorOnLoad = false
    private var shouldRemoveEpub = true
    
    var flagForFix = true
    
   // var orientation = UIInterfaceOrientationMask.Landscape
    // MARK: - Init
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(config configOrNil: FolioReaderConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
        readerConfig = configOrNil
        epubPath = epubPathOrNil
        shouldRemoveEpub = removeEpub
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())
        
        // Init with empty book
        book = FRBook()
        
        // Register custom fonts
        FontBlaster.blast(bundle: Bundle.frameworkBundle())
        
        // Register initial defaults
        FolioReader.defaults.register(defaults: [
            kCurrentFontFamily: 0,
            kNightMode: false,
            kCurrentFontSize: 2,
            kCurrentAudioRate: 1,
            kCurrentHighlightStyle: 0,
            kCurrentMediaOverlayStyle: MediaOverlayStyle.default.rawValue
            ])
    }

    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centerViewController = FolioReaderCenter()
        centerViewController.folioReaderContainer = self
        FolioReader.sharedInstance.readerCenter = centerViewController
        
        centerNavigationController = UINavigationController(rootViewController: centerViewController)
        centerNavigationController.setNavigationBarHidden(readerConfig.shouldHideNavigationOnTap, animated: false)
        view.addSubview(centerNavigationController.view)
        addChildViewController(centerNavigationController)
        centerNavigationController.didMove(toParentViewController: self)
        
        // Add gestures
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(FolioReaderContainer.handleTapGesture(recognizer:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        centerNavigationController.view.addGestureRecognizer(tapGestureRecognizer)

        // Read async book
        /**/
        readBook()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showShadowForCenterViewController(shouldShowShadow: true)
        if errorOnLoad {
            dismiss(animated: true, completion: nil)
        } 
    }
    
    func readBook() -> Void {
        if (epubPath != nil) {
            DispatchQueue.global(qos: .userInitiated).async(execute: {
                
                var isDir: ObjCBool = false
                let fileManager = FileManager.default
                
                if fileManager.fileExists(atPath: epubPath!, isDirectory:&isDir) {
                    if isDir.boolValue {
                        book = FREpubParser().readEpub(filePath: epubPath!)
                    } else {
                        book = FREpubParser().readEpub(epubPath: epubPath!, removeEpub: self.shouldRemoveEpub)
                    }
                }
                else {
                    print("Epub file does not exist.")
                    self.errorOnLoad = true
                }
                
                FolioReader.sharedInstance.isReaderOpen = true
                
                if !self.errorOnLoad {
                    // Reload data
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.centerViewController.reloadData()
                        self.addLeftPanelViewController()
                        self.addAudioPlayer()
                        FolioReader.sharedInstance.isReaderReady = true
                    }
                }
            })
        } else {
            print("Epub path is nil.")
            errorOnLoad = true
        }
    }
    
    
    //MARK: Orientation
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.allButUpsideDown
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    
    
    // MARK: CenterViewController delegate methods
    
    func toggleLeftPanel() {
        let notAlreadyExpanded = (currentState != .LeftPanelExpanded)
        
        if notAlreadyExpanded {
            addLeftPanelViewController()
        }
        
        animateLeftPanel(shouldExpand: notAlreadyExpanded)
    }
    
    func collapseSidePanels() {
        switch (currentState) {
        case .LeftPanelExpanded:
            toggleLeftPanel()
        default:
            break
        }
    }
    
    func addLeftPanelViewController() {
        if (leftViewController == nil) {
            leftViewController = FolioReaderSidePanel()
            leftViewController.delegate = self
            
            addChildSidePanelController(sidePanelController: leftViewController!)
            FolioReader.sharedInstance.readerSidePanel = leftViewController
        } else {
            addChildSidePanelController(sidePanelController: leftViewController!)
        }
    }
    
    func addChildSidePanelController(sidePanelController: FolioReaderSidePanel) {
        view.insertSubview(sidePanelController.view, at: 0)
        addChildViewController(sidePanelController)
        sidePanelController.didMove(toParentViewController: self)
    }
    
    func animateLeftPanel(shouldExpand: Bool) {
        if (shouldExpand) {
            
            if let width = pageWidth {
                if isPad {
                    centerPanelExpandedOffset = width-400
                } else {
                    // Always get the device width
                    let w = UIInterfaceOrientationIsPortrait(UIApplication.shared.statusBarOrientation) ? UIScreen.main.bounds.size.width : UIScreen.main.bounds.size.height
                    
                    centerPanelExpandedOffset = width-(w-70)
                }
            }
            
            currentState = .LeftPanelExpanded
            delegate.container(didExpandLeftPanel: leftViewController)
            animateCenterPanelXPosition(targetPosition: centerNavigationController.view.frame.width - centerPanelExpandedOffset)
            
            // Reload to update current reading chapter
            leftViewController.tableView.reloadData()
        } else {
            animateCenterPanelXPosition(targetPosition: 0) { finished in
                self.delegate.container(didCollapseLeftPanel: self.leftViewController)
                self.currentState = .BothCollapsed
            }
        }
    }
    
    func animateCenterPanelXPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseIn, .curveEaseOut], animations: {
            self.centerNavigationController.view.frame.origin.x = targetPosition
            }, completion: completion)
    }
    
    func showShadowForCenterViewController(shouldShowShadow: Bool) {
        if (shouldShowShadow) {
            centerNavigationController.view.layer.shadowOpacity = 0.2
            centerNavigationController.view.layer.shadowRadius = 6
            centerNavigationController.view.layer.shadowPath = UIBezierPath(rect: centerNavigationController.view.bounds).cgPath
            centerNavigationController.view.clipsToBounds = false
        } else {
            centerNavigationController.view.layer.shadowOpacity = 0
            centerNavigationController.view.layer.shadowRadius = 0
        }
    }
    
    func addAudioPlayer(){
        // @NOTE: should the audio player only be initialized if the epub has audio smil?
        audioPlayer = FolioReaderAudioPlayer()

        FolioReader.sharedInstance.readerAudioPlayer = audioPlayer;
    }

    // MARK: Gesture recognizer
    
    func handleTapGesture(recognizer: UITapGestureRecognizer) {
        if currentState == .LeftPanelExpanded {
            toggleLeftPanel()
        }
    }
    
    func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        let gestureIsDraggingFromLeftToRight = (recognizer.velocity(in: view).x > 0)
        
        switch(recognizer.state) {
        case .began:
            if currentState == .BothCollapsed && gestureIsDraggingFromLeftToRight {
                currentState = .Expanding
            }
        case .changed:
            if currentState == .LeftPanelExpanded || currentState == .Expanding && recognizer.view!.frame.origin.x >= 0 {
                recognizer.view!.center.x = recognizer.view!.center.x + recognizer.translation(in: view).x
                recognizer.setTranslation(CGPoint.zero, in: view)
            }
        case .ended:
            if leftViewController != nil {
                let gap = 20 as CGFloat
                let xPos = recognizer.view!.frame.origin.x
                let canFinishAnimation = gestureIsDraggingFromLeftToRight && xPos > gap ? true : false
                animateLeftPanel(shouldExpand: canFinishAnimation)
            }
        default:
            break
        }
    }
    
    // MARK: - Status Bar
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return isNight(.lightContent, .default)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Side Panel delegate
    
    func sidePanel(_ sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: IndexPath, withTocReference reference: FRTocReference) {
        collapseSidePanels()
        delegate.container(sidePanel: sidePanel, didSelectRowAtIndexPath: indexPath as NSIndexPath, withTocReference: reference)
    }
}
