//
//  LS2DatabaseManager.swift
//  LS2SDK
//
//  Created by James Kizer on 5/3/18.
//

import UIKit
import RealmSwift
import ResearchSuiteExtensions

open class LS2DatabaseManager: NSObject {
    
    static let kDatabaseKey = "ls2_database_key"
    
    var credentialsQueue: DispatchQueue!
    var credentialStore: RSCredentialsStore!
    
    let datapointQueue: RSGlossyQueue<LS2RealmDatapoint>
    
    var logger: LS2Logger?
    
    var syncQueue: DispatchQueue!
    var isSyncing: Bool = false
    
    let realmFile: URL
    let encryptionEnabled: Bool = false
    let realmEncryptionKey: Data? = nil
    let schemaVersion: UInt64 = 0
    
    public init?(
        databaseStorageDirectory: String,
        databaseFileName: String,
        queueStorageDirectory: String
        ) {
        
        self.datapointQueue = RSGlossyQueue(directoryName: queueStorageDirectory, allowedClasses: [NSDictionary.self, NSArray.self])!
        self.syncQueue = DispatchQueue(label: "\(queueStorageDirectory)/UploadQueue")
        
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first else {
            return nil
        }
        
        let finalDatabaseDirectory = documentsPath.appending("/\(databaseStorageDirectory)")
        var isDirectory : ObjCBool = false
        if FileManager.default.fileExists(atPath: finalDatabaseDirectory, isDirectory: &isDirectory) {
            
            //if a file, remove file and add directory
            if isDirectory.boolValue {
                
            }
            else {
                
                do {
                    try FileManager.default.removeItem(atPath: finalDatabaseDirectory)
                } catch let error as NSError {
                    //TODO: handle this
                    print(error.localizedDescription);
                }
            }
            
        }
        
        do {
            
            try FileManager.default.createDirectory(atPath: finalDatabaseDirectory, withIntermediateDirectories: true, attributes: nil)
            var url: URL = URL(fileURLWithPath: finalDatabaseDirectory)
            var resourceValues: URLResourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
            
        } catch let error as NSError {
            //TODO: Handle this
            print(error.localizedDescription);
        }
//
        let finalDatabaseFilePath = documentsPath.appending("/\(databaseStorageDirectory)/\(databaseFileName)")
        self.realmFile = URL(fileURLWithPath: finalDatabaseFilePath)
        
        super.init()
        
    }

    public func getRealm(queue: DispatchQueue, completion: @escaping (Realm?, Error?) -> Void) {
        let configuration = Realm.Configuration(
            fileURL: self.realmFile,
            inMemoryIdentifier: nil,
            syncConfiguration: nil,
            encryptionKey: self.encryptionEnabled ? self.realmEncryptionKey : nil,
            readOnly: false,
            schemaVersion: self.schemaVersion,
            migrationBlock: nil,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: nil,
            objectTypes: nil)
        
        Realm.asyncOpen(configuration: configuration, callbackQueue: queue, callback: completion)
    }

    public func addDatapoint(datapoint: LS2RealmDatapoint, completion: @escaping ((Error?) -> ())) {
        
        do {
            
            try self.datapointQueue.addGlossyElement(element: datapoint)
            
        } catch let error {
            completion(error)
            return
        }
        
        self.sync()
        completion(nil)

    }
    
    public func addDatapoint(datapointConvertible: LS2DatapointConvertible, completion: @escaping ((Error?) -> ())) {
        
        //this will always pass, but need to wrap in concrete datapoint type
        guard let realmDatapoint =  datapointConvertible.toDatapoint(builder: LS2RealmDatapoint.self) as? LS2RealmDatapoint else {
            return
        }
        
        self.addDatapoint(datapoint: realmDatapoint, completion: completion)
        
    }
    
    private func sync() {
        
        self.syncQueue.async {
            
            let queue = self.datapointQueue
            guard !queue.isEmpty,
                !self.isSyncing else {
                    return
            }

            do {
                
                let elementPairs = try self.datapointQueue.getGlossyElements()
                if elementPairs.count > 0 {
                    
                    self.isSyncing = true
//                    self.logger?.log("posting datapoint with id: \(datapoint.header.id)")
                    
                    self.getRealm(queue: self.syncQueue, completion: { (realm, error) in
                        
                        guard let realm = realm,
                            error == nil else {
                                debugPrint(error!)
                                fatalError("what's the deal with realm errors?")
                                self.isSyncing = false
                                return
                        }

                        do {
                            try realm.write {
                                
                                realm.add(elementPairs.map { $0.element })
                                
                            }
                            
                            try elementPairs.forEach({ (pair) in
                                try self.datapointQueue.removeGlossyElement(element: pair)
                            })
                        }
                        catch let error {
                            debugPrint(error)
                            fatalError("what's the deal with realm / datapoint queue errors?")
                            self.isSyncing = false
                            return
                        }
                        
                        self.isSyncing = false
                        
                    })
                    
                }
                    
                else {
                    self.logger?.log("either we couldnt load a valid datapoint or there is no token")
                }
                
                
            } catch let error {
                //assume file system encryption error when tryong to read
                self.logger?.log("secure queue threw when trying to get elements: \(error)")
                
            }
            
        }
        
    }
    
}
