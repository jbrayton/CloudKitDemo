//
//  Customer.swift
//  CloudKitDemo
//
//  Created by John Brayton on 4/7/21.
//

import Foundation
import CloudKit

struct Customer {
    
    static let zoneId = CKRecordZone.ID(zoneName: "customerRecordZone")
    static let recordType = "Customer"
    static let cloudkitContainer = CKContainer(identifier: "iCloud.com.goldenhillsoftware.DemoNonDefaultContainer")
    static let cloudkitDatabase = cloudkitContainer.privateCloudDatabase

    enum CloudKitAttributeKeys : CKRecord.FieldKey {
        case customerName = "customerName"
        case contactName = "contactName"
        case contactEmail = "contactEmail"
    }

    let guid: String
    var customerName: String?
    var contactName: String?
    var contactEmail: String?
    
    var cloudkitRecordId: CKRecord.ID {
        get {
            return CKRecord.ID(recordName: self.guid, zoneID: Customer.zoneId)
        }
    }
    
    static func list( handler: @escaping (Result<[Customer],Error>) -> Void ) {
        Customer.createZoneIfNecessary { (createZoneResult) in
            Customer.internalList(retrievedCustomers: [Customer](), cursor: nil, handler: handler)
        }
    }
    
    // The caller must ensure that the zone exists. When this calls itself, it returns a non-empty array of retrievedCustomers and a cursor.
    // External callers should pass an empty array of retrievedCustomers and a nil cursor. This will call the result handler when it has retrieved
    // all Customer records or failed to do so.
    private static func internalList( retrievedCustomers: [Customer], cursor: CKQueryOperation.Cursor?, handler: @escaping (Result<[Customer],Error>) -> Void ) {
        var allCustomers = retrievedCustomers
        
        let fetchRecordsOperation = CKQueryOperation(query: CKQuery(recordType: Customer.recordType, predicate: NSPredicate(value: true)))
        fetchRecordsOperation.cursor = cursor
        fetchRecordsOperation.qualityOfService = .userInteractive
        fetchRecordsOperation.recordFetchedBlock = { (record) in
            let guid = record.recordID.recordName
            let customerName = record[CloudKitAttributeKeys.customerName.rawValue] as? String
            let contactName = record[CloudKitAttributeKeys.contactName.rawValue] as? String
            let contactEmail = record[CloudKitAttributeKeys.contactEmail.rawValue] as? String
            let customer = Customer(guid: guid, customerName: customerName, contactName: contactName, contactEmail: contactEmail)
            allCustomers.append(customer)
        }
        fetchRecordsOperation.queryCompletionBlock = { (cursor, error) in
            if let error = error {
                handler(Result.failure(error))
            } else if let cursor = cursor {
                Customer.internalList(retrievedCustomers: allCustomers, cursor: cursor, handler: handler)
            } else {
                handler(Result.success(allCustomers))
            }
        }
        Customer.cloudkitDatabase.add(fetchRecordsOperation)
    }

    func save( handler: @escaping (Result<Void,Error>) -> Void ) {
        Customer.createZoneIfNecessary { (createZoneResult) in
            switch createZoneResult {
            case .success:
                let record = CKRecord(recordType: Customer.recordType, recordID: self.cloudkitRecordId)
                record[CloudKitAttributeKeys.customerName.rawValue] = self.customerName
                record[CloudKitAttributeKeys.contactName.rawValue] = self.contactName
                record[CloudKitAttributeKeys.contactEmail.rawValue] = self.contactEmail
                
                let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                operation.qualityOfService = .userInteractive
                operation.savePolicy = .changedKeys
                operation.modifyRecordsCompletionBlock = { (savedRecords, _, error) in
                    if savedRecords?.count == 1, error == nil {
                        handler(Result.success(()))
                    } else if let error = error {
                        handler(Result.failure(error))
                    } else {
                        fatalError()
                    }
                }
                Customer.cloudkitDatabase.add(operation)
            case .failure(let error):
                handler(Result.failure(error))
            }
        }
    }
    
    func delete( handler: @escaping (Result<Void,Error>) -> Void ) {
        Customer.createZoneIfNecessary { (createZoneResult) in
            switch createZoneResult {
            case .success:
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [self.cloudkitRecordId])
                operation.qualityOfService = .userInteractive
                operation.modifyRecordsCompletionBlock = { (_, deletedRecordIds, error) in
                    if deletedRecordIds?.count == 1, error == nil {
                        handler(Result.success(()))
                    } else if let error = error {
                        handler(Result.failure(error))
                    } else {
                        fatalError()
                    }
                }
                Customer.cloudkitDatabase.add(operation)
            case .failure(let error):
                handler(Result.failure(error))
            }
        }
    }
    
    
    
    // MARK: Zone Management
    
    // All customer records should go into a specific zone. This function ensures that the zone
    // exists. If we created this zone from this device successfully already, assumes the zone
    // is already there. (Technically it's possible that the zone was deleted from another device
    // or that the user deleted the app's CloudKit data via the Settings app. Ignoring that
    // for this sample app.)
    
    static func createZoneIfNecessary( handler: @escaping (Result<Void,Error>) -> Void ) {
        let zoneCreated = "customerRecordZoneCreatedKey"

        // If we know the zone exists, no need to do anything.
        guard !UserDefaults.standard.bool(forKey: zoneCreated) else {
            handler(Result.success(()))
            return
        }
        
        let zone = CKRecordZone(zoneID: Customer.zoneId)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInteractive
        operation.modifyRecordZonesCompletionBlock = { (savedZones, _, error) in
            if savedZones?.count == 1, error == nil {
                handler(Result.success(()))
            } else if let error = error {
                handler(Result.failure(error))
            } else {
                // I don't think this should be possible.
                fatalError()
            }
        }
        Customer.cloudkitDatabase.add(operation)
    }
    
}
