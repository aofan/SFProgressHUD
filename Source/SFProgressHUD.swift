//
//  ProgressHUD.swift
//  ProgressHUD
//
//  Created by Edmond on 8/22/15.
//  Copyright © 2015 XueQiu. All rights reserved.
//

import UIKit
import SnapKit

public class SFRoundProgressView: UIView {
    var annular = false {
        didSet {
            setNeedsDisplay()
        }
    }
    var progress: CGFloat = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    var progressTintColor = UIColor(white:0.5, alpha:1.0) {
        didSet {
            setNeedsDisplay()
        }
    }
    var backgroundTintColor = UIColor(white:1.0, alpha:1.0) {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame:CGRect(x: 0, y: 0, width: 37, height: 37))
        backgroundColor = UIColor.clearColor()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func drawRect(rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            let circleRect = CGRectInset(bounds, 2.0, 2.0)
            let pi = CGFloat(M_PI)
            let startAngle = -pi / 2.0 // 90 degrees
            let lineW: CGFloat = 2.0
            let center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
            if annular {
                // Draw background
                var endAngle = 2.0 * pi + startAngle
                let radius = (CGRectGetWidth(bounds) - lineW)/2
                let processBackgroundPath = UIBezierPath()
                processBackgroundPath.lineWidth = lineW
                processBackgroundPath.lineCapStyle = .Butt
                processBackgroundPath.addArcWithCenter(center, radius:radius, startAngle:startAngle, endAngle:endAngle, clockwise:true)
                backgroundTintColor.set()
                processBackgroundPath.stroke()

                // Draw progress
                let processPath = UIBezierPath()
                processPath.lineCapStyle = .Square
                processPath.lineWidth = lineW
                endAngle = progress * 2 * pi + startAngle
                processPath.addArcWithCenter(center, radius:radius, startAngle:startAngle, endAngle:endAngle, clockwise:true)
                progressTintColor.set()
                processPath.stroke()
            } else {
                // Draw background
                progressTintColor.setStroke()
                backgroundTintColor.setFill()
                CGContextSetLineWidth(context, 2.0)
                CGContextFillEllipseInRect(context, circleRect)
                CGContextStrokeEllipseInRect(context, circleRect)
                // Draw progress
                let radius = (CGRectGetWidth(bounds) - 4) / 2
                let endAngle = progress * 2 * pi + startAngle
                progressTintColor.setFill()
                CGContextMoveToPoint(context, center.x, center.y)
                CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0)
                CGContextClosePath(context)
                CGContextFillPath(context)
            }
        }
        super.drawRect(rect)
    }
}

/**
* Displays a simple HUD window containing a progress indicator and two optional labels for short messages.
*
* This is a simple drop-in class for displaying a progress HUD view similar to Apple's private UIProgressHUD class.
* The ProgressHUD window spans over the entire space given to it by the initWithFrame constructor and catches all
* user input on this region, thereby preventing the user operations on components below the view. The HUD itself is
* drawn centered as a rounded semi-transparent view which resizes depending on the user specified content.
*
* All three modes can have optional labels assigned:
*  - If the labelText property is set and non-empty then a label containing the provided content is placed below the
*    indicator view.
*  - If also the detailLabelText property is set then another label is placed below the first titleLabel.
*/

public class ProgressHUD: UIView {
    private let kPadding: CGFloat = 4.0

    var progress: Float = 0.0
    var opacity: CGFloat = 0.9
    var margin: CGFloat = 20.0
    var cornerRadius: CGFloat = 10.0
    var graceTime: Float = 0.0
    var minShowTime: NSTimeInterval = 0.0
    var minSize = CGSize.zero
    var size = CGSize.zero
    var square = false
    var customView: UIView? = nil {
        didSet {
            if let indicator = indicator {
                indicator.removeFromSuperview()
            }
            addSubview(customView!)
        }
    }
    var mode: Mode = .Indeterminate {
        didSet {
            updateSubViews()
            setNeedsUpdateConstraints()
        }
    }
    var inset = UIEdgeInsetsMake(12, 12, 12, 12)
    private var backgroundView = UIView()
    private var indicator: UIView? = nil
    private var isFinished = false
    private var taskInProgress = false
    private var rotationTransform = CGAffineTransformIdentity
    private var showStarted: NSDate? = nil
    private var graceTimer: NSTimer? = nil
    private var minShowTimer: NSTimer? = nil

    /// MARK: class Method
    public class func showHUD(onView: UIView) -> ProgressHUD {
        let hud = ProgressHUD(onView:onView)
        hud.show()
        return hud
    }

    public class func hideHUD(onView: UIView) {
        for case let hud as ProgressHUD in onView.subviews {
            hud.hide()
        }
    }

    public class func hideAllHUD(onView: UIView) {
        for case let hud as ProgressHUD in onView.subviews {
            hud.hide()
        }
    }

    public func show() {
        assert(NSThread.isMainThread(), "ProgressHUD needs to be accessed on the main thread.")
        if graceTime > 0.0 {
            let timer = NSTimer(timeInterval:1.0, target:self, selector:#selector(handleGraceTimer(_:)),
                userInfo:nil, repeats:false)
            NSRunLoop.currentRunLoop().addTimer(timer, forMode:NSRunLoopCommonModes)
        } else {
            showUsingAnimation()
        }
    }

    public func hide() {
        assert(NSThread.isMainThread(), "ProgressHUD needs to be accessed on the main thread.")

        // If the minShow time is set, calculate how long the hud was shown,
        // and pospone the hiding operation if necessary
        if let showStarted = showStarted where minShowTime > 0.0 {
            let interv = NSDate().timeIntervalSinceDate(showStarted)
            if interv < minShowTime {
                minShowTimer = NSTimer.scheduledTimerWithTimeInterval(minShowTime - interv, target:self, selector:#selector(ProgressHUD.hideUseAnimation), userInfo:nil, repeats:false)
                return
            }
        }
        hideUseAnimation()
    }

    public func hide(animated: Bool, afterDelay: UInt64) {
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(afterDelay * NSEC_PER_SEC))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            self.hide()
        }
    }

    // Timer CallBack
    @objc private func handleGraceTimer(timer: NSTimer) {
        if taskInProgress {
            showUsingAnimation()
        }
    }

    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateForCurrentOrientationAnimated(false)
    }

    @objc private func showUsingAnimation() {
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        setNeedsDisplay()
        showStarted = NSDate()
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.alpha = 1.0
        })
    }

    @objc private func hideUseAnimation() {
        if let _ = showStarted {
            UIView.animateWithDuration(0.3,
                animations: { () -> Void in
                    self.alpha = 0.02
                }, completion: { (finished) -> Void in
                    self.doneAnimation()
            })
        }
    }

    private func doneAnimation() {
        showStarted = nil
        isFinished = true
        alpha = 0.0
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        removeFromSuperview()
    }

    init(onView: UIView) {
        super.init(frame:onView.bounds)
        alpha = 0.0
        opaque = false
        backgroundColor = UIColor.clearColor()
        taskInProgress = false
        rotationTransform = CGAffineTransformIdentity

        backgroundView.layer.cornerRadius = 6
        backgroundView.clipsToBounds = true
        backgroundView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.6)
        addSubview(backgroundView)
        addSubview(titleLabel)
        onView.addSubview(self)
        updateSubViews()
        configureConstraints()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func updateSubViews() {
        switch mode {
        case .Indeterminate:
            let indicator = UIActivityIndicatorView(activityIndicatorStyle:.WhiteLarge)
            indicator.startAnimating()
            addSubview(indicator)
            self.indicator = indicator
        case .Determinate, .AnnularDeterminate:
            let roundView = SFRoundProgressView()
            roundView.annular = mode == .AnnularDeterminate
            addSubview(roundView)
            indicator = roundView
        case .CustomView:
            if let indicator = indicator {
                indicator.removeFromSuperview()
                self.indicator = nil
            }
            if let customView = customView {
                addSubview(customView)
            }
        case .Text:
            if let indicator = indicator {
                indicator.removeFromSuperview()
            }
        }
    }

    private func configureConstraints() {
        backgroundView.snp_makeConstraints { (make) -> Void in
            make.center.equalTo(self)
            make.top.greaterThanOrEqualTo(self).inset(inset)
            make.bottom.lessThanOrEqualTo(self).inset(inset)
            make.left.greaterThanOrEqualTo(self).inset(inset)
            make.right.lessThanOrEqualTo(self).inset(inset)
        }

        titleLabel.snp_makeConstraints { (make) -> Void in
            make.left.right.bottom.equalTo(backgroundView).inset(inset)
        }

        if let indicator = indicator {
            indicator.snp_makeConstraints(closure: { (make) -> Void in
                make.centerX.equalTo(backgroundView)
                make.left.greaterThanOrEqualTo(backgroundView).inset(inset)
                make.right.lessThanOrEqualTo(backgroundView).inset(inset)
                make.top.equalTo(backgroundView).inset(inset)
                make.bottom.equalTo(titleLabel.snp_top)
            })
        }
    }

    public override func updateConstraints() {
        var hasText = false
        if let text = titleLabel.text where text.characters.count > 0 {
            hasText = true
        }
        if mode == .Text {
            titleLabel.snp_remakeConstraints(closure: { (make) -> Void in
                make.edges.equalTo(backgroundView).inset(inset)
            })
            backgroundView.snp_updateConstraints { (make) -> Void in
                make.center.equalTo(self)
                make.left.greaterThanOrEqualTo(self).inset(inset)
                make.right.lessThanOrEqualTo(self).inset(inset)
            }
        } else {
            if let indicator = indicator {
                indicator.snp_updateConstraints(closure: { (make) -> Void in
                    if hasText {
                        make.bottom.equalTo(titleLabel.snp_top).offset(-5)
                    }
                })
            }
        }
        super.updateConstraints()
    }

    // MARK: Notifications

    func registeNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(ProgressHUD.statusBarOrientationDidChange(_:)), name:UIApplicationDidChangeStatusBarOrientationNotification, object:nil)
    }

    func unregisteNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name:UIApplicationDidChangeStatusBarOrientationNotification, object:nil)
    }

    func statusBarOrientationDidChange(notification: NSNotification) {
        if let _ = superview {
            updateForCurrentOrientationAnimated(true)
        }
    }

    func updateForCurrentOrientationAnimated(animated: Bool) {
        // Stay in sync with the superview in any case
        if let superview = superview {
            bounds = superview.bounds
            setNeedsDisplay()
        }
    }

    private func textSize(text: String?, font: UIFont) -> CGSize? {
        if let text = text where text.characters.count > 0 {
            return text.sizeWithAttributes([NSFontAttributeName : font])
        }
        return nil
    }

    private func mutilLineTextSize(text: String?, font: UIFont, maxSize: CGSize) -> CGSize? {
        if let text = text where text.characters.count > 0 {
            return text.boundingRectWithSize(maxSize, options:.UsesLineFragmentOrigin, attributes:[NSFontAttributeName : font], context:nil).size
        }
        return nil
    }

    lazy public var titleLabel: UILabel = {
        let titleLabel = UILabel(frame: self.bounds)
        titleLabel.opaque = true
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .Center
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.backgroundColor = UIColor.clearColor()
        titleLabel.font = UIFont.boldSystemFontOfSize(14)
        titleLabel.textColor = UIColor.whiteColor()
        return titleLabel
        }()

    public enum Mode: NSInteger {
        /** Progress is shown using an UIActivityIndicatorView. This is the default. */
        case Indeterminate
        /** Progress is shown using a round, pie-chart like, progress view. */
        case Determinate
        /** Progress is shown using a ring-shaped progress view. */
        case AnnularDeterminate
        /** Shows a custom view */
        case CustomView
        /** Shows only labels */
        case Text
    }
}
