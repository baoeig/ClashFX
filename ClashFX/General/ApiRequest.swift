//
//  ApiRequest.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Alamofire
import Cocoa
import Starscream
import SwiftyJSON

protocol ApiRequestStreamDelegate: AnyObject {
    func didUpdateTraffic(up: Int, down: Int)
    func didGetLog(log: String, level: String)
}

typealias ErrorString = String

class ApiRequest {
    static let shared = ApiRequest()

    private var proxyRespCache: ClashProxyResp?

    private lazy var logQueue = DispatchQueue(label: "com.clashfx.core.log")

    static let clashRequestQueue = DispatchQueue(label: "com.clashfx.clashRequestQueue")

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 604800
        configuration.timeoutIntervalForResource = 604800
        configuration.httpMaximumConnectionsPerHost = 100
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        alamoFireManager = Session(configuration: configuration)
    }

    static func authHeader() -> HTTPHeaders {
        let secret = ConfigManager.shared.overrideSecret ?? ConfigManager.shared.apiSecret
        return (!secret.isEmpty) ? ["Authorization": "Bearer \(secret)"] : [:]
    }

    @discardableResult
    private static func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default
    )
        -> DataRequest {
        guard ConfigManager.shared.isRunning else {
            return AF.request("")
        }

        return shared.alamoFireManager
            .request(ConfigManager.apiUrl + url,
                     method: method,
                     parameters: parameters,
                     encoding: encoding,
                     headers: authHeader())
    }

    weak var delegate: ApiRequestStreamDelegate?

    private var trafficWebSocket: WebSocket?
    private var loggingWebSocket: WebSocket?

    private var trafficWebSocketRetryDelay: TimeInterval = 1
    private var loggingWebSocketRetryDelay: TimeInterval = 1
    private var trafficWebSocketRetryTimer: Timer?
    private var loggingWebSocketRetryTimer: Timer?
    private var trafficWatchdogTimer: Timer?
    private static let maxRetryDelaySeconds: TimeInterval = 64
    private static let trafficWatchdogTimeoutSeconds: TimeInterval = 10

    private var alamoFireManager: Session

    static func useDirectApi() -> Bool {
        if ConfigManager.shared.isEnhancedModeActive {
            return false
        }
        if ConfigManager.shared.overrideApiURL != nil {
            return false
        }
        return Settings.builtInApiMode
    }

    static func requestConfig(completeHandler: @escaping ((ClashConfig) -> Void)) {
        requestConfigWithRetry(
            context: RequestConfigContext.current,
            retriesLeft: 5,
            delay: 0.2,
            completeHandler: completeHandler
        )
    }

    private struct RequestConfigContext: Equatable {
        let directApi: Bool
        let apiUrl: String
        let selectedConfig: String

        static var current: RequestConfigContext {
            RequestConfigContext(
                directApi: ApiRequest.useDirectApi(),
                apiUrl: ConfigManager.apiUrl,
                selectedConfig: ConfigManager.selectConfigName
            )
        }
    }

    private static func requestConfigWithRetry(
        context: RequestConfigContext,
        retriesLeft: Int,
        delay: TimeInterval,
        completeHandler: @escaping ((ClashConfig) -> Void)
    ) {
        let retry: (String) -> Void = { reason in
            guard context == RequestConfigContext.current else {
                Logger.log("requestConfig: context changed during retry, reissuing", level: .warning)
                requestConfig(completeHandler: completeHandler)
                return
            }
            guard retriesLeft > 0 else {
                Logger.log("requestConfig: gave up after retries, \(reason)", level: .warning)
                return
            }
            Logger.log("requestConfig: \(reason), retrying in \(delay)s (\(retriesLeft) left)", level: .warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                requestConfigWithRetry(
                    context: context,
                    retriesLeft: retriesLeft - 1,
                    delay: min(delay * 1.8, 2.0),
                    completeHandler: completeHandler
                )
            }
        }

        let dispatch: (ClashConfig) -> Void = { config in
            guard context == RequestConfigContext.current else {
                Logger.log("requestConfig: context changed before completion, reissuing", level: .warning)
                requestConfig(completeHandler: completeHandler)
                return
            }
            if config.usedHttpPort > 0 || retriesLeft <= 0 {
                if config.usedHttpPort == 0 {
                    Logger.log("requestConfig: gave up after retries, port still 0", level: .warning)
                }
                completeHandler(config)
                return
            }
            retry("port=0 transient")
        }

        if !context.directApi {
            req("/configs").responseDecodable(of: ClashConfig.self) {
                resp in
                switch resp.result {
                case let .success(config):
                    dispatch(config)
                case let .failure(err):
                    Logger.log("requestConfig: \(err.localizedDescription)")
                    if ConfigManager.shared.isRunning, !ConfigManager.shared.isEnhancedModeActive, retriesLeft <= 0 {
                        NSUserNotificationCenter.default.post(title: "Error", info: err.localizedDescription)
                    }
                    retry(err.localizedDescription)
                }
            }
            return
        }

        clashRequestQueue.async {
            let data = clashGetConfigs()?.toString().data(using: .utf8) ?? Data()
            DispatchQueue.main.async {
                guard let config = ClashConfig.fromData(data) else {
                    NSUserNotificationCenter.default.post(title: "Error", info: "Get clash config failed. Try fixing your config file, then reload the config or restart ClashFX.")
                    (NSApplication.shared.delegate as? AppDelegate)?.startProxy()
                    return
                }
                dispatch(config)
            }
        }
    }

    static func requestConfigUpdate(configName: String, callback: @escaping ((ErrorString?) -> Void)) {
        ConfigManager.getConfigPath(configName: configName) {
            requestConfigUpdate(configPath: $0, callback: callback)
        }
    }

    static func requestConfigUpdate(configPath: String, callback: @escaping ((ErrorString?) -> Void)) {
        let placeHolderErrorDesp = "Error occurred. Please try to fix it by restarting ClashFX. "

        // DEV MODE: Use API
        if !useDirectApi() {
            req("/configs", method: .put, parameters: ["Path": configPath], encoding: JSONEncoding.default).responseData { res in
                if res.response?.statusCode == 204 {
                    ConfigManager.shared.isRunning = true
                    callback(nil)
                } else {
                    let errorJson = try? res.result.get()
                    let err = JSON(errorJson ?? "")["message"].string ?? placeHolderErrorDesp
                    Logger.log(err)
                    callback(err)
                }
            }
            return
        }

        // NORMAL MODE: Use internal api
        clashRequestQueue.async {
            let res = clashUpdateConfig(configPath.goStringBuffer())?.toString() ?? placeHolderErrorDesp
            DispatchQueue.main.async {
                if res == "success" {
                    callback(nil)
                } else {
                    Logger.log(res)
                    callback(res)
                }
            }
        }
    }

    static func updateOutBoundMode(mode: ClashProxyMode, callback: ((Bool) -> Void)? = nil) {
        req("/configs", method: .patch, parameters: ["mode": mode.rawValue], encoding: JSONEncoding.default)
            .responseData { response in
                switch response.result {
                case .success:
                    callback?(true)
                case .failure:
                    callback?(false)
                }
            }
    }

    static func updateLogLevel(level: ClashLogLevel, callback: ((Bool) -> Void)? = nil) {
        req("/configs", method: .patch, parameters: ["log-level": level.rawValue], encoding: JSONEncoding.default).responseData(completionHandler: { response in
            switch response.result {
            case .success:
                callback?(true)
            case .failure:
                callback?(false)
            }
        })
    }

    static func requestProxyGroupList(completeHandler: ((ClashProxyResp) -> Void)? = nil) {
        req("/proxies").responseData {
            res in
            let proxies = ClashProxyResp(try? res.result.get())
            ApiRequest.shared.proxyRespCache = proxies
            completeHandler?(proxies)
        }
    }

    static func requestProxyProviderList(completeHandler: ((ClashProviderResp) -> Void)? = nil) {
        req("/providers/proxies")
            .responseDecodable(of: ClashProviderResp.self, decoder: ClashProviderResp.decoder) { resp in
                switch resp.result {
                case let .success(providerResp):
                    completeHandler?(providerResp)
                case let .failure(err):
                    Logger.log("\(err)")
                    completeHandler?(ClashProviderResp())
                }
            }
    }

    static func updateAllowLan(allow: Bool, completeHandler: (() -> Void)? = nil) {
        Logger.log("update allow lan:\(allow)", level: .debug)
        req("/configs",
            method: .patch,
            parameters: ["allow-lan": allow],
            encoding: JSONEncoding.default).response {
            _ in
            completeHandler?()
        }
    }

    static func updateProxyGroup(group: String, selectProxy: String, callback: @escaping ((Bool) -> Void)) {
        req("/proxies/\(group.encoded)",
            method: .put,
            parameters: ["name": selectProxy],
            encoding: JSONEncoding.default)
            .responseData { response in
                let statusCode = response.response?.statusCode ?? -1
                let success = statusCode == 204
                if success {
                    Logger.log("[Proxy Select] Selected '\(selectProxy)' for group '\(group)'")
                } else {
                    let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty body>"
                    Logger.log("[Proxy Select] Failed selecting '\(selectProxy)' for group '\(group)', status: \(statusCode), error: \(response.error?.localizedDescription ?? "unknown error"), body: \(body)", level: .warning)
                }
                callback(success)
            }
    }

    static func getAllProxyList(callback: @escaping (([ClashProxyName]) -> Void)) {
        requestProxyGroupList {
            proxyInfo in
            let lists: [ClashProxyName] = proxyInfo.proxiesMap["GLOBAL"]?.all ?? []
            callback(lists)
        }
    }

    static func getMergedProxyData(complete: ((ClashProxyResp?) -> Void)? = nil) {
        let group = DispatchGroup()
        group.enter()
        group.enter()

        var provider: ClashProviderResp?
        var proxyInfo: ClashProxyResp?

        group.notify(queue: .main) {
            guard let proxyInfo = proxyInfo, let proxyprovider = provider else {
                complete?(nil)
                return
            }
            proxyInfo.updateProvider(proxyprovider)
            complete?(proxyInfo)
        }

        ApiRequest.requestProxyProviderList {
            proxyprovider in
            provider = proxyprovider
            group.leave()
        }

        ApiRequest.requestProxyGroupList {
            proxy in
            proxyInfo = proxy
            group.leave()
        }
    }

    static func getProxyDelay(proxyName: String, callback: @escaping ((Int) -> Void)) {
        let benchmarkURL = Settings.benchMarkUrl
        Logger.log("[Proxy Delay] Testing proxy '\(proxyName)' with url: \(benchmarkURL)")
        req("/proxies/\(proxyName.encoded)/delay",
            method: .get,
            parameters: ["timeout": 5000, "url": benchmarkURL])
            .responseData { res in
                let statusCode = res.response?.statusCode ?? -1
                switch res.result {
                case let .success(value):
                    let json = JSON(value)
                    let delay = json["delay"].intValue
                    if delay > 0 {
                        Logger.log("[Proxy Delay] Proxy '\(proxyName)' succeeded: \(delay) ms, status: \(statusCode)")
                    } else {
                        let body = String(data: value, encoding: .utf8) ?? "<non-utf8 body>"
                        Logger.log("[Proxy Delay] Proxy '\(proxyName)' returned no delay, status: \(statusCode), body: \(body)", level: .warning)
                    }
                    callback(delay)
                case .failure:
                    let body = res.data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty body>"
                    Logger.log("[Proxy Delay] Proxy '\(proxyName)' failed, status: \(statusCode), error: \(res.error?.localizedDescription ?? "unknown error"), body: \(body)", level: .error)
                    callback(0)
                }
            }
    }

    static func getRules(completeHandler: @escaping ([ClashRule]) -> Void) {
        req("/rules").responseData { res in
            guard let data = try? res.result.get() else { return }
            let rule = ClashRuleResponse.fromData(data)
            completeHandler(rule.rules ?? [])
        }
    }

    static func healthCheck(proxy: ClashProviderName, completeHandler: (() -> Void)? = nil) {
        Logger.log("HeathCheck for \(proxy) started")
        req("/providers/proxies/\(proxy.encoded)/healthcheck").response { res in
            if res.response?.statusCode == 204 {
                Logger.log("HeathCheck for \(proxy) finished")
            } else {
                Logger.log("HeathCheck for \(proxy) failed:\(res.response?.statusCode ?? -1)")
            }
            completeHandler?()
        }
    }

    static func resetAutoProxyGroup(group: ClashProxyName, completeHandler: (() -> Void)? = nil) {
        Logger.log("[Proxy ReTest] Resetting auto proxy group '\(group)'")
        req("/proxies/\(group.encoded)", method: .delete).responseData { res in
            let statusCode = res.response?.statusCode ?? -1
            if statusCode == 204 {
                Logger.log("[Proxy ReTest] Auto proxy group '\(group)' reset")
            } else {
                let body = res.data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty body>"
                Logger.log("[Proxy ReTest] Failed resetting auto proxy group '\(group)', status: \(statusCode), body: \(body)", level: .warning)
            }
            completeHandler?()
        }
    }
}

// MARK: - Connections

extension ApiRequest {
    static func getConnections(completeHandler: @escaping ([ClashConnectionBaseSnapShot.Connection]) -> Void) {
        req("/connections").responseDecodable(of: ClashConnectionBaseSnapShot.self) { resp in
            switch resp.result {
            case let .success(snapshot):
                completeHandler(snapshot.connections)
            case .failure:
                completeHandler([])
            }
        }
    }

    static func closeConnection(_ id: String) {
        req("/connections/\(id)", method: .delete).response { _ in }
    }

    static func closeAllConnection() {
        if useDirectApi() {
            clash_closeAllConnections()
        } else {
            req("/connections", method: .delete).response { _ in }
        }
    }

    // MARK: - Providers

    struct AllProviders {
        var proxies = [String]()
        var rules = [String]()
    }

    static func requestExternalProviderNames(completeHandler: @escaping (AllProviders) -> Void) {
        var providers = AllProviders()
        let group = DispatchGroup()
        group.enter()
        ApiRequest.req("/providers/proxies").responseData { resp in
            switch resp.result {
            case let .success(res):
                let json = JSON(res)
                let provoders = json["providers"].dictionaryValue
                    .filter { $0.value["vehicleType"] == "HTTP" }.map(\.key)
                providers.proxies = provoders
            case let .failure(err):
                Logger.log(err.localizedDescription, level: .warning)
            }
            group.leave()
        }

        #if PRO_VERSION
            group.enter()
            ApiRequest.req("/providers/rules").responseData { resp in
                switch resp.result {
                case let .success(res):
                    let json = JSON(res)
                    let provoders = json["providers"].dictionaryValue
                        .filter { $0.value["vehicleType"] == "HTTP" }.map(\.key)
                    providers.rules = provoders
                case let .failure(err):
                    Logger.log(err.localizedDescription, level: .warning)
                }
                group.leave()
            }
        #endif
        group.notify(queue: .main) {
            completeHandler(providers)
        }
    }

    enum ProviderType {
        case proxy
        case rule
    }

    static func updateProvider(name: String, type: ProviderType, completeHandler: @escaping (Bool) -> Void) {
        let url: String
        switch type {
        case .proxy:
            url = "/providers/proxies/\(name.encoded)"
        case .rule:
            url = "/providers/rules/\(name.encoded)"
        }
        ApiRequest.req(url, method: .put).response { resp in
            if resp.response?.statusCode == 204 {
                completeHandler(true)
            } else {
                completeHandler(false)
            }
        }
    }

    static func resetFakeIpCache() {
        ApiRequest.req("/cache/fakeip/flush", method: .post).response { resp in
            Logger.log("flush fake ip: \(resp.response?.statusCode ?? -1)")
        }
    }
}

// MARK: - Stream Apis

extension ApiRequest {
    func resetStreamApis() {
        resetLogStreamApi()
        resetTrafficStreamApi()
    }

    func resetLogStreamApi() {
        loggingWebSocketRetryTimer?.invalidate()
        loggingWebSocketRetryTimer = nil
        loggingWebSocketRetryDelay = 1
        requestLog()
    }

    func resetTrafficStreamApi() {
        trafficWebSocketRetryTimer?.invalidate()
        trafficWebSocketRetryTimer = nil
        trafficWebSocketRetryDelay = 1
        requestTrafficInfo()
    }

    private func requestTrafficInfo() {
        if ApiRequest.useDirectApi() {
            cancelTrafficWatchdog()
            trafficWebSocket?.disconnect(forceTimeout: 0.5)
            return
        }
        trafficWebSocketRetryTimer?.invalidate()
        trafficWebSocketRetryTimer = nil
        trafficWebSocket?.disconnect(forceTimeout: 0.5)

        let socket = WebSocket(url: URL(string: ConfigManager.apiUrl.appending("/traffic"))!)

        for header in ApiRequest.authHeader() {
            socket.request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        socket.delegate = self
        socket.connect()
        trafficWebSocket = socket
    }

    private func requestLog() {
        if ApiRequest.useDirectApi() {
            loggingWebSocket?.disconnect(forceTimeout: 1)
            return
        }
        loggingWebSocketRetryTimer?.invalidate()
        loggingWebSocketRetryTimer = nil
        loggingWebSocket?.disconnect(forceTimeout: 1)

        let uriString = "/logs?level=".appending(ConfigManager.selectLoggingApiLevel.rawValue)
        let socket = WebSocket(url: URL(string: ConfigManager.apiUrl.appending(uriString))!)
        for header in ApiRequest.authHeader() {
            socket.request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        socket.delegate = self
        socket.callbackQueue = logQueue
        socket.connect()
        loggingWebSocket = socket
    }
}

extension ApiRequest: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        guard let webSocket = socket as? WebSocket else { return }
        if webSocket == trafficWebSocket {
            trafficWebSocketRetryDelay = 1
            armTrafficWatchdog()
            Logger.log("trafficWebSocket did Connect", level: .debug)
        } else {
            loggingWebSocketRetryDelay = 1
            Logger.log("loggingWebSocket did Connect", level: .debug)
        }
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let err = error {
            Logger.log(err.localizedDescription, level: .error)
        }

        guard let webSocket = socket as? WebSocket else { return }

        let errDesc = error?.localizedDescription ?? "clean"
        if webSocket === trafficWebSocket {
            Logger.log("trafficWebSocket did disconnect (\(errDesc))", level: .debug)
            scheduleTrafficRetry()
        } else if webSocket === loggingWebSocket {
            Logger.log("loggingWebSocket did disconnect (\(errDesc))", level: .debug)
            scheduleLogRetry()
        } else {
            Logger.log("stale websocket disconnect ignored (\(errDesc))", level: .debug)
        }
    }

    private func scheduleTrafficRetry() {
        trafficWebSocketRetryTimer?.invalidate()
        trafficWebSocketRetryTimer = Timer.scheduledTimer(
            withTimeInterval: trafficWebSocketRetryDelay, repeats: false
        ) { [weak self] _ in
            if self?.trafficWebSocket?.isConnected == true { return }
            self?.requestTrafficInfo()
        }
        trafficWebSocketRetryDelay = min(trafficWebSocketRetryDelay * 2, Self.maxRetryDelaySeconds)
    }

    private func scheduleLogRetry() {
        loggingWebSocketRetryTimer?.invalidate()
        loggingWebSocketRetryTimer = Timer.scheduledTimer(
            withTimeInterval: loggingWebSocketRetryDelay, repeats: false
        ) { [weak self] _ in
            if self?.loggingWebSocket?.isConnected == true { return }
            self?.requestLog()
        }
        loggingWebSocketRetryDelay = min(loggingWebSocketRetryDelay * 2, Self.maxRetryDelaySeconds)
    }

    private func armTrafficWatchdog() {
        let arm: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.trafficWatchdogTimer?.invalidate()
            self.trafficWatchdogTimer = Timer.scheduledTimer(
                withTimeInterval: Self.trafficWatchdogTimeoutSeconds, repeats: false
            ) { [weak self] _ in
                Logger.log("trafficWebSocket watchdog: no data for \(Self.trafficWatchdogTimeoutSeconds)s, forcing reset", level: .warning)
                self?.resetTrafficStreamApi()
            }
        }
        if Thread.isMainThread {
            arm()
        } else {
            DispatchQueue.main.async(execute: arm)
        }
    }

    private func cancelTrafficWatchdog() {
        let cancel: () -> Void = { [weak self] in
            self?.trafficWatchdogTimer?.invalidate()
            self?.trafficWatchdogTimer = nil
        }
        if Thread.isMainThread {
            cancel()
        } else {
            DispatchQueue.main.async(execute: cancel)
        }
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        guard let webSocket = socket as? WebSocket else { return }
        let json = JSON(parseJSON: text)
        if webSocket == trafficWebSocket {
            armTrafficWatchdog()
            delegate?.didUpdateTraffic(up: json["up"].intValue, down: json["down"].intValue)
        } else {
            delegate?.didGetLog(log: json["payload"].stringValue, level: json["type"].string ?? "info")
        }
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {}
}
