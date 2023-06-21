import Foundation
import UIKit

private final class NullActionClass: NSObject, CAAction {
    static let value = NullActionClass()
    
    @objc public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private final class SegmentLayer: CALayer {
    override func action(forKey event: String) -> CAAction? {
        return NullActionClass.value
    }
}

private final class GradientLayer: CAGradientLayer {
    override func action(forKey event: String) -> CAAction? {
        return NullActionClass.value
    }
}

public final class StickerEffectView: UIView {
    private final class Contents {
        let contentImage: UIImage?
        let shadowImage: UIImage?
        
        init(size: CGSize, inset: CGFloat, image: UIImage) {
            let boundingSize = CGSize(width: size.width + inset * 2.0, height: size.height + inset * 2.0)
            UIGraphicsBeginImageContextWithOptions(boundingSize, false, 0.0)
            image.draw(in: CGRect(origin: CGPoint(), size: boundingSize).insetBy(dx: inset, dy: inset))
            contentImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let contentImage {
                shadowImage = blurredImage(contentImage, radius: inset * 2.0)
            } else {
                shadowImage = nil
            }
        }
    }
    
    private var validSize: CGSize?
    
    public var inset: CGFloat = 20.0
    public var elevation: CGFloat = 60.0
    public var shadowDistance: CGFloat = 20.0
    
    private let containerLayer: SegmentLayer
    private let shadowContainerLayer: SegmentLayer
    private let shadowMaskGradient: GradientLayer
    private let glareContainerLayer: SegmentLayer
    private let glareContentLayer: SegmentLayer
    private let glareGradient: GradientLayer
    
    private var segmentLayers: [SegmentLayer] = []
    private var shadowSegmentLayers: [SegmentLayer] = []
    private var glareSegmentLayers: [SegmentLayer] = []
    
    private var snapshotContents: Contents?
    private var currentState: (fraction: CGFloat, reverse: Bool)?
    
    public var image: UIImage? {
        didSet {
            if image !== oldValue {
                if let image, let validSize {
                    snapshotContents = Contents(size: validSize, inset: inset, image: image)
                } else {
                    snapshotContents = nil
                }
            }
        }
    }
    
    override public init(frame: CGRect) {
        self.containerLayer = SegmentLayer()
        self.shadowContainerLayer = SegmentLayer()
        self.shadowMaskGradient = GradientLayer()
        self.glareContainerLayer = SegmentLayer()
        self.glareContentLayer = SegmentLayer()
        self.glareGradient = GradientLayer()
        
        super.init(frame: frame)
        
        layer.addSublayer(shadowContainerLayer)
        layer.addSublayer(containerLayer)
        layer.addSublayer(glareContentLayer)
        
        glareContentLayer.addSublayer(glareGradient)
        
        shadowContainerLayer.mask = shadowMaskGradient
        shadowContainerLayer.opacity = 0.5
        
        glareContentLayer.mask = glareContainerLayer
        
        var perspectiveTransform = CATransform3DIdentity
        perspectiveTransform.m34 = -1.0 / 200.0
        containerLayer.sublayerTransform = perspectiveTransform
        shadowContainerLayer.sublayerTransform = perspectiveTransform
        glareContainerLayer.sublayerTransform = perspectiveTransform
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func rebuildLayers() {
        if bounds.isEmpty {
            return
        }
        
        let segmentCount = 20
        let boundingSize = CGSize(width: bounds.width + inset * 2.0, height: bounds.height + inset * 2.0)
        let segmentHeight = boundingSize.height / CGFloat(segmentCount)
        
        for i in 0 ..< segmentCount {
            if segmentLayers.count <= i {
                let segmentLayer = SegmentLayer()
                let shadowSegmentLayer = SegmentLayer()
                let glareSegmentLayer = SegmentLayer()
                
                segmentLayer.anchorPoint = CGPoint()
                shadowSegmentLayer.anchorPoint = CGPoint()
                glareSegmentLayer.anchorPoint = CGPoint()
                
                segmentLayer.contents = snapshotContents?.contentImage?.cgImage
                shadowSegmentLayer.contents = snapshotContents?.shadowImage?.cgImage
                glareSegmentLayer.contents = snapshotContents?.contentImage?.cgImage
                
                let segmentFrame = CGRect(origin: CGPoint(x: 0, y: CGFloat(i) * segmentHeight), size: CGSize(width: boundingSize.width, height: segmentHeight))
                let segmentContentsRect = CGRect(origin: CGPoint(x: segmentFrame.minX / boundingSize.width, y: segmentFrame.minY / boundingSize.height), size: CGSize(width: segmentFrame.width / boundingSize.width, height: segmentFrame.height / boundingSize.height))
                
                segmentLayer.contentsRect = segmentContentsRect
                shadowSegmentLayer.contentsRect = segmentContentsRect
                glareSegmentLayer.contentsRect = segmentContentsRect
                
                containerLayer.addSublayer(segmentLayer)
                shadowContainerLayer.addSublayer(shadowSegmentLayer)
                glareContainerLayer.addSublayer(glareSegmentLayer)
                
                segmentLayers.append(segmentLayer)
                shadowSegmentLayers.append(shadowSegmentLayer)
                glareSegmentLayers.append(glareSegmentLayer)
            }
        }
        while segmentLayers.count > segmentCount {
            segmentLayers.removeLast().removeFromSuperlayer()
            shadowSegmentLayers.removeLast().removeFromSuperlayer()
            glareSegmentLayers.removeLast().removeFromSuperlayer()
        }
    }
    
    public func updateLayers(fraction: CGFloat, reverse: Bool) {
        currentState = (fraction, reverse)
        
        func windowFunction(t: CGFloat) -> CGFloat {
            return evaluateBezier(0.5, 0.0, 0.5, 1.0, t)
        }
        
        func glareWindowFunction(t: CGFloat) -> CGFloat {
            let width: CGFloat = 0.6
            let start = (1.0 - width) * 0.5
            let rescaledT = max(0.0, min(width, t - start)) / width
            return 1.0 - sin(rescaledT * .pi)
        }
        
        func valueAt(fraction: CGFloat, t: CGFloat, reverse: Bool, window: (CGFloat) -> CGFloat) -> CGFloat {
            let windowSize: CGFloat = 0.8
            
            let effectiveT: CGFloat
            let windowStartOffset: CGFloat
            let windowEndOffset: CGFloat
            if reverse {
                effectiveT = 1.0 - t
                windowStartOffset = 1.0
                windowEndOffset = -windowSize
            } else {
                effectiveT = t
                windowStartOffset = -windowSize
                windowEndOffset = 1.0
            }
            
            let windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset
            let windowT = max(0.0, min(windowSize, effectiveT - windowPosition)) / windowSize
            let localT = 1.0 - window(windowT)
            
            return localT
        }
        
        func glareFunction(fraction: CGFloat, reverse: Bool) -> CGFloat {
            let windowSize: CGFloat = 0.8
            
            let windowStartOffset: CGFloat
            let windowEndOffset: CGFloat
            if reverse {
                windowStartOffset = 1.0
                windowEndOffset = -windowSize
            } else {
                windowStartOffset = -windowSize
                windowEndOffset = 1.0
            }
            
            let windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset
            return windowPosition + windowSize * 0.5
        }
        
        shadowMaskGradient.colors = (0 ... segmentLayers.count).map { i in
            let t = CGFloat(i) / CGFloat(segmentLayers.count)
            return UIColor(white: 1.0, alpha: valueAt(fraction: fraction, t: t, reverse: reverse, window: windowFunction)).cgColor
        }
        
        let glareColor: UIColor = UIColor.white
        glareGradient.colors = (0 ... segmentLayers.count * 2).map { i in
            let t = CGFloat(i) / CGFloat(segmentLayers.count * 2)
            return glareColor.withAlphaComponent(valueAt(fraction: fraction, t: t, reverse: false, window: glareWindowFunction) * 0.15).cgColor
        }
        
        let segmentContents = snapshotContents?.contentImage?.cgImage
        let shadowSegmentContents = snapshotContents?.shadowImage?.cgImage
        
        for i in 0 ..< segmentLayers.count {
            let segmentLayer = segmentLayers[i]
            let shadowSegmentLayer = shadowSegmentLayers[i]
            let glareSegmentLayer = glareSegmentLayers[i]
            
            segmentLayer.contents = segmentContents
            shadowSegmentLayer.contents = shadowSegmentContents
            glareSegmentLayer.contents = segmentContents
            
            let topFraction: CGFloat = CGFloat(i) / CGFloat(segmentLayers.count)
            let bottomFraction: CGFloat = CGFloat(i + 1) / CGFloat(segmentLayers.count)
            
            let topZ = elevation * valueAt(fraction: fraction, t: topFraction, reverse: reverse, window: windowFunction)
            let bottomZ = elevation * valueAt(fraction: fraction, t: bottomFraction, reverse: reverse, window: windowFunction)
            
            let topY = -inset + topFraction * (bounds.height + inset * 2.0)
            let bottomY = -inset + bottomFraction * (bounds.height + inset * 2.0)
            
            let dy = bottomY - topY
            let dz = bottomZ - topZ
            let angle = -atan2(dy, dz) + .pi * 0.5
            
            segmentLayer.zPosition = topZ
            segmentLayer.transform = CATransform3DMakeRotation(angle, 1.0, 0.0, 0.0)
            
            shadowSegmentLayer.zPosition = segmentLayer.zPosition
            shadowSegmentLayer.transform = segmentLayer.transform
            
            glareSegmentLayer.zPosition = segmentLayer.zPosition
            glareSegmentLayer.transform = segmentLayer.transform
            
            let segmentHeight: CGFloat = sqrt(dy * dy + dz * dz)
            
            segmentLayer.position = CGPoint(x: -inset, y: topY)
            shadowSegmentLayer.position = segmentLayer.position
            glareSegmentLayer.position = segmentLayer.position
            
            segmentLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width + inset * 2.0, height: segmentHeight))
            shadowSegmentLayer.bounds = segmentLayer.bounds
            glareSegmentLayer.bounds = segmentLayer.bounds
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if bounds.size != validSize {
            if let image {
                snapshotContents = Contents(size: bounds.size, inset: inset, image: image)
            }
            
            containerLayer.frame = CGRect(origin: CGPoint(), size: bounds.size)
            shadowContainerLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: shadowDistance), size: bounds.size)
            
            let shadowSize = CGSize(width: bounds.width, height: bounds.height)
            
            let topLeft = applyTransform(transform: containerLayer.sublayerTransform, point: CGPoint(x: -inset - shadowSize.width * 0.5, y: -inset - shadowSize.height * 0.5), z: elevation)
            let bottomRight = applyTransform(transform: containerLayer.sublayerTransform, point: CGPoint(x: shadowSize.width * 0.5 + inset, y: shadowSize.height * 0.5 + inset), z: elevation)
            
            shadowMaskGradient.frame = CGRect(origin: CGPoint(x: topLeft.x + shadowSize.width * 0.5, y: topLeft.y + shadowSize.height * 0.5), size: CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
            
            glareContentLayer.frame = CGRect(origin: CGPoint(x: topLeft.x + shadowSize.width * 0.5, y: topLeft.y + shadowSize.height * 0.5), size: CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
            glareContainerLayer.frame = CGRect(origin: CGPoint(x: -glareContentLayer.frame.minX, y: -glareContentLayer.frame.minY), size: bounds.size)
            glareGradient.frame = CGRect(origin: CGPoint(), size: glareContentLayer.bounds.size)
            
            rebuildLayers()
            
            validSize = bounds.size
            
            if let (fraction, reverse) = currentState {
                updateLayers(fraction: fraction, reverse: reverse)
            }
        }
    }
}
