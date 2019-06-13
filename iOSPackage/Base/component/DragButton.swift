//
//  DragButton.swift
//  自动拖拽吸附悬浮块
//
//  Created by yanghuang on 2016/12/5.
//  Modifiied by DerekYabg on 2018/10/16.
//  Copyright © 2016年 yanghuang. All rights reserved.
//

import UIKit

class DragButton: UIButton {
    
    typealias btnClosure = (_ btn : DragButton) ->()
    
    let ANIMATION_DURATION_TIME = 0.2
    
    
    var originCenter : CGPoint?
    //是否拖拽中
    var isDragging = false

    //是否自动吸附
    var autoDocking = false

    //拖拽开始center
    var beginLocation : CGPoint?
    //长按手势
    var longPressGestureRecognizer : UILongPressGestureRecognizer?
    
    //单击回调
    var clickClosure : btnClosure? {
        willSet(newValue) {
            self.addTarget(self, action: #selector(buttonClick(_:)), for: .touchUpInside)
        }
    }
    
    var canClick = true
    
    //双击回调
    var doubleClickClosure : btnClosure?
    //拖拽回调
    var draggingClosure : btnClosure?
    //拖拽结束回调
    var dragDoneClosure : btnClosure?
    //自动吸附结束回调
    var autoDockEndClosure : btnClosure?
    
    //MARK: - 初始化
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        

    }
    
    //MARK: - 等待touchesEnded
    @objc func buttonClick(_ btn : DragButton) {
        
        let time = 0.1
        self.perform(#selector(singleClickAction(_:)), with: nil, afterDelay: time)
    }
    
    //MARK:单击响应
    
    @objc func singleClickAction(_ btn : DragButton) {
        //单击被取消 或者 拖拽、 无闭包都不执行
        if let clickClosure = self.clickClosure,
        canClick && !isDragging  {
            clickClosure(self)
        }

    }
    
    //MARK: - 拖拽开始
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        let touch = touches.first
        beginLocation = touch?.location(in: self)
        originCenter = self.center
    }
    
    //MARK: - 拖拽过程
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        isDragging = true
        let touch = touches.first
        let currentLocation : CGPoint = (touch?.location(in: self))!
        let offsetX : CGFloat = currentLocation.x - (beginLocation?.x)!
        let offsetY : CGFloat = currentLocation.y - (beginLocation?.y)!
       
        self.center = CGPoint(x: self.center.x+offsetX, y: self.center.y+offsetY)
        
        let superviewFrame : CGRect = (self.superview?.frame)!
        let frame = self.frame
        let leftLimitX = frame.size.width / 2.0
        let rightLimitX = superviewFrame.size.width - leftLimitX
        let topLimitY = frame.size.height / 2.0
        let bottomLimitY = superviewFrame.size.height - topLimitY
        
        if self.center.x > rightLimitX {
            self.center = CGPoint(x: rightLimitX, y: self.center.y)
        } else if self.center.x <= leftLimitX {
            self.center = CGPoint(x: leftLimitX, y: self.center.y)
        }
        
        if self.center.y > bottomLimitY {
            self.center = CGPoint(x: self.center.x, y: bottomLimitY)
        } else if self.center.y <= topLimitY{
            self.center = CGPoint(x: self.center.x, y: topLimitY)
        }
        //拖拽回调
        guard let draggingClosure = self.draggingClosure else {
            return
        }
        draggingClosure(self)
        
    }
    //MARK: - 拖拽结束
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event);
        
        let offsetX : CGFloat = self.center.x - (originCenter?.x)!
        let offsetY : CGFloat = self.center.y - (originCenter?.y)!
      
        self.canClick = (abs(offsetX) < 5) && (abs(offsetY) < 5)
   
        //拖拽结束回调
        if let dragDoneClosure = self.dragDoneClosure {
            dragDoneClosure(self)
        }
           
        
        
        if isDragging && autoDocking {
            
            let superviewFrame : CGRect = (self.superview?.frame)!
            let frame = self.frame
            let middleX = superviewFrame.size.width / 2.0
            
            if self.center.x >= middleX {
                UIView.animate(withDuration: ANIMATION_DURATION_TIME, animations: {
                    self.center = CGPoint(x: superviewFrame.size.width - frame.size.width / 2, y: self.center.y)
                    //自动吸附中
                }, completion: { _ in
                    //自动吸附结束回调
                    if let autoDockEndClosure = self.autoDockEndClosure {
                        autoDockEndClosure(self)
                    }
                    
                })
            } else {
                
                UIView.animate(withDuration: ANIMATION_DURATION_TIME, animations: {
                    self.center = CGPoint(x:frame.size.width / 2, y: self.center.y)
                    //自动吸附中
                }, completion: { _ in
                    //自动吸附结束回调
                    if let autoDockEndClosure = self.autoDockEndClosure {
                        autoDockEndClosure(self)
                    }
                    
                })
            }
        }
        isDragging = false
    }
    
    //MARK: - 拖拽取消
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
        super.touchesCancelled(touches, with: event)
    }
    
    
    //MARK: - 添加到keyWindow
    func addButtonToKeyWindow() {
        UIApplication.shared.keyWindow?.addSubview(self)
    }
    
    //MARK: - 移除
    func removeFromKeyWindow() {
        for view : UIView in (UIApplication.shared.keyWindow?.subviews)! {
            if view.isKind(of: DragButton.classForCoder()) {
                view.removeFromSuperview()
            }
        }
    }
    
}
