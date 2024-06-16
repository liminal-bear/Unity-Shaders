//shader that causes trailing render artifacts in VRChat, likely due to the pass writing nothing to the buffer
Shader "brokenMaybe" {
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