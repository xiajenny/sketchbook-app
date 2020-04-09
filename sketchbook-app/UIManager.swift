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
    
    var buttonPressed = false
    var colorPickMode = false
    
    var mustUpdate = true
    var colorPickerDim = 256
    var firstPencilLoc = Vec2()
    var currentPencilLoc = Vec2()
    var newBrushSize: Float = 256
    var buttonLoc = Vec2(x: 0, y: -800)
    
    var colorPickerLocation = Vec2(x: 800, y: -1800)
    var hue = 260
    var brushColor: Color
    //rendering glue

    init() {
        buttonColor = defaultButtonColor
        let hsv = itof(i: IntHSV(h: hue, s: 50, v: 50, a: 255))
        let color = hsv2rgb(input: hsv)
        brushColor = color
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
        let dim = colorPickerDim
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
    
    func createColorPicker(tex: inout MTLTexture) -> BrushSample {
        if mustUpdate {
            fillColorPicker(tex: &tex)
        }
        let element = BrushSample(position: colorPickerLocation, size: 256, color: defaultButtonColor)
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
    
    func firstTouch(pos: Vec2) {
        //get box of color picker
        let offset = Float(colorPickerDim/2)
        let left = colorPickerLocation.x - offset
        let right = colorPickerLocation.x + offset
        let top = colorPickerLocation.y + offset
        let bottom = colorPickerLocation.y - offset
        
        colorPickMode = left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
    }
    
    func cantDraw() -> Bool {
        return buttonPressed || colorPickMode
    }
    
    func colorPick(pos: Vec2) -> Color{
        if colorPickMode {
            let offset = Float(colorPickerDim/2)
            var origin = colorPickerLocation
            origin.x -= offset
            origin.y += offset
            let sv = origin - pos
            let s = sv.x
            let v = sv.y
            let hsv = itof(i: IntHSV(h: hue, s: Int(s), v: Int(v), a: 255))
            brushColor = hsv2rgb(input: hsv)
        }
        return brushColor
    }
}
