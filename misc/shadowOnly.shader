Shader "shadowOnly"
{

	//currently ongoing test to get shadows only (no diffuse,lighting)
	//anything not covered in shadow has reduced alpha (transparency)

	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
		[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
		_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1

		_DiffColor("Diffuse Material Color", Color) = (1,1,1,1)


		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"

		// User-specified properties
	    sampler2D _MainTex;
		uniform float _Brightness;
		uniform float4 _MainTex_ST;

		uniform sampler2D _NormalMap;
		uniform float _NormalStrength;
		
		uniform float4 _DiffColor;

	   ENDCG
	   SubShader
	   {
		  Tags
		  {
			  "Queue" = "Geometry"
			  "RenderType" = "Transparent"
			  "IgnoreProjector" = "True"
		      "VRCFallback" = "Toon"
		  }

		  Pass
		  {
			  //AlphaToMask On
			  Cull[_Cull]
			  ZWrite[_ZWrite]
			  Ztest[_Ztest]		
			  Blend Zero OneMinusSrcAlpha // multiplicative blending 
			  //Blend SrcAlpha OneMinusSrcAlpha // standard alpha blending
			  //ZWrite On
			  //Ztest LEqual

			  CGPROGRAM
			  #pragma vertex vert
			  #pragma fragment frag

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
				  float4 posObj : TEXCOORD1;
				  // position of the vertex (and fragment) in world space 
				  float4 tex : TEXCOORD2;
				  float3 tangentWorld : TEXCOORD3;
				  float3 normalWorld : TEXCOORD4;
				  float3 binormalWorld : TEXCOORD5;
				  fixed3 vLight : COLOR;

				  LIGHTING_COORDS(5, 6)
			  };
			  //CustomEditor "Scootoon_2Editor"
			  v2f vert(appdata input)
			  {
					v2f output;

					float4x4 modelMatrix = unity_ObjectToWorld;
					float4x4 modelMatrixInverse = unity_WorldToObject;

					output.tangentWorld = normalize(
						mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
					output.normalWorld = normalize(
						mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
					output.binormalWorld = normalize(
						cross(output.normalWorld, output.tangentWorld)
						* input.tangent.w); // tangent.w is specific to Unity

					////output.posWorld = mul(modelMatrix, input.vertex);
					//output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
					output.posObj = input.vertex;
					//float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					//half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					half3 worldN = UnityObjectToWorldNormal(input.normal);
					half3 shlight = ShadeSH9(float4(worldN, 1.0));
					output.vLight = shlight;
					TRANSFER_SHADOW(output);
					TRANSFER_VERTEX_TO_FRAGMENT(output);

					return output;
			  }

			  float4 frag(v2f input) : COLOR
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

					float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);
					float3 lightDirection;

					//float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

#ifdef USING_DIRECTIONAL_LIGHT
					//lightDirection = _WorldSpaceLightPos0;
#else
					//lightDirection = _WorldSpaceLightPos0 - input.posWorld;
#endif
					UNITY_LIGHT_ATTENUATION(attenuation, input, input.posWorld.xyz);
					if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					{
						//attenuation = 1.0; // no attenuation
						//lightDirection = normalize(_WorldSpaceLightPos0.xyz);
						lightDirection = viewDirection;
					}
					else // point or spot light
					{
						//float3 vertexToLightSource =
						//	_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
						//float distance = length(vertexToLightSource);
						////attenuation = 1.0 / distance; // linear attenuation 
						//lightDirection = normalize(vertexToLightSource);
						lightDirection = viewDirection;
					}

					//attenuation = LIGHT_ATTENUATION(input);

					//float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb * _DiffColor.rgb;

					float3 diffuseReflection = attenuation * float3(1,1,1) * _DiffColor.rgb * max(0.0, dot(normalDirection, lightDirection));

					//float4 lightProbeLighting;
					//lightProbeLighting.rgb = input.vLight;

					half4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

					float alpha = lerp(0, 1, (diffuseReflection.r + diffuseReflection.b + diffuseReflection.g) / 3);
	
					return float4(diffuseReflection, alpha);
			  }
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