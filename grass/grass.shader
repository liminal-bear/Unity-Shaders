// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "grass"
{

    Properties{
        _Color("Main Color", Color) = (1,1,1,1)
        _Shape("Shape Alpha Map", 2D) = "white" {}
        _Detail("Detail (RGB)", 2D) = "white" {}
        _DispTex("Flow Map", 2D) = "white" {}
        _Splotch("Splotch Map", 2D) = "white" {}
        _Cutoff("Alpha cutoff", Range(0,1)) = 0.5

        _DistortStrength("flow strength", Range(0,5)) = 1
        _DetailStrength("detail strength", Range(0,5)) = 1
        _ScrollXSpeed("flow scrollX", Range(-10,10)) = 1
        _ScrollYSpeed("flow scrollY", Range(-10,10)) = 1
        _SplotchStrength("splotch strength", Range(0,5)) = 1
        _ShakeDisplacement("Displacement", Range(0, 1.0)) = 1.0
        _ShakeTime("Shake Time Scale", Range(0, 1.0)) = 1.0
        _ShakeWindspeed("Shake Windspeed", Range(0, 1.0)) = 1.0
        _ShakeBending("Shake Bending", Range(0, 1.0)) = 1.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
    }

        SubShader{
            Tags {"Queue" = "AlphaTest" "IgnoreProjector" = "True" "RenderType" = "TransparentCutout"}
                Cull[_Cull]

                LOD 200
            Pass {
                CGPROGRAM

                #pragma target 3.0
                #pragma vertex vert  
                #pragma fragment frag// alphatest:_Cutoff addshadow


                sampler2D _Shape;
                sampler2D _DispTex;
                sampler2D _Detail;
                sampler2D _Splotch;
                float4 _DispTex_ST;
                float4 _Splotch_ST;
                float _ScrollXSpeed;
                float _ScrollYSpeed;
                fixed4 _Color;
                float _Cutoff;
                float _DistortStrength;
                float _DetailStrength;
                float _SplotchStrength;
                float _ShakeDisplacement;
                float _ShakeTime;
                float _ShakeWindspeed;
                float _ShakeBending;

                //struct Input {
                //    float2 uv_MainTex;
                //    float2 uv_Illum;
                //    float4 vertex : POSITION;
                //};

                struct vertexInput {
                    float4 vertex : POSITION;
                    float4 tangent : TANGENT;
                    float3 normal : NORMAL;
                    float4 texcoord : TEXCOORD0;
                    float4 texcoord1 : TEXCOORD1;
                    float4 texcoord2 : TEXCOORD2;
                    float4 texcoord3 : TEXCOORD3;
                    fixed4 color : COLOR;
                };

                struct vertexOutput {
                    float4 pos : SV_POSITION;
                    float4 posWorld : TEXCOORD0;
                    float4 posObj : TEXCOORD1;
                    float4 tex : TEXCOORD2;
                    float4 color : TEXCOORD3;
                    //float4 normal : TEXCOORD4;
                };

                // Calculate a 4 fast sine-cosine pairs
            // val:     the 4 input values - each must be in the range (0 to 1)
            // s:       The sine of each of the 4 values
            // c:       The cosine of each of the 4 values
                void FastSinCos(float4 val, out float4 s, out float4 c) {
                    val = val * 6.408849 - 3.1415927;
                    float4 r5 = val * val;
                    float4 r6 = r5 * r5;
                    float4 r7 = r6 * r5;
                    float4 r8 = r6 * r5;
                    float4 r1 = r5 * val;
                    float4 r2 = r1 * r5;
                    float4 r3 = r2 * r5;
                    float4 sin7 = {1, -0.16161616, 0.0083333, -0.00019841};
                    float4 cos8 = {-0.5, 0.041666666, -0.0013888889, 0.000024801587};
                    s = val + r1 * sin7.y + r2 * sin7.z + r3 * sin7.w;
                    c = 1 + r5 * cos8.x + r6 * cos8.y + r7 * cos8.z + r8 * cos8.w;
                }

                vertexOutput vert(vertexInput v) 
                {
                    vertexOutput output;
                    //output.normal = float4(v.normal, 1.0);
                    float factor = (1 - _ShakeDisplacement - v.color.r) * 0.5;
                    //fixed4 color = tex2Dlod(_DispTex, v.vertex);

                    float4 dispSampling = float4(v.vertex.xy * _DispTex_ST, 0, 0);
                    fixed xScrollValue = _ScrollXSpeed * _Time;
                    fixed yScrollValue = _ScrollYSpeed * _Time;
                    dispSampling.xy += fixed2(xScrollValue, yScrollValue);
                    fixed4 displacementCol = tex2Dlod(_DispTex, dispSampling);

                    const float _WindSpeed = (_ShakeWindspeed + v.color.g);
                    const float _WaveScale = _ShakeDisplacement;

                    const float4 _waveXSize = float4(0.048, 0.06, 0.24, 0.096);
                    const float4 _waveZSize = float4 (0.024, .08, 0.08, 0.2);
                    const float4 waveSpeed = float4 (1.2, 2, 1.6, 4.8);

                    float4 _waveXmove = float4(0.024, 0.04, -0.12, 0.096);
                    //float4 _waveXmove = float4(0.024, 0.04, -0.12, 0.096);
                    //float4 _waveZmove = float4 (0.006, .02, -0.02, 0.1);
                    float4 _waveZmove = float4 (99, .02, -0.02, 0.1);

                    float4 waves;
                    waves = v.vertex.x * _waveXSize * (displacementCol.r * _DistortStrength);// * color.x;
                    waves += v.vertex.z * _waveZSize * (displacementCol.g * _DistortStrength);// * color.y;

                    waves += (_Time.x * (1 - _ShakeTime * 2 - v.color.b) * waveSpeed * _WindSpeed);

                    float4 s, c;
                    waves = frac(waves);
                    FastSinCos(waves, s,c);

                    float waveAmount = v.texcoord.y * (v.color.a + _ShakeBending);
                    //waveAmount *= (color.r * _DistortStrength) * (color.g * _DistortStrength);
                    s *= waveAmount;

                    s *= normalize(waveSpeed);


                    s = s * s;
                    float fade = dot(s, 1.3);
                    s = s * s;
                    float3 waveMove = float3 (0,0,0);
                    //float3 waveMove = v.normal;
                    waveMove.x = dot(s, _waveXmove); //* color.r * _DistortStrength;
                    waveMove.z = dot(s, _waveZmove); //* color.g * _DistortStrength;

                    waveMove.x = dot(s, _waveXmove);// *color.r* _DistortStrength;
                    waveMove.z = dot(s, _waveZmove);// *color.g* _DistortStrength;

                    //v.vertex.xz -= mul((float3x3)unity_WorldToObject, waveMove).xz;
                    v.vertex.xz += s * (mul((float3x3)unity_WorldToObject, waveMove).xz + v.normal.xz);



                    output.tex = v.texcoord;
                    //output.pos = UnityObjectToClipPos(v.vertex);
                    output.pos = UnityObjectToClipPos(v.vertex);
                    output.posObj = v.vertex;
                    output.posWorld = mul(UNITY_MATRIX_M, v.vertex);
                    return output;
                }


                float4 frag(vertexOutput input) : COLOR
                {
                   float4 col = tex2D(_Shape, input.tex.xy);
                   float3 col2 = tex2D(_Detail, input.tex.xy);
                   col2 = saturate(lerp(half3(0.5, 0.5, 0.5), col2, _DetailStrength));
                   clip(col.a - _Cutoff);


                   float4 splotchSampling = float4(input.posObj.xy * _Splotch_ST, 0, 0);
                   fixed3 splotchCol = tex2Dlod(_Splotch, splotchSampling);
                   splotchCol = saturate(lerp(half3(0.5, 0.5, 0.5), splotchCol, _SplotchStrength));

                   float splotchGray = ((splotchCol.r + splotchCol.g + splotchCol.b) / 3);

                   _Color.rgb *= col2 * splotchGray;

                   //return input.color;
                   //return splotchCol;
                   return fixed4(_Color.rgb, col.a);
                }

                ENDCG
            }
        }
}