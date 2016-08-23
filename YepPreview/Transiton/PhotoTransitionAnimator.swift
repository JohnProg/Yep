//
//  PhotoTransitionAnimator.swift
//  Yep
//
//  Created by NIX on 16/6/17.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit

class PhotoTransitionAnimator: NSObject {

    var startingReference: Reference?
    var endingReference: Reference?

    var startingViewForAnimation: UIView?
    var endingViewForAnimation: UIView?

    var isDismissing: Bool = false

    var animationDurationWithZooming: NSTimeInterval = 4.4
    var animationDurationWithoutZooming: NSTimeInterval = 0.3

    var animationDurationFadeRatio: NSTimeInterval = 4.0 / 9.0
    var animationDurationEndingViewFadeInRatio: NSTimeInterval = 0.1
    var animationDurationStartingViewFadeOutRatio: NSTimeInterval = 0.05

    var zoomingAnimationSpringDamping: CGFloat = 0.9

    var shouldPerformZoomingAnimation: Bool {
        return (startingReference != nil) && (endingReference != nil)
    }

    private class func newViewFromView(view: UIView) -> UIView {

        let newView: UIView

        if view.layer.contents != nil {

            if let image = (view as? UIImageView)?.image {
                newView = UIImageView(image: image)
                newView.bounds = view.bounds

            } else {
                newView = UIView()
                newView.layer.contents = view.layer.contents
                newView.layer.bounds = view.layer.bounds
            }

            newView.layer.cornerRadius = view.layer.cornerRadius
            newView.layer.masksToBounds = view.layer.masksToBounds
            newView.contentMode = view.contentMode
            newView.transform = view.transform

        } else {
            newView = view.snapshotViewAfterScreenUpdates(true)
        }

        return newView
    }

    class func newAnimationViewFromView(view: UIView) -> UIView {

        return newViewFromView(view)
    }

    class func centerPointForView(view: UIView, translatedToContainerView containerView: UIView) -> CGPoint {

        guard let superview = view.superview else {
            fatalError("No superview")
        }

        var centerPoint = view.center

        if let scrollView = superview as? UIScrollView {
            if scrollView.zoomScale != 1.0 {
                centerPoint.x += (scrollView.bounds.width - scrollView.contentSize.width) / 2 + scrollView.contentOffset.x
                centerPoint.y += (scrollView.bounds.height - scrollView.contentSize.height) / 2 + scrollView.contentOffset.y
            }
        }

        return superview.convertPoint(centerPoint, toView: containerView)
    }
}

extension PhotoTransitionAnimator: UIViewControllerAnimatedTransitioning {

    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {

        if shouldPerformZoomingAnimation {
            return animationDurationWithZooming
        } else {
            return animationDurationWithoutZooming
        }
    }

    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {

        setupTransitionContainerHierarchyWithTransitionContext(transitionContext)

        performFadeAnimationWithTransitionContext(transitionContext)

        if shouldPerformZoomingAnimation {
            performZoomingAnimationWithTransitionContext(transitionContext)
        }
    }

    private func setupTransitionContainerHierarchyWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        if let toView = transitionContext.viewForKey(UITransitionContextToViewKey) {

            let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!

            toView.frame = transitionContext.finalFrameForViewController(toViewController)

            let containerView = transitionContext.containerView()!

            if !toView.isDescendantOfView(containerView) {
                containerView.addSubview(toView)
            }
        }

        if isDismissing {
            let fromView = transitionContext.viewForKey(UITransitionContextFromViewKey)!
            let containerView = transitionContext.containerView()!
            containerView.bringSubviewToFront(fromView)
        }
    }

    private func performFadeAnimationWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        let fromView = transitionContext.viewForKey(UITransitionContextFromViewKey)
        let toView = transitionContext.viewForKey(UITransitionContextToViewKey)

        let viewToFade: UIView?
        let beginningAlpha: CGFloat
        let endingAlpha: CGFloat
        if isDismissing {
            viewToFade = fromView
            beginningAlpha = 1
            endingAlpha = 0
        } else {
            viewToFade = toView
            beginningAlpha = 0
            endingAlpha = 1
        }

        viewToFade?.alpha = beginningAlpha

        let duration = fadeDurationForTransitionContext(transitionContext)

        UIView.animateWithDuration(duration, animations: {
            viewToFade?.alpha = endingAlpha

        }, completion: { [unowned self] finished in
            if !self.shouldPerformZoomingAnimation {
                self.completeTransitionWithTransitionContext(transitionContext)
            }
        })
    }

    private func performZoomingAnimationWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        let containerView = transitionContext.containerView()!

        var _startingViewForAnimation: UIView? = self.startingViewForAnimation
        var _endingViewForAnimation: UIView? = self.startingViewForAnimation

        if _startingViewForAnimation == nil {
            if let startingReference = startingReference {
                let view = isDismissing ? startingReference.view : startingReference.imageView
                //let view = startingReference.view
                _startingViewForAnimation = PhotoTransitionAnimator.newAnimationViewFromView(view)
            }
        }

        if _endingViewForAnimation == nil {
            if let endingReference = endingReference {
                let view = isDismissing ? endingReference.imageView : endingReference.view
                //let view = endingReference.view
                _endingViewForAnimation = PhotoTransitionAnimator.newAnimationViewFromView(view)
            }
        }

        guard let startingViewForAnimation = _startingViewForAnimation else {
            return
        }
        guard let endingViewForAnimation = _endingViewForAnimation else {
            return
        }

        guard let originalStartingViewForAnimation = startingReference?.view else {
            return
        }
        guard let originalEndingViewForAnimation = endingReference?.view else {
            return
        }

        startingViewForAnimation.clipsToBounds = true
        endingViewForAnimation.clipsToBounds = true

        let endingViewForAnimationFinalFrame = originalEndingViewForAnimation.frame

        endingViewForAnimation.frame = originalStartingViewForAnimation.frame

        var startingMaskView: UIView?
        if let _startingMaskView = startingReference?.view.maskView {
            startingMaskView = PhotoTransitionAnimator.newViewFromView(_startingMaskView)
            startingMaskView?.frame = startingViewForAnimation.bounds
            //startingMaskView?.frame = originalStartingViewForAnimation.bounds
        }
        var endingMaskView: UIView?
        if let _endingMaskView = endingReference?.view.maskView {
            endingMaskView = PhotoTransitionAnimator.newViewFromView(_endingMaskView)
            endingMaskView?.frame = endingViewForAnimation.bounds
            //endingMaskView?.frame = originalEndingViewForAnimation.bounds
        }
        startingViewForAnimation.maskView = startingMaskView
        endingViewForAnimation.maskView = endingMaskView

        if let startingView = startingReference?.view {
            let translatedStartingViewCenter = PhotoTransitionAnimator.centerPointForView(startingView, translatedToContainerView: containerView)
            startingViewForAnimation.center = translatedStartingViewCenter
            endingViewForAnimation.center = translatedStartingViewCenter
        }

        if isDismissing {
            startingViewForAnimation.alpha = 1
            endingViewForAnimation.alpha = 1
        } else {
            startingViewForAnimation.alpha = 1
            endingViewForAnimation.alpha = 0
        }

        containerView.addSubview(startingViewForAnimation)
        containerView.addSubview(endingViewForAnimation)

        startingReference?.view.alpha = 0
        endingReference?.view.alpha = 0

        var translatedEndingViewFinalCenter: CGPoint?
        if let endingView = endingReference?.view {
            translatedEndingViewFinalCenter = PhotoTransitionAnimator.centerPointForView(endingView, translatedToContainerView: containerView)
        }

        UIView.animateWithDuration(transitionDuration(transitionContext), delay: 0, usingSpringWithDamping: zoomingAnimationSpringDamping, initialSpringVelocity: 0, options: [.AllowAnimatedContent, .BeginFromCurrentState], animations: { [unowned self] in

            endingViewForAnimation.frame = endingViewForAnimationFinalFrame
            endingMaskView?.frame = endingViewForAnimation.bounds
            //endingMaskView?.frame = originalEndingViewForAnimation.bounds

            if let translatedEndingViewFinalCenter = translatedEndingViewFinalCenter {
                endingViewForAnimation.center = translatedEndingViewFinalCenter
            }
            
            startingViewForAnimation.frame = endingViewForAnimationFinalFrame
            startingMaskView?.frame = startingViewForAnimation.bounds
            //startingMaskView?.frame = originalStartingViewForAnimation.bounds

            if let translatedEndingViewFinalCenter = translatedEndingViewFinalCenter {
                startingViewForAnimation.center = translatedEndingViewFinalCenter
            }

            if self.isDismissing {
                startingViewForAnimation.alpha = 0
            } else {
                endingViewForAnimation.alpha = 1
            }

        }, completion: { [unowned self] finished in

            self.endingReference?.view.alpha = 1
            self.startingReference?.view.alpha = 1

            startingViewForAnimation.removeFromSuperview()
            endingViewForAnimation.removeFromSuperview()

            self.completeTransitionWithTransitionContext(transitionContext)
        })
    }

    private func fadeDurationForTransitionContext(transitionContext: UIViewControllerContextTransitioning) -> NSTimeInterval {

        if shouldPerformZoomingAnimation {
            return transitionDuration(transitionContext) * animationDurationFadeRatio
        } else {
            return transitionDuration(transitionContext)
        }
    }

    private func completeTransitionWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        if transitionContext.isInteractive() {
            if transitionContext.transitionWasCancelled() {
                transitionContext.cancelInteractiveTransition()
            } else {
                transitionContext.finishInteractiveTransition()
            }
        }

        transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
    }
}

