//
//  UIManager.swift
//  sketchbook-app
//
//  Created by Si Li on 4/9/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation
import MetalKit

class UIManager {
    let defaultButtonColor = Color(r: 80,g: 80,b: 180, a: 255)
    let buttonActivatedColor = Color(r: 40,g: 40,b: 100, a: 255)
    var buttonColor: Color
    
    var mustUpdate = true
    var colorPickerDim = 256
    var buttonPressed = false
    var firstPencilLoc = Vec2()
    var currentPencilLoc = Vec2()
    var newBrushSize: Float = 256
    let buttonLoc = Vec2(x: 0, y: -800)
    
    //rendering glue

    init() {
        buttonColor = defaultButtonColor
    }

    func pressButton() {
        buttonColor = buttonActivatedColor
        buttonPressed = true
        firstPencilLoc = Vec2()
        currentPencilLoc = Vec2()
    }
    
    func releaseButton() {
        buttonColor = defaultButtonColor
        buttonPressed = false
    }
    
    func fillColorPicker(tex: inout MTLTexture){

        mustUpdate = false
        let bytesPerPixel = 4
        //draw grid of stuff
        let dim = 256
        let cpData = UnsafeMutablePointer<UInt8>.allocate(capacity: dim * dim * bytesPerPixel)
        let hue = 260
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
    
    func createColorPicker(tex: inout MTLTexture) -> BrushSample {
        if mustUpdate {
            fillColorPicker(tex: &tex)
        }
        let loc = Vec2(x: 800, y: -1800)
        let element = BrushSample(position: loc, size: 256, color: defaultButtonColor)
        // */
        return element
    }
    
    func createResizeBrushButton() -> BrushSample {
        let element = BrushSample(position: Vec2(x: -0.0, y: -2000), size: 128.0, color: buttonColor)
        return element
    }
    
    func distTravelledFromButton() -> Float {
        let distFirst = v_len(a: firstPencilLoc - buttonLoc)
        let distCurr = v_len(a: buttonLoc - currentPencilLoc)
        let dist = distCurr - distFirst
        return dist
    }
    
    func createResizeBrush(brushSize: Float) -> BrushSample {
        let dist = distTravelledFromButton()
        newBrushSize = brushSize + dist / 2
        
        let element = BrushSample(position: buttonLoc, size: newBrushSize, color: defaultButtonColor)
        return element
    }
}
