Shader "trippy" {
    SubShader{
        Tags {"Queue" = "Geometry-10" }
        Cull off
        Lighting Off
        ZTest LEqual
        ZWrite On
        ColorMask 0
        Pass {}
    }
}
