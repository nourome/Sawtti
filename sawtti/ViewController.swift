//
//  ViewController.swift
//  sawtti
//
//  Created by Nour on 06/03/2018.
//  Copyright © 2018 Nour Saffaf. All rights reserved.
//

import UIKit

import UIKit
import RealmSwift
import NotificationCenter
import AVFoundation
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    @IBOutlet weak var songNameLabel: UILabel!
    @IBOutlet weak var startButton: CoolBtnView!
    private var isListening = false
    let disposeBag = DisposeBag()
    let viewModel = ViewModel()
    
    private var nextSongIndex = 0
    let songsFiles = ["tone400"]
    let songsNames = [ "Sample"]
    /*let songsFiles = ["1shape","2Leanon", "3mambo", "4gangam","5rolling", "6closer", "7human","8earth", "9waka", "10cheap", "11despacito", "12side", "13uptown", "14macarena", "15girl"]
    let songsNames = [ "Shape Of You","Lean On", "Mambo No 5", "Gangam Style","Rolling In The Deep", "Closer", "I am Human", "September", "Waka Waka", "Cheap Thrills", "Despacito", "Side By Side", "Uptown Funk", "Macarena", "Naughty Girl"]*/
    
   
    var start = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(Realm.Configuration.defaultConfiguration.fileURL!)
        
        NotificationCenter.default.addObserver(forName: .AVAudioSessionInterruption, object: nil, queue: nil) {_ in
            self.resetUI()
            self.viewModel.restartAudioSession()
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { state in
            if !state {
                print("please allow mic permession to use the app")
            }else {
                print("can use the app")
            }
        }
        
        viewModel.startNextFingerPrinting.subscribe(onNext: { next in
            if next {
                self.nextSongIndex += 1
                if self.nextSongIndex < self.songsFiles.count {
                    print("finger print \(self.songsNames[self.nextSongIndex])")
                    let mp3Url = Bundle.main.url(forResource: self.songsFiles[self.nextSongIndex], withExtension: "wav")!
                    self.viewModel.fingerPrint(for: mp3Url, songName: self.songsNames[self.nextSongIndex], artist: "", cover: nil)
                }
            }
        }).disposed(by: disposeBag)
        
        viewModel.detectionResult.bind(to: songNameLabel.rx.text).disposed(by: disposeBag)
        
        
        startButton.button.rx.tap.bind {
            self.isListening = !self.isListening
            if self.isListening {
                self.songNameLabel.text = "Listening..."
                self.viewModel.listenToMic()
                self.startButton.animateCountDown()
                self.startButton.fireEmitter(value: 1.0)
            }else {
                self.viewModel.stop()
                self.startButton.stopEmitter()
                self.startButton.stopCountDownAnimatation()
            }
            }.disposed(by: disposeBag)
        
        viewModel.averageMagnitude.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] average in
            
            self?.startButton.stopEmitter()
            self?.startButton.fireEmitter(value: average)
            
        }).disposed(by: disposeBag)
        
        viewModel.test()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func resetUI(){
        
    }
    
    @IBAction func fingerPrintMusic(_ sender: UIButton) {
        
        let mp3Url = Bundle.main.url(forResource: songsFiles[nextSongIndex], withExtension: "wav")!
        viewModel.fingerPrint(for: mp3Url, songName: songsNames[nextSongIndex], artist: "", cover: nil)
        
    }
    
    @IBAction func recognizeMusic(_ sender: UIButton) {
        songNameLabel.text = "Listening..."
        
        if start {
            viewModel.listenToMic()
        }else {
            viewModel.stop()
        }
        
        start = !start
        
    }
    
}

