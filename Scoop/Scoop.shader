Shader "Scoop"
{

    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _PaintTex("Paint Texture", 2D) = "white" {}
        _TintColor("Color", Color) = (1, 1, 1, 1)
        _PaintLerp("PaintLerp", Range(0, 1)) = 1


        [NoScaleOffset] _MetallicMap("Metallic Map", 2D) = "black" {}
        _MetallicScale("Metallic scale", Range(0.0, 1.0)) = 0

        [NoScaleOffset] _RoughnessMap("Roughness Map", 2D) = "black" {}
        _RoughnessScale("Roughness scale", Range(0, 1)) = 1
        

        _SpecColor("Specular Material Color", Color) = (1,1,1,1)
        _AlphaX("Roughness in Brush Direction", Range(0, 1)) = 1
        _AlphaY("Roughness orthogonal to Brush Direction", Range(0, 1)) = 1

        [NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
        _NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1

        [Toggle] _UseEmission("Emission", Int) = 0
        [NoScaleOffset] _Emission("Emission Map", 2D) = "white" {}
        _EmissionColor("Emission Color", Color) = (1,1,1)

        _MinBrightnessLight("Minimum Brightness (Light)", Range(0, 1)) = 0.533
        _MinBrightnessShadow("Minimum Brightness (Shadow)", Range(0, 1)) = 0.108

        [Toggle] _OverrideLightColor("Override Light Color", Int) = 0
        _LightColor("Light Color", Color) = (1, 1, 1, 1)

        [Toggle] _OverrideShadowColor("Override Shadow Color", Int) = 0

        _ShadowColor("Shadow Color", Color) = (0, 0, 0, 1)
        _ShadowSize("Shadow Size", Range(0,1)) = 0.297
        _ShadowGradient("Shadow Size", Range(0,1)) = 0

        _AdjustMask("Color Adjustment mask", 2D) = "white" {}
        _Hue("Hue", Range(0,360)) = 0
        _Sat("Saturation", Range(0,10)) = 1
        _Bright("Brightness", Range(0, 100)) = 1
        _Opacity("Opacity", Range(0,1)) = 1

        _OutlineTex("Outline Texture", 2D) = "white" {}
        _OutlineWidthMask("Outline Width Mask", 2D) = "white" {}
        _OutlineColor("Outline Color", Color) = (0.32, 0.32, 0.32, 1)
        _OutlineWidth("Outline Width", Range(0, 3)) = 1.03

        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
    }
    CGINCLUDE
    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"


    //textures
    sampler2D _MainTex;
    sampler2D _PaintTex;

    //value to mix the original color, and the paint color
    float _PaintLerp;

    //tiling
    uniform float4 _MainTex_ST;
    uniform float4 _PaintTex_ST;

    //tint
    float4 _TintColor;

    //metallics (reflectivity of the skybox)
    uniform sampler2D _MetallicMap;
    uniform float _MetallicScale;

    //roughess (size of specular dot, roughness of skybox (if sampled at all))
    uniform sampler2D _RoughnessMap;
    uniform float _RoughnessScale;

    //aspect ratio of the specular dot (usually 1:1)
    uniform float _AlphaX;
    uniform float _AlphaY;

    //normal map (adjusts shadows to finer details beyond vertex normals)
    uniform sampler2D _NormalMap;
    uniform float _NormalStrength;

    //settings for the minumum brightness of light and shadow
    uniform float _MinBrightnessLight;
    uniform float _MinBrightnessShadow;

    //decides whether to use provided light color, or a custom light / shadow (such as grayscale)
    uniform int _OverrideLightColor;
    uniform int _OverrideShadowColor;

    //the light and shadow colors to use if overwriting
    float4 _LightColor;
    float4 _ShadowColor;

    //shadow size & gradient
    uniform float _ShadowSize;
    uniform float _ShadowGradient;

    //used to adjust gradient from soft <-> harsh
    float Quantize(float num, float quantize)
    {
        return round(num * quantize) / quantize;
    }
//
//    float3 blendVRParallax(float3 a, float3 b, float c)
//    {
//#if defined(USING_STEREO_MATRICES)
//        return lerp(a, b, c);
//#else
//        return b;
//#endif
//    }

    //float3 orthoNormalize(float3 tangent, float3 normal)
    //{
    //    return normalize(tangent - normal * dot(normal, tangent));
    //}

    //half3 contrast(half3 color, half contrast)
    //{
    //    return (color - 0.5) * contrast + 0.5;
    //}

    //nicer way of blending rather than just straight multiplication
    float overlayBlendValue(float base, float overlay)
    {
        if (base < .5)
        {
            return (2 * base * overlay);
        }
        else
        {
            return (1 - 2 * (1 - base) * (1 - overlay));
        }


    }

    //unity provided struct (vertex, uv map, normal, tangent)
    struct appdata
    {
        float4 vertex : POSITION;
        float4 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
        float4 tangent : TANGENT;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    //processed appdata -> v2f
    struct v2f
    {
        float4 pos : SV_POSITION;
        float4 posWorld : TEXCOORD0;
        float4 posScreen : TEXCOORD1;
        // position of the vertex (and fragment) in world space 
        float4 tex : TEXCOORD2;
        float3 tangentWorld : TEXCOORD3;
        float3 normalWorld : TEXCOORD4;
        float3 binormalWorld : TEXCOORD5;
        fixed3 vLight : COLOR;
        fixed3 vLightFlat : COLOR1;

        UNITY_LIGHTING_COORDS(6, 7)

        UNITY_VERTEX_OUTPUT_STEREO
    };

  
    v2f vert(appdata input)
    {
        v2f output;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_OUTPUT(v2f, output);
        //vr rendering
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        //tangent, normal, binormal initialized here, used for lighting calculations
        float4x4 modelMatrix = unity_ObjectToWorld;
        float4x4 modelMatrixInverse = unity_WorldToObject;

        output.tangentWorld = normalize(mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
        output.normalWorld = normalize(mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
        output.binormalWorld = normalize(cross(output.normalWorld, output.tangentWorld)* input.tangent.w); // tangent.w is specific to Unity

        //output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
        //float4x4 modelMatrix = unity_ObjectToWorld;
        output.posWorld = mul(modelMatrix, input.vertex);
        output.tex = input.texcoord;
        output.pos = UnityObjectToClipPos(input.vertex);

        half3 worldN = UnityObjectToWorldNormal(input.normal);

        //gets flat ambient lighting, rather than a gradient
        half3 shlight = ShadeSH9(float4(worldN, 1.0));
        half3 shlightFlat = ShadeSH9(float4(.2, 1, .2, 1.0));

        output.vLight = shlight;
        output.vLightFlat = shlightFlat;

        output.posScreen = ComputeScreenPos(input.vertex);
    
#ifdef UNITY_HALF_TEXEL_OFFSET
        output.pos.xy += (_ScreenParams.zw - 1.0) * float2(-1, 1);
#endif
        return output;
    }

    //frag base is for directional + ambient + baked light probes
    //frag add (removed from this shader) any extra lights (point, spot)
    float4 fragBase(v2f input) : COLOR
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        //get main texture * tint
        float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw) * _TintColor;
        
        //return input.posWorld;

        //world space (triplanar?) shading, sampling from the paint texture along that space
        //results in worldAlbedo & worldAlbedoGray
        float3 projNormal = saturate(pow(input.normalWorld * 1.5, 4));

        //return float4(projNormal, 1);

        //float4 tangent = float4(0, 0, 0, 0);
        //tangent.xyz = lerp(tangent.xyz, float3(0, 0, 1), projNormal.y);
        //tangent.xyz = lerp(tangent.xyz, float3(0, 1, 0), projNormal.x);
        //tangent.xyz = lerp(tangent.xyz, float3(1, 0, 0), projNormal.z);
        //tangent.xyz = tangent.xyz - dot(tangent.xyz, input.normalWorld) * input.normalWorld;
        //tangent.xyz = normalize(tangent.xyz);

        //tangent.w = lerp(tangent.w, input.normalWorld.y, projNormal.y);
        //tangent.w = lerp(tangent.w, -input.normalWorld.x, projNormal.x);
        //tangent.w = lerp(tangent.w, input.normalWorld.z, projNormal.z);
        //tangent.w = step(tangent.w, 0);
        //tangent.w *= -2;
        //tangent.w += 1;

        //float3 binormal = cross(input.normalWorld, tangent.xyz) * tangent.w;
        //float3x3 rotation = float3x3(tangent.xyz, binormal, input.normalWorld);

        // TEXTURE INPUTS USING WORLD POSITION BASED UVS
        //addad MainTex_ST for texture tiling and stretch
        half3 albedo0 = tex2D(_PaintTex, input.posWorld.xy * _PaintTex_ST.xy + _PaintTex_ST.zw).rgb;
        half3 albedo1 = tex2D(_PaintTex, input.posWorld.zx * _PaintTex_ST.xy + _PaintTex_ST.zw).rgb;
        half3 albedo2 = tex2D(_PaintTex, input.posWorld.zy * _PaintTex_ST.xy + _PaintTex_ST.zw).rgb;

        // BLEND TEXTURE INPUTS BASED ON WORLD NORMAL
        float3 worldAlbedo;
        worldAlbedo = lerp(albedo1, albedo0, projNormal.z);
        worldAlbedo = lerp(worldAlbedo, albedo2, projNormal.x);


        //grascale is just avg
        float worldAlbedoGray = (worldAlbedo.r + worldAlbedo.g + worldAlbedo.b) / 3;

        //col = lerp(col, worldAlbedoGray, .5);
        //col *= worldAlbedoGray;

        //using nice blend function for modifying original col (if desired)
        float3 blended = float3(0, 0, 0);
        blended.r = overlayBlendValue(col.r, worldAlbedoGray);
        blended.g = overlayBlendValue(col.g, worldAlbedoGray);
        blended.b = overlayBlendValue(col.b, worldAlbedoGray);

        //uses lerp to decide blending
        col.rgb = lerp(col, blended, _PaintLerp);

        //normal texture
        float4 encodedNormal = tex2D(_NormalMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
        //807fff

        //for some reason, the default noninitialized normal texture doesn't initialize properly, this if statement fixes that
        encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
        //lerp between flat, and encoded normal
        encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

        //get metallic, lerp between sampled texture, and 1 based off of scale
        float3 metallic = tex2D(_MetallicMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
        metallic = lerp(metallic, 1, _MetallicScale);

        // get roughness, lerp between sampled texture, and 1 based off of scale
        float Roughness = tex2D(_RoughnessMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
        Roughness = lerp(Roughness, 1, _RoughnessScale);
        //calculate smoothness as inverse of roughness
        float Smoothness = -(Roughness - 1) + 0.00001;

        //lighting stuff
        float3 localCoords = float3(2.0 * encodedNormal.a - 1.0, 2.0 * encodedNormal.g - 1.0, 0.0);
        //localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
        // approximation without sqrt:  
        localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);

        float3x3 local2WorldTranspose = float3x3(input.tangentWorld, input.binormalWorld, input.normalWorld);
        float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));

        float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);
        float3 lightDirection;
  
#ifdef USING_DIRECTIONAL_LIGHT
        //lightDirection = _WorldSpaceLightPos0;
#else
        //lightDirection = _WorldSpaceLightPos0 - input.posWorld;
#endif
        UNITY_LIGHT_ATTENUATION(attenuation, input, input.posWorld.xyz);
        if (0.0 == _WorldSpaceLightPos0.w) // directional light?
        {
            //attenuation = 1.0; // no attenuation
            lightDirection = normalize(_WorldSpaceLightPos0.xyz);
        }
        else // point or spot light
        {
            float3 vertexToLightSource =
                _WorldSpaceLightPos0.xyz - input.posWorld.xyz;
            float distance = length(vertexToLightSource);
            //attenuation = 1.0 / distance; // linear attenuation 
            lightDirection = normalize(vertexToLightSource);
        }

        float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb;
       

        //_ShadowSize = -1 * (_ShadowSize - 1) + worldAlbedoGray * .2;

        //invert shadowsize and shadowgradient (not sure why I did this, tbh)
        _ShadowSize = -1 * (_ShadowSize - 1);
        _ShadowGradient = -1 * (_ShadowGradient - 1);

        float4 lightProbeColor;
        lightProbeColor.rgb = input.vLightFlat;
 
        int isLit = lightDirection >= float3(0, 0, 0) ? 1 : 0;
        if (isLit == 0)
        {
            _LightColor0.rgb = lightProbeColor.rgb;
            //lightDirection = float3(_Adjust1, _Adjust2, _Adjust3);
            lightDirection = float3(.54, 1, -.4);
        }
        else
        {
            _LightColor0.rgb += lightProbeColor.rgb;
        }

        float dotLN = dot(lightDirection, input.normalWorld);
        float3 halfwayVector = normalize(lightDirection + viewDirection);
        //float3 binormalDirection = cross(encodedNormal, input.tangentWorld);

        //THE SPECULAR DOT (all hail!)
        float3 specularReflection;
        if (dotLN < 0.0) // light source on the wrong side?
        {
            specularReflection = float3(0.0, 0.0, 0.0);
            // no specular reflection
        }
        else // light source on the right side
        {
            //aspect ratio of specular dot
            float dotHN = dot(halfwayVector, input.normalWorld);
            float dotVN = dot(viewDirection, input.normalWorld);
            float dotHTAlphaX = dot(halfwayVector, input.tangentWorld) / (_AlphaX * worldAlbedoGray + Roughness );
            float dotHBAlphaY = dot(halfwayVector, input.binormalWorld) / (_AlphaY * worldAlbedoGray + Roughness );

            //this wretched one-liner is the size of the specular dot based off of smoothness, and attenuation
            // I tried to recreate the way the Standard shader did it
            //there is a better way of doing this
            specularReflection = Smoothness * pow(0 * .4 + Smoothness, 3) * attenuation * _LightColor0.rgb * _SpecColor.rgb * sqrt(max(0.0, dotLN / dotVN)) * exp(-2.0 * (dotHTAlphaX * dotHTAlphaX + dotHBAlphaY * dotHBAlphaY) / (1.0 + dotHN));
        }
        
        //another wretched one liner for light based off of shadow size
        float light = pow(dot(normalDirection, lightDirection) + (_ShadowSize * 2) - .5 + (.5 * _ShadowGradient), 1 + pow(1 + _ShadowGradient, 12 * _ShadowGradient));

        //clamp light
        light = clamp(light, 0.000001, 1);

        //clamp according to minBrightness vals
        light = clamp(light, lerp(_MinBrightnessShadow, _MinBrightnessLight, light), 1);
        //light += _MinBrightness;
        //light += specularReflection;

        //another wretched one liner to appropriatley override shadow and light
        float3 lightColorized = light * lerp(_OverrideShadowColor == 0 ? clamp(_LightColor0.rgb, _MinBrightnessShadow, 2) : clamp(_ShadowColor, _MinBrightnessShadow,2),
                                             _OverrideLightColor == 0 ? clamp(_LightColor0.rgb, _MinBrightnessLight, 2) : clamp(_LightColor, _MinBrightnessLight,2),
                                             light);
        //do same for ambientLight
        lightColorized += lerp(_OverrideShadowColor == 0 ? ambientLighting : 0,
                               _OverrideLightColor == 0 ? ambientLighting : 0,
                               light);

        //reflect direction ray
        half3 reflection = reflect(-viewDirection, normalDirection);
        half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, Roughness * 6); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
        half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

        //multiply col by skybox, depending on metallic & smoothness
        col.rgb = col * lerp((lightColorized), 1, metallic);
        col.rgb = lerp(col.rgb, skyColor * col.rgb, min(1, -(col.a - 1) + metallic + Smoothness * .07));
        //col.rgb = lerp(col.rgb, skyColor * 2, min(1, skyFresnel + 0.02) * Smoothness);

        col.rgb = lerp(col.rgb * (lightColorized)+specularReflection, col.rgb * specularReflection * 20, metallic);


        return col;
    }


    ENDCG
    CustomEditor "ScoopEditor"
    Subshader
    {

        //ambient & directional pass
        Pass
        {

            Tags
            {
                "LightMode" = "ForwardBase"
                "Queue" = "Geometry"
                "RenderType" = "Opaque"
                //"IgnoreProjector" = "False"
                //"VRCFallback" = "Toon"
            }
            //Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragBase
            #pragma multi_compile_fwdbase
            //#pragma target 3.0

            
            ENDCG
        }
 
        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}
            CGPROGRAM
            #pragma vertex vertSShadow
            #pragma fragment fragSShadow
            float4 vertSShadow(float4 vertex : POSITION) : SV_POSITION{
                float4 clipPos = UnityObjectToClipPos(vertex.xyz);
                clipPos.z = lerp(clipPos.z,min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE), unity_LightShadowBias.y);
                return clipPos;
            }
            fixed4 fragSShadow(float4 pos : SV_POSITION) : SV_Target{return 0;}
            ENDCG
        }
   
    }

}
