Shader "MagicMarble"
{
	//the most basic shader, just a texture
	//other parameters for the shader are suppressed for now
	//you can make a copy of this code and use it as a starting point for more advanced shaders
	//to see what these parameters do, you can look at parameterView
	Properties
	{
		_MainTex("Main Texture", 2D) = "black" {}
		_NormalMap ("Normal", 2D) = "bump" {}
		_HeightMap ("HeightMap", 2D) = "bump" {}
		_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1
		_Brightness("Brightness", Range(0,5)) = 1
		_TintColor1("Color1", Color) = (1, 1, 1, 1)
		_TintColor2("Color2", Color) = (1, 1, 1, 1)

		_Iterations("iterations", Range(0,16)) = 1
		_Depth("depth", Range(0,5)) = .6
		_Smoothing("smoothing", Range(0,5)) = .2

		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1

	}

	CGINCLUDE //shared includes, variables, and functions
	#include "UnityCG.cginc"
	#include "UnityStandardUtils.cginc"

	// User-specified properties
	sampler2D _MainTex;
	uniform float4 _MainTex_ST;
	uniform float _Brightness;

	sampler2D _HeightMap;
	uniform float _Iterations;
	uniform float _Depth;
	uniform float _Smoothing;

	sampler2D _NormalMap;
	float4 _BumpMap_TexelSize;
	float4 _NormalMap_ST;
	
	float _NormalStrength;
	float4 _TintColor1;
	float4 _TintColor2;

	float PI = 3.141592653589793238462643383;
	float RECIPROCAL_PI = 0.3183098861837907;
	float RECIPROCAL_PI2 = 0.15915494309189535;

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

	float2 equirectUv(float3 dir ) 
	{
		// float u = atan2( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;
		// float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;

        // float u = atan2(dir.x, -dir.z) / (2 * PI) + .5;
		// float v = dir.y * .5 + .5;        
		
		// dir = normalize(dir);
		// float u = (atan2(dir.x, -dir.z) / PI + 1) / 2;
		// float v = asin(dir.y) / PI + .5;

		float3 n = normalize(dir - float3(0,0,0));
		float u = atan2(n.x, n.z) / (2*PI) + 0.5;
		float v = n.y * 0.5 + 0.5;

		return float2( u, v );
	}

	float3 marchMarble(float3 rayOrigin, float3 rayDir, float2 uv) 
	{
		float perIteration = 1. / float(_Iterations);
		float3 deltaRay = rayDir * perIteration * _Depth;

		// Start at point of intersection and accumulate volume
		float3 p = rayOrigin;
		float totalVolume = 0.;

		for (int i=0; i<_Iterations;i++) {
			// Read heightmap from current spherical direction
			// float2 equiUv = equirectUv(p);
			// float heightMapVal = tex2D(_HeightMap, equiUv).r;
			float heightMapVal = tex2D(_HeightMap, uv).r;

			// Take a slice of the heightmap
			float height = length(p); // 1 at surface, 0 at core, assuming radius = 1
			float cutoff = 1. - float(i) * perIteration;
			float slice = smoothstep(cutoff, cutoff + _Smoothing, heightMapVal);

			// Accumulate the volume and advance the ray forward one step
			totalVolume += slice * perIteration;
			p += deltaRay;
		}
		return lerp(_TintColor1, _TintColor2, totalVolume);
	}

	ENDCG
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
			"Queue" = "Geometry"
			"VRCFallback" = "Toon"
		}

		Pass
		{
			Cull[_Cull]
			ZWrite[_ZWrite]
			Ztest[_ZTest]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;

			};
			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 posWorld : TEXCOORD0;
				//float4 posObj : TEXCOORD1;
				// position of the vertex (and fragment) in world space 
				float2 tex : TEXCOORD2;
				// float4 cameraPositionTangent : TEXCOORD3;
				float3 tangentSpaceCameraPos : TEXCOORD3;
				float3 tangentSpacePos : TEXCOORD4;
				//float3 tangentWorld : TEXCOORD3;
				//float3 normalWorld : TEXCOORD4;
				//float3 binormalWorld : TEXCOORD5;
				float4 TangentToWorldX : TEXCOORD5;
				float4 TangentToWorldY : TEXCOORD6;
				float4 TangentToWorldZ : TEXCOORD7;
				float  depth : TEXCOORD8;
			};
			//CustomEditor "Scootoon_2Editor"
			v2f vert (appdata v)
			{
				v2f output;
				// o.pos = UnityObjectToClipPos(v.vertex);
				output.pos = UnityObjectToClipPos(v.vertex);
				output.tex = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				output.posWorld = mul(unity_ObjectToWorld,v.vertex);
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
   
                output.TangentToWorldX = float4(worldTangent.x, worldBinormal.x, worldNormal.x, output.posWorld.x);
                output.TangentToWorldY = float4(worldTangent.y, worldBinormal.y, worldNormal.y, output.posWorld.y);
                output.TangentToWorldZ = float4(worldTangent.z, worldBinormal.z, worldNormal.z, output.posWorld.z);
				
				output.depth = COMPUTE_DEPTH_01;
				
				return output;
			}

			float4 frag (v2f input) : SV_Target
			{
				float4 encodedNormal = tex2D(_NormalMap,input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
				//807fff
				encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
				encodedNormal = lerp(float4(0.5, 0.5, 0.5, 1), encodedNormal, _NormalStrength);


			    float3 worldPos = float3(input.TangentToWorldX.w,input.TangentToWorldY.w,input.TangentToWorldZ.w);

			    float depth = 1-input.depth;
			
				float3 normTangent = UnpackScaleNormal( encodedNormal, _NormalStrength );
				
				float3 normWorld = normalize( float3( dot(input.TangentToWorldX.xyz, normTangent), dot(input.TangentToWorldY.xyz, normTangent), dot(input.TangentToWorldZ.xyz, normTangent) ) );
				
				return float4(normWorld.rgb*0.5+0.5, depth);
			}
			ENDCG
		}
	}
}