/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Math extensions to Core Graphics structs.
*/

import Foundation
import CoreGraphics

// MARK: - CGRect and Size

extension CGRect {
    var center: CGPoint {
        return origin + CGVector(dx: width, dy: height) / 2.0
    }
}

func +(left: CGSize, right: CGFloat) -> CGSize {
    return CGSize(width: left.width + right, height: left.height + right)
}

func -(left: CGSize, right: CGFloat) -> CGSize {
    return left + (-1.0 * right)
}

// MARK: - CGPoint and CGVector math

func -(left: CGPoint, right: CGPoint) -> CGVector {
    return CGVector(dx: left.x - right.x, dy: left.y - right.y)
}

func /(left: CGVector, right: CGFloat) -> CGVector {
    return CGVector(dx: left.dx / right, dy: left.dy / right)
}

func *(left: CGVector, right: CGFloat) -> CGVector {
    return CGVector(dx: left.dx * right, dy: left.dy * right)
}

func +(left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
}

func +(left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
}

func +(left: CGVector?, right: CGVector?) -> CGVector? {
    if let left = left, let right = right {
        return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
    } else {
        return nil
    }
}

func -(left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
}

extension CGPoint {
    init(_ vector: CGVector) {
        self.init()
        x = vector.dx
        y = vector.dy
    }
}

extension CGVector {
    init(_ point: CGPoint) {
        self.init()
        dx = point.x
        dy = point.y
    }
    
    func applying(_ transform: CGAffineTransform) -> CGVector {
        return CGVector(CGPoint(self).applying(transform))
    }
    
    func rounding(toScale scale: CGFloat) -> CGVector {
        return CGVector(dx: CoreGraphics.round(dx * scale) / scale,
                        dy: CoreGraphics.round(dy * scale) / scale)
    }
    
    var quadrance: CGFloat {
        return dx * dx + dy * dy
    }
    
    var normal: CGVector? {
        if !(dx.isZero && dy.isZero) {
            return CGVector(dx: -dy, dy: dx)
        } else {
            return nil
        }
    }
    
    /// CGVector pointing in the same direction as self, with a length of 1.0 - or nil if the length is zero.
    var normalized: CGVector? {
        let quadrance = self.quadrance
        if quadrance > 0.0 {
            return self / sqrt(quadrance)
        } else {
            return nil
        }
    }
}

