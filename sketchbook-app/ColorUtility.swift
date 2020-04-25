//
//  ColorUtility.swift
//  sketchbook-app
//
//  Created by Si Li on 4/7/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation

struct Color {
    var r : UInt8 = 0
    var g : UInt8 = 0
    var b : UInt8 = 0
    var a : UInt8 = 0
    init() {
        r = 0
        g = 0
        b = 0
        a = 0
    }
    init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

struct FloatRGB {
    var r : Float = 0
    var g : Float = 0
    var b : Float = 0
    var a : Float = 1
}

struct FloatHSV {
    var h : Float = 0
    var s : Float = 0
    var v : Float = 0
    var a : Float = 1
}

struct IntHSV {
    var h : Int = 0
    var s : Int = 0
    var v : Int = 0
    var a : Int = 1
}

func itof(i: IntHSV) -> FloatHSV {
    var out = FloatHSV()
    out.h = Float(i.h)
    out.s = sqrt(sqrt(Float(i.s) / 255))
    out.v = pow(Float(i.v) / 255, 1.4)
    out.a = sqrt(Float(i.a) / 255)
    return out
}
func ftoi(f: FloatRGB) -> Color {
    var out = Color()
    out.r = UInt8(min(255, abs(f.r) * 255))
    out.g = UInt8(min(255, abs(f.g) * 255))
    out.b = UInt8(min(255, abs(f.b) * 255))
    out.a = UInt8(min(255, abs(f.a) * 255))
    return out
}

//adapted from https://stackoverflow.com/questions/3018313/algorithm-to-convert-rgb-to-hsv-and-hsv-to-rgb-in-range-0-255-for-both
func hsv2rgb(input: FloatHSV) -> Color {
    var hh, p, q, t, ff: Float
    var i: Int
    var out = FloatRGB()
    if input.s <= 0.0  {       // < is bogus, just shuts up warninputgs
        out.r = input.v;
        out.g = input.v;
        out.b = input.v;
        return ftoi(f: out);
    }
    hh = input.h;
    if hh >= 360.0 { hh = 0.0; }
    hh /= 60.0;
    i = Int(hh);
    ff = Float(hh - Float(i));
    p = input.v * (1.0 - input.s);
    q = input.v * (1.0 - (input.s * ff));
    t = input.v * (1.0 - (input.s * (1.0 - ff)));
    
    switch(i) {
    case 0:
        out.r = input.v;
        out.g = t;
        out.b = p;
        break;
    case 1:
        out.r = q;
        out.g = input.v;
        out.b = p;
        break;
    case 2:
        out.r = p;
        out.g = input.v;
        out.b = t;
        break;
        
    case 3:
        out.r = p;
        out.g = q;
        out.b = input.v;
        break;
    case 4:
        out.r = t;
        out.g = p;
        out.b = input.v;
        break;
    default:
        out.r = input.v;
        out.g = p;
        out.b = q;
        break;
    }
    return ftoi(f: out);
}
