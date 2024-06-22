Shader "dawnOutline"
{

    //the outline effect is achieved with 2 passes, one pass for the base color, and another pass with the outline color, and the vertexes displaced outwards (along normals)
    //this shader makes the source / body color equal to the background (grabpass)

    Properties
    {

        _Color("Color", Color) = (1, 1, 1, 1)

        _OutlineWidthMask("Outline Width Mask", 2D) = "white" {}
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", Range(0, 0.1)) = 0.03

        _DisplacementTex("Displacement Texture", 2D) = "white" {}
        //_MaxDisplacement("Max Displacement", Float) = 1.0
        _MaxDisplacement("Max Displacement", Range(0,1)) = 1

        _Quantize("Quantize", Range(0, 1000)) = 1


        _Hue("Hue", Range(0, 360)) = 120
        _Sat("Saturation", Range(0, 10)) = 1
        _Brightness("Brightness", Range(0, 4)) = 1
    }
    CGINCLUDE
    #include "UnityCG.cginc"

    sampler2D _GrabTexture;
    uniform sampler2D _MainTex;
    uniform float4 _MainTex_ST;
    sampler2D _DisplacementTex;
    uniform float _MaxDisplacement;

    //float4 _OutlineColor;
    uniform sampler2D _OutlineWidthMask;
    half _OutlineWidth;
    half4 _OutlineColor;

    int _Quantize;

    float _Hue;
    float _Sat;
    float _Brightness;

    float3 rgb2hsv(float3 C)
    {
        saturate(C);
        float3 HSV = { 0, 1, 1 };
        float _min = C.r;
        float _med = C.g;
        float _max = C.b;
        float _t = 0;
        if (_min > _med)
        {
            _t = _min;
            _min = _med;
            _med = _t;
        }
        if (_min > _max)
        {
            _t = _min;
            _min = _max;
            _max = _t;
        }
        if (_med > _max)
        {
            _t = _med;
            _med = _max;
            _max = _t;
        }

        HSV.b = _max;

        float Delta = _max - _min;
        if (_max > 0)
        {
            HSV.g = Delta / _max;
        }

        if (Delta > 0)
        {
            if (_max == C.r) HSV.r = (C.g - C.b) / Delta;
            else if (_max == C.g) HSV.r = 2.0f + (C.b - C.r) / Delta;
            else HSV.r = 4.0f + (C.r - C.g) / Delta;
        }
        HSV.r /= 6.0f;

        return HSV;
    }
    float3 hsv2rgb(float3 C)
    {
        float c = C.z * C.y;
        float x = c * (1 - abs((C.x * 6) % 2 - 1));
        float m = C.z - c;



        float3 CC = { 0, 0, 0 };
        switch (floor(C.r * 6))
        {
            case 0: CC = float3(c, x, 0); break;
            case 1: CC = float3(x, c, 0); break;
            case 2: CC = float3(0, c, x); break;
            case 3: CC = float3(0, x, c); break;
            case 4: CC = float3(x, 0, c); break;
            case 5: CC = float3(c, 0, x); break;
        }
        CC.rgb += m;
        return CC;
    }

    float Quantize(float num, float quantize)
    {
        return round(num * quantize) / quantize;
    }

    struct appdata
    {
        float4 vertex : POSITION;
        float4 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
        float4 tangent : TANGENT;
    };
    struct v2f
    {
        float4 pos : SV_POSITION;
        float4 posWorld : TEXCOORD0;
        float4 vGrabPos : TEXCOORD1;
        float4 posObj : TEXCOORD2;
        float4 tex : TEXCOORD3;
        float4 color : COLOR;
    };

    ENDCG
    Subshader
    {
        GrabPass
        {
            "_GrabTexture"
        }
        Pass
        {

            //Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //#pragma multi_compile_fwdbase
            //#pragma target 3.0
            v2f vert(appdata input)
            {
                v2f output;
                //position.xyz += normal * _OutlineWidth;//offset vertex positions outwards by _OutlineWidth
                output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
                //output.tex = input.texcoord;

                //input.vertex.xyz += input.normal * _OutlineWidth;//offset vertex positions outwards by _OutlineWidth
                output.posObj = input.vertex;
                output.pos = UnityObjectToClipPos(input.vertex);


                //float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
                //half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
                half3 worldN = UnityObjectToWorldNormal(input.normal);

                //float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(input.texcoord.xy, 0.0, 0.0));
                //float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb) * _MaxDisplacement;



                //using wiggling of the vertices to give an animated drawn effect
                float displacement = _MaxDisplacement * (.5 - tex2Dlod(_DisplacementTex, float4(output.posObj.xy + Quantize(_Time.y, _Quantize), 0, 0)));

                //float4 newVertexPos = input.vertex + float4(random(input.vertex.x) * displacement, 0, 0, 0.0);
                float3 newVertexPos = float3(input.vertex.x + displacement, input.vertex.y + displacement, input.vertex.z + displacement);




                output.pos = UnityObjectToClipPos(newVertexPos);


                output.vGrabPos = ComputeGrabScreenPos(output.pos);
                return output;
            }

            float4 frag(v2f input) : COLOR
            {
                //float4 col = float4(1,1,1,1);
                float4 col = tex2Dproj(_GrabTexture, input.vGrabPos);

                return col;
            }
            ENDCG
        }

        Pass
        {

            Cull Front

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag



            v2f vert(appdata input)
            {
                v2f output;
                //position.xyz += normal * _OutlineWidth;//offset vertex positions outwards by _OutlineWidth
                output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
                //output.tex = input.texcoord;

                input.vertex.xyz += input.normal * _OutlineWidth;//offset vertex positions outwards by _OutlineWidth
                output.posObj = input.vertex;
                output.pos = UnityObjectToClipPos(input.vertex);


                //float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
                //half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
                half3 worldN = UnityObjectToWorldNormal(input.normal);

                //float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(input.texcoord.xy, 0.0, 0.0));
                //float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb) * _MaxDisplacement;

                float displacement = _MaxDisplacement * (.5 - tex2Dlod(_DisplacementTex, float4(output.posObj.xy + Quantize(_Time.y, _Quantize), 0, 0)));

                //float4 newVertexPos = input.vertex + float4(random(input.vertex.x) * displacement, 0, 0, 0.0);
                float3 newVertexPos = float3(input.vertex.x + displacement, input.vertex.y + displacement, input.vertex.z + displacement);
                //output.pos = UnityObjectToClipPos(newVertexPos);

                output.pos = UnityObjectToClipPos(newVertexPos);

                float4 clipPos = UnityObjectToClipPos(newVertexPos);

                float4 outlineWidthMask = tex2Dlod(_OutlineWidthMask, input.texcoord);
                _OutlineWidth /= 1000;
                _OutlineWidth *= outlineWidthMask.r;
                _OutlineWidth = clamp(_OutlineWidth / (1 / clipPos.w), 0, _OutlineWidth);
                output.pos = UnityObjectToClipPos(input.vertex + input.normal * _OutlineWidth);

    //#ifdef UNITY_HALF_TEXEL_OFFSET
    //                output.pos.xy += (_ScreenParams.zw - 1.0) * float2(-1, 1);
    //#endif

                return output;
                //return UnityObjectToClipPos(position);
            }


            float4 frag(v2f input) : COLOR
            {
                float4 col = _OutlineColor;


                _Hue = (_Hue) / 360;
                _Hue += 1;
                col.rgb = rgb2hsv(col.rgb);
                col.r += _Hue;
                col.r %= 1;
                col.rgb = hsv2rgb(col.rgb);

                fixed lum = saturate(Luminance(col.rgb));
                col.rgb = lerp(col.rgb, fixed3(lum, lum, lum), (1 - _Sat));
                col.rgb *= _Brightness;

                return col;
            }

            ENDCG

        }

    }

}
