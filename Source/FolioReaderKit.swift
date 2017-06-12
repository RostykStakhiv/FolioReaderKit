//
//  FolioReaderKit.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Internal constants for devices

internal let isPad = UIDevice.current.userInterfaceIdiom == .pad
internal let isPhone = UIDevice.current.userInterfaceIdiom == .phone
internal let isPhone4 = (UIScreen.main.bounds.size.height == 480)
internal let isPhone5 = (UIScreen.main.bounds.size.height == 568)
internal let isPhone6P = UIDevice.current.userInterfaceIdiom == .phone && UIScreen.main.bounds.size.height == 736
internal let isSmallPhone = isPhone4 || isPhone5
internal let isLargePhone = isPhone6P

// MARK: - Internal constants

internal let kApplicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] 
internal let kCurrentFontFamily = "kCurrentFontFamily"
internal let kCurrentFontSize = "kCurrentFontSize"
internal let kCurrentAudioRate = "kCurrentAudioRate"
internal let kCurrentHighlightStyle = "kCurrentHighlightStyle"
internal var kCurrentMediaOverlayStyle = "kMediaOverlayStyle"
internal let kNightMode = "kNightMode"
internal let kHighlightRange = 30
internal var kBookId: String!

/**
 `0` Default  
 `1` Underline  
 `2` Text Color
*/
enum MediaOverlayStyle: Int {
    case `default`
    case underline
    case textColor
    
    init () {
        self = .default
    }
    
    func className() -> String {
        return "mediaOverlayStyle\(self.rawValue)"
    }
}

/**
*  Main Library class with some useful constants and methods
*/
open class FolioReader : NSObject {
    fileprivate override init() {}
    
    static let sharedInstance = FolioReader()
    static let defaults = UserDefaults.standard
    static var kgBookModel: KGBook? = nil
    static var kgTranslationModel: KGTranslation? = nil
    var readerCenter: FolioReaderCenter!
    var readerSidePanel: FolioReaderSidePanel!
    var readerContainer: FolioReaderContainer!
    var readerAudioPlayer: FolioReaderAudioPlayer!
    var isReaderOpen = false
    var isReaderReady = false
    
    
    var nightMode: Bool? {
        get { return FolioReader.defaults.value(forKey: kNightMode) as? Bool }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kNightMode)
            FolioReader.defaults.synchronize()
        }
    }
    var currentFontName: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentFontFamily) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentFontFamily)
            FolioReader.defaults.synchronize()
        }
    }
    
    var currentFontSize: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentFontSize) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentFontSize)
            FolioReader.defaults.synchronize()
        }
    }
    
    var currentAudioRate: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentAudioRate) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentAudioRate)
            FolioReader.defaults.synchronize()
        }
    }

    var currentHighlightStyle: Int {
        get { return FolioReader.defaults.value(forKey: kCurrentHighlightStyle) as! Int }
        set (value) {
            FolioReader.defaults.setValue(value, forKey: kCurrentHighlightStyle)
            FolioReader.defaults.synchronize()
        }
    }
    
    var currentMediaOverlayStyle: MediaOverlayStyle {
        get { return MediaOverlayStyle(rawValue: FolioReader.defaults.value(forKey: kCurrentMediaOverlayStyle) as! Int)! }
        set (value) {
            FolioReader.defaults.setValue(value.rawValue, forKey: kCurrentMediaOverlayStyle)
            FolioReader.defaults.synchronize()
        }
    }
    
    // MARK: - Get Cover Image
    
    /**
     Read Cover Image and Return an IUImage
     */
    
    open class func getCoverImage(_ epubPath: String) -> UIImage? {
        return FREpubParser().parseCoverImage(epubPath)
    }

    // MARK: - Present Folio Reader
    
    /**
    Present a Folio Reader for a Parent View Controller.
    */
    open class func presentReader(parentViewController: UINavigationController, withEpubPath epubPath: String, andConfig config: FolioReaderConfig, shouldRemoveEpub: Bool = true, animated: Bool = true) {
        let reader = FolioReaderContainer(config: config, epubPath: epubPath, removeEpub: shouldRemoveEpub)
        FolioReader.sharedInstance.readerContainer = reader
        FolioReader.sharedInstance.readerAudioPlayer = FolioReaderAudioPlayer()
        parentViewController.present(reader, animated: animated, completion: nil)
//showViewController(reader, sender: nil) //    
    }
    
    // MARK: - Application State
    
    /**
    Called when the application will resign active
    */
    open class func applicationWillResignActive() {
        //saveReaderState()
    }
    
    /**
    Called when the application will terminate
    */
    open class func applicationWillTerminate() {
        //saveReaderState()
    }
    
    /**
    Save Reader state, book, page and scroll are saved
    */
    class func saveReaderState() {
        if FolioReader.sharedInstance.isReaderOpen {
            if let currentPage = FolioReader.sharedInstance.readerCenter.currentPage {
                let position = [
                    "pageNumber": currentPageNumber,
                    "pageOffset": currentPage.webView.scrollView.contentOffset.x
                ] as [String : Any]
                
                FolioReader.defaults.set(position, forKey: kBookId)
                FolioReader.defaults.synchronize()
            }
        }
    }
}

// MARK: - Global Functions

func isNight<T> (_ f: T, _ l: T) -> T {
    return (FolioReader.sharedInstance.nightMode == nil) ? f : l
}

// MARK: - Extensions

extension Bundle {
    class func frameworkBundle() -> Bundle {
        return Bundle(for: FolioReader.self)
    }
}

extension UIColor {
    convenience init(rgba: String) {
        var red:   CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue:  CGFloat = 0.0
        var alpha: CGFloat = 1.0
        
        if rgba.hasPrefix("#") {
            let index   = rgba.characters.index(rgba.startIndex, offsetBy: 1)
            let hex     = rgba.substring(from: index)
            let scanner = Scanner(string: hex)
            var hexValue: CUnsignedLongLong = 0
            if scanner.scanHexInt64(&hexValue) {
                switch (hex.characters.count) {
                case 3:
                    red   = CGFloat((hexValue & 0xF00) >> 8)       / 15.0
                    green = CGFloat((hexValue & 0x0F0) >> 4)       / 15.0
                    blue  = CGFloat(hexValue & 0x00F)              / 15.0
                    break
                case 4:
                    red   = CGFloat((hexValue & 0xF000) >> 12)     / 15.0
                    green = CGFloat((hexValue & 0x0F00) >> 8)      / 15.0
                    blue  = CGFloat((hexValue & 0x00F0) >> 4)      / 15.0
                    alpha = CGFloat(hexValue & 0x000F)             / 15.0
                    break
                case 6:
                    red   = CGFloat((hexValue & 0xFF0000) >> 16)   / 255.0
                    green = CGFloat((hexValue & 0x00FF00) >> 8)    / 255.0
                    blue  = CGFloat(hexValue & 0x0000FF)           / 255.0
                    break
                case 8:
                    red   = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
                    green = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
                    blue  = CGFloat((hexValue & 0x0000FF00) >> 8)  / 255.0
                    alpha = CGFloat(hexValue & 0x000000FF)         / 255.0
                    break
                default:
                    print("Invalid RGB string, number of characters after '#' should be either 3, 4, 6 or 8", terminator: "")
                    break
                }
            } else {
                print("Scan hex error")
            }
        } else {
            print("Invalid RGB string, missing '#' as prefix", terminator: "")
        }
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }

    /**
     Hex string of a UIColor instance.

     - parameter rgba: Whether the alpha should be included.
     */
    // from: https://github.com/yeahdongcn/UIColor-Hex-Swift
    public func hexString(_ includeAlpha: Bool) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)

        if (includeAlpha) {
            return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        } else {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
    }

    // MARK: - color shades
    // https://gist.github.com/mbigatti/c6be210a6bbc0ff25972

    func highlightColor() -> UIColor {

        var hue : CGFloat = 0
        var saturation : CGFloat = 0
        var brightness : CGFloat = 0
        var alpha : CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: 0.30, brightness: 1, alpha: alpha)
        } else {
            return self;
        }

    }

    /**
     Returns a lighter color by the provided percentage

     :param: lighting percent percentage
     :returns: lighter UIColor
     */
    func lighterColor(_ percent : Double) -> UIColor {
        return colorWithBrightnessFactor(CGFloat(1 + percent));
    }

    /**
     Returns a darker color by the provided percentage

     :param: darking percent percentage
     :returns: darker UIColor
     */
    func darkerColor(_ percent : Double) -> UIColor {
        return colorWithBrightnessFactor(CGFloat(1 - percent));
    }

    /**
     Return a modified color using the brightness factor provided

     :param: factor brightness factor
     :returns: modified color
     */
    func colorWithBrightnessFactor(_ factor: CGFloat) -> UIColor {
        var hue : CGFloat = 0
        var saturation : CGFloat = 0
        var brightness : CGFloat = 0
        var alpha : CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * factor, alpha: alpha)
        } else {
            return self;
        }
    }
}

extension String {
    /// Truncates the string to length number of characters and
    /// appends optional trailing string if longer
    func truncate(_ length: Int, trailing: String? = nil) -> String {
        if self.characters.count > length {
            return self.substring(to: self.characters.index(self.startIndex, offsetBy: length)) + (trailing ?? "")
        } else {
            return self
        }
    }
    
    func stripHtml() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    func stripLineBreaks() -> String {
        return self.replacingOccurrences(of: "\n", with: "", options: .regularExpression)
    }

    /**
     Converts a clock time such as `0:05:01.2` to seconds (`Double`)

     Looks for media overlay clock formats as specified [here][1]

     - Note: this may not be the  most efficient way of doing this. It can be improved later on.

     - Returns: seconds as `Double`

     [1]: http://www.idpf.org/epub/301/spec/epub-mediaoverlays.html#app-clock-examples
    */
    func clockTimeToSeconds() -> Double {

        let val = self.trimmingCharacters(in: CharacterSet.whitespaces)

        if( val.isEmpty ){ return 0 }

        let formats = [
            "HH:mm:ss.SSS"  : "^\\d{1,2}:\\d{2}:\\d{2}\\.\\d{1,3}$",
            "HH:mm:ss"      : "^\\d{1,2}:\\d{2}:\\d{2}$",
            "mm:ss.SSS"     : "^\\d{1,2}:\\d{2}\\.\\d{1,3}$",
            "mm:ss"         : "^\\d{1,2}:\\d{2}$",
            "ss.SSS"         : "^\\d{1,2}\\.\\d{1,3}$",
        ]

        // search for normal duration formats such as `00:05:01.2`
        for (format, pattern) in formats {

            if val.range(of: pattern, options: .regularExpression) != nil {

                let formatter = DateFormatter()
                formatter.dateFormat = format
                let time = formatter.date(from: val)

                if( time == nil ){ return 0 }

                formatter.dateFormat = "ss.SSS"
                let seconds = (formatter.string(from: time!) as NSString).doubleValue

                formatter.dateFormat = "mm"
                let minutes = (formatter.string(from: time!) as NSString).doubleValue

                formatter.dateFormat = "HH"
                let hours = (formatter.string(from: time!) as NSString).doubleValue

                return seconds + (minutes*60) + (hours*60*60)
            }
        }

        // if none of the more common formats match, check for other possible formats

        // 2345ms
        if val.range(of: "^\\d+ms$", options: .regularExpression) != nil{
            return (val as NSString).doubleValue / 1000.0
        }

        // 7.25h
        if val.range(of: "^\\d+(\\.\\d+)?h$", options: .regularExpression) != nil {
            return (val as NSString).doubleValue * 60 * 60
        }

        // 13min
        if val.range(of: "^\\d+(\\.\\d+)?min$", options: .regularExpression) != nil {
            return (val as NSString).doubleValue * 60
        }

        return 0
    }

    func clockTimeToMinutesString() -> String {

        let val = clockTimeToSeconds()

        let min = floor(val / 60)
        let sec = floor(val.truncatingRemainder(dividingBy: 60))

        return String(format: "%02.f:%02.f", min, sec)
    }

}

extension UIImage {
    convenience init?(readerImageNamed: String) {
        let traits = UITraitCollection(displayScale: UIScreen.main.scale)
        self.init(named: readerImageNamed, in: Bundle.frameworkBundle(), compatibleWith: traits)
    }
    
    func imageTintColor(_ tintColor: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        
        let context = UIGraphicsGetCurrentContext()! as CGContext
        context.translateBy(x: 0, y: self.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(CGBlendMode.normal)
        
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height) as CGRect
        context.clip(to: rect, mask: self.cgImage!)
        tintColor.setFill()
        context.fill(rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()! as UIImage
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    class func imageWithColor(_ color: UIColor?) -> UIImage! {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        if let color = color {
            color.setFill()
        } else {
            UIColor.white.setFill()
        }
        
        context!.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

/*extension UIViewController: UIGestureRecognizerDelegate {
    
    func setCloseButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(readerImageNamed: "icon-close"), style: UIBarButtonItemStyle.Plain, target: self, action:#selector(UIViewController.dismiss))
    }
    
    func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - NavigationBar
    
    func setTransparentNavigation() {
        let navBar = self.navigationController?.navigationBar
        navBar?.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
        navBar?.hideBottomHairline()
        navBar?.translucent = true
    }
    
    func setTranslucentNavigation(translucent: Bool = true, color: UIColor, tintColor: UIColor = UIColor.whiteColor(), titleColor: UIColor = UIColor.blackColor(), andFont font: UIFont = UIFont.systemFontOfSize(17)) {
        let navBar = self.navigationController?.navigationBar
        navBar?.setBackgroundImage(UIImage.imageWithColor(color), forBarMetrics: UIBarMetrics.Default)
        navBar?.showBottomHairline()
        navBar?.translucent = translucent
        navBar?.tintColor = tintColor
        navBar?.titleTextAttributes = [NSForegroundColorAttributeName: titleColor, NSFontAttributeName: font]
    }
}*/

extension UINavigationController {
    /*override public func preferredStatusBarStyle() -> UIStatusBarStyle {
        return isNight(.LightContent, .Default)
    }*/
}

extension UINavigationBar {
    
    func hideBottomHairline() {
        let navigationBarImageView = hairlineImageViewInNavigationBar(self)
        navigationBarImageView!.isHidden = true
    }
    
    func showBottomHairline() {
        let navigationBarImageView = hairlineImageViewInNavigationBar(self)
        navigationBarImageView!.isHidden = false
    }
    
    fileprivate func hairlineImageViewInNavigationBar(_ view: UIView) -> UIImageView? {
        if view.isKind(of: UIImageView.self) && view.bounds.height <= 1.0 {
            return (view as! UIImageView)
        }
        
        let subviews = (view.subviews )
        for subview: UIView in subviews {
            if let imageView: UIImageView = hairlineImageViewInNavigationBar(subview) {
                return imageView
            }
        }
        return nil
    }
}

extension Array {
    
    /**
     Return index if is safe, if not return nil
     http://stackoverflow.com/a/30593673/517707
     */
    subscript(safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}
