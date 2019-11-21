@objc(WMFRouter)
public class Router: NSObject {
    public enum Destination: Equatable {
        case inAppLink(_: URL)
        case externalLink(_: URL)
        case article(_: URL)
        case articleHistory(_: URL)
        case articleDiff(_: URL, rev: String)
        case userTalk(_: URL)
        case search(_: URL, term: String?)
    }
    
    unowned let configuration: Configuration
    required init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    // From https://github.com/wikimedia/mediawiki-title
    private let namespaceRegex = try! NSRegularExpression(pattern: "^(.+?)_*:_*(.*)$")
    private let mobilediffRegex = try! NSRegularExpression(pattern: "^mobilediff/([0-9]+)", options: .caseInsensitive)
    
     internal func destinationForWikiResourceURL(_ url: URL) -> Destination? {
        guard let path = configuration.wikiResourcePath(url.path) else {
             return nil
         }
         let language = url.wmf_language ?? "en"
         let articleActivity = Destination.article(url)
         if let namespaceMatch = namespaceRegex.firstMatch(in: path, options: [], range: NSMakeRange(0, path.count)) {
             let namespaceString = namespaceRegex.replacementString(for: namespaceMatch, in: path, offset: 0, template: "$1")
             let title = namespaceRegex.replacementString(for: namespaceMatch, in: path, offset: 0, template: "$2")
             let namespace = WikipediaURLTranslations.commonNamespace(for: namespaceString, in: language)
            let inAppLinkActivity = Destination.inAppLink(url)
             switch namespace {
             case .userTalk:
                 return .userTalk(url)
             case .special:
                 if let diffMatch = mobilediffRegex.firstMatch(in: title, options: [], range: NSMakeRange(0, title.count)) {
                     let oldid = mobilediffRegex.replacementString(for: diffMatch, in: title, offset: 0, template: "$1")
                    return .articleDiff(url, rev:oldid)
                 } else {
                    return inAppLinkActivity
                 }
             case nil: // if the string before the : isn't a namespace, it's likely part of an article title
                 return articleActivity
             default:
                 return inAppLinkActivity
             }
         }
         return articleActivity
     }
     
     internal func destinationForWResourceURL(_ url: URL) -> Destination? {
        guard let path = configuration.wResourcePath(url.path) else {
             return nil
         }
         let defaultActivity = Destination.inAppLink(url)
         guard var components = URLComponents(string: path) else {
             return defaultActivity
         }
         components.query = url.query
         guard components.path.lowercased() == Configuration.Path.indexPHP else {
             return defaultActivity
         }
         guard let queryItems = components.queryItems else {
             return defaultActivity
         }
         for item in queryItems {
             if item.name.lowercased() == "search" {
                return .search(url, term:item.value)
             }
         }
         return defaultActivity
     }
     
    internal func destinationForWikiHostURL(_ url: URL) -> Destination {
         let canonicalURL = url.canonical
         
         if let wikiResourcePathInfo = destinationForWikiResourceURL(canonicalURL) {
             return wikiResourcePathInfo
         }
         
         if let wResourcePathInfo = destinationForWResourceURL(canonicalURL) {
              return wResourcePathInfo
         }
         
         // keep mobile URLs for in app links
         return .inAppLink(url)
     }
     
     public func destination(for url: URL?) throws -> Destination {
         guard let url = url else {
             throw RequestError.invalidParameters
         }
         
        guard configuration.isWikiHost(url.host) else {
            return .externalLink(url)
         }
         
         return destinationForWikiHostURL(url)
     }
}
