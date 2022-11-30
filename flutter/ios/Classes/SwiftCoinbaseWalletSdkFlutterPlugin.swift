import Flutter
import UIKit
import CoinbaseWalletSDK

public class SwiftCoinbaseWalletSdkFlutterPlugin: NSObject, FlutterPlugin {
    private static let success = "{ \"success\": true}"
    
    private var mwpClient: MWPClient? = nil
    
    public override init() {}
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "coinbase_wallet_sdk", binaryMessenger: registrar.messenger())
        let instance = SwiftCoinbaseWalletSdkFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            if (call.method == "configure") {
                return configure(call: call, result: result)
            }
            
            if (call.method == "initiateHandshake") {
                return try initiateHandshake(call: call, result: result)
            }
            
            if (call.method == "makeRequest") {
                return try makeRequest(call: call, result: result)
            }
            
            if (call.method == "resetSession") {
                return resetSession(call: call, result: result)
            }
            
            if (call.method == "isAppInstalled") {
                return isAppInstalled(result: result)
            }
            
            if (call.method == "getWallets") {
                return try getWallets(result: result)
            }
            
            if (call.method == "connectWallet") {
                return connectWallet(call: call, result: result)
            }
        } catch {
            result(FlutterError(code: "handle", message: error.localizedDescription, details: nil))
            return
        }
        
        result(FlutterMethodNotImplemented)
    }
    
    private func isAppInstalled(result: @escaping FlutterResult) {
        result(CoinbaseWalletSDK.isCoinbaseWalletInstalled())
    }
    
    private func connectWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args =  call.arguments as? String else {
            result(FlutterError(code: "configure", message: "Invalid arguments", details: nil))
            return
        }
        let jsonData = Data(args.utf8)
        let decoder = JSONDecoder()
        do {
            let wallet = try decoder.decode(Wallet.self, from: jsonData)
            self.mwpClient = MWPClient.getInstance(to: wallet)
            result(SwiftCoinbaseWalletSdkFlutterPlugin.success)
        } catch {
            result(FlutterError(code: "configure", message: "Filed connecting to wallet", details: nil))
        }
    }
    
    private func configure(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let callback = args["callback"] as? String,
            let callbackURL = URL(string: callback)
        else {
            result(FlutterError(code: "configure", message: "Invalid arguments", details: nil))
            return
        }
        CoinbaseWalletSDK.configure(callback: callbackURL)
        CoinbaseWalletSDK.appendVersionTag("flutter")
        
        result(SwiftCoinbaseWalletSdkFlutterPlugin.success)
    }
    
    private func initiateHandshake(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        var actions = [Action]()
        
        if let args = call.arguments as? String, let jsonData = args.data(using: .utf8) {
            actions = try JSONDecoder().decode([Action].self, from: jsonData)
        }
        
        guard let client = self.mwpClient else {
            result(FlutterError(code: "initiate handshake", message: "Client can not be null", details: nil))
            return
        }
        
        client.initiateHandshake(initialActions: actions) { responseResult, account in
            self.handleResponse(
                code: "initiateHandshake",
                responseResult: responseResult,
                account: account,
                result: result
            )
        }
    }
    
    private func makeRequest(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        guard
            let args = call.arguments as? String,
            let jsonData = args.data(using: .utf8)
        else {
            result(FlutterError(code: "makeRequest", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let client = self.mwpClient else {
            result(FlutterError(code: "make request", message: "Client can not be null", details: nil))
            return
        }
        
        let request = try JSONDecoder().decode(Request.self, from: jsonData)
        
        client.makeRequest(request) { responseResult in
            self.handleResponse(
                code: "makeRequest",
                responseResult: responseResult,
                account: nil,
                result: result
            )
        }
    }
    
    private func resetSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let client = self.mwpClient else {
            result(FlutterError(code: "reset session", message: "Client can not be null", details: nil))
            return
        }
        let responseResult = client.resetSession()
        
        switch responseResult {
        case .success:
            result(SwiftCoinbaseWalletSdkFlutterPlugin.success)
        case .failure(let error):
            result(FlutterError(code: "resetSession", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleResponse(
        code: String,
        responseResult: ResponseResult,
        account: Account?,
        result: @escaping FlutterResult
    ) {
        do {
            switch responseResult {
            case .success(let returnValues):
                var toFlutter = [[String: Any]]()
                
                returnValues.content.forEach { it in
                    var response = [String: Any]()
                    
                    if let account = account {
                        response["account"] = [
                            "chain": account.chain,
                            "networkId": account.networkId,
                            "address": account.address
                        ]
                    }
                    switch it {
                    case .success(let value):
                        response["result"] = value.rawValue
                    case .failure(let error):
                        response["error"] = ["code": error.code, "message": error.message]
                    }
                    
                    toFlutter.append(response)
                }
                
                let data = try JSONSerialization.data(withJSONObject: toFlutter, options: [])
                let jsonString = String(data: data, encoding: .utf8)!
                
                result(jsonString)
            case .failure(let error):
                result(FlutterError(code: code, message: error.localizedDescription, details: nil))
            }
        } catch {
            result(FlutterError(code: code, message: error.localizedDescription, details: nil))
        }
    }
    
    private func getWallets(result: @escaping FlutterResult) throws {
        let defaultWallets = Wallet.defaultWallets()
        let encodedData = try JSONEncoder().encode(defaultWallets)
        let jsonString = String(data: encodedData, encoding: .utf8)
        result(jsonString)
    }
}
