//
//  Vector.swift
//  sketchbook-app
//
//  Created by Si Li on 4/21/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation

struct Vec2 {
    var x : Float = 0.0
    var y : Float = 0.0
    init () {}
    init (_ _x: Float) {
        x = _x
        y = _x
    }
    init (_ _x: Float, _ _y: Float) {
        x = _x
        y = _y
    }
}

extension Vec2: CustomStringConvertible {
    var description: String {
        return "\(x), \(y)"
    }
}

extension Vec2 {
    static func + (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(left.x + right.x, left.y+right.y)
    }
    static func - (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(left.x - right.x, left.y-right.y)
    }
    static func * (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(left.x * right.x, left.y*right.y)
    }
    static func * (left: Vec2, right: Float) -> Vec2 {
        return Vec2(left.x * right, left.y*right)
    }
    static func / (left: Vec2, right: Float) -> Vec2 {
        return Vec2(left.x / right, left.y/right)
    }
}

typealias ivec2 = (x: Int, y: Int)
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

func v_len(a: Vec2) -> Float { return sqrtf(a.x*a.x + a.y*a.y) }
func v_norm(a: Vec2) -> Vec2 { return a * (1.0 / v_len(a: a)) }
