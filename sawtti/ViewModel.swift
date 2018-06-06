//
//  ViewModel.swift
//  sawtti
//
//  Created by Nour on 06/03/2018.
//  Copyright © 2018 Nour Saffaf. All rights reserved.
// FFT based on https://gist.github.com/ArthurGuibert/31eb614a4bf5bf52d84cedfac1eb9483#file-fftperform-swift


import Foundation
import AVFoundation
import Accelerate
import RealmSwift
import RxSwift


enum ProcessingError: Error {
    case BufferCreationFailed
    case BufferUnloaded
}

class ViewModel {
    
    private let realmService = RealmService()
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    private let bufferSize = 1024
    private let sampleSize = 8
    private let samplingFrequency = 44100
    //private var outfile: AVAudioFile!
    //var isFingerPrintMode = true
    private var silenceThreashold: Float = 10.0
    //var noiseThreashold: Float = 0.17
    private let maxNeighbor = 7
    private var peaks : [FPModel] = []
    private var sampleCount = 0
    //private let freqBins = [50, 100, 184, 368, 552] //16 Kb
    private let freqBins = [25, 50, 92, 184, 276] //8Kb
    var startNextFingerPrinting = PublishSubject<Bool>()
    var detectionResult = PublishSubject<String>()
    var averageMagnitude = PublishSubject<Float>()
    private let disposeBag = DisposeBag()
    
    func restartAudioSession() {
        
    }
    
    
    func fingerPrint(for songUrl: URL, songName: String, artist: String, cover: String?) {
        
        silenceThreashold = 100.0
        
        do {
            try realmService.createSongRecord(for: songName, artist: artist, cover: cover)
        } catch {
            print("Could not create database record \(error)")
            return
        }
        
        do {
            try processAudioFile(url: songUrl)
        }catch {
            print("Could not process audio file \(error)")
            return
        }
        
    }
    
    
    private func processAudioFile(url: URL) throws {
        sampleCount = 0
        audioEngine.attach(audioPlayerNode)
        var done = false
        let audioFile  = try! AVAudioFile(forReading: url)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))
        guard let _ = buffer else {throw ProcessingError.BufferCreationFailed}
        
        do {
            try audioFile.read(into: buffer!)
        }catch{
            print("failed to fill the buffer due to \(error)")
            throw ProcessingError.BufferUnloaded
        }
        
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(samplingFrequency), channels: 1, interleaved: false)
        let monoMixer = AVAudioMixerNode()
        audioEngine.attach(monoMixer)
        audioEngine.connect(audioPlayerNode, to: monoMixer, format: buffer!.format)
        audioEngine.connect(monoMixer, to: audioEngine.mainMixerNode, format: audioFormat)
        audioPlayerNode.scheduleBuffer(buffer!) {
            done = true
        }
        print("audio format \(audioFormat.debugDescription)")
        
        monoMixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize * sampleSize), format: audioFormat) { (buffer, time) in
            //print("frame length = \(buffer.frameLength)")
            let dataPtr = buffer.floatChannelData?.pointee
            let dataSize = dataPtr?[Int(buffer.frameLength) - 1]
            if done && dataSize == 0.0 {
                print("sample count = \(self.sampleCount)")
                self.audioPlayerNode.stop()
                self.audioEngine.stop()
                self.audioEngine.reset()
                monoMixer.removeTap(onBus: 0)
                self.audioEngine.detach(monoMixer)
                self.audioEngine.detach(self.audioPlayerNode)
                self.saveToDatabase()
                return
                
            }
            self.sampleCount += 1
            self.performFFT(buffer: buffer, time: time)
            
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        }catch {
            print("audio engine could not start \(error)")
        }
        audioPlayerNode.play()
        
    }
    
    func extractPeaks(magz: [Float], time: AVAudioTime, size:Int) {
        var magnitudes:[Float] = [0,0,0,0]
        var frequencies:[Int] = [0,0,0,0]
        
        for i in 0..<freqBins.last! {
            let mag = magz[i]
            let freq = i * samplingFrequency / (bufferSize * sampleSize)
            
            switch i {
            case freqBins[0] ... freqBins[1]:
                if magnitudes[0] < mag {
                    frequencies[0] =  freq
                    magnitudes[0] = mag
                }
            case freqBins[1] ... freqBins[2]:
                if magnitudes[1] < mag {
                    frequencies[1] =  freq
                    magnitudes[1] = mag
                }
            case freqBins[2] ... freqBins[3]:
                if magnitudes[2] < mag {
                    frequencies[2] =  freq
                    magnitudes[2] = mag
                }
            case freqBins[3] ... freqBins[4]:
                if magnitudes[3] < mag {
                    frequencies[3] =  freq
                    magnitudes[3] = mag
                }
            default:
                break
            }
            
        }
        
        let highestMagnitude = magnitudes.sorted().last ?? 0
        //print("highestMagnitude \(highestMagnitude)")
        
        if highestMagnitude > silenceThreashold {
            for x in 0..<freqBins.count-1 {
                let fp = FPModel(position: sampleCount, frequency: frequencies[x], magnitude: magnitudes[x], time: time.sampleTime, band: x+1)
                peaks.append(fp)
            }
            
           
        }
        
        if sampleCount % 10 == 0 {
            let totalMagnitude = magz.reduce(0, +)
            let average = totalMagnitude / Float(magz.count)
            print("average \(average)")
            averageMagnitude.onNext(average)
        }
        
    }
    
    func generateHashes(duplicates: Bool) -> [Int] {
        
        var hashes: [Int] = []
        
        if peaks.count > (maxNeighbor) {
            for n in 0..<(peaks.count - maxNeighbor) {
                for x in 1..<maxNeighbor {
                    let nextId = n + x
                    if peaks[n].band != peaks[nextId].band && peaks[n].position != peaks[nextId].position   {
                        if peaks[n].frequency != 0 && peaks[nextId].frequency != 0 {
                            let hashValue = hash(peak: peaks[n].frequency, peakTime: peaks[n].time, nextPeak: peaks[nextId].frequency, nextPeakTime:  peaks[nextId].time)
                            hashes.append(hashValue)
                        }
                    }
                }
            }
        }
        
        //print("size before = \(hashes.count)")
        if !duplicates {
            hashes = Array(Set(hashes))
        }
        //print("size after = \(hashes.count)")
        return hashes
    }
    
    
    func hash(peak:Int, peakTime: Int64, nextPeak: Int, nextPeakTime: Int64) -> Int {
        let timeDiff  = Int(nextPeakTime - peakTime)
        let freqDiff = abs(nextPeak - peak)
        var pins  = [0,0,0,0]
        pins[0] = abs(((peak + nextPeak) << 3)  &+ timeDiff)
        pins[1] = abs(((nextPeak << 3) + peak &- freqDiff))
        let peakHash =  Int(((pins[0] * 1000000 ) + pins[1]))
        return peakHash
        
    }
    
    func saveToDatabase(){
        //peakMap()
        do {
            try  realmService.addToDatabase(hashes: generateHashes(duplicates: false))
        }catch {
            print("database error \(error)")
        }
        
        peaks = []
        startNextFingerPrinting.onNext(true)
        
    }
    
    func filter(results: [Results<FingerPrints>]) -> [String : Int]{
        
        var filteredResults: [String : Int] = [:]
        
        if !results.isEmpty {
            for result in results {
                for fingerPrint in result {
                    for songId in fingerPrint.songs{
                        let currentValue = filteredResults[songId] ?? 0
                        filteredResults.updateValue(currentValue + 1, forKey: songId)
                    }
                }
            }
        }
        
        return filteredResults
    }
    
    
    
    func detectSong() -> Observable<String> {
    
        return Observable.create { observer in
            
           let qResults = self.realmService.searchDatabase(hashes:  self.generateHashes(duplicates: true))
            let filteredResults = self.filter(results: qResults)
            let sortedResults = filteredResults.sorted{ $0.value > $1.value }
         
            if sortedResults.count > 0 {
                //let correctSong:Results<Song>? = nil
                let correctSong:Results<Song>? = self.realmService.getSong(id: sortedResults.first!.key)
                guard let songName = correctSong?.first?.name else {
                   observer.onNext("Song not found in the Database?")
                   observer.onCompleted()
                   return Disposables.create()
                }
                
                if sortedResults.count > 1 {
                    if (sortedResults.first!.value - sortedResults[1].value) < 10 {
                        observer.onNext("I guess \(songName)")
                    } else {
                        observer.onNext(songName)
                    }
                    let nextSong = self.realmService.getSong(id: sortedResults[1].key)
                    print("next song = \(String(describing: nextSong?.first?.name))")
                }else {
                    observer.onNext(songName)
                    print("song found \(songName)")
                }
            } else {
                observer.onNext("No single match in Database?")
                
            }
            
            // for testing only ---- check order or detection
            var x = 1
            for res in sortedResults {
                print("\(x)- \(res.value)")
                x += 1
            }
            //---------------------
            observer.onCompleted()
            return Disposables.create()
        }
        
        
        //
        
       //.observeOn(bgSched1).subscribe(onNext: { qResults in
            
        
            
        
        
        //let qResults = realmService.searchDatabase(hashes:  generateHashes(duplicates: true))
       
        
    }
    
    func stop() {
        audioEngine.stop()
        audioEngine.reset()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        let bgSched1 = SerialDispatchQueueScheduler(queue: DispatchQueue.global(qos: .default), internalSerialQueueName: "background_search")
        
       // peakMap()
        
        detectSong().subscribeOn(bgSched1).subscribe(onNext: { result in
           self.detectionResult.onNext(result)
        }, onCompleted: {
            self.peaks = []
        }).disposed(by: disposeBag)
        
       
        
       
    }
    
    
    func listenToMic(){
        sampleCount = 0
        silenceThreashold = 10.0
        
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(samplingFrequency), channels: 1, interleaved: false)
        
        /*
         let fm = FileManager.default
         let doc = try! fm.url(for:.documentDirectory,
         in: .userDomainMask, appropriateFor: nil, create: true)
         let outurl = doc.appendingPathComponent("mic.wav", isDirectory:false)
         outfile = try! AVAudioFile(forWriting: outurl, settings: [
         AVFormatIDKey : kAudioFormatLinearPCM,
         AVNumberOfChannelsKey : 1,
         AVSampleRateKey : 44100,
         AVLinearPCMBitDepthKey:32,
         AVLinearPCMIsFloatKey: true,
         AVLinearPCMIsNonInterleaved: false
         ])
         //print("format: \(outfile.processingFormat)")
         //print(outfile.processingFormat)
         */
        
        print(audioFormat.debugDescription)
        
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize * sampleSize), format: audioFormat) { buffer, time in
            /*
             do {
             try self.outfile.write(from:buffer)
             } catch {
             print(error)
             }
             */
            self.sampleCount += 1
            self.performFFT(buffer: buffer, time: time)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    
    
    
    func performFFT(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let frameCount = buffer.frameLength
        let log2n = UInt(round(log2(Double(frameCount))))
        let bufferSizePOT = Int(1 << log2n)
        let inputCount = bufferSizePOT / 2
        print("bufferSize = \(bufferSize)")
        print("inputCount = \(bufferSizePOT)")
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        var realp = [Float](repeating: 0, count: inputCount)
        var imagp = [Float](repeating: 0, count: inputCount)
        var magz = [Float](repeating: 0, count: inputCount)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        let windowSize = bufferSizePOT
        var transferBuffer = [Float](repeating: 0, count: windowSize)
        var window = [Float](repeating: 0, count: windowSize)
        
        // Hann windowing to reduce the frequency leakage
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((buffer.floatChannelData?.pointee)!, 1, window,
                  1, &transferBuffer, 1, vDSP_Length(windowSize))
        
        // Transforming the [Float] buffer into a UnsafePointer<Float> object for the vDSP_ctoz method
        // And then pack the input into the complex buffer (output)
        let temp = UnsafePointer<Float>(transferBuffer)
        temp.withMemoryRebound(to: DSPComplex.self,
                               capacity: transferBuffer.count) {
                                vDSP_ctoz($0, 2, &output, 1, vDSP_Length(inputCount))
        }
        
        // Perform the FFT
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Gets the magnitude
        vDSP_zvabs(&output, 1, &magz, 1, vDSP_Length(inputCount))
        extractPeaks(magz: magz, time: time, size: inputCount)
        
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    
    /*for Visualization peak map only*/
    func peakMap() {
        var freq: [Int] = []
        var time : [Int] = []
        
        for fp in peaks {
            freq.append(fp.frequency)
            time.append(fp.position)
        }
        
        print("freq = \(freq);")
        print("time = \(time);")
        
    }

    
    //not used
    func normalize() {
        let noiseThreashold: Float = 0.0
        for x in 1..<4 {
            let filteredPeak = peaks.filter { $0.band == x }
            let sortedPeaks = filteredPeak.sorted { $0.magnitude > $1.magnitude }
            let highestMagnitude = sortedPeaks.first?.magnitude ?? -1
            
            if highestMagnitude != -1 {
                for j in 0..<peaks.count {
                    if peaks[j].band == x {
                        if (peaks[j].magnitude / highestMagnitude) < noiseThreashold {
                            peaks[j].frequency = 0
                        }
                    }
                }
            }
        }
    }
    
    func test() {
        let transferImage = Observable<Int>.create { (obs) -> Disposable in
            if let nextPacket = self.getNextPacket() {
                obs.onNext(nextPacket)
            
            } else{
                obs.onNext(-1)
                obs.onCompleted()
                
            }
            return Disposables.create()
        }
        
        transferImage.takeWhile{$0 > 0}.subscribe(onNext: { nextPacket in
            print(nextPacket)
            let completed = self.sendFWpacket()
            if !completed {
                self.test()
            }
            
        }, onError: { error in
            print(error)
        }, onCompleted: {
            print("onCompleted")
        }) {
            print("disposed")
            }.disposed(by: disposeBag)
        
    }
    
    func sendFWpacket()-> Bool {
        return false
    }
    
    func getNextPacket() ->  Int? {
        return 1
    }
    
    
    
}
