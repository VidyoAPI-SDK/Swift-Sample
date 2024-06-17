import Foundation

class CertificatesManager {
    static func getDefaultCertificates() -> String {
        var content = ""
        do {
            if let filePath = Bundle.main.path(forResource: "custom_certificates", ofType: "pem") {
                content = try String(contentsOfFile: filePath)
            }
        } catch {
            log.info("Failed to get certificate content with error: \(error.localizedDescription)")
        }
        return content
    }
}
