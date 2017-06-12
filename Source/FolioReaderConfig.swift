//
//  FolioReaderConfig.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

open class FolioReaderConfig: NSObject {
    // Reader Colors
    open var tintColor: UIColor!
    open lazy var toolBarBackgroundColor: UIColor! = self.tintColor
    open var toolBarTintColor: UIColor!
    open var menuBackgroundColor: UIColor!
    open var menuSeparatorColor: UIColor!
    open var menuTextColor: UIColor!
    open var nightModeBackground: UIColor!
    open var nightModeMenuBackground: UIColor!
    open var nightModeSeparatorColor: UIColor!
    open lazy var mediaOverlayColor: UIColor! = self.tintColor
    
    // Custom actions
    open var shouldHideNavigationOnTap = true
    open var allowSharing = true
    open var enableTTS = true
    
    // Reader Strings
    open var localizedHighlightsTitle: String
    open var localizedHighlightsDateFormat: String
    open var localizedHighlightMenu: String
    open var localizedTranslateMenu: String
    open var localizedDefineMenu: String
    open var localizedPlayMenu: String
    open var localizedPauseMenu: String
    open var localizedFontMenuNight: String
    open var localizedPlayerMenuStyle: String
    open var localizedFontMenuDay: String
    open var localizedReaderOnePageLeft: String
    open var localizedReaderManyPagesLeft: String
    open var localizedReaderManyMinutes: String
    open var localizedReaderOneMinute: String
    open var localizedReaderLessThanOneMinute: String
    open var localizedShareWebLink: String?
    open var localizedShareChapterSubject: String
    open var localizedShareHighlightSubject: String
    open var localizedShareAllExcerptsFrom: String
    open var localizedShareBy: String
    
    // MARK: - Init with defaults
    
    public override init() {
        self.tintColor = UIColor(rgba: "#6ACC50")
        self.toolBarTintColor = UIColor.white
        self.menuBackgroundColor = UIColor(rgba: "#F5F5F5")
        self.menuSeparatorColor = UIColor(rgba: "#D7D7D7")
        self.menuTextColor = UIColor(rgba: "#767676")
        self.nightModeBackground = UIColor(rgba: "#131313")
        self.nightModeMenuBackground = UIColor(rgba: "#1E1E1E")
        self.nightModeSeparatorColor = UIColor(white: 0.5, alpha: 0.2)
        
        self.localizedHighlightsTitle = NSLocalizedString("Highlights", comment: "")
        self.localizedHighlightsDateFormat = "MMM dd, YYYY | HH:mm"
        self.localizedHighlightMenu = NSLocalizedString("Highlight", comment: "")
        self.localizedTranslateMenu = NSLocalizedString("Translate", comment: "")
        self.localizedPlayMenu = NSLocalizedString("Play", comment: "")
        self.localizedPauseMenu = NSLocalizedString("Pause", comment: "")
        self.localizedDefineMenu = NSLocalizedString("Define", comment: "")
        self.localizedFontMenuNight = NSLocalizedString("Night", comment: "")
        self.localizedFontMenuDay = NSLocalizedString("Day", comment: "")
        self.localizedPlayerMenuStyle = NSLocalizedString("Style", comment: "")
        self.localizedReaderOnePageLeft = NSLocalizedString("1 page left", comment: "")
        self.localizedReaderManyPagesLeft = NSLocalizedString("pages left", comment: "")
        self.localizedReaderManyMinutes = NSLocalizedString("minutes", comment: "")
        self.localizedReaderOneMinute = NSLocalizedString("1 minute", comment: "")
        self.localizedReaderLessThanOneMinute = NSLocalizedString("Less than a minute", comment: "")
        self.localizedShareWebLink = nil
        self.localizedShareChapterSubject = NSLocalizedString("Check out this chapter from", comment: "")
        self.localizedShareHighlightSubject = NSLocalizedString("Notes from", comment: "")
        self.localizedShareAllExcerptsFrom = NSLocalizedString("All excerpts from", comment: "")
        self.localizedShareBy = NSLocalizedString("by", comment: "")
        
        super.init()
    }
}
