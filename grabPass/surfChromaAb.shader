Shader "SurfChromaticGrabPass"
{
    Properties
    {
        _TintColor ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Smoothness ("Smoothness", Range(0,1)) = 0.942
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _ChromaticAberration ("Chromatic Aberration", Range(0.0,.2)) = 0.001
        _Center ("Center", Range(0,99)) = .5
        _Bright("Brightness", Range(0, 100)) = 1

        _Refraction ("Refraction", Range (0.00, 20.0)) = 10.0
		_Power ("Power", Range (1.00, 20.0)) = 1.0
		_AlphaPower ("Vertex Alpha Power", Range (1.00, 10.0)) = 1.0
		_NormalMap( "Normal Map", 2D ) = "bump" {}
        _NormalStrength("Normal Strength", Range(0.0, 5.0)) = 1

        _SeeThrough ("See Through (not a transparency)", Range(0,1)) = 0.5
    }
    SubShader
    {
    	// In tags we use Transparent+1 to get everything behind
        Tags { "Queue"="Transparent+1" "RenderType"="Opaque" }

        LOD 200
	
	GrabPass { "_GrabTex" }

        CGPROGRAM
        float4 _MainTex_ST;

        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.5

        // This is similar to appdata_full but we keep it here to have more control
        struct appdata {
            float4 vertex : POSITION;
            float4 tangent : TANGENT;
            float3 normal : NORMAL;
            float4 texcoord : TEXCOORD0;
            float4 texcoord1 : TEXCOORD1;
            float4 texcoord2 : TEXCOORD2;
            //float4 texcoord3 : TEXCOORD3;
            fixed4 color : COLOR;
        };

        struct Input
        {
            float2 texcoord : TEXCOORD0;
            float4 GrabTexUV : TEXCOORD1; // the uv slot for the grab texture. Note that we don't use uv_GrabTex because...
            //.. Unity would take the "uv_" as something known and tries to initialize it in a way that gives error
            // so we want our own variable name here.

            float3 vNormalWs : TEXCOORD2;
            float3 vTangentUWs : TEXCOORD3;
            float3 vTangentVWs : TEXCOORD4;
        };

        sampler2D _GrabTex;
        sampler2D _MainTex;
        sampler2D _NormalMap;
        float _NormalStrength;
        fixed _Center;
        fixed _ChromaticAberration;
        fixed _Bright;
        float _Smoothness;
        half _Metallic;
        float _SeeThrough;
        fixed4 _TintColor;
        float _Refraction;
        float _Power;
        float _AlphaPower;


        // From Valve's Lab Renderer, Copyright (c) Valve Corporation, All rights reserved. 
        float3 Vec3TsToWs( float3 vVectorTs, float3 vNormalWs, float3 vTangentUWs, float3 vTangentVWs )
        {
            float3 vVectorWs;
            vVectorWs.xyz = vVectorTs.x * vTangentUWs.xyz;
            vVectorWs.xyz += vVectorTs.y * vTangentVWs.xyz;
            vVectorWs.xyz += vVectorTs.z * vNormalWs.xyz;
            return vVectorWs.xyz; // Return without normalizing
        }

        // From Valve's Lab Renderer, Copyright (c) Valve Corporation, All rights reserved. 
        float3 Vec3TsToWsNormalized( float3 vVectorTs, float3 vNormalWs, float3 vTangentUWs, float3 vTangentVWs )
        {
            return normalize( Vec3TsToWs( vVectorTs.xyz, vNormalWs.xyz, vTangentUWs.xyz, vTangentVWs.xyz ) );
        }

        half3 UnityUnpackScaleNormal(half4 packednormal, half bumpScale)
        {
            #if defined(UNITY_NO_DXT5nm)
                half3 normal = packednormal.xyz * 2 - 1;
                #if (SHADER_TARGET >= 30)
                    normal.xy *= bumpScale;
                    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                #endif
                return normal;
            #else
                half3 normal;
                normal.xy = (packednormal.wy * 2 - 1);
                #if (SHADER_TARGET >= 30)
                    // SM2.0: instruction count limitation
                    // SM2.0: normal scaler is not supported
                    normal.xy *= bumpScale;
                #endif
                normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                return normal;
            #endif
        }


        void vert(inout appdata v, out Input o) 
        {
            //v.vertex.xyz = ... // do things to vertices
            o.texcoord = v.texcoord;
            float4 hpos = UnityObjectToClipPos (v.vertex);
            o.GrabTexUV = ComputeGrabScreenPos(hpos); // compute the uvs for the grab texture (using Unity's utilities)
        
            // World space normal
            o.vNormalWs = UnityObjectToWorldNormal(v.normal);

            // Tangent
            o.vTangentUWs.xyz = UnityObjectToWorldDir( v.tangent.xyz ); // World space tangentU
            o.vTangentVWs.xyz = cross( o.vNormalWs.xyz, o.vTangentUWs.xyz ) * v.tangent.w;

        }

        void surf (Input i, inout SurfaceOutputStandard o)
        {
            float2 rectangle = float2(i.texcoord.x - _Center, i.texcoord.y - _Center);
            float dist = sqrt(pow(rectangle.x,2) + pow(rectangle.y,2));

            float mov = _ChromaticAberration * dist;

            // Albedo comes from a texture tinted by color
            // fixed4 c = tex2D (_MainTex, i.uv_MainTex) * _Color;
    
            // o.Normal = UnpackNormal(tex2D(_NormalMap, i.texcoord * _MainTex_ST.xy + _MainTex_ST.zw));
            o.Normal = UnityUnpackScaleNormal(tex2D(_NormalMap, i.texcoord * _MainTex_ST.xy + _MainTex_ST.zw), _NormalStrength);

            // float4 encodedNormal = tex2D(_NormalMap,i.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw);
            // //807fff
            // encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
            // encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

            // o.Normal = encodedNormal;

            // Tangent space -> World space
            float3 vNormalWs = Vec3TsToWsNormalized( o.Normal.xyz, i.vNormalWs.xyz, i.vTangentUWs.xyz, i.vTangentVWs.xyz );
            // World space -> View space
            float3 vNormalVs = normalize(mul((float3x3)UNITY_MATRIX_V, vNormalWs));
            // Calculate offset
            float2 offset = vNormalVs.xy * _Refraction;
            offset *= pow(length(vNormalVs.xy), _Power);
            // Scale to pixel size
            offset /= float2(_ScreenParams.x, _ScreenParams.y);
            // Scale with screen depth
            // offset /=  i.vertex.z;
            // // Scale with vertex alpha
            // offset *= pow(i.vColor.a, _AlphaPower);

            i.GrabTexUV = i.GrabTexUV + float4(offset, 0.0, 0.0);

            float4 uvR = float4(i.GrabTexUV.x - mov, i.GrabTexUV.y,i.GrabTexUV.z,i.GrabTexUV.w);
            float4 uvG = float4(i.GrabTexUV.x + mov, i.GrabTexUV.y,i.GrabTexUV.z,i.GrabTexUV.w);
            float4 uvB = float4(i.GrabTexUV.x, i.GrabTexUV.y - mov,i.GrabTexUV.z,i.GrabTexUV.w);

            float colorR = tex2Dproj(_GrabTex, uvR).r;
            float colorG = tex2Dproj(_GrabTex, uvG).g;
            float colorB = tex2Dproj(_GrabTex, uvB).b;

            float4 color = float4(colorR,colorG,colorB,.99f)*_TintColor;

            o.Albedo = _Bright * (1.0 - _SeeThrough) * color + (_SeeThrough) * tex2Dproj( _GrabTex, UNITY_PROJ_COORD(i.GrabTexUV));
            o.Emission = o.Albedo;
            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
            o.Alpha = color.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}