//
//  RealmService.swift
//  sawtti
//
//  Created by Nour on 06/03/2018.
//  Copyright © 2018 Nour Saffaf. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift

enum DbErrors: Error {
    case RealmInstanceIsNill
    case SongRecrodIsNotCreated
    case FingerPrintWriteOperationFailed
}

class RealmService  {
    var songId: String?
    var duplicates = 0
    let config = Realm.Configuration(
        fileURL: Bundle.main.url(forResource: "fingerprints", withExtension: "realm"),
        readOnly: true)
    
    
    func createSongRecord(for name: String, artist:String, cover: String?) throws {
        //let realm = try? Realm(configuration: config)
        let realm = try? Realm()
        
        guard let realmInstance = realm else {throw DbErrors.RealmInstanceIsNill}
        
        let song = Song()
        song.name = name
        song.artist = artist
        song.cover = cover
        
        do {
            try realmInstance.write {
                realmInstance.add(song)
            }
        }catch {
            print("failed to add new song due to \(error)")
        }
        
        songId = song.id
    }
    
    func searchDatabase(hashes: [Int]) -> [Results<FingerPrints>] {
        
        var results: [Results<FingerPrints>] = []
        let realm = try? Realm(configuration: config)
        //print("search size \(hashes.count)")
        
        for hash in hashes {
            if let fp =  realm?.objects(FingerPrints.self).filter("id == \(hash)") {
                results.append(fp)
            }
        }
        //print("single \(results.count)")
        
        return results
    }
 
    /*
    func searchDatabase(hashes: [Int]) -> Observable<[Results<FingerPrints>]> {

        return Observable.create { observer in
            let realm = try? Realm(configuration: self.config)
            var results: [Results<FingerPrints>] = []
            
            for hash in hashes {
                if let fp =  realm?.objects(FingerPrints.self).filter("id == \(hash)") {
                    results.append(fp)
                }
            }
            
            observer.onNext(results)
            observer.onCompleted()
            return Disposables.create()
        }
        
    }
    */
    func addToDatabase(hashes: [Int]) throws {
        //let realm = try? Realm(configuration: config)
        let realm = try? Realm()
        guard let songId = songId else { throw DbErrors.SongRecrodIsNotCreated}
        guard let realmInstance = realm else {throw DbErrors.RealmInstanceIsNill}
        for hash in hashes {
            let fingerPrint = realmInstance.object(ofType: FingerPrints.self, forPrimaryKey: hash)
            if fingerPrint == nil {
                do {
                    try realmInstance.write {
                        realmInstance.create(FingerPrints.self, value: ["id": hash, "songs": [songId] ], update: false)
                    }
                }catch {
                    print("Failed to write finger prints to database \(error)" )
                    throw DbErrors.FingerPrintWriteOperationFailed
                }
            }else {
                duplicates += 1
                do {
                    try realmInstance.write {
                        fingerPrint?.songs.append(songId)
                    }
                }catch {
                    print("Failed to write finger prints to database \(error)" )
                    throw DbErrors.FingerPrintWriteOperationFailed
                }
                
            }
        }
        
        print("duplicates = \(duplicates)")
        duplicates = 0
    }
    
    
    func getSong(id: String) -> Results<Song>? {
        let realm = try? Realm(configuration: config)
        //let realm = try? Realm()
        let predicate = NSPredicate(format: "id == %@", id)
        let song = realm?.objects(Song.self).filter(predicate)
        return song
    }
    
/* func searchDatabase(hashes: [Int]) -> Observable<[Results<FingerPrints>]> {
 
 let realm = try? Realm(configuration: config)
 
 
 return Observable.create { observer in
 var results: [Results<FingerPrints>] = []
 
 for hash in hashes {
 if let fp =  realm?.objects(FingerPrints.self).filter("id == \(hash)") {
 results.append(fp)
 }
 }
 
 observer.onNext(results)
 observer.onCompleted()
 return Disposables.create()
 }
 
 
 //print("single \(results.count)")
 
 // return results
 }*/
    
    
    
}
