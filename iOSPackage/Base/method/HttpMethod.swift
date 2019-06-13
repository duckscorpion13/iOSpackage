//
//  HttpMethod.swift
//  promo
//
//  Created by DerekYang on 2018/10/11.
//  Copyright © 2018年 Kuo Yueh Chia. All rights reserved.
//

import Foundation

public class ST_ERROR_PACKET: NSObject
{
    public var systemError: Error?
    public var httpStatus: Int
    public var errorCode: Int
    public var errorMsg: String?
    
    public init(error: Error? = nil, status: Int = 0, code: Int = 0, msg: String? = nil) {
        
        self.systemError = error
        self.httpStatus = status
        self.errorCode = code
        self.errorMsg = msg
        
        super.init()
    }
}

@objc public enum EN_HTTP_TYPE: Int
{
    case EN_HTTP_TYPE_GET = 0
    case EN_HTTP_TYPE_POST
    case EN_HTTP_TYPE_PUT
    case EN_HTTP_TYPE_DELETE
}

public class HttpMethod: NSObject
{
  
    @objc public class func httpRequest(url: URL, type: EN_HTTP_TYPE = .EN_HTTP_TYPE_GET,
                                        merchant: String? = nil,
                                        params: Dictionary<String, Any>? = nil,
                                        success: @escaping (Data) -> (),
                                        failure: ((ST_ERROR_PACKET) -> ())? = nil)
    {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        var body: Data? = nil
        if let _params = params {
            if (type == .EN_HTTP_TYPE_GET) {
                components.queryItems = _params.map { (arg) -> URLQueryItem in
                    
                    let (key, value) = arg
                    return URLQueryItem(name: key, value: value as? String ?? "\(value)")
                }
            } else {
                let jsonData = try? JSONSerialization.data(withJSONObject: _params)
                body = jsonData
            }
        }
        
        guard let _url = components.url else {
            failure?(ST_ERROR_PACKET(msg: "URL Error"))
            return
        }
        
        var request = URLRequest(url: _url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let _merchant = merchant {
            request.setValue(_merchant, forHTTPHeaderField: "Merchant")
        }
   
        request.setValue("COMM3", forHTTPHeaderField: "moduleid")
        
        var method = ""
        switch type {
        case .EN_HTTP_TYPE_GET:
            method = "GET"
        case .EN_HTTP_TYPE_POST:
            method = "POST"
        case .EN_HTTP_TYPE_PUT:
            method = "PUT"
        case .EN_HTTP_TYPE_DELETE:
            method = "DELETE"
        default:
            method = "GET"
        }
        request.httpMethod = method
  
        request.httpBody = body
       
        let task = URLSession.shared.dataTask(with: request) {
            (data, response, error) in
            guard let _data = data, error == nil else {  // check for fundamental networking error
                return
            }
//                    if let dataStr = String(data: _data, encoding: .utf8) {
//                        print("data:" + dataStr)
//                    }
            if let httpStatus = response as? HTTPURLResponse {
                if httpStatus.statusCode == 200 {   // check for http errors
                    success(_data)
                } else {
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    failure?(ST_ERROR_PACKET(status: httpStatus.statusCode))
                }
            }
        }
        task.resume()
    }
}
