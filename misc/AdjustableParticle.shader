//basic particle shader, supports hue, sat bright controls
Shader "Custom/AdjustableParticle" {
    Properties{
        _TintColor("Tint Color", Color) = (0.5,0.5,0.5,0.5)
        _MainTex("Particle Texture", 2D) = "white" {}
        _InvFade("Soft Particles Factor", Range(0.01,3.0)) = 1.0
        _Hue("Hue", Range(0,360)) = 120
        _Sat("Saturation", Range(0,10)) = 10
        _Bright("Brightness", Range(0, 100)) = 1
    }

    Category
    {
        Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Opaque" }
        //Tags{"RenderType" = "Transparent"}

        //additive blending
        Blend One OneMinusSrcAlpha
        //Blend SrcAlpha SrcAlpha
        Cull Off Lighting Off

        Ztest On
        Zwrite Off

        SubShader 
        {
            Pass {

                CGPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #pragma multi_compile_particles
                #pragma multi_compile_fog

                #include "UnityCG.cginc"

                sampler2D _MainTex;
                fixed4 _TintColor;

                struct appdata_t {
                    float4 vertex : POSITION;
                    fixed4 color : COLOR;
                    float2 texcoord : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct v2f {
                    float4 vertex : SV_POSITION;
                    fixed4 color : COLOR;
                    float2 texcoord : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    #ifdef SOFTPARTICLES_ON
                    float4 projPos : TEXCOORD2;
                    #endif
                    UNITY_VERTEX_OUTPUT_STEREO
                };

                float4 _MainTex_ST;
                float _Hue;
                float _Sat;
                float _Bright;

                v2f vert(appdata_t v)
                {
                    v2f o;
                    UNITY_SETUP_INSTANCE_ID(v);
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    #ifdef SOFTPARTICLES_ON
                    o.projPos = ComputeScreenPos(o.vertex);
                    COMPUTE_EYEDEPTH(o.projPos.z);
                    #endif
                    o.color = v.color;
                    o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
                    UNITY_TRANSFER_FOG(o,o.vertex);
                    return o;
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

                // UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
                // float _InvFade;

                fixed4 frag(v2f i) : SV_Target
                {
                    //#ifdef SOFTPARTICLES_ON
                    //float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
                    //float partZ = i.projPos.z;
                    //float fade = saturate(_InvFade * (sceneZ - partZ));
                    //i.color *= fade;
                    //#endif


                    fixed4 tex = tex2D(_MainTex, i.texcoord);
                    fixed4 col;

                    //setting color to a combination of tint, texture, and vertex colors
                    //multiplied x2 for a brighter default
                    col.rgb = _TintColor.rgb * tex.rgb * i.color.rgb * 2.0f;

                    //similar code, but filling for opacity
                    col.a = (1 - tex.a) * (_TintColor.a * i.color.a * 2.0f);

                    //hsv stuff
                    _Hue = (_Hue) / 360;
                    _Hue += 1;
                    col.rgb = rgb2hsv(col.rgb);
                    col.r += _Hue;
                    col.r %= 1;
                    col.rgb = hsv2rgb(col.rgb);

                    fixed lum = saturate(Luminance(col.rgb));
                    col.rgb = lerp(col.rgb, fixed3(lum, lum, lum), (1 - _Sat));

                    col.rgb *= _Bright;

                    //UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0, 0, 0, 0)); // fog towards black due to our blend mode


                    return col;
                }
                ENDCG
            }
        }
    }
}