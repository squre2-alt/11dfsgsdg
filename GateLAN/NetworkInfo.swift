import Foundation

enum NetworkInfo {
    static func currentIPv4Prefix() -> String? {
        guard let address = currentWiFiIPv4Address() else { return nil }
        var parts = address.split(separator: ".").map(String.init)
        guard parts.count == 4 else { return nil }
        parts.removeLast()
        return parts.joined(separator: ".")
    }

    private static func currentWiFiIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return nil }
        defer { freeifaddrs(interfaces) }

        var pointer = interfaces
        while pointer != nil {
            guard let interface = pointer?.pointee else {
                pointer = pointer?.pointee.ifa_next
                continue
            }

            let name = String(cString: interface.ifa_name)
            let family = interface.ifa_addr.pointee.sa_family

            if name == "en0", family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )

                if result == 0 {
                    return String(cString: hostname)
                }
            }

            pointer = interface.ifa_next
        }

        return nil
    }
}
