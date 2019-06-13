//
//  WkWebVC.swift
//  TestApp
//
//  Created by DerekYang on 2018/9/28.
//  Modified by DerekYang on 2019/5/22.
//  Copyright © 2018年 DKY. All rights reserved.
//


import UIKit
import WebKit
import SafariServices
import CoreData

public let AppShellVer = infoForKey("CFBundleShortVersionString")//"2.3.1"

public let DEF_FUNC_CLEAR_CACHE = "clearCache"
public let DEF_FUNC_OPEN_SAFARI = "openSafari"
public let DEF_FUNC_OPEN_WEBVIEW = "openWebView"

public let DEF_FUNC_SET_TOP_COLOR = "setTopColor"
public let DEF_FUNC_SET_LAUNCH_ON = "setLaunchOn"
public let DEF_FUNC_SET_LAUNCH_OFF = "setLaunchOff"

public let DEF_FUNC_SET_ORIENT = "setOrient"

public let DEF_FUNC_SET_KEYVALUE = "setKeyValue"
public let DEF_FUNC_GET_LOCAL_KEYVALUE = "getLocalKeyValue"
public let DEF_FUNC_GET_SESSION_KEYVALUE = "getSessionKeyValue"

public let DEF_FUNC_PRINT_LOG = "printLog"

public let DEF_IS_ERROR_LOG = false// (AppShellVer > 2.3~)

public let DEF_IS_DEBUG_MODE = false

public let DEF_IS_USE_LOADBAR = (3 == valueForKey("DEF_WPS_DEVICE"))

struct ST_URL_RESULT: Codable
{
    let name: String?
    let url: String?
}

func infoForKey(_ key: String) -> String {
    return (Bundle.main.infoDictionary?[key] as? String) ?? ""
}

func valueForKey(_ key: String) -> Int {
    return (Bundle.main.infoDictionary?[key] as? Int) ?? 1
}

class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

class WkWebVC: UIViewController {
    
    let USER_DEFAULT_DOMAINS_LIST = "USER_DEFAULT_DOMAINS_LIST"
    let USER_DEFAULT_LINK = "USER_DEFAULT_LINK"
    let USER_DEFAULT_EXPIRE_TIME = "USER_DEFAULT_EXPIRE_TIME"
    
    let USER_DEFAULT_AGENT = "USER_DEFAULT_AGENT"
    
    let m_semaphore = DispatchSemaphore.init(value: 0)
    
    var m_urlStr = "" {
        willSet {
            if let _url = URL(string: newValue) {
                let request = URLRequest(url: _url)
                    // set up the session
//                    let task = URLSession.shared.dataTask(with: request) {
//                        (data, response, error) in
//
//                        let err = error?.localizedDescription ?? ""
//                        let len = data?.count ?? -1
//                        let resp = response as? HTTPURLResponse
//                        self.saveLog(status: resp?.statusCode ?? -1, length: len, url: newValue, memo: err)
//
//                    }
//                  task.resume()
//
                DispatchQueue.main.async {
                    //                                    print("url=" + self.m_urlStr)
                    self.m_webView?.load(request)
                }
              
            }
        }
    }
    var m_orientType = 0
    var m_testCount = 0
    
    var m_isRoot = false
    var m_gotfast = false
    var m_topConstraint: NSLayoutConstraint? = nil
    
    var m_imgView: UIImageView? = nil
    @objc var m_webView: WKWebView? = nil
    var m_indicator: UIActivityIndicatorView? = nil
    
    var m_testField: UITextField? = nil
    
    var m_closeBtn: DragButton? = nil
   
    var m_debugView: UIView? = nil
    var m_tableView: UITableView? = nil
    var m_logArray: [String] = []
    
    var m_dispatchWorkItem: DispatchWorkItem? = nil
    
    private var m_progressLayer: CALayer?
    private var m_progressLabel: UILabel?
    
    lazy var m_coreDataMgr: CoreDataMgr = {
        return CoreDataMgr()
    }()
    
    lazy var m_subWebVC: WkWebVC = {
        return WkWebVC()
    }()
    
    convenience init(url: String) {
        self.init()
        self.m_urlStr = url
    }
    
    deinit {
        self.m_webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        self.m_webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupWebView()

        self.setupCloseBtn()
        
        self.m_webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        self.m_webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [.new, .old], context: nil)
        
        self.setupImageView("launch")
        
        self.setupTestField()
        
        self.setupDebugView()
      
        self.setupTestBtn()
      
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.url) {
            print("### redirect URL: ", self.m_webView?.url ?? "")
         
            self.m_testField?.text = self.m_webView?.url?.absoluteString
            
            self.m_logArray.append(self.m_webView?.url?.absoluteString ?? "")
            self.m_tableView?.reloadData()
        }
        
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            guard let changes = change else { return }
            //    请注意这里读取options中数值的方法
            let newValue = changes[NSKeyValueChangeKey.newKey] as? Double ?? 0
            
//            let oldValue = changes[NSKeyValueChangeKey.oldKey] as? Double ?? 0
            let persent = Int(newValue * 100)
            let posX = self.view.frame.width * CGFloat(newValue)/2
            DispatchQueue.main.async {
                self.m_progressLabel?.text = "\(persent)%"
                self.m_progressLayer?.frame = CGRect(x: posX, y: 0, width: self.view.frame.width, height: 10)
            }
            
            // 当进度为100%时，隐藏progressLayer并将其初始值改为0
//            if newValue == 1.0 {
//                let time1 = DispatchTime.now() + 0.4
//                let time2 = time1 + 0.1
//                DispatchQueue.main.asyncAfter(deadline: time1) {
//                    weak var weakself = self
//                    weakself?.m_progressLayer.opacity = 0
//                }
//                DispatchQueue.main.asyncAfter(deadline: time2) {
//                    weak var weakself = self
//                    weakself?.m_progressLayer.frame = CGRect(x: 0, y: 0, width: 0, height: 10)
//                }
//            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        playAudio()
        
        self.navigationController?.navigationBar.isHidden = false
        
        if let imgView = self.m_imgView{
            self.view.bringSubviewToFront(imgView)
        }
        
        if let indicator = self.m_indicator {
            self.view.bringSubviewToFront(indicator)
        }
        
        if let btn = self.m_closeBtn {
            self.view.bringSubviewToFront(btn)
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch self.m_orientType {
        case 1:
            return .portrait
        case 2:
            return .landscape
        default:
            return .all
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
//        stopAudio()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupIndicator()
    {
        if(nil == self.m_indicator) {
            self.m_indicator = UIActivityIndicatorView(style: .white)
            if let indicator =  self.m_indicator {
                indicator.color = UIColor.gray
                view.addSubview(indicator)
                indicator.translatesAutoresizingMaskIntoConstraints = false
                indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
                indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                view.bringSubviewToFront(indicator)
            }
        }
    }
    
    func clearCache(callback: String? = nil)
    {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { (records) in
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: {
//                print("clear")
                if let jsStr = callback {
                    self.m_webView?.evaluateJavaScript(jsStr)
                }
            })
        }
    }
    
    fileprivate func openSafari(url: URL)
    {
        DispatchQueue.main.async {
            if #available(iOS 10, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    fileprivate func openWebView(url: URL) {
        
//        if(self.m_subWebVC.m_urlStr != url.absoluteString) {
//            self.m_subWebVC.m_urlStr = url.absoluteString
//        }
//        self.present(self.m_subWebVC, animated: true)
        
        let vc = WkWebVC()
        vc.m_isRoot = false
        vc.setupWebView()
        vc.m_imgView?.image = UIImage(named: "loading")
        vc.m_urlStr = url.absoluteString
        self.present(vc, animated: true)
        
    }
    
    fileprivate func openWebView(request: URLRequest) {
        
        self.m_subWebVC.m_webView?.load(request)
        self.present(self.m_subWebVC, animated: true)
    }
    
    func openFastLink(urls: [String])
    {
        let q = DispatchQueue.global()
        for urlStr in urls {
            q.async {
                
                if let url = URL(string: urlStr) {
                    
                    let urlRequest = URLRequest(url: url)
                    
                    // set up the session
                    let config = URLSessionConfiguration.default
                    let session = URLSession(configuration: config)
                    
                    // make the request
                    let task = session.dataTask(with: urlRequest) {
                        (data, response, error) in
                        
//                        let err = error?.localizedDescription ?? ""
//                        let len = data?.count ?? -1
//                        let resp = response as? HTTPURLResponse
//                        self.saveLog(status: resp?.statusCode ?? -1, length: len, url: urlStr, memo: err)
                        
                        if(self.m_gotfast) {
                            return
                        }
                        
                        // check for any errors
                        guard error == nil else {
                            print(error!)
                            return
                        }
                        // make sure we got data
                        guard let _ = data else {
                            print("Error: did not receive data")
                            return
                        }
                        // parse the result as JSON, since that's what the API provides
                        
                        self.m_gotfast = true
                        
                        DispatchQueue.main.async {
                            // 程式碼片段 ...
                            if let link = urlRequest.url?.absoluteString {
//                                print("fast = \(urlStr)")
                                self.setLocalLinkAndTime(urlStr)
                                self.m_semaphore.signal()
                                if let agent = UserDefaults.standard.object(forKey: self.USER_DEFAULT_AGENT) as? String {
                                    self.m_urlStr = self.mergeAgentlink(agent: agent, link: link)
                                } else {
                                    self.m_webView?.load(urlRequest)
                                }
                            }
                        }
                    }
                    task.resume()
                }
            }
        }
    }
    
    func mergeAgentlink(agent: String, link: String) -> String {
        let orgUri = link.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").split(separator: ".")[0]
        return link.replacingOccurrences(of: orgUri, with: agent)
    }
    
    fileprivate func getUIColor(_ color: Int) -> UIColor {
        if(color > 0) {
            let red = CGFloat((color&0xFF0000)>>16) / CGFloat(0xFF)
            let green = CGFloat((color&0x00FF00)>>8) / CGFloat(0xFF)
            let blue = CGFloat(color&0x0000FF) / CGFloat(0xFF)
            return UIColor.init(red: red, green: green, blue: blue, alpha: 1.0)
        } else {
            return UIColor.white
        }
    }
    
    func setTopColor(_ color: Int) {
        if(color > 0) {
            let red = CGFloat((color&0xFF0000)>>16) / CGFloat(0xFF)
            let green = CGFloat((color&0x00FF00)>>8) / CGFloat(0xFF)
            let blue = CGFloat(color&0x0000FF) / CGFloat(0xFF)
            UIApplication.shared.statusBarView?.backgroundColor = UIColor.init(red: red, green: green, blue: blue, alpha: 1.0)
        }
    }
    
    
    func setLocalWpsDomains(_ urls: [String]) {
        UserDefaults.standard.set(urls, forKey: USER_DEFAULT_DOMAINS_LIST)
        UserDefaults.standard.synchronize()
    }
    
    func setLocalLinkAndTime(_ url: String) {
        let timeInterval = Date().timeIntervalSince1970
        let timeStamp = Int(timeInterval)
        UserDefaults.standard.set(timeStamp, forKey: USER_DEFAULT_EXPIRE_TIME)
        UserDefaults.standard.set(url, forKey: USER_DEFAULT_LINK)
        UserDefaults.standard.synchronize()
    }
    
    func setAgent(_ str: String) {
        UserDefaults.standard.set(str, forKey: USER_DEFAULT_AGENT)
        UserDefaults.standard.synchronize()
    }
    
//    func getWpsDomain() -> String? {
//        if let link = UserDefaults.standard.object(forKey: USER_DEFAULT_DOMAIN),
//        let linkStr = link as? String {
//            if let time =  UserDefaults.standard.object(forKey: USER_DEFAULT_DOMAIN_TIME) as? Int {
//                let now = Int(Date().timeIntervalSince1970)
//                return (now - time > 2*24*60*60) ? nil : linkStr
//            } else {
//                return linkStr
//            }
//        }
//        return nil
//    }
    
    func setupCloseBtn()
    {
        self.m_closeBtn = DragButton(frame: CGRect.zero)
        
        if let btn = self.m_closeBtn {
            
            let image = UIImage(named: "close")
            btn.setImage(image, for: .normal)
            //            btn.addTarget(self, action: #selector(clickClose), for: .touchUpInside)
            btn.clickClosure = {
                [weak self]
                (btn) in
                //单击回调
                self?.clickClose(sender: btn)
            }
            self.view.addSubview(btn)
            btn.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 11.0, *) {
                btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
                btn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10).isActive = true
            } else {
                // Fallback on earlier versions
                self.edgesForExtendedLayout = []
                
                btn.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
                btn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10).isActive = true
            }
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
    }
    
    @objc func clickClose(sender: UIButton)
    {
        self.dismiss(animated: true)
    }
    
    
    fileprivate func setupLoadBar(parent: UIImageView) {
      
        let barBack =  UIImageView(frame: CGRect.zero)
        let imgBar = UIImage(named: "bar")
        barBack.image = imgBar
        
        parent.addSubview(barBack)
        barBack.translatesAutoresizingMaskIntoConstraints = false
        
        barBack.heightAnchor.constraint(equalToConstant: 20).isActive = true
        barBack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        barBack.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        if #available(iOS 11.0, *) {
            barBack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true
        } else {
            barBack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10).isActive = true
        }
        
        let light =  UIImageView(frame: CGRect.zero)
        let imgLight = UIImage(named: "light")
        light.image = imgLight
        
        parent.addSubview(light)
        light.translatesAutoresizingMaskIntoConstraints = false
        
        light.heightAnchor.constraint(equalToConstant: 15).isActive = true
        light.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5).isActive = true
        light.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        light.centerYAnchor.constraint(equalTo: barBack.centerYAnchor).isActive = true
        
     
      
        // 创建名为progress的进度条
        let progress = UIView(frame: CGRect.zero)
        parent.addSubview(progress)
        //            barBack.addSubview(progress)
        progress.translatesAutoresizingMaskIntoConstraints = false
        
        progress.heightAnchor.constraint(equalToConstant: 10).isActive = true
        progress.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5).isActive = true
        progress.centerXAnchor.constraint(equalTo: barBack.centerXAnchor).isActive = true
        progress.centerYAnchor.constraint(equalTo: barBack.centerYAnchor).isActive = true
        // 之前已经提前声明了progressLayer作为实例变量，方便作为进度条修改
        self.m_progressLayer = CALayer()
        self.m_progressLayer?.backgroundColor = UIColor.black.cgColor
        //self.m_progressLayer?.backgroundColor = self.getUIColor(0x11EFF0).cgColor
        progress.layer.cornerRadius = 20
        progress.layer.masksToBounds = true
//        progress.backgroundColor = .black
        progress.layer.addSublayer(self.m_progressLayer!)
        
        self.m_progressLabel = UILabel(frame: CGRect.zero)
        if let lbl = self.m_progressLabel {
            lbl.textColor = .white
            parent.addSubview(lbl)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            lbl.heightAnchor.constraint(equalToConstant: 35).isActive = true
            lbl.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            lbl.bottomAnchor.constraint(equalTo: progress.topAnchor).isActive = true
        }
        parent.bringSubviewToFront(barBack)

        self.m_progressLabel?.text = "0%"
        self.m_progressLayer?.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 10)
        
    }
    
    func setupImageView(_ imgName: String) {
        if let _ = self.m_imgView {
            return
        }
        
        
        self.m_imgView = UIImageView(frame: CGRect.zero)
        if let imgView = self.m_imgView {
            
            let img = UIImage(named: imgName)
            imgView.image = img
            
            self.view.addSubview(imgView)
            imgView.translatesAutoresizingMaskIntoConstraints = false
   
            imgView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            imgView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            imgView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            imgView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            
            imgView.isHidden = false
            
            if(DEF_IS_USE_LOADBAR) {
                self.setupLoadBar(parent: imgView)
            } else {
                self.setupIndicator()
            }
        }
    }
    
    func socialMedia(msg: String, url: String) {
        let activityController = UIActivityViewController(activityItems: [msg, URL(string: url) ?? ""],
                                                          applicationActivities: nil)
        let excludeActivities = [UIActivity.ActivityType.postToWeibo,
                                 UIActivity.ActivityType.postToTencentWeibo,
                                 UIActivity.ActivityType.print,
                                 UIActivity.ActivityType.saveToCameraRoll]
        
        activityController.excludedActivityTypes = excludeActivities
        
        activityController.completionWithItemsHandler = { (type, completed, items, error) in
            if let type = type {
                print("completed. type=\(type.rawValue) error=\(error.debugDescription)")
            }
            if completed {
                print("success")
            }
            activityController.completionWithItemsHandler = nil
        }
        self.present(activityController, animated: true, completion: nil)        
    }
    
    
    // MARK: ////// Test Function //////
    @objc func clickTest1() {
        
        let jsStr = ""
//        let key = "AAAAA"
//        let value = "abccdefg"
//        let funcName = "setKeyValue"
//        let jsStr =  "window.webkit.messageHandlers.\(funcName).postMessage({key: '\(key)', value: '\(value)'});"
//
//        let jsStr = "window.webkit.messageHandlers.openSafari.postMessage({url: 'http://52.184.82.25/?utm_source=homescreen&utm_medium=shortcut#/',type: 2})"
        
//        let jsStr = "window.webkit.messageHandlers.setLaunchOn.postMessage(null);" + "window.webkit.messageHandlers.setLaunchOff.postMessage({delay: 5000});"
//        self.m_webView?.evaluateJavaScript(jsStr)
        
//        let msg = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" + "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
//        let jsStr =  "window.webkit.messageHandlers.printLog.postMessage({msg: '\(msg)'});"


//        var jsStr =  "window.webkit.messageHandlers.setLaunchOff.postMessage(null);" +
//        "window.webkit.messageHandlers.setTopColor.postMessage({color: 0xF0F018});"
//        if(m_testCount % 2 == 1) {
//            jsStr =  "window.webkit.messageHandlers.setLaunchOn.postMessage(null);" +
//            "window.webkit.messageHandlers.setTopColor.postMessage({color: 0x010101});"
//        }

      
//        let logs = [ST_ERROR_LOG(time: "1234", url: "https://tw.yahoo.com", status: 200, length: 20, memo: "fafsdfdgsg")]
    
//        let logs = loadLogs()
//        do {
//            let jsonData = try JSONEncoder().encode(logs)
//            let jsonString = String(data: jsonData, encoding: .utf8)!
//            print(jsonString)
//
//            // and decode it back
////            let decodedSentences = try JSONDecoder().decode([ST_ERROR_LOG].self, from: jsonData)
////            print(decodedSentences)
//        } catch { print(error) }
//        print(self.m_webView?.url?.absoluteString ?? "")
//        self.m_webView?.evaluateJavaScript("document.documentElement.outerHTML.toString()",
//                                   completionHandler: { (html: Any?, error: Error?) in
//                                    if let str = html {
//                                        print(str)
//                                    }
//        })
      
//        self.m_testCount += 1
//        self.m_testCount %= 3
//        let jsStr =  "window.webkit.messageHandlers.setOrient.postMessage({type:\(self.m_testCount)});"

//
//        let jsStr = "localStorage.name = 'caibin';localStorage;"
//
        
//        saveErrorLog(time: timeStamp, status: m_testCount, length: m_testCount, url: timeStamp)
//        loadErrorLog()
//        if(m_testCount % 3 == 2) {
//            deleteErrorLog()
//        }
    
        self.m_webView?.evaluateJavaScript(jsStr)
    }
    
    @objc func clickTest2() {
  
        let key = "AAAAA"
        let funcName = "getSessionKeyValue"//"getLocalKeyValue"
        let jsStr =  "window.webkit.messageHandlers.\(funcName).postMessage({key: '\(key)'});" +
                     "var value = sessionStorage.getItem('\(key)');" +
                     "window.webkit.messageHandlers.printLog.postMessage({msg: value});"
        
        self.m_webView?.evaluateJavaScript(jsStr)
    }
    
    fileprivate func setupTableAndClear(parent: UIView) {
   
        if let _ = self.m_tableView {
            return
        }
        
        let btn = UIButton(frame: CGRect.zero)
        btn.setTitle("CLEAR", for: .normal)
        btn.addTarget(self, action: #selector(self.clearLog), for: .touchDown)
        
        parent.addSubview(btn)
        parent.bringSubviewToFront(btn)
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 35).isActive = true
        btn.widthAnchor.constraint(equalToConstant: 60).isActive = true
        btn.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
        btn.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
        
        self.m_tableView =  UITableView(frame: CGRect.zero)
        
        if let tv = self.m_tableView {
            tv.dataSource = self
            tv.delegate = self
            
            tv.rowHeight = UITableView.automaticDimension
            tv.estimatedRowHeight = 25
            
            tv.register(MyTableViewCell.self, forCellReuseIdentifier: "MyCell")
            
            parent.addSubview(tv)
            parent.bringSubviewToFront(tv)
            
            tv.translatesAutoresizingMaskIntoConstraints = false
            
            tv.topAnchor.constraint(equalTo: btn.bottomAnchor).isActive = true
            if #available(iOS 11.0, *) {
                tv.bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor).isActive = true
            } else {
                tv.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
            }
            tv.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
            tv.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
        }
    }
    
    
    @objc fileprivate func clearLog() {
        self.m_logArray.removeAll()
        self.m_tableView?.reloadData()
    }
    
    fileprivate func setupTestField() {
        if let _ = self.m_testField {
            return
        }
        self.m_testField =  UITextField(frame: CGRect.zero)

        if let field = self.m_testField {
            self.view.addSubview(field)
            field.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 11.0, *) {
                field.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            } else {
                field.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            }
            field.heightAnchor.constraint(equalToConstant: 25).isActive = true
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            
            field.isEnabled = false
            field.isHidden = true
        }
    }
    
    fileprivate func setupDebugView() {
        if let _ = self.m_debugView {
            return
        }
        
        self.m_debugView = UIView(frame: CGRect.zero)
        if let debugView = self.m_debugView {
            debugView.isHidden = !DEF_IS_DEBUG_MODE
            self.view.addSubview(debugView)
            self.view.bringSubviewToFront(debugView)
            
            debugView.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 11.0, *) {
                debugView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50).isActive = true
            } else {
                debugView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50).isActive = true
            }
            debugView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3).isActive = true
            debugView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            debugView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            
            self.setupTableAndClear(parent: debugView)
        }
    }
    
    fileprivate func setupTestBtn() {
        let btn = UIButton(frame: CGRect(x: 10, y: 10, width: 100, height: 50))
        btn.setTitle("Test Click1", for: .normal)
        btn.addTarget(self, action: #selector(self.clickTest1), for: .touchDown)
        btn.isHidden = !DEF_IS_DEBUG_MODE
        self.view.addSubview(btn)
        self.view.bringSubviewToFront(btn)
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        } else {
            btn.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        }
        btn.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        
        let btn2 = UIButton(frame: CGRect(x: 10, y: 10, width: 100, height: 50))
        btn2.setTitle("Test Click2", for: .normal)
        btn2.addTarget(self, action: #selector(self.clickTest2), for: .touchDown)
        btn2.isHidden = !DEF_IS_DEBUG_MODE
        self.view.addSubview(btn2)
        self.view.bringSubviewToFront(btn2)
        
        btn2.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            btn2.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        } else {
            btn2.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        }
        btn2.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }
    
    func saveLog(status: Int = -1, length: Int = -1, url: String, memo: String = "") {
        if(!DEF_IS_ERROR_LOG) {
            return
        }

        let managedContext = self.m_coreDataMgr.managedObjectContext
        let entity = NSEntityDescription.entity(forEntityName: "ErrorLog", in: managedContext)!

        // 使用自動產生的類別
        let log = ErrorLog(entity: entity, insertInto: managedContext)
        let timeInterval = Date().timeIntervalSince1970
        let timeStamp = "\(Int(timeInterval))"
        log.status = Int32(status)
        log.url = url
        log.time = timeStamp
        log.length = Int32(length)
        log.memo = memo

        // 將資料寫入資料庫
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func loadLogs() -> [ST_ERROR_LOG] {
        let managedContext = self.m_coreDataMgr.managedObjectContext
        
        let fetchRequest = NSFetchRequest<ErrorLog>(entityName: "ErrorLog")
        var fetchResult = [ErrorLog]()
        do {
            fetchResult = try managedContext.fetch(fetchRequest).reversed()
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
   
        var logs = [ST_ERROR_LOG]()
        for each in fetchResult {
            let log = ST_ERROR_LOG(time: each.time, url: each.url, status: Int(each.status), length: Int(each.length), memo: each.memo)
            logs.append(log)
        }
        return logs
    }
    
    func deleteLogs() {
        let managedContext = self.m_coreDataMgr.managedObjectContext
        let fetchRequest = NSFetchRequest<ErrorLog>(entityName: "ErrorLog")
        if let fetchResult = try? managedContext.fetch(fetchRequest) {
            for log in fetchResult {
                managedContext.delete(log)
            }
        }
    }
    
   
}

// MARK: ////// H5 Audio //////
extension WkWebVC {
    func playAudio() {
        let jsStr =  "window.tcPlayAudio();"
        self.m_webView?.evaluateJavaScript(jsStr)
    }
    
    func stopAudio() {
        let jsStr =  "window.tcStopAudio();"
        self.m_webView?.evaluateJavaScript(jsStr)
    }
}

// MARK: ////// Wk Delegate //////
extension WkWebVC: WKNavigationDelegate, WKUIDelegate
{
    
    func setupWebView() {
        
        if let _ = self.m_webView {
            return
        }
        
        let myConfig = WKWebViewConfiguration()
        myConfig.allowsInlineMediaPlayback = true
        myConfig.userContentController.add(self, name: DEF_FUNC_CLEAR_CACHE)
        myConfig.userContentController.add(self, name: DEF_FUNC_OPEN_SAFARI)
        myConfig.userContentController.add(self, name: DEF_FUNC_OPEN_WEBVIEW)
        myConfig.userContentController.add(self, name: DEF_FUNC_SET_TOP_COLOR)
        myConfig.userContentController.add(self, name: DEF_FUNC_SET_LAUNCH_ON)
        myConfig.userContentController.add(self, name: DEF_FUNC_SET_LAUNCH_OFF)
        myConfig.userContentController.add(self, name: DEF_FUNC_SET_ORIENT)
        myConfig.userContentController.add(self, name: DEF_FUNC_PRINT_LOG)
        
        myConfig.userContentController.add(self, name: DEF_FUNC_SET_KEYVALUE)
        myConfig.userContentController.add(self, name: DEF_FUNC_GET_LOCAL_KEYVALUE)
        myConfig.userContentController.add(self, name: DEF_FUNC_GET_SESSION_KEYVALUE)
        
//        myConfig.userContentController.add(self, name: "log")
//        let jsCode = "console.log = (function(oriLogFunc){ return function(str) { window.webkit.messageHandlers.log.postMessage(str); oriLogFunc.call(console,str);}})(console.log);" +
//                    "console.warn = (function(oriLogFunc){ return function(str) { window.webkit.messageHandlers.log.postMessage(str); oriLogFunc.call(console,str);}})(console.warn);" +
//                    "console.error = (function(oriLogFunc){ return function(str) { window.webkit.messageHandlers.log.postMessage(str); oriLogFunc.call(console,str);}})(console.error);"
//
//        myConfig.userContentController.addUserScript(WKUserScript(source: jsCode, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        if #available(iOS 11.0, *) {
            myConfig.mediaTypesRequiringUserActionForPlayback = .init(rawValue: 0)
        } else {
            myConfig.requiresUserActionForMediaPlayback = false
        }
        
        self.m_webView = FullScreenWKWebView(frame: CGRect.zero, configuration: myConfig)
        if let webView = self.m_webView {
            
            let arrVer = AppShellVer.components(separatedBy: ".")
            let mainVer = Int(arrVer[0]) ?? 1
            if(mainVer >= 2) {
                // UserAgent EX: "Mozilla/5.0 (iPhone; CPU iPhone OS 12_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/16A366"
                let deviceModel = UIDevice.current.model
                let systemName = UIDevice.current.systemName
                let sysVersion = UIDevice.current.systemVersion
                let modelName = UIDevice.current.modelName
                let uuid = UIDevice.vkKeychainIDFV() ?? ""
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                webView.customUserAgent =  "Mozilla/5.0 (\(deviceModel);\(systemName) \(sysVersion)) AppleWebKit (KHTML, like Gecko) Mobile AppShellVer:\(AppShellVer) Build:\(build) model:\(modelName) UUID:\(uuid)"
            }
            
            webView.scrollView.bounces = false
            webView.allowsBackForwardNavigationGestures = true
            webView.navigationDelegate = self
            
            webView.uiDelegate = self
            
            self.view.addSubview(webView)
            webView.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 11.0, *) {
                webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            } else {
//                // Fallback on earlier versions
                self.edgesForExtendedLayout = []
                self.m_topConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)
                webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
                self.m_topConstraint?.isActive = true
            }
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            
            if(self.m_urlStr != "") {
                let str = self.m_urlStr
                self.m_urlStr = str
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        //        print("didStartProvisionalNavigation")
        m_indicator?.startAnimating()
        self.m_dispatchWorkItem?.cancel()
        
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        //        print("didCommit")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //        print("didFinish")
//        if (!webView.isLoading) {
            self.m_indicator?.stopAnimating()
            let delay = self.m_isRoot ? 5.0 : 1.0
            self.m_dispatchWorkItem = DispatchWorkItem {
                self.m_imgView?.isHidden = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute:  self.m_dispatchWorkItem!)
//            webView.evaluateJavaScript("document.readyState") {
//                (readyState, _) in
//                if let state = readyState as? String,
//                (state == "complete") {
//                    self.m_indicator?.stopAnimating()
//                    self.m_imgView?.isHidden = true
//                }
////                print(readyState)
//            }
//        }
        //        webView.evaluateJavaScript("navigator.userAgent")  { (result, error) in
        //            if let _result = result as? String {
        //                print(_result)
        //            }
        //        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let msg = "didFail, error: \(error.localizedDescription)"
        self.m_logArray.append(msg)
        self.m_tableView?.reloadData()
        
        let err = error as NSError
        self.saveLog(status: err.code, url: webView.url?.absoluteString ?? "", memo: err.localizedDescription)
        
        m_indicator?.stopAnimating()
        m_imgView?.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let msg = "didFailProvisionalNavigation, error:  \(error.localizedDescription), url: \(webView.url?.absoluteString ?? "")"
        self.m_logArray.append(msg)
        self.m_tableView?.reloadData()
        
        let err = error as NSError
        self.saveLog(status: err.code, url: webView.url?.absoluteString ?? "", memo: err.localizedDescription)
        
        m_indicator?.stopAnimating()
        m_imgView?.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        //        print("didReceiveServerRedirectForProvisionalNavigation")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let url = navigationResponse.response.url {
            //            print("decidePolicyFor navigationResponse response url: \(url.absoluteString)")
            
            if url.absoluteString.hasSuffix("close.html") {
                m_webView?.isHidden = true
            }
//            print(navigationResponse.response.url?.absoluteString)
        }
        
        if let resp = navigationResponse.response as? HTTPURLResponse {
            print(resp.allHeaderFields)
            print("url = \(resp.url?.absoluteString ?? "")  status = \(resp.statusCode)  length = \(resp.expectedContentLength)")
            
            self.saveLog(status: resp.statusCode, length: Int(resp.expectedContentLength), url: resp.url?.absoluteString ?? "")
            
            if(resp.statusCode != 200) {
                print("")
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, cred)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
       
        guard let url = navigationAction.request.url else {
            return nil
        }
        
//        guard let frame = navigationAction.targetFrame, frame.isMainFrame else {
//            self.openWebView(request: navigationAction.request)
//            return nil
//        }
        
        if(url.absoluteString.prefix(4).lowercased() == "http") {
            self.openWebView(url: url)
        } else {
            self.openSafari(url: url)
        }
        
        return nil
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView)
    {
        webView.reload()
    }
    
//    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
//    {
//        // 判断服务器采用的验证方法
//        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
//            if challenge.previousFailureCount == 0 {
//                // 如果没有错误的情况下 创建一个凭证，并使用证书
//                let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
//                completionHandler(.useCredential, credential)
//            } else {
//                // 验证失败，取消本次验证
//                completionHandler(.cancelAuthenticationChallenge, nil)
//            }
//        } else {
//            completionHandler(.cancelAuthenticationChallenge, nil)
//        }
//    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
         print("An error from web view: \(message)")
    }
}

// MARK: ////// WKScriptMessageHandler //////
extension WkWebVC: WKScriptMessageHandler
{
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
    {
        self.m_logArray.append("H5 call " + message.name)

//        print(message.name)
        if message.name == DEF_FUNC_CLEAR_CACHE {
            if let dic = message.body as? NSDictionary,
            let callback = dic["callback"] as? String {
                self.clearCache(callback: callback)
            } else {
                self.clearCache()
            }
        } else if message.name == DEF_FUNC_OPEN_SAFARI {
            if let dic = message.body as? NSDictionary,
            let urlStr = dic["url"] as? String,
            let data = urlStr.data(using: String.Encoding.utf8),
            let url = URL(dataRepresentation: data, relativeTo: nil) {
//            let url = URL(string: urlStr) {
                let type = dic["type"] as? Int ?? 1
                if(type == 1) {
                    self.openSafari(url: url)
                } else {
                    let safariVC = SFSafariViewController(url: url)
                    self.present(_: safariVC, animated: true)
                }
            }
        } else if message.name == DEF_FUNC_OPEN_WEBVIEW {
            if let dic = message.body as? NSDictionary,
            let urlStr = dic["url"] as? String,
            let data = urlStr.data(using: String.Encoding.utf8),
            let url = URL(dataRepresentation: data, relativeTo: nil) {
                self.openWebView(url: url)
            }
        } else if message.name == DEF_FUNC_SET_TOP_COLOR {
            if let dic = message.body as? NSDictionary,
            let color = dic["color"] as? Int {
                self.setTopColor(color)
            }
        } else if message.name == DEF_FUNC_SET_LAUNCH_ON {
            self.m_imgView?.isHidden = false
        } else if message.name == DEF_FUNC_SET_LAUNCH_OFF {
            if let dic = message.body as? NSDictionary,
            let delay = dic["delay"] as? Int {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                    self.m_imgView?.isHidden = true
                }
            } else {
                 self.m_imgView?.isHidden = true
            }
        } else if message.name == DEF_FUNC_SET_ORIENT {
            if let dic = message.body as? NSDictionary,
            let type = dic["type"] as? Int {
                self.m_orientType = type
            }
        } else if message.name == DEF_FUNC_PRINT_LOG {
//            print(message.body)
            self.m_debugView?.isHidden = false
            if let dic = message.body as? NSDictionary,
            let msg = dic["msg"] as? String {
                self.m_logArray.append(msg)
            }
        } else if message.name == DEF_FUNC_SET_KEYVALUE {
            if let dic = message.body as? NSDictionary,
            let key = dic["key"] as? String,
            let value = dic["value"] as? String {
                UserDefaults.standard.set(value, forKey: key)
                UserDefaults.standard.synchronize()
            }
        } else if message.name == DEF_FUNC_GET_LOCAL_KEYVALUE {
            if let dic = message.body as? NSDictionary,
            let key = dic["key"] as? String,
            let value = UserDefaults.standard.object(forKey: key) as? String {
                let jsStr = "localStorage.setItem('\(key)', '\(value)')"
                self.m_webView?.evaluateJavaScript(jsStr)
            }
        } else if message.name == DEF_FUNC_GET_SESSION_KEYVALUE {
            if let dic = message.body as? NSDictionary,
            let key = dic["key"] as? String,
            let value = UserDefaults.standard.object(forKey: key) as? String {
                let jsStr = "sessionStorage.setItem('\(key)', '\(value)')"
                self.m_webView?.evaluateJavaScript(jsStr)
            }
        }
        self.m_tableView?.reloadData()
        self.m_tableView?.scrollToRow(at: IndexPath(row: self.m_logArray.count - 1, section: 0), at: .bottom, animated: false)
    }
}

extension WkWebVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        print("Num: \(indexPath.row)")
//        print("Value: \(m_logArray[indexPath.row])")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return m_logArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell")! as! MyTableViewCell
//        cell.nameLabel.text = "\(indexPath.row)"
        cell.detailLabel.text = "\(m_logArray[indexPath.row])"
        return cell
    }
}

extension WkWebVC {
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            print("shake start")
            self.m_testField?.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.m_testField?.isHidden = true
            }
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            print("shake end")
        }
    }
}

//MARK: ////// 判斷版號 //////
extension String {
    func greaterThanBundleVer() -> Bool {
        if let infoDictionary = Bundle.main.infoDictionary,
            let local = infoDictionary["CFBundleShortVersionString"] as? String,
            let build = infoDictionary["CFBundleVersion"] as? String {
            let result = (local + "." + build).compare(self, options: .numeric)
            //            print(local + "." + build)
            if(local == self) {
                return false
            } else {
                return result == .orderedAscending
            }
        }
        return true
    }
    
    func greaterThan(ver: String, andEqual: Bool = false) -> Bool
    {
        if(ver == self) {
            return andEqual
        } else {
            let result = ver.compare(self, options: .numeric)
            return result == .orderedAscending
        }
    }
    
    //handle URL
    func encodeUrl() -> String?
    {
        return self.addingPercentEncoding( withAllowedCharacters: .urlQueryAllowed)
    }
    func decodeUrl() -> String?
    {
        return self.removingPercentEncoding
    }
}


extension UIDevice {
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
}



extension UIApplication {
    var statusBarView: UIView? {
        if responds(to: Selector(("statusBar"))) {
            return value(forKey: "statusBar") as? UIView
        }
        return nil
    }
}

