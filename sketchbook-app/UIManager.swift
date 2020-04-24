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
    var txwidth: Int = 0
    var txheight: Int = 0
    
    let defaultButtonColor = Color(r: 80,g: 80,b: 180, a: 255)
    let buttonActivatedColor = Color(r: 40,g: 40,b: 100, a: 255)
    var buttonColor: Color
    
    var buttonPressed = false
    var colorPickMode = false
    var colorPickHueMode = false
    
    var updateHue = true
    var updateHueOnce = true
    
    var colorPickerDim = 256
    var firstPencilLoc = Vec2()
    var currentPencilLoc = Vec2()
    var newBrushSize: Float = 256
    var brushSize: Float = 256
    var buttonLoc = Vec2(0, -800)
    
    var colorPickerLocation = Vec2(800, -2000)
    let colorPickerHueOffsetLocation = Vec2(700, 0)
    var hue = 260
    var sat = 255
    var val = 255
    let widthHue = 360
    let heightHue = 2
    var brushColor: Color
    //rendering glue

    var uiMap : [String: GraphicalElement] = [:]

    var renderer: Renderer!
    var initialized: Bool = false
    
    init(w: Int, h: Int, r: Renderer) {
        txwidth = w
        txheight = h
        renderer = r
        initialized = true
        
        buttonColor = defaultButtonColor
        let hsv = itof(i: IntHSV(h: hue, s: 50, v: 50, a: 255))
        brushColor = hsv2rgb(input: hsv)

        //create graphical elements and their backing texture
        let td = MTLTextureDescriptor()
        td.usage = [.shaderRead, .shaderWrite]
        //color picker
        var size = Vec2(Float(colorPickerDim))
        var ti = renderer.createTexture(td, size: size)
        uiMap["colorPicker"] = ColorPicker(p: colorPickerLocation, s: size, h: hue, ti: ti)

        //color picker hue
        size = Vec2(Float(widthHue), Float(heightHue))
        ti = renderer.createTexture(td, size: size)
        let p = colorPickerLocation + colorPickerHueOffsetLocation
        uiMap["colorPickerHue"] = ColorPickerHue(p: p, s: size, ti: ti)

        //new layer
        
        //create gradient maps
        
        //create color markers for gradient map
        
        //how to add and delete markesr??
        
        //how to change colors of each marker?
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
    
    func confirmBrushSize() {
        brushSize = newBrushSize
    }
    
    func convert(sample: BrushSample, txIndex: uint = 0) -> BrushUniform {
        let p = Vec2(sample.position.x / Float(txwidth),
                     sample.position.y / Float(txheight))
        let s = Vec2(sample.size / Float(txwidth),
                     sample.size / Float(txheight))
        let c = float4(Float(sample.color.r)/255.0,
                       Float(sample.color.g)/255.0,
                       Float(sample.color.b)/255.0,
                       Float(sample.color.a)/255.0 * powf(sample.force, 2.0))
        //print("convert color: \(c)")
        let strokeSample = BrushUniform(position: p, size: s, color: c, txIndex: txIndex)
        return strokeSample
    }

    func getElements(_ textureBox : TextureBox, _ buffer : inout [BrushUniform]) {
        for (uiName, ge) in uiMap {
            ge.fill(&textureBox.t[Int(ge.txIndex)]!)
            let element = ge.getElement()
            buffer.append(convert(sample: element, txIndex: uint(ge.txIndex)))
        }
    }
    
    func createResizeBrushButton() -> BrushSample {
        let element = BrushSample(position: Vec2(-0.0, -2000), size: 128.0, color: buttonColor)
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
    
    //MARK: - UI logic
    
    func firstTouch(pos: Vec2) {
        //get box of color picker
        var offset = Float(colorPickerDim)
        var left = colorPickerLocation.x - offset
        var right = colorPickerLocation.x + offset
        var top = colorPickerLocation.y + offset
        var bottom = colorPickerLocation.y - offset
        
        colorPickMode = left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
        
        offset = Float(widthHue)
        let hueLoc = colorPickerLocation + colorPickerHueOffsetLocation
        left = hueLoc.x - offset
        right = hueLoc.x + offset
        top = hueLoc.y + offset
        bottom = hueLoc.y - offset
        colorPickHueMode = left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
        
    }
    
    func cantDraw() -> Bool {
        return buttonPressed || colorPickMode || colorPickHueMode
    }
    
    func colorPick(pos: Vec2) -> Color{
        if colorPickMode {
            let offset = Float(colorPickerDim)
            var origin = colorPickerLocation
            origin.x += offset
            origin.y += offset
            let sv = (origin - pos)/2
            sat = Int(min(255.0, max(0.0, 255-sv.y)))
            val = Int(min(255, max(0, 255-sv.x)))
//            print("pos: \(pos) origin: \(origin) sv: \(sv) hue: \(hue) s: \(sat) v: \(val)")
            print("sv: \(sv) hue: \(hue) s: \(sat) v: \(val)")
            let hsv = itof(i: IntHSV(h: hue, s: Int(sat), v: Int(val), a: 255))
            brushColor = hsv2rgb(input: hsv)
        }
        
        if colorPickHueMode {
            let offset = Float(colorPickerDim)
            var origin = colorPickerLocation
            origin.x += offset
            let sv = (pos - origin) / 2
            hue = Int(min(255.0, max(0.0, sv.x)))
            var cp = uiMap["colorPicker"] as! ColorPicker
            cp.hue = hue
            cp.toUpdate = true
            let hsv = itof(i: IntHSV(h: hue, s: Int(sat), v: Int(val), a: 255))
            brushColor = hsv2rgb(input: hsv)
            print("pos: \(pos.x) origin: \(origin.x) sv: \(sv) hue: \(hue) s: \(sat) v: \(val)")
            updateHue = true
        }
        return brushColor
    }
}
