//
//  RealmModels.swift
//  sawtti
//
//  Created by Nour on 06/03/2018.
//  Copyright © 2018 Nour Saffaf. All rights reserved.
//
import Foundation
import RealmSwift

class Song: Object {
    @objc dynamic var id:String = NSUUID().uuidString
    @objc dynamic var name:String = ""
    @objc dynamic var artist:String = ""
    @objc dynamic var cover:String?
    
    override static func primaryKey() -> String? {
        return "id"
    }
}

class FingerPrints: Object {
    @objc dynamic var id:Int = 0
    let songs = List<String>()
    
    override static func primaryKey() -> String? {
        return "id"
    }
}




