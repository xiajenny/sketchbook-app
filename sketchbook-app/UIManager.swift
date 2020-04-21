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

    class GraphicalElement {
        var toUpdate = false
        var txIndex: UInt32
        var position: Vec2
        var size: Vec2
        var color: Color
        var g: (Int, TextureBox) -> ()
        func createElement(_ box: TextureBox) -> BrushSample{
            if toUpdate {
                toUpdate = false
                g(Int(txIndex), box)
                withUnsafePointer(to: box.t[Int(txIndex)]) {
                    print("createElement: \($0)")
                }
            }
            
            return BrushSample(position: position, size: size.x, color: color)
        }
        
        init(p: Vec2, s: Vec2, c: Color = Color(), g: @escaping (Int, TextureBox) -> (),
             ti: UInt32) {
            position = p
            size = s
            color = c
            self.g = g
            
            txIndex = ti
        }
    }

    var uiMap : [String: GraphicalElement] = [:]

    var renderer: Renderer!
    var initialized: Bool = false
    
    init(w: Int, h: Int, r: Renderer) {
        txwidth = w
        txheight = h
        buttonColor = defaultButtonColor
        let hsv = itof(i: IntHSV(h: hue, s: 50, v: 50, a: 255))
        let color = hsv2rgb(input: hsv)
        brushColor = color
        renderer = r
        
        initialized = true
        
        //create graphical elements and their backing texture
        //color picker
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        uiMap["colorPicker"] = createGE(pos: colorPickerLocation,
                                           size: Vec2(Float(colorPickerDim)),
                                           g: fillColorPicker,
                                           td: textureDescriptor)

        //color picker hue
        let p = colorPickerLocation + colorPickerHueOffsetLocation
        uiMap["colorPickerHue"] = createGE(pos: p,
                                              size: Vec2(Float(widthHue), Float(heightHue)),
                                              g: fillColorPickerHue,
                                              td: textureDescriptor)

        //new layer
        
        //create gradient maps
        
        //create color markers for gradient map
        
        //how to add and delete markesr??
        
        //how to change colors of each marker?
    }
    
    func createGE(pos: Vec2, size: Vec2, g: @escaping (Int, TextureBox) -> (), td: MTLTextureDescriptor) -> GraphicalElement {
        let ti = renderer.createTexture(td, size: size)//, size: size)
        //TODO GE size not necessarily the same size as texture!! need 2 sizes
        return GraphicalElement(p: pos, s: size, g: g, ti: UInt32(ti))
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
    
    func getDrawElements(_ textures: TextureBox) -> [BrushUniform]{
        assert(initialized)

        var uniformStagingBuffer: [BrushUniform] = []
        for (_, ui) in uiMap {
            let element = ui.createElement(textures)
            uniformStagingBuffer.append(convert(sample: element, txIndex: ui.txIndex))
        }
        
        //button for resizing brush
        var element = createResizeBrushButton()
        element.color = brushColor
        uniformStagingBuffer.append(convert(sample: element))
        
        if buttonPressed {
            element = createResizeBrush(brushSize: brushSize)
            element.color = brushColor
            uniformStagingBuffer.append(convert(sample: element))
        }
        return uniformStagingBuffer
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
    
    func fillColorPickerHue(i: Int, b: TextureBox) {
        fillColorPickerHue(&b.t[i]!)
    }
    func fillColorPicker(i: Int, b: TextureBox) {
        fillColorPicker(&b.t[i]!)
    }
    func fillColorPickerHue(_ texture: inout MTLTexture) {

        let bytesPerPixel = 4
        let cpData = UnsafeMutablePointer<UInt8>.allocate(capacity: widthHue * heightHue * bytesPerPixel)
        for v in 0 ..< heightHue {
            for h in 0 ..< widthHue {
                let hsv = itof(i: IntHSV(h: h, s: 255, v: 255, a: 255))
                let color = hsv2rgb(input: hsv)
                let index = v * widthHue + h
                //let index = h * heightHue + v
                cpData[index * bytesPerPixel + 0] = color.r
                cpData[index * bytesPerPixel + 1] = color.g
                cpData[index * bytesPerPixel + 2] = color.b
                cpData[index * bytesPerPixel + 3] = 255//color.a
            }
        }
        let region = MTLRegionMake2D(0, 0, widthHue, heightHue)
        texture.replace(region: region, mipmapLevel: 0, withBytes: cpData, bytesPerRow: widthHue*bytesPerPixel)
    }
    
    func createColorPickerHue(box: TextureBox) -> BrushSample {
        if updateHueOnce {
            fillColorPickerHue(&(box.t[2]!))
        }
        let element = BrushSample(position: colorPickerLocation+colorPickerHueOffsetLocation, size: 360, color: defaultButtonColor)
        return element
    }
    func createColorPickerHue(tex: inout MTLTexture) -> BrushSample {
        if updateHueOnce {
            fillColorPickerHue(&tex)
        }
        
        let element = BrushSample(position: colorPickerLocation+colorPickerHueOffsetLocation, size: 360, color: defaultButtonColor)
        return element
    }
    
    func fillColorPicker(_ tex: inout MTLTexture) {
        updateHue = false

        let bytesPerPixel = 4
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
    
    func createColorPicker(box: TextureBox) -> BrushSample {
        if updateHue {
            fillColorPicker(&(box.t[1]!))
        }
        let element = BrushSample(position: colorPickerLocation, size: 256, color: defaultButtonColor)
        return element
    }
    func createColorPicker(tex: inout MTLTexture) -> BrushSample {
        if updateHue {
            fillColorPicker(&tex)
        }
        let element = BrushSample(position: colorPickerLocation, size: 256, color: defaultButtonColor)
        return element
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
            let hsv = itof(i: IntHSV(h: hue, s: Int(sat), v: Int(val), a: 255))
            brushColor = hsv2rgb(input: hsv)
            print("pos: \(pos.x) origin: \(origin.x) sv: \(sv) hue: \(hue) s: \(sat) v: \(val)")
            updateHue = true
        }
        return brushColor
    }
}
