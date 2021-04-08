//
//  CloudKitDemoIntegrationTests.swift
//  CloudKitDemoIntegrationTests
//
//  Created by John Brayton on 4/7/21.
//

import XCTest
@testable import CloudKitDemo

class CloudKitDemoIntegrationTests: XCTestCase {

    func testEndToEnd() throws {
        
        // Delete any data left over from previous run
        self.startClean()
        
        let firstCustomerGuid = UUID().uuidString
        var firstCustomer = Customer(guid: firstCustomerGuid, customerName: "Apple", contactName: "Tim Cook", contactEmail: "tim@apple.com")
        self.synchronousSave(customer: firstCustomer, file: #file, line: #line)
        
        let secondCustomerGuid = UUID().uuidString
        let secondCustomer = Customer(guid: secondCustomerGuid, customerName: "Google", contactName: "Sundar Pichai", contactEmail: "sundar@google.com")
        self.synchronousSave(customer: secondCustomer, file: #file, line: #line)

        self.pause()
        
        var retrievedCustomerList = self.synchronousList(file: #file, line: #line)
        guard retrievedCustomerList.count == 2 else {
            XCTFail("count: \(retrievedCustomerList.count)")
            return
        }
        
        retrievedCustomerList.sort { c1, c2 in
            return c1.customerName ?? "" < c2.customerName ?? ""
        }
        
        XCTAssertEqual(retrievedCustomerList[0].guid, firstCustomerGuid)
        XCTAssertEqual(retrievedCustomerList[0].customerName, "Apple")
        XCTAssertEqual(retrievedCustomerList[0].contactName, "Tim Cook")
        XCTAssertEqual(retrievedCustomerList[0].contactEmail, "tim@apple.com")
        XCTAssertEqual(retrievedCustomerList[1].guid, secondCustomerGuid)
        XCTAssertEqual(retrievedCustomerList[1].customerName, "Google")
        XCTAssertEqual(retrievedCustomerList[1].contactName, "Sundar Pichai")
        XCTAssertEqual(retrievedCustomerList[1].contactEmail, "sundar@google.com")
        
        firstCustomer.customerName = "iApple"
        self.synchronousSave(customer: firstCustomer, file: #file, line: #line)
        self.synchronousDelete(customer: secondCustomer, file: #file, line: #line)
        
        self.pause()
        
        retrievedCustomerList = self.synchronousList(file: #file, line: #line)
        guard retrievedCustomerList.count == 1 else {
            XCTFail("count: \(retrievedCustomerList.count)")
            return
        }
        XCTAssertEqual(retrievedCustomerList[0].guid, firstCustomerGuid)
        XCTAssertEqual(retrievedCustomerList[0].customerName, "iApple")
        XCTAssertEqual(retrievedCustomerList[0].contactName, "Tim Cook")
        XCTAssertEqual(retrievedCustomerList[0].contactEmail, "tim@apple.com")
    }
    
    // Delete any customers in the remote database, and verify that they are gone.
    private func startClean() {
        let initialCustomerList = self.synchronousList(file: #file, line: #line)
        for customer in initialCustomerList {
            self.synchronousDelete(customer: customer, file: #file, line: #line)
        }
        XCTAssertEqual(self.synchronousList(file: #file, line: #line).count, 0)
    }
    
    // Wait a few seconds, so we don't get old CloudKit data.
    private func pause() {
        let expectation = self.expectation(description: "pauseExpectation")
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 60)
    }
    
    private func synchronousSave( customer: Customer, file: StaticString, line: UInt ) {
        let expectation = self.expectation(description: "synchronousSaveExpectation")
        customer.save { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail(error.localizedDescription, file: file, line: line)
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 60)
    }

    private func synchronousDelete( customer: Customer, file: StaticString, line: UInt ) {
        let expectation = self.expectation(description: "synchronousDeleteExpectation")
        customer.delete { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail(error.localizedDescription, file: file, line: line)
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 60)
    }
    
    private func synchronousList( file: StaticString, line: UInt ) -> [Customer] {
        var functionResult = [Customer]()
        let expectation = self.expectation(description: "synchronousListExpectation")
        Customer.list { result in
            switch result {
            case .success(let customers):
                functionResult = customers
            case .failure(let error):
                XCTFail(error.localizedDescription, file: file, line: line)
            }
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 60)
        return functionResult
    }

}
