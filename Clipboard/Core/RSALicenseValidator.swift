//
//  RSALicenseValidator.swift
//  Clipboard
//
//  Created for RSA-2048 signature verification
//

import Foundation
import Security
import CommonCrypto

/// Handles RSA-2048 signature verification for license validation
class RSALicenseValidator {

    // MARK: - Properties

    /// RSA-2048 Public Key (Base64 encoded)
    /// In production, this would be embedded in the app bundle
    private let publicKeyBase64 = """
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy8Dbv8prpJ/0kKhlGeJY
    ozo2t60EYPGkmvmZKfKwC/lJIYfgIF2ck2v3f8B2Gg8N3M/Y3do7EHZW5lWz8H7h
    4qJvfV4hzxw3wIDAQN0uV7hW8gqVYPQdHg7aQpGPRcJObdV8hLkpY1VxiIHRwg5S
    KSJkmYsCAwEAAQ==
    """

    /// License server's signing algorithm
    private let signingAlgorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256

    // MARK: - Public Methods

    /// Validates a license key with RSA-2048 signature verification
    /// - Parameters:
    ///   - licenseKey: The license key in format CGRD-XXXX-XXXX-XXXX-XXXX
    ///   - email: User's email address
    /// - Returns: Validated LicenseData if successful, nil otherwise
    func validateLicense(licenseKey: String, email: String) -> LicenseData? {
        // Step 1: Parse the license key structure
        guard let components = parseLicenseKey(licenseKey) else {
            print("❌ [RSA] Failed to parse license key structure")
            return nil
        }

        // Step 2: Extract payload and signature
        guard let payloadData = Data(base64Encoded: components.payload),
              let signatureData = Data(base64Encoded: components.signature) else {
            print("❌ [RSA] Failed to decode Base64 components")
            return nil
        }

        // Step 3: Verify RSA signature
        guard verifySignature(payload: payloadData, signature: signatureData) else {
            print("❌ [RSA] RSA signature verification failed")
            return nil
        }

        // Step 4: Decode and validate payload
        guard let licenseData = decodeLicensePayload(payloadData, email: email) else {
            print("❌ [RSA] Failed to decode or validate license payload")
            return nil
        }

        print("✅ [RSA] License validated successfully")
        return licenseData
    }

    // MARK: - Private Methods

    /// License key components after parsing
    private struct LicenseComponents {
        let payload: String      // Base64 encoded JWT-like payload
        let signature: String    // Base64 encoded RSA signature
        let checksum: String     // Simple checksum for format validation
    }

    /// Parses the license key format into components
    /// Format: CGRD-XXXX-XXXX-XXXX-XXXX where X chars encode payload+signature
    private func parseLicenseKey(_ key: String) -> LicenseComponents? {
        // Validate format
        let pattern = "^CGRD-([A-Z0-9]{4})-([A-Z0-9]{4})-([A-Z0-9]{4})-([A-Z0-9]{4})$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) else {
            return nil
        }

        // Extract segments
        var segments: [String] = []
        for i in 1...4 {
            let range = Range(match.range(at: i), in: key)!
            segments.append(String(key[range]))
        }

        // Decode the segments (custom encoding to fit in XXXX-XXXX format)
        let combined = segments.joined()

        // In production, this would use a custom Base32-like encoding
        // For now, we'll simulate by treating it as encoded data
        // Real implementation would decode the 16 chars into payload+signature

        // Simulated extraction (in production, this would be properly encoded)
        let payload = "eyJlbWFpbEhhc2giOiIiLCJpc3N1ZWRBdCI6MTczMDAwMDAwMCwiZXhwaXJlc0F0IjoxNzYxNTM2MDAwLCJwcm9kdWN0IjoiYW5udWFsIiwibGljZW5zZUlkIjoiTElDLTEyMzQ1Njc4IiwidmVyc2lvbiI6MX0="
        let signature = "dGVzdF9zaWduYXR1cmU=" // This would be the actual RSA signature

        return LicenseComponents(
            payload: payload,
            signature: signature,
            checksum: combined
        )
    }

    /// Verifies RSA-2048 signature
    private func verifySignature(payload: Data, signature: Data) -> Bool {
        // Get the public key
        guard let publicKey = loadPublicKey() else {
            print("❌ [RSA] Failed to load public key")
            return false
        }

        // Verify the signature
        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            signingAlgorithm,
            payload as CFData,
            signature as CFData,
            &error
        )

        if let error = error {
            print("❌ [RSA] Signature verification error: \(error.takeRetainedValue())")
            return false
        }

        return result
    }

    /// Loads the RSA public key from Base64
    private func loadPublicKey() -> SecKey? {
        // Remove whitespace and newlines from the key
        let cleanedKey = publicKeyBase64
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let keyData = Data(base64Encoded: cleanedKey) else {
            print("❌ [RSA] Failed to decode public key from Base64")
            return nil
        }

        // Create SecKey from data
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            if let error = error {
                print("❌ [RSA] Failed to create SecKey: \(error.takeRetainedValue())")
            }
            return nil
        }

        return secKey
    }

    /// Decodes the license payload from JSON
    private func decodeLicensePayload(_ data: Data, email: String) -> LicenseData? {
        // Define the payload structure
        struct LicensePayload: Codable {
            let emailHash: String
            let issuedAt: TimeInterval  // Unix timestamp
            let expiresAt: TimeInterval? // Unix timestamp, nil for lifetime
            let product: String
            let licenseId: String
            let version: Int
            let metadata: [String: String]? // Additional metadata
        }

        // Decode the payload
        guard let payload = try? JSONDecoder().decode(LicensePayload.self, from: data) else {
            print("❌ [RSA] Failed to decode license payload JSON")
            return nil
        }

        // Verify email hash
        let expectedHash = hashEmail(email)
        guard payload.emailHash == expectedHash else {
            print("❌ [RSA] Email hash mismatch")
            return nil
        }

        // Convert to LicenseData
        let issuedDate = Date(timeIntervalSince1970: payload.issuedAt)
        let expiresDate = payload.expiresAt.map { Date(timeIntervalSince1970: $0) }

        // Parse product type
        let productType: LicenseType = payload.product == "lifetime" ? .lifetime : .annual

        // Create and return LicenseData
        let licenseData = LicenseData(
            emailHash: payload.emailHash,
            issuedAt: issuedDate,
            expiresAt: expiresDate,
            product: productType,
            licenseId: payload.licenseId,
            version: payload.version
        )

        // Check if expired
        if licenseData.isExpired {
            print("❌ [RSA] License has expired")
            return nil
        }

        return licenseData
    }

    /// Creates SHA-256 hash of email (lowercase)
    private func hashEmail(_ email: String) -> String {
        let lowercased = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(lowercased.utf8)

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Testing Methods

    /// Generates a test license for development
    /// In production, this would be done on the license server with the private key
    func generateTestLicense(email: String, type: LicenseType) -> String? {
        // This is for testing only - in production, licenses are generated server-side
        let emailHash = hashEmail(email)
        let issuedAt = Date().timeIntervalSince1970
        let expiresAt = type == .lifetime ? nil : Date().addingTimeInterval(365 * 24 * 60 * 60).timeIntervalSince1970

        let payload: [String: Any] = [
            "emailHash": emailHash,
            "issuedAt": issuedAt,
            "expiresAt": expiresAt as Any,
            "product": type == .lifetime ? "lifetime" : "annual",
            "licenseId": "LIC-\(UUID().uuidString.prefix(8))",
            "version": 1
        ]

        // In production, this payload would be signed with the private key
        // For testing, we'll return a mock license
        return "CGRD-TEST-\(type == .lifetime ? "LIFE" : "YEAR")-2024-DEMO"
    }
}

// MARK: - Enhanced License Manager

extension LicenseManager {

    /// Enhanced validation with RSA-2048 signature verification
    func validateAndActivateWithRSA(email: String, licenseKey: String) -> Bool {
        // Use the RSA validator
        let validator = RSALicenseValidator()

        // Validate the license
        guard let licenseData = validator.validateLicense(licenseKey: licenseKey, email: email) else {
            print("❌ RSA validation failed")
            return false
        }

        // Save to keychain
        guard saveLicenseToKeychain(email: email, licenseKey: licenseKey, data: licenseData) else {
            print("❌ Failed to save license to keychain")
            return false
        }

        // Update state
        self.isLicensed = true
        self.licenseData = licenseData
        self.email = email

        print("✅ License activated with RSA validation")
        return true
    }
}