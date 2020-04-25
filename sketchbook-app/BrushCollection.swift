//
//  BrushCollection.swift
//  sketchbook-app
//
//  Created by Si Li on 4/15/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation
//input sample
struct BrushSample {
    var position: Vec2 = Vec2(40, 40)
    var force: Float = 1
    var first: Bool = true
    var size: Float = 16
    var alpha: Float = 1.0
    var color = Color(255,10,255,100)
}

extension BrushSample: CustomStringConvertible {
    var description: String {
        return "pos: \(position), f: \(force), size: \(size), color: \(color)"
    }
}

class Brush {
    var name: String
    var size: Float = defaultBrushSize
    var sampleBuffer: [BrushSample] = []
    //var strokeBuffer: [BrushUniform] = []
    var color = Color(10,10,80,155)
    var prevSample = BrushSample()
    var touchEnded: Bool = true
    var firstUpdateIndex: Int = 0
    var txwidth: Int = 0
    var txheight: Int = 0
    init (n: String, w: Int, h: Int) {
        name = n
        //strokeBuffer.reserveCapacity(1000)
        txwidth = w
        txheight = h
    }

    func append(pos: Vec2, force: Float, first: Bool) {
        var sample = BrushSample(position: pos, force: force, first: first)
        sample.size = self.size //* force
        sample.color = self.color
        sample.first = first
        sample.force = force
        sampleBuffer.append(sample)
        //print("appending brush.size: \(self.size) f: \(force) size: \(sample.size)")
    }

}

class BrushCollection {
    //create textures
    //create uniformstagingbuffer
    //create render descriptors
}
