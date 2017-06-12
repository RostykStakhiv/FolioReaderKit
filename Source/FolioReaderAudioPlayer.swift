//
//  FolioReaderAudioPlayer.swift
//  FolioReaderKit
//
//  Created by Kevin Jantzer on 1/4/16.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

protocol FolioReaderAudioPlayerDelegate {
    /**
     Notifies that Player read all sentence
     */
    func didReadSentence()
}

class FolioReaderAudioPlayer: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    var delegate: FolioReaderAudioPlayerDelegate!
    var isTextToSpeech = false
    var synthesizer: AVSpeechSynthesizer!
    var playing = false
    var player: AVAudioPlayer!
    var currentHref: String!
    var currentFragment: String!
    var currentSmilFile: FRSmilFile!
    var currentAudioFile: String!
    var currentBeginTime: Double!
    var currentEndTime: Double!
    var playingTimer: Timer!
    var registeredCommands = false
    var completionHandler: () -> Void = {}
    var utteranceRate: float_t = 0
    override init() {
        super.init()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        // this is needed to the audio can play even when the "silent/vibrate" toggle is on
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSessionCategoryPlayback)
        try! session.setActive(true)
        
        
    }
    
    
    deinit {
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    func isPlaying() -> Bool {
        return playing
    }

    func setRate(_ rate: Int) {
        if( player != nil ){
            switch rate {
            case 0:
                player.rate = 0.5
                break
            case 1:
                player.rate = 1.0
                break
            case 2:
                player.rate = 1.5
                break
            case 3:
                player.rate = 2
                break
            default:
                break
            }
            
            updateNowPlayingInfo()
        }
        if( synthesizer != nil){
            switch rate {
            case 0:
                utteranceRate = 0.42
                break
            case 1:
                utteranceRate = 0.5
                break
            case 2:
                utteranceRate = 0.53
                break
            case 3:
                utteranceRate = 0.56
                break
            default:
                break
            }
            
            updateNowPlayingInfo()
        }
    }
    
    func stopAndResetCurrentFragment() {
        currentFragment = nil

        playing = false
        if (!isTextToSpeech) {
            if (player != nil && player.isPlaying) {
                player.stop()
                
                UIApplication.shared.isIdleTimerDisabled = false
            }
        } else {
            synthesizer.stopSpeaking(at: AVSpeechBoundary.word)
        }
    }

    func stop() {
        playing = false
		if (!isTextToSpeech) {
			if (player != nil && player.isPlaying) {
				player.stop()

				UIApplication.shared.isIdleTimerDisabled = false
			}
		} else {
            synthesizer.stopSpeaking(at: AVSpeechBoundary.word)
		}
    }
    
    func stopSynthesizer(_ stopCompletion: @escaping ()->Void){
        playing = false
        synthesizer.stopSpeaking(at: AVSpeechBoundary.word)
        completionHandler = stopCompletion
    }

    func pause() {
        playing = false
        
        if(!isTextToSpeech){
            
            if( player != nil && player.isPlaying ){
                player.pause()
                
                UIApplication.shared.isIdleTimerDisabled = false
            }
            
        }else{
			if (synthesizer.isSpeaking) {
				synthesizer.pauseSpeaking(at: AVSpeechBoundary.word)
			}
        }
    }

    func togglePlay() {
        isPlaying() ? pause() : playAudio()
    }

    func playAudio() {
        if let currentPage = FolioReader.sharedInstance.readerCenter.currentPage {
            print("\(currentPage.pageNumber)")
            currentPage.playAudio()
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func playAudioFromPageBegin() {
        let currentPage = FolioReader.sharedInstance.readerCenter.currentPage
        print("\(String(describing: currentPage?.pageNumber))")
        currentPage?.playAudioFromPageBegin()
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
 
    /**
     Play Audio (href/fragmentID)

     Begins to play audio for the given chapter (href) and text fragment.
     If this chapter does not have audio, it will delay for a second, then attempt to play the next chapter
    */
    func playAudio(_ href: String, fragmentID: String) {
        isTextToSpeech = false;
        
        stop();
        let smilFile = book.smilFileForHref(href)

        // if no smil file for this href and the same href is being requested, we've hit the end. stop playing
        if smilFile == nil && currentHref != nil && href == currentHref {
            return
        }

        playing = true
        currentHref = href
        currentFragment = "#"+fragmentID
        currentSmilFile = smilFile
        print("current fragment = \(currentFragment)")
        // if no smil file, delay for a second, then move on to the next chapter
        if smilFile == nil {
            Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(FolioReaderAudioPlayer._autoPlayNextChapter), userInfo: nil, repeats: false)
            return
        }

        let fragment =  smilFile!.parallelAudioForFragment(currentHref+currentFragment)
        print("#fragment = \(String(describing: fragment))")

        if( fragment != nil ){
            if _playFragment(fragment) {
                startPlayerTimer()
            }
        }
    }

    func _autoPlayNextChapter() {
        // if user has stopped playing, dont play the next chapter
        if isPlaying() == false { return }
        playNextChapter()
    }

    func playPrevChapter(){
        stopPlayerTimer()
        // Wait for "currentPage" to update, then request to play audio
        FolioReader.sharedInstance.readerCenter.changePageToPrevious { () -> Void in
            if self.isPlaying() {
                self.playAudio()
            } else {
                self.pause()
            }
        }
    }

    func playNextChapter(){
        stopPlayerTimer()
        // Wait for "currentPage" to update, then request to play audio
        FolioReader.sharedInstance.readerCenter.changePageToNext { () -> Void in
            if self.isPlaying() {
                self.playAudio()
            }
        }
    }


    /**
     Play Fragment of audio

     Once an audio fragment begins playing, the audio clip will continue playing until the player timer detects
     the audio is out of the fragment timeframe.
    */
    fileprivate func _playFragment(_ smil: FRSmilElement?) -> Bool{
        if( smil == nil ){
            print("no more parallel audio to play")
            stop()
            stopPlayerTimer()
            return false
        }

        let textFragment = smil!.textElement().attributes["src"]
        let audioFile = smil!.audioElement().attributes["src"]

        currentBeginTime = smil!.clipBegin()
        currentEndTime = smil!.clipEnd()

        // new audio file to play, create the audio player
        if( player == nil || (audioFile != nil && audioFile != currentAudioFile) ){

            currentAudioFile = audioFile

            let fileURL = currentSmilFile.resource.basePath() + ("/"+audioFile!)
            let audioData = try? Data(contentsOf: URL(fileURLWithPath: fileURL))
            if( audioData != nil ){
                //player = try! AVAudioPlayer(data: audioData!)
                player = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL))
                player.enableRate = true
                setRate(FolioReader.sharedInstance.currentAudioRate)
                player.prepareToPlay()
                player.delegate = self
                
                updateNowPlayingInfo()
            
            } else {
                print("could not read audio file:", audioFile!)
                return false
            }
        }

        // if player is initialized properly, begin playing
        if( player != nil ){

            // the audio may be playing already, so only set the player time if it is NOT already within the fragment timeframe
            // this is done to mitigate milisecond skips in the audio when changing fragments
            if( player.currentTime < currentBeginTime || ( currentEndTime > 0 && player.currentTime > currentEndTime) ){
                player.currentTime = currentBeginTime;
                updateNowPlayingInfo()
            }

            player.play();

            // get the fragment ID so we can "mark" it in the webview
            let textParts = textFragment!.components(separatedBy: "#")
            let fragmentID = textParts[1];
            FolioReader.sharedInstance.readerCenter.audioMark(href: currentHref, fragmentID: fragmentID)
        }

        return true
    }

    /**
     Next Audio Fragment

     Gets the next audio fragment in the current smil file, or moves on to the next smil file
    */
    fileprivate func nextAudioFragment() -> FRSmilElement? {

        let smilFile = book.smilFileForHref(currentHref)

        if smilFile == nil { return nil }

        let smil = currentFragment == nil ? smilFile!.parallelAudioForFragment(currentHref) : smilFile!.nextParallelAudioForFragment(currentFragment)

        if( smil != nil ){
            currentFragment = smil!.textElement().attributes["src"]

            return smil
        }

        currentHref = book.spine.nextChapter(currentHref)?.href
        currentFragment = nil
        currentSmilFile = smilFile

        if( currentHref == nil ){
            stopPlayerTimer()
            return nil
        }

        return nextAudioFragment()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completionHandler()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if isPlaying() {
            if delegate != nil {
                delegate.didReadSentence()
            }
        }
    }
    
    func playText(_ href: String, text: String) {
        isTextToSpeech = true
        playing = true
        currentHref = href
        
        if((synthesizer) == nil){
            synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = self;
            setRate(FolioReader.sharedInstance.currentAudioRate);
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = utteranceRate
        if(synthesizer.isSpeaking){
            synthesizer.stopSpeaking(at: AVSpeechBoundary.word)
        }
        synthesizer.speak(utterance)
    }
    
    // MARK: - Audio timing events

    fileprivate func startPlayerTimer() {
        // we must add the timer in this mode in order for it to continue working even when the user is scrolling a webview
        stopPlayerTimer()
        playingTimer = Timer(timeInterval: 0.01, target: self, selector: #selector(FolioReaderAudioPlayer.playerTimerObserver), userInfo: nil, repeats: true)
        RunLoop.current.add(playingTimer, forMode: RunLoopMode.commonModes)
    }

    fileprivate func stopPlayerTimer() {
        if( playingTimer != nil ){
            playingTimer.invalidate()
            playingTimer = nil
        }
    }

    func playerTimerObserver(){
        if( currentEndTime != nil && currentEndTime > 0 && player.currentTime > currentEndTime ){
            _ = _playFragment(nextAudioFragment())
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        _ = _playFragment(nextAudioFragment())
    }
    
    // MARK: - Now Playing Info and Controls
    
    /**
     Update Now Playing info
     
     Gets the book and audio information and updates on Now Playing Center
     */
    func updateNowPlayingInfo() {
        var songInfo = [String: AnyObject]()
        
        // Get book Artwork
        if let fullHref = book.coverImage?.fullHref {
            let artwork = UIImage(contentsOfFile: fullHref)
            let albumArt = MPMediaItemArtwork(image: artwork!)
            songInfo[MPMediaItemPropertyArtwork] = albumArt
        }
        
        // Get book title
        if let title = book.title() {
            songInfo[MPMediaItemPropertyAlbumTitle] = title as AnyObject
        }
        
        // Get chapter name
        if let chapter = getCurrentChapterName() {
            songInfo[MPMediaItemPropertyTitle] = chapter as AnyObject
        }
        
        // Get author name
        if let author = book.metadata.creators.first {
            songInfo[MPMediaItemPropertyArtist] = author.name as AnyObject
        }
        
        // Set player times
        if !isTextToSpeech {
            songInfo[MPMediaItemPropertyPlaybackDuration] = player.duration as AnyObject
            songInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate as AnyObject
            songInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime ] = player.currentTime as AnyObject
        }
        
        // Set Audio Player info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
        
        registerCommandsIfNeeded()
    }
    
    /**
     Get Current Chapter Name
     
     This is done here and not in ReaderCenter because even though `currentHref` is accurate,
     the `currentPage` in ReaderCenter may not have updated just yet
     */
    func getCurrentChapterName() -> String? {
        for item in FolioReader.sharedInstance.readerSidePanel.tocItems {
            if item.resource.href == currentHref {
                return item.title
            }
        }
        return nil
    }
    
    /**
     Register commands if needed, check if it's registered to avoid register twice.
     */
    func registerCommandsIfNeeded() {
        
        if registeredCommands {return}
        
        let command = MPRemoteCommandCenter.shared()
        command.previousTrackCommand.isEnabled = true
        command.previousTrackCommand.addTarget(self, action: #selector(FolioReaderAudioPlayer.playPrevChapter))
        command.nextTrackCommand.isEnabled = true
        command.nextTrackCommand.addTarget(self, action: #selector(FolioReaderAudioPlayer.playNextChapter))
        command.pauseCommand.isEnabled = true
        command.pauseCommand.addTarget(self, action: #selector(FolioReaderAudioPlayer.pause))
        command.playCommand.isEnabled = true
        command.playCommand.addTarget(self, action: #selector(FolioReaderPage.playAudio))
        command.togglePlayPauseCommand.isEnabled = true
        command.togglePlayPauseCommand.addTarget(self, action: #selector(FolioReaderAudioPlayer.togglePlay))
        
        registeredCommands = true
    }

}
