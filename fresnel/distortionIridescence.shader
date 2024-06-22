Shader "Custom/Experimental" 
{
    //shader with iridescent fresnel, and mesh distortion
    //used in jelly effect

    Properties
    {
        _MainTex("Diffuse (RGB)", 2D) = "white" {}
        _Color("TintColor", Color) = (1,1,1,1)
        _Opacity("Opacity", Range(0,1)) = 1
        
        _DisplacementTex("Displacement Texture", 2D) = "white" {}
        //_MaxDisplacement("Max Displacement", Float) = 1.0
        _MaxDisplacement("Max Displacement", Range(0,1)) = 1

        _Roughness("Roughness", Range(0.0, 10.0)) = 0.0

        _ShimmerAmount("Shimmer Amount", Range(0,100)) = 1.0
        _ShimmerOffset1("Shimmer Offset 1", Range(0, 3.14)) = 1.04
        _ShimmerOffset2("Shimmer Offset 2", Range(0, 3.14)) = 2.09

        _AdjustMask("Color Adjustment mask", 2D) = "white" {}
        _Hue("Hue", Range(0,360)) = 0
        _Sat("Saturation", Range(0,10)) = 1
        _Bright("Brightness", Range(0, 10)) = 1

        _Quantize("Quantize", Range(0, 1000)) = 1

        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
    }

    CGINCLUDE
    uniform sampler2D _MainTex;
    uniform float4 _MainTex_ST;
    sampler2D _DisplacementTex;
    uniform float _MaxDisplacement;
    fixed4 _Color;
    uniform float _Opacity;

    float _ShimmerAmount;
    float _ShimmerOffset1;
    float _ShimmerOffset2;

    int _Quantize;
    float _Roughness;

    uniform sampler2D _AdjustMask;
    float _Hue;
    float _Sat;
    float _Bright;

    uniform sampler2D _NormalMap;
    uniform float _NormalStrength;

    float Unity_FresnelEffect_float(float3 Normal, float3 ViewDir, float Power)
    {
        float output = pow((1.0 - saturate(dot(normalize(Normal), normalize(ViewDir)))), Power);
        return output;
    }

    float toGrayscale(float3 input)
    {
        return (input.r + input.g + input.b) / 3;
    }

    float random(float seed)
    {
        return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
    }

    float Quantize(float num, float quantize)
    {
        return round(num * quantize) / quantize;
    }

    float3  rgb2hsv(float3 C)
    {
        saturate(C);
        float3 HSV = { 0,1,1 };
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
            else      HSV.r = 4.0f + (C.r - C.g) / Delta;
        }
        HSV.r /= 6.0f;

        return HSV;
    }
    float3 hsv2rgb(float3 C)
    {
        float c = C.z * C.y;
        float x = c * (1 - abs((C.x * 6) % 2 - 1));
        float m = C.z - c;



        float3 CC = { 0,0,0 };
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

    ENDCG
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200
        //Blend SrcAlpha OneMinusSrcAlpha // use alpha blending
        Blend One OneMinusSrcAlpha
        AlphaToMask On
        Pass
        {
            AlphaToMask On
        

            Cull[_Cull]
            ZWrite[_ZWrite]
            Ztest[_ZTest]

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            // Add includes and function declarations here
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
                // position of the vertex (and fragment) in world space 
                float4 posObj : TEXCOORD2;
                float4 tex : TEXCOORD3;
                float3 tangentWorld : TEXCOORD4;
                float3 normalWorld : TEXCOORD5;
                float3 binormalWorld : TEXCOORD6;
            };

            v2f vert(appdata input)
            {

                v2f output;

                float4x4 modelMatrix = unity_ObjectToWorld;
                float4x4 modelMatrixInverse = unity_WorldToObject;

                output.tangentWorld = normalize(
                    mul(modelMatrix, float4(input.tangent.xyz* input.tangent.xyz, 0.0)).xyz);
                output.normalWorld = normalize(
                    mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
                output.binormalWorld = normalize(
                    cross(output.normalWorld, output.tangentWorld)
                    * input.tangent.w); // tangent.w is specific to Unity

                //output.posWorld = mul(modelMatrix, input.vertex);
                output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
                output.tex = input.texcoord;
                output.posObj = input.vertex;

                //float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
                //half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
                half3 worldN = UnityObjectToWorldNormal(input.normal);

                //float4 dispTexColor = tex2Dlod(_DisplacementTex, float4(input.texcoord.xy, 0.0, 0.0));
                //float displacement = dot(float3(0.21, 0.72, 0.07), dispTexColor.rgb) * _MaxDisplacement;

                float displacement = _MaxDisplacement * (.5 - tex2Dlod(_DisplacementTex, float4(output.posObj.xy + Quantize(_Time.y, _Quantize), 0, 0)));

                //float4 newVertexPos = input.vertex + float4(random(input.vertex.x) * displacement, 0, 0, 0.0);
                float3 newVertexPos = float3(input.vertex.x + displacement, input.vertex.y + displacement, input.vertex.z + displacement);

                //output.pos = UnityObjectToClipPos(input.vertex);
                output.pos = UnityObjectToClipPos(newVertexPos);

                return output;
            }

            float4 frag(v2f input) : COLOR
            {
                // Calculate the surface normal and view direction
                // ...

                float4 encodedNormal = tex2D(_NormalMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
                //807fff
                encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
                //encodedNormal.rgb = saturate(lerp(half3(0.5, 0.5, 0.5), encodedNormal, _NormalStrength));
                encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

                float3 localCoords = float3(2.0 * encodedNormal.a - 1.0, 2.0 * encodedNormal.g - 1.0, 0.0);
                //localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
                // approximation without sqrt:  
                localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);

                float3x3 local2WorldTranspose = float3x3(input.tangentWorld, input.binormalWorld, input.normalWorld);
                float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));


                float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

                // Calculate the fresnel value for the surface
                float fresnel = Unity_FresnelEffect_float(viewDirection, normalDirection, 1.5);

                float angle = dot(input.normalWorld, viewDirection);

                // Use the fresnel value to adjust the surface color and transparency
                //fixed4 col = tex2D(_MainTex, input.tex) * _Color;
                fixed4 col = tex2D(_MainTex, input.tex * _MainTex_ST.xy + _MainTex_ST.zw);

                float adjustMask = tex2D(_AdjustMask, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
                col *= _Color;

                //c.a *= fresnel;
                //c.rgb *= fresnel;

                col.r *= sin(angle * _ShimmerAmount);
                col.g *= sin(angle * _ShimmerAmount + _ShimmerOffset1);
                col.b *= sin(angle * _ShimmerAmount + _ShimmerOffset2);

                //c.rgb *= _Brightness;

                float3 adjustedCol = col.rgb;
                _Hue = (_Hue) / 360;
                _Hue += 1;
                adjustedCol = rgb2hsv(adjustedCol.rgb);
                adjustedCol.r += _Hue;
                adjustedCol.r %= 1;
                adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

                fixed lum = saturate(Luminance(adjustedCol.rgb));
                adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

                adjustedCol.rgb *= _Bright;

                col.rgb = lerp(col.rgb, adjustedCol, adjustMask);

                half3 reflection = reflect(-viewDirection, input.normalWorld); // Direction of ray after hitting the surface of object
/*If Roughness feature is not needed : UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflection) can be used instead.
It chooses the correct LOD value based on camera distance*/
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, _Roughness); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
                half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

                col.rgb *= skyColor;

                //col.rgb *= _Brightness;


                col.a = _Opacity;

                // Return the final surface color
                return col;
            }
            ENDCG
        }
    }
}