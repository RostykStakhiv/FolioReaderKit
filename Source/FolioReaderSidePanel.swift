//
//  FolioReaderSidePanel.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

@objc
protocol FolioReaderSidePanelDelegate {
    /**
    Notifies when the user selected some item on menu.
    */
    func sidePanel(_ sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: IndexPath, withTocReference reference: FRTocReference)
}

class FolioReaderSidePanel: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var delegate: FolioReaderSidePanelDelegate?
    var tableView: UITableView!
    var toolBar: UIToolbar!
    let toolBarHeight: CGFloat = 50
    var tocItems = [FRTocReference]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var tableViewFrame = screenBounds()
        tableViewFrame.size.height = tableViewFrame.height-toolBarHeight
        
        tableView = UITableView(frame: tableViewFrame)
        tableView.delaysContentTouches = true
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = isNight(readerConfig.nightModeMenuBackground, readerConfig.menuBackgroundColor)
        tableView.separatorColor = isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        toolBar = UIToolbar(frame: CGRect(x: 0, y: screenBounds().height-toolBarHeight, width: view.frame.width, height: toolBarHeight))
        toolBar.autoresizingMask = .flexibleWidth
        toolBar.barTintColor = readerConfig.toolBarBackgroundColor
        toolBar.tintColor = readerConfig.toolBarTintColor
        toolBar.clipsToBounds = true
        toolBar.isTranslucent = false
        view.addSubview(toolBar)
        
        let imageHighlight = UIImage(readerImageNamed: "icon-highlight")
        let imageClose = UIImage(readerImageNamed: "icon-close")
        let imageFont = UIImage(readerImageNamed: "icon-font")
        let space = 70 as CGFloat
        
        let blackImage = UIImage.imageWithColor(UIColor(white: 0, alpha: 0.2))
        let closeButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        closeButton.setImage(imageClose, for: UIControlState())
        closeButton.setBackgroundImage(blackImage, for: UIControlState())
        closeButton.addTarget(self, action: #selector(FolioReaderSidePanel.didSelectClose(_:)), for: UIControlEvents.touchUpInside)
        
        let noSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.fixedSpace, target: nil, action: nil)
        noSpace.width = isPad || isLargePhone ? -20 : -16
        let iconClose = UIBarButtonItem(customView: closeButton)
        
        let iconHighlight = UIBarButtonItem(image: imageHighlight, style: .plain, target: self, action: #selector(FolioReaderSidePanel.didSelectHighlight(_:)))
        iconHighlight.width = space
        
        let iconFont = UIBarButtonItem(image: imageFont, style: .plain, target: self, action: #selector(FolioReaderSidePanel.didSelectFont(_:)))
        iconFont.width = space
        
        //toolBar.setItems([noSpace, iconClose, iconFont, iconHighlight], animated: false)
        toolBar.setItems([noSpace, iconClose], animated: false)

        
        // Register cell classes
        tableView.register(FolioReaderSidePanelCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.separatorInset = UIEdgeInsets.zero
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        
        // Create TOC list
        createTocList()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Recursive add items to a list
    
    func createTocList() {
        for item in book.tableOfContents {
            tocItems.append(item)
            countTocChild(item)
        }
    }
    
    func countTocChild(_ item: FRTocReference) {
        if item.children.count > 0 {
            for item in item.children {
                tocItems.append(item)
            }
        }
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tocItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! FolioReaderSidePanelCell
        
        let tocReference = tocItems[indexPath.row]
        let isSection = tocReference.children.count > 0
        
        cell.indexLabel.text = tocReference.title.trimmingCharacters(in: CharacterSet.whitespaces)
        cell.indexLabel.font = UIFont(name: "Avenir-Light", size: 17)
        cell.indexLabel.textColor = readerConfig.menuTextColor

        if( tocReference.resource.mediaOverlay != nil ){
            let duration = book.durationFor("#"+tocReference.resource.mediaOverlay);
            let durationFormatted = (duration != nil ? duration : "")?.clockTimeToMinutesString()

            cell.indexLabel.text = cell.indexLabel.text! + (duration != nil ? " - "+durationFormatted! : "");
        }

        // Mark current reading chapter
        if let currentPageNumber = currentPageNumber, let reference = book.spine.spineReferences[safe: currentPageNumber-1] {
            let resource = reference.resource
            cell.indexLabel.textColor = tocReference.resource.href == resource?.href ? readerConfig.tintColor : readerConfig.menuTextColor
        }
        
        cell.layoutMargins = UIEdgeInsets.zero
        cell.preservesSuperviewLayoutMargins = false
        cell.contentView.backgroundColor = isSection ? UIColor(white: 0.7, alpha: 0.1) : UIColor.clear
        cell.backgroundColor = UIColor.clear
        
        // Adjust text position
        cell.indexLabel.center = cell.contentView.center
        var frame = cell.indexLabel.frame
        frame.origin = isSection ? CGPoint(x: 40, y: frame.origin.y) : CGPoint(x: 20, y: frame.origin.y)
        cell.indexLabel.frame = frame

        return cell
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tocReference = tocItems[indexPath.row]
        delegate?.sidePanel(self, didSelectRowAtIndexPath: indexPath, withTocReference: tocReference)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Table view data source
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    // MARK: - Get Screen bounds
    
    func screenBounds() -> CGRect {
        return UIScreen.main.bounds
    }
    
    // MARK: - Rotation
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        UIView.animate(withDuration: duration, animations: { () -> Void in
            var frame = self.toolBar.frame
            frame.origin.y = pageHeight-self.toolBarHeight
            self.toolBar.frame = frame
        })
    }
    
    // MARK: - Toolbar actions
    
    func didSelectHighlight(_ sender: UIBarButtonItem) {
        FolioReader.sharedInstance.readerContainer.toggleLeftPanel()
        FolioReader.sharedInstance.readerCenter.presentHighlightsList()
    }
    
    func didSelectClose(_ sender: UIBarButtonItem?) {
        //FolioReader.sharedInstance.readerContainer.orientation = UIInterfaceOrientationMask.Portrait

        self.dismiss(animated: true, completion: {
            FolioReader.sharedInstance.isReaderOpen = false
            FolioReader.sharedInstance.isReaderReady = false
            FolioReader.sharedInstance.readerAudioPlayer.stop()
        })
    }
    
    func didSelectFont(_ sender: UIBarButtonItem) {
        FolioReader.sharedInstance.readerContainer.toggleLeftPanel()
        FolioReader.sharedInstance.readerCenter.presentFontsMenu()
    }

}
