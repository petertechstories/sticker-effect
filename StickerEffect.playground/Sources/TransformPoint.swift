import Foundation
import UIKit

func applyTransform(transform: CATransform3D, point: CGPoint, z: CGFloat) -> CGPoint {
    let newX = point.x * Double(transform.m11) + point.y * Double(transform.m21) + z * Double(transform.m31) + 1.0 * Double(transform.m41)
    let newY = point.x * Double(transform.m12) + point.y * Double(transform.m22) + z * Double(transform.m32) + 1.0 * Double(transform.m42)
    let newW = point.x * Double(transform.m14) + point.y * Double(transform.m24) + z * Double(transform.m34) + 1.0 * Double(transform.m44)
    
    return CGPoint(x: CGFloat(newX / newW), y: CGFloat(newY / newW))
}
