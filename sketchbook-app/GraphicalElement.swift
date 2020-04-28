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
    var tag = "default"
    var hitable = true
    var toUpdate = true
    var txIndex: Int
    var position: Vec2
    var size: Vec2 //ui size
    var txSize: Vec2 //texture size
    var color: Color

    func fill(_ tex: inout MTLTexture) {
        fatalError("must override fill")
    }
    
    func isOver(_ pos: Vec2) -> Bool {
        //TODO assume rectangular hit target, but should do circles or others depending on the class
        let left = position.x - size.x
        let right = position.x + size.x
        let top = position.y + size.y
        let bottom = position.y - size.y
        
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
    override func fill(_ tex: inout MTLTexture) {
        return
    }
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
