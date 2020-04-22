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
    var toUpdate = true
    var txIndex: Int
    var position: Vec2
    var size: Vec2 //ui size
    var txSize: Vec2 //texture size
    var color: Color
    func createElement(_ box: TextureBox) -> BrushSample{

        return BrushSample(position: position, size: size.x, color: color)
    }
    
    func fill(_ tex: inout MTLTexture) {
        fatalError("must override fill")
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
}

class ColorPicker : GraphicalElement {
    var hue : Int
    init(p: Vec2, s: Vec2, h: Int, ti: Int) {
        hue = h
        super.init(p: p, s: s, ti: ti)
    }
    
    override func fill(_ tex: inout MTLTexture) {
        if toUpdate {
            toUpdate = false
        } else {
            return
        }
        let bytesPerPixel = 4
        let dim = Int(size.x)
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
        let width = Int(size.x)
        let height = Int(size.y)
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
