// jave.lin :  Reference resources ：https://medium.com/playkids-tech-blog/matcap-render-art-pipeline-optimization-for-mobile-devices-4e1a520b9f1a
//  It's too simple 
//  The principle is ： take   Convert normals to  ViewSpace, And then  ViewSpace  Normal under  [-1~1]  To  [0~1]
// also utilized matcap method used by lilToon shaders

Shader "MatCap1"
{

	Properties
	{
		_MainTex("Diffuse (RGB)", 2D) = "white" {}
		_MatCap("MatCap (RGB)", 2D) = "gray" {}
		[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
		_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1
	}

	CGINCLUDE

	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "AutoLight.cginc"

	uniform sampler2D _MainTex;
	uniform sampler2D _MatCap;
	uniform float4 _MainTex_ST;
	uniform float4 _MatCap_ST;

	uniform sampler2D _NormalMap;
	uniform float _NormalStrength;

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

//	float3 cameraDirection()
//	{
//#if defined(USING_STEREO_MATRICES)
//		return normalize(LIL_STEREO_MATRIX_V(0)._m20_m21_m22 + LIL_STEREO_MATRIX_V(1)._m20_m21_m22);
//#else
//		return UNITY_MATRIX_V._m20_m21_m22;
//#endif
	//}

	ENDCG
	Subshader
	{

		Tags {
		"Queue" = "Geometry" "RenderType" = "Opaque" }

		Pass
		{
			//Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

	

			struct vertexInput
			{
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float4 posWorld : TEXCOORD0;
				// position of the vertex (and fragment) in world space 
				float4 tex : TEXCOORD1;
				float3 tangentWorld : TEXCOORD2;
				float3 normalWorld : TEXCOORD3;
				float3 binormalWorld : TEXCOORD4;
				fixed3 vLight : COLOR;

				//LIGHTING_COORDS(5, 6)
				UNITY_LIGHTING_COORDS(5, 6)
					//V2F_SHADOW_CASTER
			};

			vertexOutput vert(vertexInput input)
			{

				vertexOutput output;

				float4x4 modelMatrix = unity_ObjectToWorld;
				float4x4 modelMatrixInverse = unity_WorldToObject;

				output.tangentWorld = normalize(
					mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
				output.normalWorld = normalize(
					mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
				output.binormalWorld = normalize(
					cross(output.normalWorld, output.tangentWorld)
					* input.tangent.w); // tangent.w is specific to Unity

				//output.posWorld = mul(modelMatrix, input.vertex);
				output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
				output.tex = input.texcoord;
				output.pos = UnityObjectToClipPos(input.vertex);
				//float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
				//half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
				half3 worldN = UnityObjectToWorldNormal(input.normal);
				half3 shlight = ShadeSH9(float4(worldN, 1.0));
				output.vLight = shlight;

				return output;
			}

			float4 frag(vertexOutput input) : COLOR
			{

				float4 encodedNormal = tex2D(_NormalMap,input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
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


				float3 headDirection;

#if defined(USING_STEREO_MATRICES)
				//float x = _XRWorldSpaceCameraPos[i](0).xyz
				headDirection = normalize(_XRWorldSpaceCameraPos[i](0).xyz + _XRWorldSpaceCameraPos[i](1).xyz * 0.5) - posWorld;
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
				
				matCapUV = matCapUV * _MatCap_ST.xy + _MatCap_ST.zw;

				matCapUV = matCapUV * 0.5 + 0.5;

				//float4 albedo = tex2D(_MainTex, input.tex.xy);
				float4 MatCap = tex2D(_MatCap, matCapUV);
				//return float4(headDirection,1);
				return MatCap;
			}
			ENDCG
		}
	}
}