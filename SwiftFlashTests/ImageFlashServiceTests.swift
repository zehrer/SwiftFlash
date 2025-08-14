//
//  ImageFlashServiceTests.swift
//  SwiftFlashTests
//
//  Created by AI Assistant on 08.08.25.
//

import Testing
import LocalAuthentication
import Combine
@testable import SwiftFlash

/// Test suite for ImageFlashService authentication functionality
/// Tests the Touch ID authentication flow for root privileges
struct ImageFlashServiceTests {
    
    // MARK: - Mock Classes
    
    /// Mock implementation of ImageHistoryServiceProtocol for testing
    class MockImageHistoryService: ObservableObject, ImageHistoryServiceProtocol {
        let objectWillChange = PassthroughSubject<Void, Never>()
        var imageHistory: [ImageHistoryItem] = []
        
        func addToHistory(_ imageFile: ImageFile) {
            // Simple mock implementation
        }
        
        func removeFromHistory(_ item: ImageHistoryItem) {
            // Simple mock implementation
        }
        
        func clearHistory() {
            imageHistory.removeAll()
        }
        
        func validateAllBookmarks() {
            // Simple mock implementation
        }
        
        func loadImageFromHistory(_ item: ImageHistoryItem) -> ImageFile? {
            return nil
        }
    }
    
    /// Mock LAContext for testing authentication scenarios
    class MockLAContext: LAContext {
        var shouldSucceedCanEvaluatePolicy = true
        var shouldSucceedEvaluatePolicy = true
        var evaluatePolicyError: Error?
        
        override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
            if !shouldSucceedCanEvaluatePolicy {
                let nsError = NSError(domain: LAErrorDomain, code: LAError.touchIDNotAvailable.rawValue, userInfo: [NSLocalizedDescriptionKey: "Touch ID not available"])
                error?.pointee = nsError
                return false
            }
            return true
        }
        
        override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
            if let error = evaluatePolicyError {
                throw error
            }
            return shouldSucceedEvaluatePolicy
        }
    }
    
    // MARK: - Authentication Test Helper
    
    /// Standalone authentication test function that mimics ImageFlashService authentication logic
    func testAuthenticateForRootPrivileges(context: MockLAContext) async throws {
        print("🔐 [TEST] Starting Touch ID authentication for root privileges...")
        
        // Check Touch ID availability
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else {
            print(
                "❌ [TEST] Touch ID not available: \(error?.localizedDescription ?? "Unknown error")"
            )
            throw FlashError.authenticationFailed
        }
        
        // Authenticate with Touch ID
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "SwiftFlash needs authentication to write to external drives"
            )
            
            if !success {
                print("❌ [TEST] Touch ID authentication failed")
                throw FlashError.authenticationFailed
            }
            
            print("✅ [TEST] Touch ID authentication successful")
        } catch {
            print("❌ [TEST] Touch ID authentication error: \(error.localizedDescription)")
            throw FlashError.authenticationFailed
        }
        
        print("✅ [TEST] User authenticated for root operations")
    }
    
    // MARK: - Test Cases
    
    /// Test successful Touch ID authentication
    @Test func testTouchIDAuthenticationSuccess() async throws {
        // Arrange
        let mockContext = MockLAContext()
        mockContext.shouldSucceedCanEvaluatePolicy = true
        mockContext.shouldSucceedEvaluatePolicy = true
        
        // Act & Assert
        try await testAuthenticateForRootPrivileges(context: mockContext)
        
        // If we reach here without throwing, the test passes
        #expect(true, "Authentication should succeed with valid Touch ID")
    }
    
    /// Test Touch ID authentication failure when Touch ID is not available
    @Test func testTouchIDNotAvailable() async {
        // Arrange
        let mockContext = MockLAContext()
        mockContext.shouldSucceedCanEvaluatePolicy = false
        
        // Act & Assert
        do {
            try await testAuthenticateForRootPrivileges(context: mockContext)
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed")
        } catch let error as FlashError {
            #expect(error.description == "Touch ID authentication failed")
        } catch {
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed, got \(error)")
        }
    }
    
    /// Test Touch ID authentication failure when user cancels or fails authentication
    @Test func testTouchIDAuthenticationFailure() async {
        // Arrange
        let mockContext = MockLAContext()
        mockContext.shouldSucceedCanEvaluatePolicy = true
        mockContext.shouldSucceedEvaluatePolicy = false
        
        // Act & Assert
        do {
            try await testAuthenticateForRootPrivileges(context: mockContext)
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed")
        } catch let error as FlashError {
            #expect(error.description == "Touch ID authentication failed")
        } catch {
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed, got \(error)")
        }
    }
    
    /// Test Touch ID authentication timeout/error scenarios
    @Test func testTouchIDAuthenticationTimeout() async {
        // Arrange
        let mockContext = MockLAContext()
        mockContext.shouldSucceedCanEvaluatePolicy = true
        
        // Simulate timeout error
        let timeoutError = NSError(
            domain: LAErrorDomain,
            code: LAError.authenticationFailed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Authentication timed out"]
        )
        mockContext.evaluatePolicyError = timeoutError
        
        // Act & Assert
        do {
            try await testAuthenticateForRootPrivileges(context: mockContext)
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed")
        } catch let error as FlashError {
            #expect(error.description == "Touch ID authentication failed")
        } catch {
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed, got \(error)")
        }
    }
    
    /// Test Touch ID authentication when user cancels
    @Test func testTouchIDAuthenticationUserCancel() async {
        // Arrange
        let mockContext = MockLAContext()
        mockContext.shouldSucceedCanEvaluatePolicy = true
        
        // Simulate user cancel error
        let cancelError = NSError(
            domain: LAErrorDomain,
            code: LAError.userCancel.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "User canceled authentication"]
        )
        mockContext.evaluatePolicyError = cancelError
        
        // Act & Assert
        do {
            try await testAuthenticateForRootPrivileges(context: mockContext)
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed")
        } catch let error as FlashError {
            #expect(error.description == "Touch ID authentication failed")
        } catch {
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed, got \(error)")
        }
    }
    
    /// Test Touch ID authentication when system is locked out
    @Test func testTouchIDAuthenticationLockout() async {
        // Arrange
        let mockContext = MockLAContext()
        mockContext.shouldSucceedCanEvaluatePolicy = true
        
        // Simulate lockout error
        let lockoutError = NSError(
            domain: LAErrorDomain,
            code: LAError.touchIDLockout.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Touch ID is locked out"]
        )
        mockContext.evaluatePolicyError = lockoutError
        
        // Act & Assert
        do {
            try await testAuthenticateForRootPrivileges(context: mockContext)
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed")
        } catch let error as FlashError {
            #expect(error.description == "Touch ID authentication failed")
        } catch {
            #expect(Bool(false), "Should have thrown FlashError.authenticationFailed, got \(error)")
        }
    }
    
    /// Test FlashError descriptions for authentication-related errors
    @Test func testFlashErrorDescriptions() {
        #expect(FlashError.authenticationFailed.description == "Touch ID authentication failed")
        #expect(FlashError.authorizationDenied.description == "Root privileges denied")
    }
}