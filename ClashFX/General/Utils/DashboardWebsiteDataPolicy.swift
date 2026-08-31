import WebKit

/// Defines the website data that ClashFX may discard without erasing dashboard preferences.
enum DashboardWebsiteDataPolicy {
    static let volatileDataTypes: Set<String> = [
        WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeDiskCache,
        WKWebsiteDataTypeOfflineWebApplicationCache,
        WKWebsiteDataTypeServiceWorkerRegistrations
    ]

    static func removableDataTypes(from availableDataTypes: Set<String>) -> Set<String> {
        return availableDataTypes.intersection(volatileDataTypes)
    }
}
