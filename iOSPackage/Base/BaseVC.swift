//
//  BaseVC.swift
//  TestApp
//
//  Created by DerekYang on 2018/5/21.
//  Modified by DerekYang on 2019/5/22.
//  Copyright © 2018 DKY. All rights reserved.
//
//  Check List
//
//v1.0
//  1. Info.plist -> App Transport Security... -> Allow Arbitrary Loads = true
//  2. optional(statusBarView.backgroundColor)
//  3. optional(JSON API URL)
//  4. optional(Push Notifications)
//  5. clearCache
//  6. windows.open handle
//  7. Fabric & Crashlytics
//  8. Layout Rotate Test in iPhoneX & <ios10 devices
//  9. support ios >= 9.0(check App size must > 6MB)
//
//v2.0
//  1. support use the other WkWebVC for windows.open
//  2. Add UserAgent deviceInfo
//  3. Info.plist -> Privacy - Camera Usage Description/Photo Library Usage & Additions Description
//  4. dynamic close button
//
//v2.0.6
//  1. openSafari()
//
//v2.1
//  1. use getDomainList()
//      if get no list ,modify ["device" : 1]
//  2. openWebView()
//  3. Info.plist -> Localized resources can be mixed = YES
//
//v2.2
//  1. Version Update Setting: Targets->General->Set Build(first : 0)
//  2. check API_LINK_URL & API_UPDATE_URL
//  3. Target -> General -> Identity ->Version = AppShellVer(2 Digit EX: "2.2")
//
//v2.3
//  1. Target -> Info -> URL Types
//  2. Appdelegate:
//        //Scheme Links
//        func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
//            if let key = url.host {
//                UIPasteboard.general.string = key
//            }
//            return true
//        }
//
//        //Universal Links
//        func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
//            if (userActivity.activityType == NSUserActivityTypeBrowsingWeb) {
//                if let webpageURL = userActivity.webpageURL,
//                let webUrlStr = webpageURL.absoluteString.decodeUrl() {
//                    let strArray = webUrlStr.components(separatedBy: "&url=")
//                    if let baseVC = application.keyWindow?.rootViewController as? BaseVC {
//                        baseVC.m_urlStr = strArray[1]
//                    }
//                    return true
//                }
//            }
//            return false
//        }
//
//        //Statistics
//        func applicationDidBecomeActive(_ application: UIApplication) {
//            if(AppShellVer.greaterThan(ver: "2.3", andEqual: true)) {
//                if let url = URL(string: API_ACTIVE_URL),
//                let uuid = UIDevice.current.identifierForVendor?.uuidString {
//                    HttpMethod.httpRequest(url: url, type: .EN_HTTP_TYPE_POST,
//                                           params: ["os" : "iOS",
//                                                    "uuid" : uuid],
//                                           success: { _ in
//                    })
//                }
//            }
//        }
//  3. set API_MERCHANT = Merchant
//  4. Scheme Link : Info.plist -> URL type -> Item 0 -> URL Schemes -> Item 0 = Merchant
//  5. Universal Link : Capabilities -> Assosiated Domain
//      SIT:
//          applinks: {Merchant}.sit-www.gfbwff.com
//      PROD:
//          applinks: {Merchant}.www.gfbwff.com

//https://www.gfbwff.com/view/install?merchant=kaiyuan&url=https://tw.yahoo.com
import UIKit
import SafariServices
import AuthenticationServices
//import AVFoundation

public let DEF_IS_GET_WPS = true// AppShellVer.greaterThan(ver: "2.1", andEqual: true)
public let DEF_IS_CHECK_VER = true// AppShellVer.greaterThan(ver: "2.2", andEqual: true)
public let DEF_IS_CHECK_FP_KEY = true// AppShellVer.greaterThan(ver: "2.3", andEqual: true)

public let DEF_IS_DO_COOKIE_PROC = false
public let API_MERCHANT = infoForKey("DEF_INI_MERCHANT")

//TCG  "http://\(API_MERCHANT).www.gfbwff.com/"
//QPK  "https://\(API_MERCHANT).www.ertyudf.com/"
public let API_DOMAIN = (1 == valueForKey("DEF_WPS_DEVICE")) ? "gfbwff" : "ertyudf"
public let API_BASE_URL = "https://\(API_MERCHANT)." + "www." + API_DOMAIN + ".com/"

public let API_ACTIVE_URL = API_BASE_URL + "api/app/activate"
public let API_LINK_URL = API_BASE_URL + "api/app/property"
public let API_UPDATE_URL = API_BASE_URL + "api/app/latest?os=ios"


public struct ST_JSON_LINK_INFO: Codable
{
    let url: String?
}

public struct ST_JSON_VERSION_INFO: Codable
{
    let os: String?
    let version: String?
    let build: Int
    let url: String?
    let description: String?
    let createdAt: String?
}


class BaseVC: WkWebVC {

    let m_color = 0//
    let m_iniWpsDomain = infoForKey("DEF_INI_DOMAIN")
//
//    "https://lbdapp.tk/test/"
//
    var m_isMute = false
    let m_merchant = API_MERCHANT//
    
    var authSession: NSObject?//SFAuthenticationSession?//ASWebAuthenticationSession?
    
    var m_isInBackground = false
    
    fileprivate func getDomainList(domainStr: String, merchant: String, callback: @escaping ([String]) -> Void = { _ in }) {
        let device = valueForKey("DEF_WPS_DEVICE")
        if let url = URL(string: domainStr + "/wps/system/domainRoute") {
            HttpMethod.httpRequest(url: url, merchant: merchant, params: ["device" : device],
                                   success:  { data in
                                    
                                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary,
                                    let value = json["value"] as? NSDictionary,
                                    let list = value["domainList"] as? [Any] {
                                        
                                        var domainList = [String]()
                                        for domainInfo in list {
                                            if let info = domainInfo as? NSDictionary,
                                                let domain = info["domainName"] as? String {
                                                if let _ = domain.range(of: "http") {
                                                    domainList.append(domain)
                                                } else {
                                                    domainList.append("https://" + domain)
                                                }
                                            }
                                        }
                                        self.setLocalWpsDomains(domainList)
//                                        print(domainList)
                                        callback(domainList)
                                    }
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.deleteLogs()
        
        self.m_isRoot = true
        
        self.setTopColor(self.m_color)
        
        if(DEF_IS_CHECK_VER) {
            self.checkVer()
        }

        if(DEF_IS_GET_WPS) {
//            if let link = UserDefaults.standard.object(forKey: USER_DEFAULT_LINK) as? String,
//            let doamins = UserDefaults.standard.object(forKey: USER_DEFAULT_DOMAINS_LIST) as? [String],
//            let time =  UserDefaults.standard.object(forKey: USER_DEFAULT_EXPIRE_TIME) as? Int {
//                let now = Int(Date().timeIntervalSince1970)
//                if(now - time > 2*24*60*60) {
//                    self.openFastLink(urls: doamins)
//                } else {
//                    if let agent = UserDefaults.standard.object(forKey: USER_DEFAULT_AGENT) as? String {
//                        self.m_urlStr = self.mergeAgentlink(agent: agent, link: link)
//                    } else {
//                        self.m_urlStr = link
//                    }
//                    self.getDomainList(domainStr: self.m_iniWpsDomain, merchant: self.m_merchant)
//                }
//            } else {
                self.getDomainList(domainStr: self.m_iniWpsDomain, merchant: self.m_merchant,
                                   callback: self.openFastLink)
//            }
        } else {
            self.m_urlStr = self.m_iniWpsDomain
        }
        
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.soloAmbient)
//            try AVAudioSession.sharedInstance().setActive(true)
//        } catch {
//            print(error)
//        }
        
        //Detect Mute
        Mute.shared.checkInterval = 0.5
//        Mute.shared.alwaysNotify = false
        Mute.shared.notify = { isMute in
            if(self.m_isInBackground) {
                return
            }
                
            if(isMute) {
                self.stopAudio()
            } else {
                if(self.m_isMute) {
                    self.playAudio()
                }
            }
            self.m_isMute = isMute
        }
        
//        let path = Bundle.main.path(forResource: "Info", ofType:"plist")!//Bundle.main.path(forResource: "GoogleService-Info", ofType:"plist")!//Bundle.main.path(forResource: "TestApp", ofType:"entitlements")!//
//        let dict = NSDictionary(contentsOfFile:path)!
//        print(dict)
       
//        print(UIDevice.current.identifierForVendor?.uuidString)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.m_isInBackground = false
        self.playAudio()
        
        self.m_closeBtn?.isHidden = self.m_isRoot
        deviceRotated()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let link = UserDefaults.standard.object(forKey: self.USER_DEFAULT_LINK) as? String,
        let agent = UserDefaults.standard.object(forKey: USER_DEFAULT_AGENT) as? String {
            let mergeUrlStr = self.mergeAgentlink(agent: agent, link: link)
            if(mergeUrlStr != self.m_urlStr) {
                self.m_urlStr = mergeUrlStr
            }
        } else {
            if let key = UIPasteboard.general.string {
//                print(key)
                self.checkKey(key)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.m_isInBackground = true
        self.stopAudio()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.deviceRotated()
    }

    
    @objc func deviceRotated()
    {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight :
            self.m_topConstraint?.constant = 0
        case .unknown, .portrait :
            self.m_topConstraint?.constant = 20
        default:
            break
        }
    }
    
    func getCookieProc(url: URL)
    {
        //Initialize auth session
        if #available(iOS 12.0, *) {
            self.authSession = ASWebAuthenticationSession(url: url,
                                                          callbackURLScheme: "",
                                                          completionHandler: { (callBack: URL?, error: Error? ) in
                                                            guard error == nil, let successURL = callBack else {
//                                                                print(error!)
                                                                UIPasteboard.remove(withName: .general)
                                                                return
                                                            }
//                                                            print(successURL.absoluteString)
                                                            if let key = successURL.host {
//                                                                print(key)
                                                                UIPasteboard.general.string = key
                                                            } else {
                                                                UIPasteboard.remove(withName: .general)
                                                            }
            })
            if let session = self.authSession as? ASWebAuthenticationSession {
                session.start()
            }
        } else if #available(iOS 11.0, *) {
            self.authSession = SFAuthenticationSession(url: url,
                                                       callbackURLScheme: "",
                                                       completionHandler: { (callBack: URL?, error: Error? ) in
                                                        guard error == nil, let successURL = callBack else {
//                                                            print(error!)
                                                            UIPasteboard.remove(withName: .general)
                                                            return
                                                        }
//                                                        print(successURL.absoluteString)
                                                        if let key = successURL.host {
//                                                            print(key)
                                                            UIPasteboard.general.string = key
                                                        } else {
                                                            UIPasteboard.remove(withName: .general)
                                                        }
            })
            if let session = self.authSession as? SFAuthenticationSession {
                session.start()
            }
        } else {
            let safariVC = SFSafariViewController(url: url)
            safariVC.delegate = self
            self.present(_: safariVC, animated: true, completion: nil)
        }
    }
    
    func checkKey(_ key: String)
    {
        guard let url = URL(string: API_LINK_URL) else {
            return
        }
        
        if(DEF_IS_CHECK_FP_KEY) {
            HttpMethod.httpRequest(url: url,
                                params: ["fp" : key],
                                success: { data in
                                    if let info = try? JSONDecoder().decode(ST_JSON_LINK_INFO.self, from: data),
                                    let urlStr = info.url {
                                       
                                        DispatchQueue.global().async {
                                            if(self.m_semaphore.wait(timeout: .distantFuture) == .success) {
                                                if let link = UserDefaults.standard.object(forKey: self.USER_DEFAULT_LINK) as? String {
                                                    let agent = urlStr.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").split(separator: ".")[0]
                                                    let orgUri = link.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").split(separator: ".")[0]
                                                    let mergeUrl = link.replacingOccurrences(of: orgUri, with: agent)
                                                    self.setAgent(String(agent))
                                                    self.m_urlStr = mergeUrl
                                                }
                                            }
                                        }
                                    }
            },
                                failure: { packet in
                                    if let url = URL(string: API_LINK_URL) {
                                        if(DEF_IS_DO_COOKIE_PROC) {
                                            self.getCookieProc(url: url)
                                        }
                                    }
            })
        }
    }
    
    func checkVer()
    {
        guard let url = URL(string: API_UPDATE_URL) else {
            return
        }
        HttpMethod.httpRequest(url: url,
                            success: { data in
                                if let info = try? JSONDecoder().decode(ST_JSON_VERSION_INFO.self, from: data),
                                let urlStr = info.url,
                                let newVer = info.version,
                                    newVer.greaterThan(ver: AppShellVer) {
                                    //handle data to redirect
                                    let downloadStr = "itms-services://?action=download-manifest&url=" + urlStr
                                    if let url = URL(string: downloadStr) {
                                        DispatchQueue.main.async {
                                            if #available(iOS 10, *) {
                                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                            } else {
                                                UIApplication.shared.openURL(url)
                                            }
                                        }
                                    }
                                }
                                        
        })
    }
}


extension BaseVC: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        controller.dismiss(animated: false, completion: nil)
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: false, completion: nil)
    }
}



