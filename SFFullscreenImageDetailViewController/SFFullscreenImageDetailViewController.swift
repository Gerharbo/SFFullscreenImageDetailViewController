//
//  SFFullscreenImageDetailViewController.swift
//  Databox
//
//  Created by Jan Haložan on 12/08/15.
//  Copyright (c) 2015 Jan Haložan. All rights reserved.
//

import UIKit
import Foundation
import QuartzCore

public class SFFullscreenImageDetailViewController: UIViewController, UIScrollViewDelegate {
    let image: UIImage
    let originFrame: CGRect
    var originalView: UIImageView!
    public var imageCornerRadius:CGFloat = 5
    public var targetRect:CGRect?
    public var contentMode = UIViewContentMode.scaleAspectFit
    
    let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.layer.masksToBounds = false
        view.minimumZoomScale = 1
        view.maximumZoomScale = 1.5
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        
        return view
    }()
    
    let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "close_button"), for: UIControlState())
        
        return button
    }()
    
    var tintColor = UIColor.black
    var retainHolder: SFFullscreenImageDetailViewController!
    let animator = UIDynamicAnimator()
    var tapRecognizer:UITapGestureRecognizer?
    
    let imageView: UIImageView = {
        let view = UIImageView()
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        view.autoresizingMask = [UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleRightMargin]
        
        return view
    }()
    
    
    public init (imageView view: UIImageView) {
        self.originalView = view
        let superview:UIView = UIApplication.shared.keyWindow!
        var visibleRect = view.bounds
        
        visibleRect = superview.convert(visibleRect, from: view)
        visibleRect = visibleRect.intersection(superview.bounds)
        
        if visibleRect.origin.x.isInfinite || visibleRect.origin.y.isInfinite {
            visibleRect = CGRect()
        }
        
        self.originFrame = visibleRect
        self.imageView.contentMode = view.contentMode
        self.image = view.image!.copy() as! UIImage
        
        super.init(nibName: nil, bundle: nil)
        
        self.closeButton.addTarget(self, action: #selector(self.closeTapped(_:)), for: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.image = aDecoder.decodeObject(forKey: "image") as! UIImage
        self.originFrame = aDecoder.decodeCGRect(forKey: "originFrame")
        
        super.init(coder: aDecoder)
    }
    
    override public func loadView() {
        let window = UIApplication.shared.keyWindow!
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        
        UIApplication.shared.keyWindow?.rootViewController?.addChildViewController(self)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        self.view = view
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        //Additional setup
        self.scrollView.frame = targetRect ?? CGRect(x: 15, y: 60, width: self.view.bounds.width - 30, height: self.view.bounds.height - 80)
        self.scrollView.delegate = self
        self.view.addSubview(self.scrollView)
        
        self.closeButton.frame = CGRect(x: 0, y: 20, width: 50, height: 50)
        self.view.addSubview(self.closeButton)
        
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGestureCallback(_:)))
        self.imageView.addGestureRecognizer(recognizer)
        
        self.tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.zoomTap(_:)))
        tapRecognizer?.numberOfTapsRequired = 2
        self.imageView.addGestureRecognizer(tapRecognizer!)
    }
    
    public func presentInCurrentKeyWindow() {
        self.view.layer.backgroundColor = UIColor.clear.cgColor
        
        self.retainHolder = self
        self.originalView.isHidden = true
        
        let height = self.scrollView.bounds.width/self.image.size.width * self.image.size.height
        let newFrame = CGRect(x: self.originFrame.origin.x, y: self.originFrame.origin.y, width: self.scrollView.bounds.width, height: height)
        
        self.imageView.frame = self.originalView.convert(self.originalView.frame, to: self.view)
        self.imageView.image = self.image
        self.scrollView.addSubview(imageView)
        self.scrollView.contentSize = self.imageView.frame.size
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 5, options: .curveEaseOut, animations: {
            
            self.imageView.frame = newFrame
            self.imageView.center = CGPoint(x: self.scrollView.bounds.midX, y: self.scrollView.bounds.midY)
            self.view.layer.backgroundColor = self.tintColor.cgColor
            self.imageView.layer.cornerRadius = self.imageCornerRadius
            //line below -apply corner radius if source image has corner radius
            self.imageView.layer.masksToBounds = self.imageCornerRadius != 0 ? true : false

            self.imageView.contentMode = self.contentMode
        }, completion: nil)
    }
    
    func zoomTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self.imageView)
        if self.imageView.point(inside: location, with: nil) {
            if self.scrollView.zoomScale == 1 {
                self.scrollView.setZoomScale(1.5, animated: true)
            } else {
                self.scrollView.setZoomScale(1, animated: true)
            }
        }
    }
    
    func panGestureCallback(_ sender: UIPanGestureRecognizer) {
        if self.scrollView.zoomScale != 1 {
            return
        }
        
        let view = sender.view!
        let translation = sender.translation(in: view)
        sender.setTranslation(CGPoint.zero, in: view)
        
        switch sender.state {
        case .began:
            self.animator.removeAllBehaviors()
        case .changed:
            var center = view.center
            center.x += translation.x
            center.y += translation.y
            view.center = center
            
            let viewCenterDistanceFromEdge = self.view.center.y * self.view.center.y + self.view.center.x * self.view.center.x
            let diffY = self.view.center.y - view.center.y
            let diffX = self.view.center.x - view.center.x
            let imageCenterDistanceFromCenter = diffY * diffY + diffX * diffX
            let percent = 1 - imageCenterDistanceFromCenter / (viewCenterDistanceFromEdge * 0.25)
            self.view.layer.backgroundColor = self.tintColor.withAlphaComponent(percent).cgColor
            self.closeButton.alpha = percent * 0.5
        case .ended:
            let originalBoundsSize = self.originFrame.size
            let sizingBounds = CGSize(width: view.bounds.size.width - originalBoundsSize.width, height: view.bounds.size.height - originalBoundsSize.height)
            let originalCenter = CGPoint(x: self.originFrame.midX - self.scrollView.frame.origin.x, y: self.originFrame.midY - self.scrollView.frame.origin.y)
            let dropCenter = self.view.convert(CGPoint(x: view.frame.midX, y: view.frame.midY), from: self.scrollView)
            let diffX = originalCenter.x - dropCenter.x, diffY = originalCenter.y - dropCenter.y
            let totalDistance = diffX * diffX + diffY * diffY
            
            if totalDistance > 12600 {
                self.view.isUserInteractionEnabled = false
                
                weak var instance = view
                weak var weakSelf = self
                let snapBehaviour = UISnapBehavior(item: view, snapTo: originalCenter)
                snapBehaviour.damping = 0.85
                snapBehaviour.action = {
                    let movingCenter = instance!.center
                    let diffX = originalCenter.x - movingCenter.x, diffY = originalCenter.y - movingCenter.y
                    let toTravelDistance = diffX * diffX + diffY * diffY
                    let progress = toTravelDistance / totalDistance
                    var frame = instance!.frame
                    frame.size.width = originalBoundsSize.width + sizingBounds.width * progress
                    frame.size.height = originalBoundsSize.height + sizingBounds.height * progress
                    instance!.frame = frame
                    instance!.center = movingCenter
                    
                    if progress <= 0.0001 {
                        DispatchQueue.main.async {
                            weakSelf!.animator.removeAllBehaviors()
                            weakSelf!.cleanUpAndDismiss()
                        }
                    }
                }
                
                self.animator.addBehavior(snapBehaviour)
                
                let velocity = sender.velocity(in: view)
                let pushBehaviour = UIPushBehavior(items: [view], mode: .instantaneous)
                pushBehaviour.pushDirection = CGVector(dx: velocity.x * 0.2, dy: velocity.y * 0.2)
                
                self.animator.addBehavior(pushBehaviour)
                
                UIView.animate(withDuration: 0.1, delay: 0, options: UIViewAnimationOptions(), animations: {
                    self.view.layer.backgroundColor = UIColor.clear.cgColor
                    self.imageView.contentMode = self.originalView.contentMode
                    self.imageView.layer.cornerRadius = self.originalView.layer.cornerRadius
                    self.closeButton.alpha = 0
                }, completion: nil)
            } else {
                let behaviour = UISnapBehavior(item: self.imageView, snapTo: CGPoint(x: self.scrollView.bounds.midX, y: self.scrollView.bounds.midY))
                self.animator.addBehavior(behaviour)
                
                UIView.animate(withDuration: 0.1, delay: 0, options: UIViewAnimationOptions(), animations: {
                    self.view.layer.backgroundColor = self.tintColor.cgColor
                    self.closeButton.alpha = 1
                    
                }, completion: nil)
            }
        default:
            break
        }
    }
    
    func cleanUpAndDismiss() {
        self.originalView.isHidden = false
        self.imageView.removeFromSuperview()
        self.closeButton.removeFromSuperview()
        self.view.removeFromSuperview()
        self.retainHolder = nil
        self.removeFromParentViewController()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        
    }
    
    func closeTapped(_ sender: UIButton) {
        let originalCenter = CGPoint(x: self.originFrame.midX - self.scrollView.frame.origin.x, y: self.originFrame.midY - self.scrollView.frame.origin.y)
        
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut, animations: {
            self.imageView.contentMode = self.originalView.contentMode
            self.imageView.frame = self.originFrame
            self.imageView.center = originalCenter
            self.view.layer.backgroundColor = UIColor.clear.cgColor
            self.closeButton.alpha = 0
        }, completion: { _ in
            self.animator.removeAllBehaviors()
            self.cleanUpAndDismiss()
        })
    }
    
    // MARK: UIScrollViewDelegate
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews.first
    }
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
        let offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
        
        self.imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
        
        
        if self.scrollView.zoomScale == 1 {
            self.tapRecognizer?.numberOfTapsRequired = 2
        } else {
            self.tapRecognizer?.numberOfTapsRequired = 1
        }
        if self.closeButton.isHidden != (self.scrollView.zoomScale > 1) {
            self.closeButton.isHidden = !self.closeButton.isHidden
        }
        
    }
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    // MARK: NSCoding
    
    override public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.image, forKey: "image")
        aCoder.encode(self.originFrame, forKey: "originFrame")
        
        super.encode(with: aCoder)
    }
    
    // MARL - Rotation
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        let offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0
        let offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0
        
        // Will rotatie, so x = y, y = x
        self.imageView.center = CGPoint(x: scrollView.contentSize.height * 0.5 + offsetY, y: scrollView.contentSize.width * 0.5 + offsetX)
        
        
        if #available(iOS 8.0, *) {
            super.viewWillTransition(to: size, with: coordinator)
        }
    }
    
}
