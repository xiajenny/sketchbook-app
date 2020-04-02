//
//  Renderer.swift
//
//  Copyright © 2020
//

import MetalKit

struct Vec2 {
    var x : Float = 0.0
    var y : Float = 0.0
}

extension Vec2: CustomStringConvertible {
    var description: String {
        return "\(x), \(y)"
    }
}
    
extension Vec2 {
    static func + (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(x: left.x + right.x, y: left.y+right.y)
    }
    static func - (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(x: left.x - right.x, y: left.y-right.y)
    }
    static func * (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(x: left.x * right.x, y: left.y*right.y)
    }
    static func * (left: Vec2, right: Float) -> Vec2 {
        return Vec2(x: left.x * right, y: left.y*right)
    }
    static func / (left: Vec2, right: Float) -> Vec2 {
        return Vec2(x: left.x / right, y: left.y/right)
    }
}

//typealias Vec2 = (x: Float, y: Float)
typealias ivec2 = (x: Int, y: Int)
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

func v_len(a: Vec2) -> Float { return sqrtf(a.x*a.x + a.y*a.y) }
func v_norm(a: Vec2) -> Vec2 { return a * (1.0 / v_len(a: a)) }

struct Vertex {
    var position: float3
    var color: float4
}

struct Brush {
    var position: Vec2
    var size: Float
    var force: Float
    var color: Color
}

struct BrushUniform {
    var position: Vec2
    var size: Float
    var color: Color
}

struct Color {
    var r : UInt8
    var g : UInt8
    var b : UInt8
}

class Renderer: NSObject {
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    var brushPipelineState: MTLRenderPipelineState!
    var strokePipelineState: MTLRenderPipelineState!
    
    var uniformBuffer: MTLBuffer! = nil;
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformStrokeBuffer: MTLBuffer!
    /*
    var vertices: [Vertex] = [
        Vertex(position: float3(1,1,0), color: float4(1,0,0,1)),
        Vertex(position: float3(-1,-1,0), color: float4(0,1,0,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,1,1)),
        Vertex(position: float3(1,1,0), color: float4(1,0,0,1)),
        Vertex(position: float3(-1,-1,0), color: float4(0,1,0,1)),
        Vertex(position: float3(-1,1,0), color: float4(0,0,1,1))
    ]
    // */
    let vertices:[Float] = [
    -1.0,-1.0, 0.0,   0.0, 0.0,
    1.0,-1.0, 0.0,   1.0, 0.0,
    1.0, 1.0, 0.0,   1.0, 2732.0/2736.0,
    1.0, 1.0, 0.0,   1.0, 2732.0/2736.0,
    -1.0, 1.0, 0.0,   0.0, 2732.0/2736.0,
    -1.0,-1.0, 0.0,   0.0, 0.0]
    let indices: [UInt16] = [0,1,2,2,4,0]
    
    var brushTexture: MTLTexture! = nil
    var imageTexture: MTLTexture! = nil
    var displayTexture: MTLTexture! = nil
    
    var winwidth: Int = 0
    var winheight: Int = 0
    var txwidth: Int = 0
    var txheight: Int = 0
    
    //brush stuff
    var brushSize: Float = 256
    var brushBuffer: [Brush] = []
    var strokeBuffer: [BrushUniform] = []
    var defaultColor: Color = Color(r: 10,g: 10,b: 80)
    var prevStroke: Brush
    var touchEnded: Bool = true
    
    init(device: MTLDevice) {
        txwidth = 2048
        txheight = 2736 // multiple of 16 px tile size
        winwidth = 2048
        winheight = 2732
        prevStroke = Brush(position: Vec2(x: 0,y: 0), size: 0, force: 0, color: defaultColor)
        super.init()
        createCommandQueue(device: device)
        createPipelineState(device: device)
        createBuffers(device: device)
        clearCanvas(color: Color(r: 200, g: 40, b: 40))
        fillBrush(color: Color(r:40, g: 40, b: 200))
        strokeBuffer.reserveCapacity(1000)
    }
    
    //how to do this in mtk??
    func flushGraphics()
    {
        if commandQueue != nil
        {
    //        commandQueue!.commit()
     //       commandQueue!.waitUntilCompleted()
        }
        //why make command queue nil all the time?
        //commandQueue = nil
    }
    
    func fillColor(imgData: UnsafeMutablePointer<UInt8>, width: Int, height: Int, color: Color) -> UnsafeMutablePointer<UInt8>{
        var i = 0
        for _ in 0 ..< height {
            for _ in 0 ..< width {
                imgData[i+0] = color.r
                imgData[i+1] = color.g
                imgData[i+2] = color.b
                imgData[i+3] = 0xff
                i+=4
            }
        }
        return imgData
    }
    
    func fillBrush(color: Color) {
        let bytesPerPixel = 4
        let kw = Int(brushSize)
        let kernelSize = kw * kw * 4
        let brushData = UnsafeMutablePointer<UInt8>.allocate(capacity: kernelSize)
        let center = ivec2(kw/2, kw/2)
        for x in 0 ..< kw {
            for y in 0 ..< kw {
                let i = (y * kw + x) * 4 //4 is num components per pixel
                //if distance from center is more than brush radius, 0 alpha
                brushData[i+0] = color.r
                brushData[i+1] = color.g
                brushData[i+2] = color.b
                if pow(Decimal(x - center.x), 2) + pow(Decimal(y - center.y), 2) < pow(Decimal(kw/2), 2) {
                    brushData[i+3] = 0xff
                } else {
                    brushData[i+3] = 0
                }
            }
        }
        let region = MTLRegionMake2D(0, 0, kw, kw)
        brushTexture.replace(region: region, mipmapLevel: 0, withBytes: brushData, bytesPerRow: kw*bytesPerPixel)
        brushData.deallocate()
    }
    
    func clearCanvas(color: Color) {
        flushGraphics()
        let bytesPerPixel = 4
        //TODO switch this back to 16bits to remove banding
        var imgData = UnsafeMutablePointer<UInt8>.allocate(capacity: txwidth * txheight * 4)
        imgData = fillColor(imgData: imgData, width: txwidth, height: txheight, color: color)
        let region = MTLRegionMake2D(0, 0, txwidth, txheight)
        imageTexture.replace(region: region, mipmapLevel: 0, withBytes: imgData, bytesPerRow: txwidth*bytesPerPixel)
        imgData.deallocate()
        
        //draw grids
        let w = 8
        let markerColor = Color(r: 0,g: 0,b: 0)
        var markerData = UnsafeMutablePointer<UInt8>.allocate(capacity: w*w*4)
        markerData = fillColor(imgData: markerData, width: w, height: w, color: markerColor)
        for row in 0 ... 7 {
            for col in 0 ... 7 {
                let x = row * txwidth / 8
                let y = col * txheight / 8
                let region = MTLRegionMake2D(x, y, w, w)
                imageTexture.replace(region: region, mipmapLevel: 0, withBytes: markerData, bytesPerRow: w*bytesPerPixel)
            }
        }
        markerData.deallocate()
    }
    
    func drawCanvasInstanced(in view: MTKView) {
        var c = prevStroke
        for brush in brushBuffer {
            var spacing: Float = max(5.0, brush.size / 20.0)
            let d = v_len(a: (brush.position - c.position))
            var n: Int = Int(d / spacing)
            if n > 400 {
                n = 400
                spacing = d / Float(n)
            }
            let step = v_norm(a: (brush.position - c.position)) * spacing
            //let n = 4
            //let step = v_norm(a: (brush.position - c.position)) * (d / Float(n))
            //let df: Float = (brush.force - c.force) / Float(n + 1)

            //debug color, r channel
            c.color = Color(r: 0,g: 0,b: 0)
            for _ in 0 ..< n {
                //FIXME later: save unrendered brushes for later
                if strokeBuffer.count == 1000 {
                    break;
                }
                strokeBuffer.append(BrushUniform(position: c.position, size: c.size, color: c.color))
                c.position = c.position + step
                c.color.r = UInt8(Int(c.color.r) + 255/n % 256)
            }
            print("d: \(d) n: \(n) strokeBuffer: \(strokeBuffer.count)/\(strokeBuffer.capacity)")
        }
        if !strokeBuffer.isEmpty {
            drawStroke(in: view)
            strokeBuffer.removeAll(keepingCapacity: true)
        }
        prevStroke = c
        brushBuffer.removeAll()
    }
    
    func drawCanvas(in view: MTKView) {
        var c = prevStroke
        for brush in brushBuffer {
            var spacing: Float = max(5.0, brush.size / 20.0)
            let d = v_len(a: (brush.position - c.position))
            var n: Int = Int(d / spacing)
            if n > 100 {
                n = 100
                spacing = d / Float(n)
            }
            let step = v_norm(a: (brush.position - c.position)) * spacing
            //let n = 4
            //let step = v_norm(a: (brush.position - c.position)) * (d / Float(n))
            //let df: Float = (brush.force - c.force) / Float(n + 1)
            print("d: \(d) n: \(n)")
            
            //debug color, r channel
            c.color = Color(r: 0,g: 0,b: 0)
            for _ in 0 ..< n {
                //print("drawCanvas xy: \(c.position.x),\(c.position.y)")
                drawBrush(in: view, brush: c)

                c.position = c.position + step
                //c.force += df
                c.color.r = UInt8(Int(c.color.r) + 255/n % 256)
            }
            drawBrush(in: view, brush: c)
            //c = brush
        }
        prevStroke = c
        brushBuffer.removeAll()
    }
    
    /*
    //TODO do this in fragment shader
    func drawBrush(brush: Brush) {
        if Int(brush.position.x + brush.size) > txwidth
            || Int(brush.position.y + brush.size) > txheight {
            return
        }
        let color = defaultColor
        let bytesPerPixel = 4
        let kernelWidth = Int(brush.size)
        let kernelSize = kernelWidth * kernelWidth * bytesPerPixel
        var brushData = UnsafeMutablePointer<UInt8>.allocate(capacity: kernelSize)
        brushData = fillColor(imgData: brushData, width: kernelWidth, height: kernelWidth, color: color)
        let region = MTLRegionMake2D(Int(brush.position.x), Int(brush.position.y), kernelWidth, kernelWidth)
        imageTexture.replace(region: region, mipmapLevel: 0, withBytes: brushData, bytesPerRow: kernelWidth*bytesPerPixel)
        brushData.deallocate()
    }
 // */
    func processTouchPosition(touch: UITouch, view: MTKView) -> Vec2 {
        let t = touch.preciseLocation(in: view)
        let txw = Float(txwidth)
        let txh = Float(txheight)
        let bounds = view.bounds.size
        let x = 2 * Float(t.x) / Float(bounds.width) * txw - txw
        let y = 2 * Float(t.y) / Float(bounds.height) * txh - txh
        let pos: Vec2 = Vec2(x: x,y: y)
            //pos = Vec2(Float(touch_location.x), Float(touch_location.y))
        //print ("processTouchPosition touch \(t.x),\(t.y) xy \(pos.x),\(pos.y)")
        //print ("processTouchPosition bounds \(view.bounds.size.width),\(view.bounds.size.height)")
        return pos
    }
    
    func newTouch(touch: UITouch, view: MTKView) {
        let pos = processTouchPosition(touch: touch, view: view)
        prevStroke = Brush(position: pos, size: brushSize, force: Float(touch.force), color: defaultColor)
    }
    
    func newColor() {
        defaultColor.r = UInt8((Int(defaultColor.r) + 43) % 256)
        defaultColor.g = UInt8((Int(defaultColor.g) + 19) % 256)
        defaultColor.b = UInt8((Int(defaultColor.b) + 4) % 256)
        //let d = defaultColor
        //print("color: \(d.r) \(d.g) \(d.b)")
    }
    var filter: Int = 10
    var touchCount: Int = 0
    func didTouch(touches: Set<UITouch>, view: MTKView) {
        for touch in touches {
            touchCount += 1
            if touchCount == filter {
                touchCount = 0
            } else {
                //continue
            }
            let pos = processTouchPosition(touch: touch, view: view)
            brushBuffer.append(Brush(position: pos, size: brushSize, force: Float(touch.force), color: defaultColor))
            newColor()
        }
    }
    
    //MARK: Builders
    func createCommandQueue(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
    }
    
    func createPipelineState(device: MTLDevice) {
        // The device will make a library for us
        let library = device.makeDefaultLibrary()
        //let vertexFunction = library?.makeFunction(name: "basic_vertex_function")
        //let fragmentFunction = library?.makeFunction(name: "basic_fragment_function")
        let vertexFunction = library?.makeFunction(name: "basic_vertex")
        let fragmentFunction = library?.makeFunction(name: "basic_fragment")

        // create canvas texture
        let txdesc = MTLTextureDescriptor()
        //    txdesc.pixelFormat = MTLPixelFormat.BGRA8Unorm
        txdesc.pixelFormat = MTLPixelFormat.rgba8Unorm
        txdesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        txdesc.storageMode = MTLStorageMode.shared
        txdesc.textureType = MTLTextureType.type2D
        txdesc.width = txwidth
        txdesc.height = txheight
        displayTexture = device.makeTexture(descriptor: txdesc)
        //txdesc.pixelFormat = MTLPixelFormat.rgba16Unorm
        imageTexture = device.makeTexture(descriptor: txdesc)
        txdesc.usage = [.shaderRead, .shaderWrite]
        txdesc.width = Int(brushSize)
        txdesc.height = Int(brushSize)
        brushTexture = device.makeTexture(descriptor: txdesc)
        
        // Create basic descriptor
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        // Attach the pixel format that si the same as the MetalView
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat(rawValue: 252)!
        // Attach the shader functions
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Try to update the state of the renderPipeline
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
        
        // create a brush pipeline
        let brushVertexFunction = library?.makeFunction(name: "brush_vertex")
        let brushFragmentFunction = library?.makeFunction(name: "brush_fragment")
        renderPipelineDescriptor.depthAttachmentPixelFormat = .invalid
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.isDepthWriteEnabled = false
        depthStateDescriptor.depthCompareFunction = .never
        device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.vertexFunction = brushVertexFunction
        renderPipelineDescriptor.fragmentFunction = brushFragmentFunction

        do {
            brushPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<float3>.size
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        let strokeVertexFunction = library?.makeFunction(name: "stroke_vertex")
        renderPipelineDescriptor.vertexFunction = strokeVertexFunction
        do {
            strokePipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func createBuffers(device: MTLDevice) {
        uniformBuffer = device.makeBuffer(length: 8 * MemoryLayout<Float>.stride)
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<Float>.size * vertices.count,
                                         options: [])
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.size * indices.count,
                                        options: [])
        uniformStrokeBuffer = device.makeBuffer(length: 32 * 1000 * MemoryLayout<Float>.stride)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        //draw on texture first, then present to screen
        //drawCanvas(in: view)
        drawCanvasInstanced(in: view)
        drawFrame(in: view)
        if touchEnded == true && brushBuffer.count == 0 {
            // MARK: - pausing causes new stroke not recognized as new
            //view.isPaused = true /
        }
    }
        
    func drawFrame(in view: MTKView) {
        // Get the current drawable and descriptor

        guard let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
        }
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(renderPipelineState)
        // Pass in the vertexBuffer into index 0
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // Draw primitive at vertextStart 0
        commandEncoder?.setFragmentTexture(imageTexture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    func drawBrush(in view: MTKView, brush: Brush) {
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = imageTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let uniformBuffer_ptr = uniformBuffer.contents().assumingMemoryBound(to: Float.self)
        uniformBuffer_ptr[0] = brush.position.x / Float(txwidth)
        uniformBuffer_ptr[1] = brush.position.y / Float(txheight)
        
        //print ("drawBrush \(brush.position)")
        uniformBuffer_ptr[2] = brush.size / Float(txwidth)
        uniformBuffer_ptr[3] = brush.size / Float(txheight)
        
        uniformBuffer_ptr[4] = Float(Float(brush.color.r)/255.0)
        uniformBuffer_ptr[5] = Float(Float(brush.color.g)/255.0)
        uniformBuffer_ptr[6] = Float(Float(brush.color.b)/255.0)
        
        //print("drawBrush color: \(brush.color.r) \(brush.color.g) \(brush.color.b)")
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(brushPipelineState)
        // Pass in the vertexBuffer into index 0
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        // Draw primitive at vertextStart 0
        //commandEncoder?.setFragmentTexture(imageTexture, index: 0)
        commandEncoder?.setFragmentTexture(brushTexture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
    
    func drawStroke(in view: MTKView) {

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = imageTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        let uniformBuffer_ptr = uniformStrokeBuffer.contents()//.assumingMemoryBound(to: Float.self)
        memcpy(uniformBuffer_ptr, strokeBuffer, strokeBuffer.count * MemoryLayout<Float>.size)

        //print("drawBrush color: \(brush.color.r) \(brush.color.g) \(brush.color.b)")
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(strokePipelineState)
        // Pass in the vertexBuffer into index 0
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(uniformStrokeBuffer, offset: 0, index: 1)
        //commandEncoder?.setVertexBuffer(&modelConstraints, length: MemoryLayout<ModelConstraints>.stride, index: 1)
        // Draw primitive at vertextStart 0
        //commandEncoder?.setFragmentTexture(imageTexture, index: 0)
        commandEncoder?.setFragmentTexture(brushTexture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: strokeBuffer.count)

        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
}
