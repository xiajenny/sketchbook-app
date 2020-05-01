//
//  GraphicalElement.swift
//  sketchbook-app
//
//  Created by Si Li on 4/21/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation
import MetalKit

class GraphicalElement {
    var name = "graphical element"
    var hitable = true
    var toUpdate = true
    var txIndex: Int
    var position: Vec2
    var size: Vec2 //ui size
    var txSize: Vec2 //texture size
    var color: Color

    func fill(_ tex: inout MTLTexture) {
        return
    }
    
    func isOver(_ pos: Vec2, debug: Bool = false) -> Bool {
        //TODO assume rectangular hit target, but should do circles or others depending on the class
        let left = position.x - size.x
        let right = position.x + size.x
        let top = position.y + size.y
        let bottom = position.y - size.y
        
        if debug {
            let hit = hitable && left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
            print("hitable: \(hitable) hit: \(hit) pos: \(pos) lrtb: \(left) \(right) \(top) \(bottom)")
        }
        return hitable && left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
    }
    
    func getElement() -> BrushSample {
        return BrushSample(position: position, size: size.x, color: color)
    }

    init(p: Vec2, s: Vec2, c: Color = Color(), ti: Int) {
        position = p
        size = s
        txSize = s
        color = c
        color.a = 0xff
        txIndex = ti
        print("GraphicalElement.init txIndex: \(txIndex)")
    }

    init(p: Vec2, s: Vec2, ts: Vec2, c: Color = Color(), ti: Int) {
        position = p
        size = s
        txSize = ts
        color = c
        color.a = 0xff
        txIndex = ti
        print("GraphicalElement.init txIndex: \(txIndex)")
    }
}

class ColorSlot : GraphicalElement {
    var hsvColor = FloatHSV()
    //init(p: Vec2, s: Vec2, c: Color, ti: Int) {
    //    super.init(p: p, s: s, c: c, ti: ti)
    //}
}

class ColorPicker : GraphicalElement {
    var hue : Int
    init(p: Vec2, s: Vec2, ts: Vec2, h: Int, ti: Int) {
        hue = h
        super.init(p: p, s: s, ts: ts, ti: ti)
    }
    
    override func fill(_ tex: inout MTLTexture) {
        if toUpdate {
            toUpdate = false
        } else {
            return
        }
        let bytesPerPixel = 4
        let dim = Int(txSize.x)
        let cpData = UnsafeMutablePointer<UInt8>.allocate(capacity: dim * dim * bytesPerPixel)
        for s in 0 ... 255 {
            for v in 0 ... 255 {
                let hsv = itof(i: IntHSV(h: hue, s: s, v: v, a: 255))
                let color = hsv2rgb(input: hsv)
                let index = s * dim + v
                cpData[index * bytesPerPixel + 0] = color.r
                cpData[index * bytesPerPixel + 1] = color.g
                cpData[index * bytesPerPixel + 2] = color.b
                cpData[index * bytesPerPixel + 3] = 255//color.a
            }
        }
        let region = MTLRegionMake2D(0, 0, dim, dim)
        tex.replace(region: region, mipmapLevel: 0, withBytes: cpData, bytesPerRow: dim*bytesPerPixel)
    }
    
    func touch(_ touchPos: Vec2) -> FloatHSV {
        var hsv = FloatHSV()
        let dim = size.x
        var origin = position
        origin.x += dim
        origin.y += dim
        let sv = (origin - touchPos)/2
        hsv.s = min(1, max(0.0, (dim - sv.y) / dim))
        hsv.v = min(1, max(0, (dim - sv.x) / dim))
        print("sv: \(sv) hsv: \(hsv)")
        return hsv
    }
}

class ColorPickerHue : GraphicalElement {
    override func fill(_ texture: inout MTLTexture) {
        if toUpdate {
            toUpdate = false
        } else {
            return
        }
        
        let bytesPerPixel = 4
        let width = Int(txSize.x)
        let height = Int(txSize.y)
        let cpData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)

        for v in 0 ..< height {
            for h in 0 ..< width {
                let hsv = itof(i: IntHSV(h: h, s: 255, v: 255, a: 255))
                let color = hsv2rgb(input: hsv)
                let index = v * width + h
                //let index = h * heightHue + v
                cpData[index * bytesPerPixel + 0] = color.r
                cpData[index * bytesPerPixel + 1] = color.g
                cpData[index * bytesPerPixel + 2] = color.b
                cpData[index * bytesPerPixel + 3] = 255//color.a
            }
        }
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: cpData, bytesPerRow: width*bytesPerPixel)
    }
    
    func touch(_ touchPos: Vec2) -> Float {
        let dim = Float(size.x)
        var origin = position
        origin.x -= dim
        let sv = (touchPos - origin) / 2
        return min(360, max(0.0, sv.x ))
    }
}

class CircleBrush : GraphicalElement {
    override func fill(_ texture: inout MTLTexture) {
        if toUpdate {
            toUpdate = false
        } else {
            return
        }
        
        //fillBrush(color: Color(40, 40, 200,255))
        let bytesPerPixel = 8
        let kw = Int(defaultBrushSize)
        let kernelSize = kw * kw * 4
        let brushData = UnsafeMutablePointer<UInt16>.allocate(capacity: kernelSize)
        let center = ivec2(kw/2, kw/2)
        for x in 0 ..< kw {
            for y in 0 ..< kw {
                let i = (y * kw + x) * 4 //4 is num components per pixel
                //if distance from center is more than brush radius, 0 alpha
                brushData[i + 0] = UInt16(color.r) * 256
                brushData[i + 1] = UInt16(color.g) * 256
                brushData[i + 2] = UInt16(color.b) * 256
                if pow(Decimal(x - center.x), 2) + pow(Decimal(y - center.y), 2) < pow(Decimal(kw / 2), 2) {
                    brushData[i + 3] = 0xffff
                } else {
                    brushData[i + 3] = 0
                }
            }
        }
        let region = MTLRegionMake2D(0, 0, kw, kw)
        texture.replace(region: region, mipmapLevel: 0, withBytes: brushData, bytesPerRow: kw * bytesPerPixel)
        brushData.deallocate()
    }
}

class Button : GraphicalElement {
    var firstLocation = Vec2()
    var currentLocation = Vec2()
    var newBrushSize : FloatBox

    init(p: Vec2, s: Vec2, b: FloatBox, ti: Int) {
        newBrushSize = b
        super.init(p: p, s: s, ts: s, ti: ti)
    }
    func foo(_ brushSize: Float) {
        let distFirst = v_len(a: firstLocation - position)
        let distCurr = v_len(a: position - currentLocation)
        let dist = distCurr - distFirst
        newBrushSize.value = brushSize + dist / 2
    }
}

class BrushIndicator : GraphicalElement {
    var newBrushSize : FloatBox
    init(p: Vec2, b: FloatBox, ti: Int) {
        newBrushSize = b
        super.init(p: p, s: Vec2(b.value), ti: ti)
    }
    
    override func getElement() -> BrushSample {
        return BrushSample(position: position, size: newBrushSize.value, color: color)
    }
}
