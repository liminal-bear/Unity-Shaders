Shader "Scootoon_2"
{

    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _Color("Color", Color) = (1, 1, 1, 1)

        [Toggle] _UseMatcap("Use Matcap", Int) = 0
        [NoScaleOffset] _MatcapTex("Matcap texture", 2D) = "black" {}
        [NoScaleOffset] _MatcapMask("Matcap mask", 2D) = "black" {}
        _MatcapScale("Matcap scale", Range(0.0, 1.0)) = 0

        [NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
        _NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1

        [Toggle] _UseEmission("Emission", Int) = 0
        [NoScaleOffset] _Emission("Emission Map", 2D) = "black" {}
        _EmissionColor("Emission Color", Color) = (1,1,1)

        _MinBrightnessLight("Minimum Brightness (Light)", Range(0, 1)) = 0.533
        _MinBrightnessShadow("Minimum Brightness (Shadow)", Range(0, 1)) = 0.108

        [Toggle] _OverrideLightColor("Override Light Color", Int) = 0
        _LightColor("Light Color", Color) = (1, 1, 1, 1)

        [Toggle] _OverrideShadowColor("Override Shadow Color", Int) = 0

        _ShadowColor("Shadow Color", Color) = (0, 0, 0, 1)
        _ShadowSize("Shadow Size", Range(0,1)) = 0.297
        _ShadowGradient("Shadow Size", Range(0,1)) = 0

        _OutlineTex("Outline Texture", 2D) = "white" {}
        _OutlineColor("Outline Color", Color) = (0.32, 0.32, 0.32, 1)
        _OutlineWidth("Outline Width", Range(0, 3)) = 1.03


    }
    CGINCLUDE
    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"


    sampler2D _MainTex;
    uniform float4 _MainTex_ST;

    uniform sampler2D _NormalMap;
    uniform float _NormalStrength;

    uniform int _UseMatcap;
    uniform sampler2D _MatcapTex;
    uniform sampler2D _MatcapMask;
    uniform float _MatcapScale;

    uniform int _UseEmission;
    uniform sampler2D _Emission;
    uniform float3 _EmissionColor;

    uniform float _MinBrightnessLight;
    uniform float _MinBrightnessShadow;

    uniform int _OverrideLightColor;
    uniform int _OverrideShadowColor;

    float4 _LightColor;
    float4 _ShadowColor;
    uniform float _ShadowSize;
    uniform float _ShadowGradient;

    uniform sampler2D _OutlineTex;
    half _OutlineWidth;
    half4 _OutlineColor;

    float _Adjust1;
    float _Adjust2;
    float _Adjust3;

    float Quantize(float num, float quantize)
    {
        return round(num * quantize) / quantize;
    }

    float3 blendVRParallax(float3 a, float3 b, float c)
    {
#if defined(USING_STEREO_MATRICES)
        return lerp(a, b, c);
#else
        return b;
#endif
    }

    float3 orthoNormalize(float3 tangent, float3 normal)
    {
        return normalize(tangent - normal * dot(normal, tangent));
    }

    half3 contrast(half3 color, half contrast)
    {
        return (color - 0.5) * contrast + 0.5;
    }
    struct vertexInput
    {
        float4 vertex : POSITION;
        float4 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
        float4 tangent : TANGENT;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    struct vertexOutput
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

  
    vertexOutput vert(vertexInput input)
    {

        vertexOutput output;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_OUTPUT(vertexOutput, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        float4x4 modelMatrix = unity_ObjectToWorld;
        float4x4 modelMatrixInverse = unity_WorldToObject;

        output.tangentWorld = normalize(
            mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
        output.normalWorld = normalize(
            mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
        output.binormalWorld = normalize(
            cross(output.normalWorld, output.tangentWorld)
            * input.tangent.w); // tangent.w is specific to Unity

        output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
        output.tex = input.texcoord;
        output.pos = UnityObjectToClipPos(input.vertex);

        half3 worldN = UnityObjectToWorldNormal(input.normal);
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

    struct vertexOutputOutline
    {
        float4 pos : SV_POSITION;
        float4 posWorld : TEXCOORD0;
        float4 posScreen : TEXCOORD1;
        // position of the vertex (and fragment) in world space 
        float4 tex : TEXCOORD2;
        fixed3 vLight : COLOR;
        fixed3 vLightFlat : COLOR1;
        
        //LIGHTING_COORDS(5, 6)
        UNITY_LIGHTING_COORDS(3, 4)
            //V2F_SHADOW_CASTER

        UNITY_VERTEX_OUTPUT_STEREO
    };

    vertexOutputOutline outlineVert(vertexInput input)
    {
        vertexOutputOutline output;

        UNITY_SETUP_INSTANCE_ID(input); //Insert
        UNITY_INITIALIZE_OUTPUT(vertexOutputOutline, output); //Insert
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
        output.tex = input.texcoord;
        half3 worldN = UnityObjectToWorldNormal(input.normal);
        half3 shlight = ShadeSH9(float4(worldN, 1.0));
        half3 shlightFlat = ShadeSH9(float4(.2, 1, .2, 1.0));
        output.vLight = shlight;
        output.vLightFlat = shlightFlat;
        float4 clipPos = UnityObjectToClipPos(input.vertex);
        _OutlineWidth /= 1000;
        _OutlineWidth = clamp(_OutlineWidth / (1 / clipPos.w), 0, _OutlineWidth);
        output.pos = UnityObjectToClipPos(input.vertex + input.normal * _OutlineWidth);

        output.posScreen = ComputeScreenPos(input.vertex);

#ifdef UNITY_HALF_TEXEL_OFFSET
        output.pos.xy += (_ScreenParams.zw - 1.0) * float2(-1, 1);
#endif

        return output;
    }

    float4 fragBase(vertexOutput input) : COLOR
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

        float4 encodedNormal = tex2D(_NormalMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
        //807fff
        encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
        encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

        float3 localCoords = float3(2.0 * encodedNormal.a - 1.0, 2.0 * encodedNormal.g - 1.0, 0.0);
        //localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
        // approximation without sqrt:  
        localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);

        float3x3 local2WorldTranspose = float3x3(input.tangentWorld, input.binormalWorld, input.normalWorld);
        float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));

        float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);
        float3 lightDirection;

        float4 matCapCol = float4(0, 0, 0, 0);
        if (_UseMatcap == 1)
        {
            float3 headDirection;

#if defined(USING_STEREO_MATRICES)
            headDirection = normalize(unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz + unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz * 0.5) - input.posWorld;
#else
            headDirection = normalize(UNITY_MATRIX_V._m20_m21_m22);
#endif
            float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

            float3 normalViewDirection = blendVRParallax(headDirection, viewDirection, 0.5);
            //float3 bitangentViewDirection = UNITY_MATRIX_V._m10_m11_m12;
            float3 bitangentViewDirection = float3(0, 1, 0);
            bitangentViewDirection = orthoNormalize(bitangentViewDirection, normalViewDirection);

            float3 tangentViewDirection = cross(normalViewDirection, bitangentViewDirection);

            float3x3 tbnViewDirection = float3x3(tangentViewDirection, bitangentViewDirection, normalViewDirection);

            float2 matCapUV = mul(tbnViewDirection, normalDirection).xy;

            matCapUV = matCapUV * 0.5 + 0.5;

            matCapCol = tex2D(_MatcapTex, matCapUV);
            float matCapMask = tex2D(_MatcapMask, input.tex).r;
            col.rgb = lerp(col.rgb, matCapCol, matCapMask + _MatcapScale);
        }
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

        //attenuation = LIGHT_ATTENUATION(input);

        //float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb * _DiffColor.rgb;
        float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb;
       


        _ShadowSize = -1 * (_ShadowSize - 1);
        _ShadowGradient = -1 * (_ShadowGradient - 1);

        //float4 lightProbeLighting;
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
        //float light = pow(dot(normalDirection, lightDirection) + (_ShadowSize * 2) - .5 + (.5 * _ShadowGradient), 1 + pow(1 + _ShadowGradient, 12 * _ShadowGradient));
        float light = pow(dot(normalDirection, lightDirection) + (_ShadowSize * 2) - .5 + (.5 * _ShadowGradient), 1 + pow(1 + _ShadowGradient, 12 * _ShadowGradient));
        light = clamp(light, 0.000001, 1);
        light = clamp(light, lerp(_MinBrightnessShadow, _MinBrightnessLight, light), 1);
        //light += _MinBrightness;

        float3 lightColorized = light * lerp(_OverrideShadowColor == 0 ? clamp(_LightColor0.rgb, _MinBrightnessShadow, 2) : clamp(_ShadowColor, _MinBrightnessShadow,2),
                                             _OverrideLightColor == 0 ? clamp(_LightColor0.rgb, _MinBrightnessLight, 2) : clamp(_LightColor, _MinBrightnessLight,2),
                                             light);
        lightColorized += lerp(_OverrideShadowColor == 0 ? ambientLighting : 0,
                               _OverrideLightColor == 0 ? ambientLighting : 0,
                               light);

        col.rgb = col.rgb * (lightColorized);


        if (_UseEmission)
        {
            float3 emission = tex2D(_Emission, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).rgb * _EmissionColor;
            col.rgb += emission;
        }

        return col;
    }

    //float4 fragAdd(vertexOutput input) : COLOR
    float4 fragAdd(vertexOutput input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        //float4 col = float4(1,1,1,1);
        float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

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
        float3 lightDirection;

        float4 matCapCol = float4(0, 0, 0, 0);
        if (_UseMatcap == 1)
        {
            float3 headDirection;

#if defined(USING_STEREO_MATRICES)
            headDirection = normalize(unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz + unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz * 0.5) - input.posWorld;
#else
            headDirection = normalize(UNITY_MATRIX_V._m20_m21_m22);
#endif
            float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

            float3 normalViewDirection = blendVRParallax(headDirection, viewDirection, 0.5);
            //float3 bitangentViewDirection = UNITY_MATRIX_V._m10_m11_m12;
            float3 bitangentViewDirection = float3(0, 1, 0);
            bitangentViewDirection = orthoNormalize(bitangentViewDirection, normalViewDirection);

            float3 tangentViewDirection = cross(normalViewDirection, bitangentViewDirection);

            float3x3 tbnViewDirection = float3x3(tangentViewDirection, bitangentViewDirection, normalViewDirection);

            //float2 matCapUV = mul(tbnViewDirection, input.normalWorld).xy;
            float2 matCapUV = mul(tbnViewDirection, normalDirection).xy;
            //matcapUV = lerp(matcapUV, input.tex * 2 - 1, 0);

            matCapUV = matCapUV * 0.5 + 0.5;

            //float4 albedo = tex2D(_MainTex, input.tex.xy);
            matCapCol = tex2D(_MatcapTex, matCapUV);
            float matCapMask = tex2D(_MatcapMask, input.tex).r;
            col.rgb = lerp(col.rgb, matCapCol, matCapMask + _MatcapScale);
        }

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

        float4 lightProbeLighting;
        lightProbeLighting.rgb = input.vLight;


        _ShadowSize = -1 * (_ShadowSize - 1);
        float light = pow(attenuation * dot(normalDirection, lightDirection), _ShadowGradient);
        //light = clamp(light, .0000001, 1);
        light = clamp(light, .000001, 1);
        //light += _MinBrightness;

        //do not colorize shadow, as that was done in the previous pass
        //thus, we multiply by 1 when light is closer to zero
        float3 lightColorized = light * lerp(1, _OverrideLightColor == 0 ? clamp(_LightColor0.rgb, 0, 1) : _LightColor + _MinBrightnessLight, light);

        col.rgb = col * lightColorized;

        return col;

    }

    float4 fragBaseOutline(vertexOutputOutline input) : COLOR
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float4 outlineCol = tex2D(_OutlineTex, input.tex) * _OutlineColor;
        float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb;
        float3 ambientLightingGrayscale = (ambientLighting.r + ambientLighting.g + ambientLighting.b) / 3;

        float4 lightProbeLighting;
        float4 lightProbeColor;
        lightProbeLighting.rgb = input.vLight;
        lightProbeColor.rgb = input.vLightFlat + _LightColor0.rgb;
        lightProbeLighting.rgb = (lightProbeLighting.r + lightProbeLighting.g + lightProbeLighting.b) / 3;
        lightProbeLighting.rgb = pow(lightProbeLighting.rgb, 1 / (1 + (_ShadowSize / 1.2 )+ 0.000001));
        lightProbeLighting.rgb += (_ShadowSize - 0.6);
        lightProbeLighting.rgb = contrast(lightProbeLighting.rgb, 1 + pow(_ShadowGradient * 3, 8));

        lightProbeLighting.rgb = clamp(lightProbeLighting.rgb, 0.000001, 1);
        lightProbeLighting.rgb = clamp(lightProbeLighting.rgb, lerp(_MinBrightnessShadow, _MinBrightnessLight, lightProbeLighting.r), 1);

        lightProbeLighting.rgb = lightProbeLighting.r * lerp(_OverrideShadowColor == 0 ? ambientLighting + clamp(lightProbeColor.rgb, _MinBrightnessShadow, 2) : ambientLightingGrayscale + clamp(_ShadowColor, _MinBrightnessShadow, 2),
                                                             _OverrideLightColor == 0 ? ambientLighting + clamp(lightProbeColor.rgb, _MinBrightnessLight, 2): ambientLightingGrayscale + clamp(_LightColor, _MinBrightnessLight, 2),
                                                             lightProbeLighting.r);
        outlineCol.rgb *= lightProbeLighting.rgb;

        return outlineCol;
    }
    //float4 fragAddOutline(vertexOutputOutline input) : COLOR
    float4 fragAddOutline(vertexOutputOutline input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        float4 outlineCol = tex2D(_OutlineTex, input.tex) * _OutlineColor;
        outlineCol.rgb *= clamp(_LightColor0.rgb, 0, 1);

        return outlineCol;
    }

    ENDCG
    CustomEditor "Scootoon_2Editor"
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
        //additional lights pass
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
                "VRCFallback" = "Toon"
                "Queue" = "Geometry"
                "RenderType" = "Opaque"
            }

            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragAdd
            #pragma multi_compile_fwdadd_fullshadows
            ENDCG
        }

     
        //outline pass 
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
            Cull Front

            CGPROGRAM

            #pragma vertex outlineVert
            #pragma fragment fragBaseOutline

            ENDCG

        }
      
        //additional lights pass for outlines
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
                "VRCFallback" = "Toon"
                "Queue" = "Geometry"
                "RenderType" = "Opaque"
            }
            Cull Front
            Blend One One
            CGPROGRAM
            #pragma vertex outlineVert
            #pragma fragment fragAddOutline
            #pragma multi_compile_fwdadd_fullshadows
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
